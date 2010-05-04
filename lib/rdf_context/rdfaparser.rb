require File.join(File.dirname(__FILE__), 'parser')

module RdfContext
  ##
  # An RDFa parser in Ruby
  #
  # Based on processing rules described here:
  #   file:///Users/gregg/Projects/rdf_context/RDFa%20Core%201.1.html#sequence
  #
  # Ben Adida
  # 2008-05-07
  # Gregg Kellogg
  # 2009-08-04
  class RdfaParser < Parser
    # Host language, One of:
    #   :xhtml_rdfa_1_0
    #   :xhtml_rdfa_1_1
    attr_reader :host_language
    
    # The Recursive Baggage
    class EvaluationContext # :nodoc:
      # The base. This will usually be the URL of the document being processed,
      # but it could be some other URL, set by some other mechanism,
      # such as the (X)HTML base element. The important thing is that it establishes
      # a URL against which relative paths can be resolved.
      attr :base, true
      # The parent subject.
      # The initial value will be the same as the initial value of base,
      # but it will usually change during the course of processing.
      attr :parent_subject, true
      # The parent object.
      # In some situations the object of a statement becomes the subject of any nested statements,
      # and this property is used to convey this value.
      # Note that this value may be a bnode, since in some situations a number of nested statements
      # are grouped together on one bnode.
      # This means that the bnode must be set in the containing statement and passed down,
      # and this property is used to convey this value.
      attr :parent_object, true
      # A list of current, in-scope URI mappings.
      attr :uri_mappings, true
      # A list of incomplete triples. A triple can be incomplete when no object resource
      # is provided alongside a predicate that requires a resource (i.e., @rel or @rev).
      # The triples can be completed when a resource becomes available,
      # which will be when the next subject is specified (part of the process called chaining).
      attr :incomplete_triples, true
      # The language. Note that there is no default language.
      attr :language, true
      # The term mappings, a list of terms and their associated URIs.
      # This specification does not define an initial list.
      # Host Languages may define an initial list.
      # If a Host Language provides an initial list, it should do so via an RDFa Profile document.
      attr :term_mappings, true
      # The default vocabulary, a value to use as the prefix URI when a term is used.
      # This specification does not define an initial setting for the default vocabulary.
      # Host Languages may define an initial setting.
      attr :default_vocabulary, true

      def initialize(base, host_defaults)
        # Initialize the evaluation context, [5.1]
        @base = base
        @parent_subject = @base
        @parent_object = nil
        @uri_mappings = {}
        @incomplete_triples = []
        @language = nil
        @term_mappings = host_defaults.fetch(:term_mappings, {})
        @default_voabulary = host_defaults.fetch(:voabulary, nil)
      end

      # Copy this Evaluation Context
      def initialize_copy(from)
          # clone the evaluation context correctly
          @uri_mappings = from.uri_mappings.clone
          @incomplete_triples = from.incomplete_triples.clone
      end
      
      def inspect
        v = %w(base parent_subject parent_object language default_vocabulary).map {|a| "#{a}='#{self.send(a).nil? ? '<nil>' : self.send(a)}'"}
        v << "uri_mappings[#{uri_mappings.keys.length}]"
        v << "incomplete_triples[#{incomplete_triples.length}]"
        v << "term_mappings[#{term_mappings.keys.length}]"
        v.join(",")
      end
    end

    ## 
    # Creates a new parser for RDFa.
    #
    # @param [Hash] options:: Options from
    # <em>options[:graph]</em>:: Graph to parse into, otherwise a new RdfContext::Graph instance is created
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:type]</em>:: One of _rdfxml_, _html_, or _n3_
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    def initialize(options = {})
      super
      @@vocabulary_cache ||= {}
    end
    
    # Parse XHTML+RDFa document from a string or input stream to closure or graph.
    #
    # If the parser is called with a block, triples are passed to the block rather
    # than added to the graph.
    #
    # Optionally, the stream may be a Nokogiri::HTML::Document or Nokogiri::XML::Document
    # With a block, yeilds each statement with URIRef, BNode or Literal elements
    #
    # @param  [IO] stream:: the HTML+RDFa IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri:: the URI of the document
    # @param [Hash] options:: Parser options, one of
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph]:: Returns the graph containing parsed triples
    # @raise [Error]:: Raises RdfError if _strict_
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      super

      @doc = case stream
      when Nokogiri::HTML::Document then stream
      when Nokogiri::XML::Document then stream
      else   Nokogiri::XML.parse(stream, uri.to_s)
      end
      
      raise ParserException, "Empty document" if @doc.nil? && @strict
      @callback = block

      # Determine host language
      # XXX - right now only XHTML defined
      @host_language = case @doc.root.attributes["version"].to_s
      when /XHTML+RDFa/ then :xhtml
      end
      
      # If none found, assume xhtml
      @host_language ||= :xhtml
      
      @host_defaults = case @host_language
      when :xhtml
        @graph.bind(XHV_NS)
        {
          :vocabulary => XHV_NS.uri,
          :prefix     => XHV_NS,
          :term_mappings => %w(
            alternate appendix bookmark cite chapter contents copyright first glossary help icon index
            last license meta next p3pv1 prev role section stylesheet subsection start top up
            ).inject({}) { |hash, term| hash[term] = XHV_NS.send("#{term}_"); hash },
        }
      else
        {}
      end
      
      # parse
      parse_whole_document(@doc, @uri)

      @graph
    end
    
    private
  
    # Parsing an RDFa document (this is *not* the recursive method)
    def parse_whole_document(doc, base)
      # find if the document has a base element
      # XXX - HTML specific
      base_el = doc.css('html>head>base').first
      if (base_el)
        base = base_el.attributes['href']
        # Strip any fragment from base
        base = base.to_s.split("#").first
        @uri = URIRef.new(base)
        add_debug(base_el, "parse_whole_doc: base='#{base}'")
      end

      # initialize the evaluation context with the appropriate base
      evaluation_context = EvaluationContext.new(base, @host_defaults)

      traverse(doc.root, evaluation_context)
    end
  
    # Extract the XMLNS mappings from an element
    def extract_mappings(element, uri_mappings, term_mappings)
      # Process @profile
      # Next the current element is parsed for any updates to the local term mappings and
      # local list of URI mappings via @profile.
      # If @profile is present, its value is processed as defined in RDFa Profiles.
      element.attributes['profile'].to_s.split(/\s/).each do |profile|
        # Don't try to open ourselves!
        if @uri == profile
          add_debug(element, "extract_mappings: skip recursive profile <#{profile}>")
          @@vocabulary_cache[profile]
        elsif @@vocabulary_cache.has_key?(profile)
          add_debug(element, "extract_mappings: skip previously parsed profile <#{profile}>")
        else
          begin
            add_debug(element, "extract_mappings: parse profile <#{profile}>")
            @@vocabulary_cache[profile] = {
              :uri_mappings => {},
              :term_mappings => {}
            }
            um = @@vocabulary_cache[profile][:uri_mappings]
            tm = @@vocabulary_cache[profile][:term_mappings]
            add_debug(element, "extract_mappings: profile open <#{profile}>")
            require 'patron' unless defined?(Patron)
            sess = Patron::Session.new
            sess.timeout = 10
            resp = sess.get(profile)
            raise RuntimeError, "HTTP returned status #{resp.status} when reading #{profile}" if resp.status >= 400
      
            # Parse profile, and extract mappings from graph
            old_debug, old_verbose, = $DEBUG, $verbose
            $DEBUG, $verbose = false, false
            p_graph = Parser.parse(resp.body, profile)
            ttl = p_graph.serialize(:format => :ttl) if old_debug
            $DEBUG, $verbose = old_debug, old_verbose
            add_debug(element, ttl) if ttl
            p_graph.subjects.each do |subject|
              props = p_graph.properties(subject)
              #puts props.inspect
              
              # If one of the objects is not a Literal or if there are additional rdfa:uri or rdfa:term
              # predicates sharing the same subject, no mapping is created.
              uri = props[RDFA_NS.uri_.to_s]
              term = props[RDFA_NS.term_.to_s]
              prefix = props[RDFA_NS.prefix_.to_s]
              add_debug(element, "extract_mappings: uri=#{uri.inspect}, term=#{term.inspect}, prefix=#{prefix.inspect}")
          
              next if !uri || (!term && !prefix)
              raise ParserException, "multi-valued rdf:uri" if uri.length != 1
              raise ParserException, "multi-valued rdf:term." if term && term.length != 1
              raise ParserException, "multi-valued rdf:prefix" if prefix && prefix.length != 1
            
              uri = uri.first
              term = term.first if term
              prefix = prefix.first if prefix
              raise ParserException, "rdf:uri must be a Literal" unless uri.is_a?(Literal)
              raise ParserException, "rdf:term must be a Literal" unless term.nil? || term.is_a?(Literal)
              raise ParserException, "rdf:prefix must be a Literal" unless prefix.nil? || prefix.is_a?(Literal)
            
              # For every extracted triple that is the common subject of an rdfa:prefix and an rdfa:uri
              # predicate, create a mapping from the object literal of the rdfa:prefix predicate to the
              # object literal of the rdfa:uri predicate. Add or update this mapping in the local list of
              # URI mappings after transforming the 'prefix' component to lower-case.
              # For every extracted
              um[prefix.to_s.downcase] = @graph.bind(Namespace.new(uri.to_s, prefix.to_s.downcase)) if prefix
            
              # triple that is the common subject of an rdfa:term and an rdfa:uri predicate, create a
              # mapping from the object literal of the rdfa:term predicate to the object literal of the
              # rdfa:uri predicate. Add or update this mapping in the local term mappings.
              tm[term.to_s] = URIRef.new(uri.to_s) if term
            end
          rescue ParserException
            add_debug(element, "extract_mappings: profile subject #{subject.to_s}: #{e.message}")
            raise if @strict
          rescue RuntimeError => e
            add_debug(element, "extract_mappings: profile: #{e.message}")
            raise if @strict
          end
        end
        
        # Merge mappings from this vocabulary
        uri_mappings.merge!(@@vocabulary_cache[profile][:uri_mappings])
        term_mappings.merge!(@@vocabulary_cache[profile][:term_mappings])
      end
      
      # look for xmlns
      # (note, this may be dependent on @host_language)
      # Regardless of how the mapping is declared, the value to be mapped must be converted to lower case,
      # and the URI is not processed in any way; in particular if it is a relative path it is
      # not resolved against the current base.
      element.namespaces.each do |attr_name, attr_value|
        begin
          abbr, prefix = attr_name.split(":")
          uri_mappings[prefix.to_s.downcase] = @graph.bind(Namespace.new(attr_value, prefix.to_s.downcase)) if abbr.downcase == "xmlns"
        rescue RdfException => e
          add_debug(element, "extract_mappings raised #{e.class}: #{e.message}")
          raise if @strict
        end
      end

      # Set mappings from @prefix
      # prefix is a whitespace separated list of prefix-name URI pairs of the form
      #   NCName ':' ' '+ xs:anyURI
      # SPEC Confusion: prefix is forced to lower-case in @profile, but not specified here.
      element.attributes["prefix"].to_s.split(/[^:]\s+/).each do |pair|
        #puts "uri_mappings prefix #{pair}, #{element.attributes["prefix"]}"
        prefix, uri = pair.split(': ')
        prefix = prefix.downcase
        
        uri_mappings[prefix] = @graph.bind(Namespace.new(uri, prefix))
      end
      
      add_debug(element, "uri_mappings: #{uri_mappings.values.map{|ns|ns.to_s}.join(", ")}")
      add_debug(element, "term_mappings: #{term_mappings.keys.join(", ")}")
    end

    # The recursive helper function
    def traverse(element, evaluation_context)
      if element.nil?
        add_debug(element, "traverse nil element")
        raise ParserException, "Can't parse nil element" if @strict
        return nil
      end
      
      add_debug(element, "traverse, ec: #{evaluation_context.inspect}")

      # local variables [5.5 Step 1]
      recurse = true
      skip = false
      new_subject = nil
      current_object_resource = nil
      uri_mappings = evaluation_context.uri_mappings.clone
      incomplete_triples = []
      language = evaluation_context.language
      term_mappings = evaluation_context.term_mappings.clone
      default_vocabulary = evaluation_context.default_vocabulary

      current_object_literal = nil  # XXX Not explicit
    
      # shortcut
      attrs = element.attributes

      about = attrs['about']
      src = attrs['src']
      resource = attrs['resource']
      href = attrs['href']
      vocab = attrs['vocab']

      # Pull out the attributes needed for the skip test.
      property = attrs['property'].to_s if attrs['property']
      typeof = attrs['typeof'].to_s if attrs['typeof']
      datatype = attrs['datatype'].to_s if attrs['datatype']
      content = attrs['content'].to_s if attrs['content']
      rel = attrs['rel'].to_s if attrs['rel']
      rev = attrs['rev'].to_s if attrs['rev']

      # Default vocabulary [7.5 Step 2]
      # First the current element is examined for any change to the default vocabulary via @vocab.
      # If @vocab is present and contains a value, its value updates the local default vocabulary.
      # If the value is empty, then the local default vocabulary must be reset to the Host Language defined default.
      unless vocab.nil?
        default_vocabulary = if vocab.to_s.empty?
          # Set default_vocabulary to host language default
          @host_defaults.fetch(:voabulary, nil)
        else
          vocab.to_s
        end
        add_debug(element, "traverse, default_vocaulary: #{default_vocabulary.inspect}")
      end
      
      # Local term mappings [7.5 Steps 3 & 4]
      # Next the current element is parsed for any updates to the local term mappings and local list of URI mappings via @profile.
      # If @profile is present, its value is processed as defined in RDFa Profiles.
      extract_mappings(element, uri_mappings, term_mappings)
    
      # Language information [7.5 Step 5]
      # From HTML5 [3.2.3.3]
      #   If both the lang attribute in no namespace and the lang attribute in the XML namespace are set
      #   on an element, user agents must use the lang attribute in the XML namespace, and the lang
      #   attribute in no namespace must be ignored for the purposes of determining the element's
      #   language.
      language = case
      when element.at_xpath("@xml:lang", "xml" => XML_NS.uri.to_s)
        element.at_xpath("@xml:lang", "xml" => XML_NS.uri.to_s).to_s
      when element.at_xpath("lang")
        element.at_xpath("lang").to_s
      else
        language
      end
      add_debug(element, "traverse, lang: #{language}") if attrs['lang']
    
      # rels and revs
      rels = process_uris(element, rel, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary)
      revs = process_uris(element, rev, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary)
    
      add_debug(element, "traverse, about: #{about.nil? ? 'nil' : about}, src: #{src.nil? ? 'nil' : src}, resource: #{resource.nil? ? 'nil' : resource}, href: #{href.nil? ? 'nil' : href}")
      add_debug(element, "traverse, property: #{property.nil? ? 'nil' : property}, typeof: #{typeof.nil? ? 'nil' : typeof}, datatype: #{datatype.nil? ? 'nil' : datatype}, content: #{content.nil? ? 'nil' : content}")
      add_debug(element, "traverse, rels: #{rels.join(" ")}, revs: #{revs.join(" ")}")

      if not rel || rev
        # Establishing a new subject if no rel/rev [7.5 Step 6]
        # May not be valid, but can exist
        if about
          new_subject = process_uri(element, about, evaluation_context, :uri_mappings => uri_mappings)
        elsif src
          new_subject = process_uri(element, about, evaluation_context)
        elsif resource
          new_subject =  process_uri(element, resource, evaluation_context, :uri_mappings => uri_mappings)
        elsif href
          new_subject = process_uri(element, about, evaluation_context)
        end

        # If no URI is provided by a resource attribute, then the first match from the following rules
        # will apply:
        #   if @typeof is present, then new subject is set to be a newly created bnode.
        # otherwise,
        #   if parent object is present, new subject is set to the value of parent object.
        # Additionally, if @property is not present then the skip element flag is set to 'true';
        if new_subject.nil?
          if @host_language == :xhtml && element.name =~ /^(head|body)$/ && evaluation_context.base
            # From XHTML+RDFa 1.1:
            # if no URI is provided, then first check to see if the element is the head or body element.
            # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
            new_subject = URIRef.new(evaluation_context.base)
          elsif element.attributes['typeof']
            new_subject = BNode.new
          else
            # if it's null, it's null and nothing changes
            new_subject = evaluation_context.parent_object
            skip = true unless property
          end
        end
        add_debug(element, "new_subject: #{new_subject}, skip = #{skip}")
      else
        # [7.5 Step 7]
        # If the current element does contain a @rel or @rev attribute, then the next step is to
        # establish both a value for new subject and a value for current object resource:
        if about
          new_subject =  process_uri(element, about, evaluation_context, :uri_mappings => uri_mappings)
        elsif src
          new_subject =  process_uri(element, src, evaluation_context, :uri_mappings => uri_mappings)
        end
      
        # If no URI is provided then the first match from the following rules will apply
        if new_subject.nil?
          if @host_language == :xhtml && element.name =~ /^(head|body)$/
            # From XHTML+RDFa 1.1:
            # if no URI is provided, then first check to see if the element is the head or body element.
            # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
            new_subject = URIRef.new(evaluation_context.base)
          elsif element.attributes['typeof']
            new_subject = BNode.new
          else
            # if it's null, it's null and nothing changes
            new_subject = evaluation_context.parent_object
            # no skip flag set this time
          end
        end
      
        # Then the current object resource is set to the URI obtained from the first match from the following rules:
        if resource
          current_object_resource =  process_uri(element, resource, evaluation_context, :uri_mappings => uri_mappings)
        elsif href
          current_object_resource = process_uri(element, href, evaluation_context)
        end

        add_debug(element, "new_subject: #{new_subject}, current_object_resource = #{current_object_resource.nil? ? 'nil' : current_object_resource}")
      end
    
      # Process @typeof if there is a subject [Step 8]
      if new_subject and typeof
        # Typeof is TERMorCURIEorURIs
        types = process_uris(element, typeof, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary)
        add_debug(element, "typeof: #{typeof}")
        types.each do |one_type|
          add_triple(element, new_subject, RDF_TYPE, one_type)
        end
      end
    
      # Generate triples with given object [Step 9]
      if current_object_resource
        rels.each do |r|
          add_triple(element, new_subject, r, current_object_resource)
        end
      
        revs.each do |r|
          add_triple(element, current_object_resource, r, new_subject)
        end
      elsif rel || rev
        # Incomplete triples and bnode creation [Step 10]
        add_debug(element, "incompletes: rels: #{rels}, revs: #{revs}")
        current_object_resource = BNode.new
      
        rels.each do |r|
          incomplete_triples << {:predicate => r, :direction => :forward}
        end
      
        revs.each do |r|
          incomplete_triples << {:predicate => r, :direction => :reverse}
        end
      end
    
      # Establish current object literal [Step 11]
      if property
        properties = process_uris(element, property, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary)

        # get the literal datatype
        type = datatype
        children_node_types = element.children.collect{|c| c.class}.uniq
      
        # the following 3 IF clauses should be mutually exclusive. Written as is to prevent extensive indentation.
        type_resource = process_uri(element, type, evaluation_context, :uri_mappings => uri_mappings, :term_mappings => term_mappings, :vocab => default_vocabulary) if type
        if type and !type.empty? and (type_resource.to_s != XML_LITERAL.to_s)
          # typed literal
          add_debug(element, "typed literal")
          current_object_literal = Literal.typed(content || element.inner_text, type_resource, :language => language)
        elsif content or (children_node_types == [Nokogiri::XML::Text]) or (element.children.length == 0) or (type == '')
          # plain literal
          add_debug(element, "plain literal")
          current_object_literal = Literal.untyped(content || element.inner_text, language)
        elsif children_node_types != [Nokogiri::XML::Text] and (type == nil or type_resource.to_s == XML_LITERAL.to_s)
          # XML Literal
          add_debug(element, "XML Literal: #{element.inner_html}")
          current_object_literal = Literal.typed(element.children, XML_LITERAL, :language => language, :namespaces => uri_mappings)
          recurse = false
        end
      
        # add each property
        properties.each do |p|
          add_triple(element, new_subject, p, current_object_literal)
        end
        # SPEC CONFUSION: "the triple has been created" ==> there may be more than one
        # set the recurse flag above in the IF about xmlliteral, as it is the only place that can happen
      end
    
      if not skip and new_subject && !evaluation_context.incomplete_triples.empty?
        # Complete the incomplete triples from the evaluation context [Step 12]
        add_debug(element, "complete incomplete triples: new_subject=#{new_subject}, completes=#{evaluation_context.incomplete_triples.inspect}")
        evaluation_context.incomplete_triples.each do |trip|
          if trip[:direction] == :forward
            add_triple(element, evaluation_context.parent_subject, trip[:predicate], new_subject)
          elsif trip[:direction] == :reverse
            add_triple(element, new_subject, trip[:predicate], evaluation_context.parent_subject)
          end
        end
      end

      # Create a new evaluation context and proceed recursively [Step 13]
      if recurse
        if skip
          if language == evaluation_context.language &&
              uri_mappings == evaluation_context.uri_mappings &&
              term_mappings == evaluation_context.term_mappings &&
              default_vocabulary == evaluation_context.default_vocabulary &&
            new_ec = evaluation_context
            add_debug(element, "skip: reused ec")
          else
            new_ec = evaluation_context.clone
            new_ec.language = language
            new_ec.uri_mappings = uri_mappings
            new_ec.term_mappings = term_mappings
            new_ec.default_vocabulary = default_vocabulary
            add_debug(element, "skip: cloned ec")
          end
        else
          # create a new evaluation context
          new_ec = EvaluationContext.new(evaluation_context.base, @host_defaults)
          new_ec.parent_subject = new_subject || evaluation_context.parent_subject
          new_ec.parent_object = current_object_resource || new_subject || evaluation_context.parent_subject
          new_ec.uri_mappings = uri_mappings
          new_ec.incomplete_triples = incomplete_triples
          new_ec.language = language
          new_ec.term_mappings = term_mappings
          new_ec.default_vocabulary = default_vocabulary
          add_debug(element, "new ec")
        end
      
        element.children.each do |child|
          # recurse only if it's an element
          traverse(child, new_ec) if child.class == Nokogiri::XML::Element
        end
      end
    end

    # space-separated TERMorCURIEorURI
    def process_uris(element, value, evaluation_context, options)
      return [] if value.to_s.empty?
      add_debug(element, "process_uris: #{value}")
      value.to_s.split(/\s+/).map {|v| process_uri(element, v, evaluation_context, options)}.compact
    end

    def process_uri(element, value, evaluation_context, options = {})
      return if value.to_s.empty?
      #add_debug(element, "process_uri: #{value}")
      options = {:uri_mappings => {}}.merge(options)
      if !options[:term_mappings] && options[:uri_mappings] && value.to_s.match(/^\[(.*)\]$/)
        # SafeCURIEorCURIEorURI
        # When the value is surrounded by square brackets, then the content within the brackets is
        # evaluated as a CURIE according to the CURIE Syntax definition. If it is not a valid CURIE, the
        # value must be ignored.
        uri = curie_to_resource_or_bnode($1, options[:uri_mappings], evaluation_context.parent_subject)
        add_debug(element, "process_uri: #{value} => safeCURIE => <#{uri}>")
        uri
      elsif options[:term_mappings] && NC_REGEXP.match(value.to_s)
        # TERMorCURIEorURI
        # If the value is an NCName, then it is evaluated as a term according to General Use of Terms in
        # Attributes. Note that this step may mean that the value is to be ignored.
        uri = process_term(value.to_s, options)
        add_debug(element, "process_uri: #{value} => term => <#{uri}>")
        uri
      else
        # SafeCURIEorCURIEorURI or TERMorCURIEorURI
        # Otherwise, the value is evaluated as a CURIE.
        # If it is a valid CURIE, the resulting URI is used; otherwise, the value will be processed as a URI.
        uri = curie_to_resource_or_bnode(value, options[:uri_mappings], evaluation_context.parent_subject)
        if uri
          add_debug(element, "process_uri: #{value} => CURIE => <#{uri}>")
        else
          uri = URIRef.new(value, evaluation_context.base)
          add_debug(element, "process_uri: #{value} => URI => <#{uri}>")
        end
        uri
      end
    end
    
    # [7.4.3] General Use of Terms in Attributes
    #
    # @param [String] term:: term
    # @param [Hash] options:: Parser options, one of
    # <em>options[:term_mappings]</em>:: Term mappings
    # <em>options[:vocab]</em>:: Default vocabulary
    def process_term(value, options)
      case
      when options[:term_mappings].is_a?(Hash) && options[:term_mappings].has_key?(value)
        # If the term is in the local term mappings, use the associated URI.
        options[:term_mappings][value]
      when options[:vocab]
        # Otherwise, if there is a local default vocabulary the URI is obtained by concatenating that value and the term.
        options[:vocab] + value
      else
        # Finally, if there is no local default vocabulary, the term has no associated URI and must be ignored.
        nil
      end
    end

    # From section 6. CURIE Syntax Definition
    def curie_to_resource_or_bnode(curie, uri_mappings, subject)
      # URI mappings for CURIEs default to XH_MAPPING, rather than the default doc namespace
      prefix, reference = curie.to_s.split(":")

      # consider the bnode situation
      if curie.to_s.empty?
        add_debug(nil, "curie_to_resource_or_bnode #{subject}, empty CURIE")
        # Empty curie resolves to current subject (No, an empty curie should be ignored)
        #URIRef.new(subject)
        nil
      elsif prefix == "_"
        # we force a non-nil name, otherwise it generates a new name
        BNode.new(reference || "", @named_bnodes)
      elsif curie.to_s.match(/^:/)
        # Default prefix
        case
        when uri_mappings[""]
          uri_mappings[""].send("#{reference}_")
        when @host_defaults[:prefix]
          @host_defaults[:prefix].send("#{reference}_")
        else
          nil
        end
      elsif !curie.to_s.match(/:/)
        # No prefix, undefined (in this context, it is evaluated as a term elsewhere)
        nil
      else
        ns = uri_mappings[prefix.to_s]
        if ns
          ns + reference
        else
          add_debug(nil, "curie_to_resource_or_bnode No namespace mapping for #{prefix}")
          nil
        end
      end
    end
  end
end