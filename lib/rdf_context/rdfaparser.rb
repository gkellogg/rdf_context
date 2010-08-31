require File.join(File.dirname(__FILE__), 'parser')

module RdfContext
  ##
  # An RDFa parser in Ruby
  #
  # Based on processing rules described here:
  # @see http://www.w3.org/TR/rdfa-syntax/#s_model RDFa 1.0
  # @see http://www.w3.org/2010/02/rdfa/drafts/2010/WD-rdfa-core-20100803/ RDFa 1.1
  #
  # @author Ben Adida
  # @author Gregg Kellogg
  class RdfaParser < Parser
    SafeCURIEorCURIEorURI = {
      :rdfa_1_0 => [:term, :safe_curie, :uri, :bnode],
      :rdfa_1_1 => [:safe_curie, :curie, :term, :uri, :bnode],
    }
    TERMorCURIEorAbsURI = {
      :rdfa_1_0 => [:curie],
      :rdfa_1_1 => [:term, :curie, :absuri],
    }

    # Host language
    # @return [:xhtml]
    attr_reader :host_language

    # Version
    # @return [:rdfa_1_0, :rdfa_1_1]
    attr_reader :version
    
    # The Recursive Baggage
    # @private
    class EvaluationContext # :nodoc:
      # The base.
      #
      # This will usually be the URL of the document being processed,
      # but it could be some other URL, set by some other mechanism,
      # such as the (X)HTML base element. The important thing is that it establishes
      # a URL against which relative paths can be resolved.
      #
      # @return [URIRef]
      attr :base, true
      # The parent subject.
      #
      # The initial value will be the same as the initial value of base,
      # but it will usually change during the course of processing.
      #
      # @return [URIRef]
      attr :parent_subject, true
      # The parent object.
      #
      # In some situations the object of a statement becomes the subject of any nested statements,
      # and this property is used to convey this value.
      # Note that this value may be a bnode, since in some situations a number of nested statements
      # are grouped together on one bnode.
      # This means that the bnode must be set in the containing statement and passed down,
      # and this property is used to convey this value.
      #
      # @return URIRef
      attr :parent_object, true
      # A list of current, in-scope URI mappings.
      #
      # @return [Hash{String => Namespace}]
      attr :uri_mappings, true
      # A list of incomplete triples.
      #
      # A triple can be incomplete when no object resource
      # is provided alongside a predicate that requires a resource (i.e., @rel or @rev).
      # The triples can be completed when a resource becomes available,
      # which will be when the next subject is specified (part of the process called chaining).
      #
      # @return [Array<Array<URIRef, Resource>>]
      attr :incomplete_triples, true
      # The language. Note that there is no default language.
      #
      # @return [String]
      attr :language, true
      # The term mappings, a list of terms and their associated URIs.
      #
      # This specification does not define an initial list.
      # Host Languages may define an initial list.
      # If a Host Language provides an initial list, it should do so via an RDFa Profile document.
      #
      # @return [Hash{String => URIRef}]
      attr :term_mappings, true
      # The default vocabulary
      #
      # A value to use as the prefix URI when a term is used.
      # This specification does not define an initial setting for the default vocabulary.
      # Host Languages may define an initial setting.
      #
      # @return [URIRef]
      attr :default_vocabulary, true

      # @param [URIRef] base
      # @param [Hash] host_defaults
      # @option host_defaults [Hash{String => URIRef}] :term_mappings Hash of NCName => URIRef
      # @option host_defaults [Hash{String => Namespace}] :vocabulary Hash of prefix => URIRef
      def initialize(base, host_defaults)
        # Initialize the evaluation context, [5.1]
        @base = base
        @parent_subject = @base
        @parent_object = nil
        @uri_mappings = host_defaults.fetch(:uri_mappings, {}).merge("rdf" => RDF_NS.uri.to_s)
        @incomplete_triples = []
        @language = nil
        @term_mappings = host_defaults.fetch(:term_mappings, {})
        @default_vocabulary = host_defaults.fetch(:vocabulary, nil)
      end

      # Copy this Evaluation Context
      #
      # @param [EvaluationContext] from
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
    # @option options [Graph] :graph (nil) Graph to parse into, otherwise a new RdfContext::Graph instance is created
    # @option options [Graph] :processor_graph (nil) Graph to record information, warnings and errors.
    # @option options [Array] :debug (nil) Array to place debug messages
    # @option options [:rdfxml, :html, :n3] :type (nil)
    # @option options [Boolean] :strict (false) Raise Error if true, continue with lax parsing, otherwise
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
    # @param  [Nokogiri::HTML::Document, Nokogiri::XML::Document, #read, #to_s] stream the HTML+RDFa IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri (nil) the URI of the document
    # @option options [Array] :debug (nil) Array to place debug messages
    # @option options [:rdfa_1_0, :rdfa_1_1] :version (:rdfa_1_1) Parser version information
    # @option options [:xhtml] :host_language (:xhtml) Host Language
    # @option options [Boolean] :strict (false) Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph] Returns the graph containing parsed triples
    # @yield  [triple]
    # @yieldparam [Triple] triple
    # @raise [Error]:: Raises RdfError if _strict_
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      super

      @doc = case stream
      when Nokogiri::HTML::Document then stream
      when Nokogiri::XML::Document then stream
      else   Nokogiri::XML.parse(stream, uri.to_s)
      end
      
      add_error(nil, "Empty document", RDFA_NS.HostLanguageMarkupError) if @doc.nil?
      add_warning(nil, "Synax errors:\n#{@doc.errors}", RDFA_NS.HostLanguageMarkupError) unless @doc.errors.empty?
      
      @callback = block

      @version = options[:version] ? options[:version].to_sym : :rdfa_1_1
      @host_language = options[:host_language] || :xhtml

      # Section 4.2 RDFa Host Language Conformance
      #
      # The Host Language may define a default RDFa Profile. If it does, the RDFa Profile triples that establish term or
      # URI mappings associated with that profile must not change without changing the profile URI. RDFa Processors may
      # embed, cache, or retrieve the RDFa Profile triples associated with that profile.
      @host_defaults = case @host_language
      when :xhtml
        @graph.bind(XHV_NS)
        {
          :vocabulary => XHV_NS.uri,
          :prefix     => XHV_NS,
          :uri_mappings => {"xhv" => XHV_NS}, # RDF::XHTML is wrong
          :term_mappings => %w(
            alternate appendix bookmark cite chapter contents copyright first glossary help icon index
            last license meta next p3pv1 prev role section stylesheet subsection start top up
            ).inject({}) { |hash, term| hash[term] = XHV_NS.send("#{term}_"); hash },
        }
      else
        {}
      end

      @host_defaults.delete(:vocabulary) if @version == :rdfa_1_0
      
      add_debug(@doc.root, "version = #{@version.inspect},  host_language = #{@host_language}")
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
        @uri = URIRef.intern(base, :normalize => false, :normalize => false)
        add_debug(base_el, "parse_whole_doc: base='#{base}'")
      end

      # initialize the evaluation context with the appropriate base
      evaluation_context = EvaluationContext.new(@uri, @host_defaults)

      traverse(doc.root, evaluation_context)
    end
  
    # Parse and process URI mappings, Term mappings and a default vocabulary from @profile
    #
    # Yields each mapping
    def process_profile(element)
      element.attributes['profile'].to_s.split(/\s/).reverse.each do |profile|
        # Don't try to open ourselves!
        if @uri == profile
          add_debug(element, "process_profile: skip recursive profile <#{profile}>")
        elsif @@vocabulary_cache.has_key?(profile)
          add_debug(element, "process_profile: skip previously parsed profile <#{profile}>")
        else
          begin
            add_debug(element, "process_profile: parse profile <#{profile}>")
            @@vocabulary_cache[profile] = {
              :uri_mappings => {},
              :term_mappings => {},
              :default_vocabulary => nil
            }
            um = @@vocabulary_cache[profile][:uri_mappings]
            tm = @@vocabulary_cache[profile][:term_mappings]
            add_debug(element, "process_profile: profile open <#{profile}>")
            require 'patron' unless defined?(Patron)
            sess = Patron::Session.new
            sess.timeout = 10
            resp = sess.get(profile)
            raise ParserException, "Empty document" if resp.status >= 400 && @strict
      
            # Parse profile, and extract mappings from graph
            old_debug, old_verbose, = $DEBUG, $verbose
            $DEBUG, $verbose = false, false
            p_graph = Parser.parse(resp.body, profile)
            ttl = p_graph.serialize(:format => :ttl) if @debug || $DEBUG
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
              vocab = props[RDFA_NS.vocabulary.to_s]
              add_debug(element, "process_profile: uri=#{uri.inspect}, term=#{term.inspect}, prefix=#{prefix.inspect}, vocabulary=#{vocab.inspect}")

              raise ParserException, "multi-valued rdf:uri" if uri && uri.length != 1
              raise ParserException, "multi-valued rdf:term." if term && term.length != 1
              raise ParserException, "multi-valued rdf:prefix" if prefix && prefix.length != 1
              raise ParserException, "multi-valued rdf:vocabulary" if vocab && vocab.length != 1
            
              uri = uri.first if uri
              term = term.first if term
              prefix = prefix.first if prefix
              vocab = vocab.first if vocab
              raise ParserException, "rdf:uri #{uri.inspect} must be a Literal" unless uri.nil? || uri.is_a?(Literal)
              raise ParserException, "rdf:term #{term.inspect} must be a Literal" unless term.nil? || term.is_a?(Literal)
              raise ParserException, "rdf:prefix #{prefix.inspect} must be a Literal" unless prefix.nil? || prefix.is_a?(Literal)
              raise ParserException, "rdf:vocabulary #{vocab.inspect} must be a Literal" unless vocab.nil? || vocab.is_a?(Literal)

              @@vocabulary_cache[profile][:default_vocabulary] = vocab if vocab
              
              # For every extracted triple that is the common subject of an rdfa:prefix and an rdfa:uri
              # predicate, create a mapping from the object literal of the rdfa:prefix predicate to the
              # object literal of the rdfa:uri predicate. Add or update this mapping in the local list of
              # URI mappings after transforming the 'prefix' component to lower-case.
              # For every extracted
              um[prefix.to_s.downcase] = @graph.bind(Namespace.new(uri.to_s, prefix.to_s.downcase)) if prefix && prefix.to_s != "_"
            
              # triple that is the common subject of an rdfa:term and an rdfa:uri predicate, create a
              # mapping from the object literal of the rdfa:term predicate to the object literal of the
              # rdfa:uri predicate. Add or update this mapping in the local term mappings.
              tm[term.to_s.downcase] = URIRef.intern(uri.to_s, :normalize => false) if term
            end
          rescue ParserException => e
            add_error(element, e.message, RDFA_NS.ProfileReferenceError)
            raise # Incase we're not in strict mode, we need to be sure processing stops
          end
        end
        profile_mappings = @@vocabulary_cache[profile]
        yield :uri_mappings, profile_mappings[:uri_mappings] unless profile_mappings[:uri_mappings].empty?
        yield :term_mappings, profile_mappings[:term_mappings] unless profile_mappings[:term_mappings].empty?
        yield :default_vocabulary, profile_mappings[:default_vocabulary] if profile_mappings[:default_vocabulary]
      end
    end

    # Extract the XMLNS mappings from an element
    def extract_mappings(element, uri_mappings)
      # look for xmlns
      # (note, this may be dependent on @host_language)
      # Regardless of how the mapping is declared, the value to be mapped must be converted to lower case,
      # and the URI is not processed in any way; in particular if it is a relative path it is
      # not resolved against the current base.
      element.namespace_definitions.each do |ns|
        add_debug(element, "extract_mappings: namespace #{ns.prefix} => <#{ns.href}>")
        begin
          # A Conforming RDFa Processor must ignore any definition of a mapping for the '_' prefix.
          next if ns.prefix == "_"

          # Downcase prefix for RDFa 1.1
          pfx_lc = (@version == :rdfa_1_0 || ns.prefix.nil?) ? ns.prefix : ns.prefix.to_s.downcase
          if ns.prefix
            uri_mappings[pfx_lc] = @graph.bind(Namespace.new(ns.href, ns.prefix.to_s))
            add_debug(element, "extract_mappings: xmlns:#{ns.prefix} => <#{ns.href}>")
          end
          
        rescue RdfException => e
          add_error(element, "extract_mappings raised #{e.class}: #{e.message}")
        end
      end

      # Set mappings from @prefix
      # prefix is a whitespace separated list of prefix-name URI pairs of the form
      #   NCName ':' ' '+ xs:anyURI
      # SPEC Confusion: prefix is forced to lower-case in @profile, but not specified here.
      mappings = element.attributes["prefix"].to_s.split(/\s+/)
      while mappings.length > 0 do
        prefix, uri = mappings.shift.downcase, mappings.shift
        #puts "uri_mappings prefix #{prefix} <#{uri}>"
        next unless prefix.match(/:$/)
        prefix.chop!
        
        # A Conforming RDFa Processor must ignore any definition of a mapping for the '_' prefix.
        next if prefix == "_"

        uri_mappings[prefix] = @graph.bind(Namespace.new(uri, prefix))
        add_debug(element, "extract_mappings: prefix #{prefix} => <#{uri}>")
      end unless @version == :rdfa_1_0
    end

    # The recursive helper function
    def traverse(element, evaluation_context)
      if element.nil?
        add_debug(element, "traverse nil element")
        raise ParserException, "Can't parse nil element" if @strict
        return nil
      end
      
      add_debug(element, "traverse, ec: #{evaluation_context.inspect}")

      # local variables [7.5 Step 1]
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
      property = attrs['property'].to_s.strip if attrs['property']
      typeof = attrs['typeof'].to_s.strip if attrs['typeof']
      datatype = attrs['datatype'].to_s if attrs['datatype']
      content = attrs['content'].to_s if attrs['content']
      rel = attrs['rel'].to_s.strip if attrs['rel']
      rev = attrs['rev'].to_s.strip if attrs['rev']

      # Local term mappings [7.5 Steps 2]
      # Next the current element is parsed for any updates to the local term mappings and local list of URI mappings via @profile.
      # If @profile is present, its value is processed as defined in RDFa Profiles.
      unless @version == :rdfa_1_0
        begin
          process_profile(element) do |which, value|
            add_debug(element, "[Step 2] traverse, #{which}: #{value.inspect}")
            case which
            when :uri_mappings        then uri_mappings.merge!(value)
            when :term_mappings       then term_mappings.merge!(value)
            when :default_vocabulary  then default_vocabulary = value
            end
          end 
        rescue
          # Skip this element and all sub-elements
          # If any referenced RDFa Profile is not available, then the current element and its children must not place any
          # triples in the default graph .
          raise if @strict
          return
        end
      end
    
      # Default vocabulary [7.5 Step 3]
      # Next the current element is examined for any change to the default vocabulary via @vocab.
      # If @vocab is present and contains a value, its value updates the local default vocabulary.
      # If the value is empty, then the local default vocabulary must be reset to the Host Language defined default.
      unless vocab.nil?
        default_vocabulary = if vocab.to_s.empty?
          add_debug(element, "[Step 2] traverse, reset default_vocaulary to #{@host_defaults.fetch(:vocabulary, nil).inspect}")
          # Set default_vocabulary to host language default
          @host_defaults.fetch(:vocabulary, nil)
        else
          URIRef.intern(vocab)
        end
        add_debug(element, "[Step 2] traverse, default_vocaulary: #{default_vocabulary.inspect}")
      end
      
      # Local term mappings [7.5 Steps 4]
      # Next, the current element is then examined for URI mapping s and these are added to the local list of URI mappings.
      # Note that a URI mapping will simply overwrite any current mapping in the list that has the same name
      extract_mappings(element, uri_mappings)
    
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
      add_debug(element, "HTML5 [3.2.3.3] traverse, lang: #{language}") if attrs['lang']
    
      # rels and revs
      rels = process_uris(element, rel, evaluation_context,
                          :uri_mappings => uri_mappings,
                          :term_mappings => term_mappings,
                          :vocab => default_vocabulary,
                          :restrictions => SafeCURIEorCURIEorURI[@version])
      revs = process_uris(element, rev, evaluation_context,
                          :uri_mappings => uri_mappings,
                          :term_mappings => term_mappings,
                          :vocab => default_vocabulary,
                          :restrictions => SafeCURIEorCURIEorURI[@version])
    
      add_debug(element, "traverse, about: #{about.nil? ? 'nil' : about}, src: #{src.nil? ? 'nil' : src}, resource: #{resource.nil? ? 'nil' : resource}, href: #{href.nil? ? 'nil' : href}")
      add_debug(element, "traverse, property: #{property.nil? ? 'nil' : property}, typeof: #{typeof.nil? ? 'nil' : typeof}, datatype: #{datatype.nil? ? 'nil' : datatype}, content: #{content.nil? ? 'nil' : content}")
      add_debug(element, "traverse, rels: #{rels.join(" ")}, revs: #{revs.join(" ")}")

      if !(rel || rev)
        # Establishing a new subject if no rel/rev [7.5 Step 6]
        # May not be valid, but can exist
        new_subject = if about
          process_uri(element, about, evaluation_context,
                      :uri_mappings => uri_mappings,
                      :restrictions => SafeCURIEorCURIEorURI[@version])
        elsif src
          process_uri(element, src, evaluation_context, :restrictions => [:uri])
        elsif resource
          process_uri(element, resource, evaluation_context,
                      :uri_mappings => uri_mappings,
                      :restrictions => SafeCURIEorCURIEorURI[@version])
        elsif href
          process_uri(element, href, evaluation_context, :restrictions => [:uri])
        end

        # If no URI is provided by a resource attribute, then the first match from the following rules
        # will apply:
        #   if @typeof is present, then new subject is set to be a newly created bnode.
        # otherwise,
        #   if parent object is present, new subject is set to the value of parent object.
        # Additionally, if @property is not present then the skip element flag is set to 'true';
        new_subject ||= if @host_language == :xhtml && element.name =~ /^(head|body)$/ && evaluation_context.base
          # From XHTML+RDFa 1.1:
          # if no URI is provided, then first check to see if the element is the head or body element.
          # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
          evaluation_context.base
        elsif element.attributes['typeof']
          BNode.new
        else
          skip = true unless property
          # if it's null, it's null and nothing changes
          evaluation_context.parent_object
        end
        add_debug(element, "[Step 6] new_subject: #{new_subject}, skip = #{skip}")
      else
        # [7.5 Step 7]
        # If the current element does contain a @rel or @rev attribute, then the next step is to
        # establish both a value for new subject and a value for current object resource:
        new_subject = process_uri(element, about, evaluation_context,
                                  :uri_mappings => uri_mappings,
                                  :restrictions => SafeCURIEorCURIEorURI[@version]) ||
                      process_uri(element, src, evaluation_context,
                                  :uri_mappings => uri_mappings,
                                  :restrictions => [:uri])

        # If no URI is provided then the first match from the following rules will apply
        new_subject ||= if @host_language == :xhtml && element.name =~ /^(head|body)$/
          # From XHTML+RDFa 1.1:
          # if no URI is provided, then first check to see if the element is the head or body element.
          # If it is, then act as if there is an empty @about present, and process it according to the rule for @about.
          evaluation_context.base
        elsif element.attributes['typeof']
          BNode.new
        else
          # if it's null, it's null and nothing changes
          evaluation_context.parent_object
          # no skip flag set this time
        end
      
        # Then the current object resource is set to the URI obtained from the first match from the following rules:
        current_object_resource = if resource
          process_uri(element, resource, evaluation_context,
                      :uri_mappings => uri_mappings,
                      :restrictions => SafeCURIEorCURIEorURI[@version])
        elsif href
          process_uri(element, href, evaluation_context,
                      :restrictions => [:uri])
        end

        add_debug(element, "[Step 7] new_subject: #{new_subject}, current_object_resource = #{current_object_resource.nil? ? 'nil' : current_object_resource}")
      end
    
      # Process @typeof if there is a subject [Step 8]
      if new_subject and typeof
        # Typeof is TERMorCURIEorAbsURIs
        types = process_uris(element, typeof, evaluation_context,
                            :uri_mappings => uri_mappings,
                            :term_mappings => term_mappings,
                            :vocab => default_vocabulary,
                            :restrictions => TERMorCURIEorAbsURI[@version])
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
        add_debug(element, "[Step 10] incompletes: rels: #{rels}, revs: #{revs}")
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
        properties = process_uris(element, property, evaluation_context,
                                  :uri_mappings => uri_mappings,
                                  :term_mappings => term_mappings,
                                  :vocab => default_vocabulary,
                                  :restrictions => TERMorCURIEorAbsURI[@version])

        properties.reject! do |p|
          if p.is_a?(URIRef)
            false
          else
            add_debug(element, "Illegal predicate: #{p.inspect}")
            raise InvalidPredicate, "predicate #{p.inspect} must be a URI" if @strict
            true
          end
        end

        # get the literal datatype
        children_node_types = element.children.collect{|c| c.class}.uniq
      
        # the following 3 IF clauses should be mutually exclusive. Written as is to prevent extensive indentation.
        datatype = process_uri(element, datatype, evaluation_context,
                              :uri_mappings => uri_mappings,
                              :term_mappings => term_mappings,
                              :vocab => default_vocabulary,
                              :restrictions => TERMorCURIEorAbsURI[@version]) unless datatype.to_s.empty?
        current_object_literal = if !datatype.to_s.empty? && datatype.to_s != XML_LITERAL.to_s
          # typed literal
          add_debug(element, "[Step 11] typed literal")
          Literal.typed(content || element.inner_text, datatype, :language => language)
        elsif @version == :rdfa_1_1
          if datatype.to_s == XML_LITERAL.to_s
            # XML Literal
            add_debug(element, "[Step 11(1.1)] XML Literal: #{element.inner_html}")
            recurse = false
            Literal.typed(element.children, XML_LITERAL, :language => language, :namespaces => uri_mappings)
          else
            # plain literal
            add_debug(element, "[Step 11(1.1)] plain literal")
            Literal.untyped(content || element.inner_text, language)
          end
        else
          if content || (children_node_types == [Nokogiri::XML::Text]) || (element.children.length == 0) || datatype == ""
            # plain literal
            add_debug(element, "[Step 11 (1.0)] plain literal")
            Literal.untyped(content || element.inner_text, language)
          elsif children_node_types != [Nokogiri::XML::Text] and (datatype == nil or datatype.to_s == XML_LITERAL.to_s)
            # XML Literal
            add_debug(element, "[Step 11 (1.0)] XML Literal: #{element.inner_html}")
            recurse = false
            Literal.typed(element.children, XML_LITERAL, :language => language, :namespaces => uri_mappings)
          end
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
        add_debug(element, "[Step 12] complete incomplete triples: new_subject=#{new_subject}, completes=#{evaluation_context.incomplete_triples.inspect}")
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
            add_debug(element, "[Step 13] skip: reused ec")
          else
            new_ec = evaluation_context.clone
            new_ec.language = language
            new_ec.uri_mappings = uri_mappings
            new_ec.term_mappings = term_mappings
            new_ec.default_vocabulary = default_vocabulary
            add_debug(element, "[Step 13] skip: cloned ec")
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
          add_debug(element, "[Step 13] new ec")
        end
      
        element.children.each do |child|
          # recurse only if it's an element
          traverse(child, new_ec) if child.class == Nokogiri::XML::Element
        end
      end
    end

    # space-separated TERMorCURIEorAbsURI or SafeCURIEorCURIEorURI
    def process_uris(element, value, evaluation_context, options)
      return [] if value.to_s.empty?
      add_debug(element, "process_uris: #{value}")
      value.to_s.split(/\s+/).map {|v| process_uri(element, v, evaluation_context, options)}.compact
    end

    def process_uri(element, value, evaluation_context, options = {})
      return if value.nil?
      restrictions = options[:restrictions]
      add_debug(element, "process_uri: #{value}, restrictions = #{restrictions.inspect}")
      options = {:uri_mappings => {}}.merge(options)
      if !options[:term_mappings] && options[:uri_mappings] && value.to_s.match(/^\[(.*)\]$/) && restrictions.include?(:safe_curie)
        # SafeCURIEorCURIEorURI
        # When the value is surrounded by square brackets, then the content within the brackets is
        # evaluated as a CURIE according to the CURIE Syntax definition. If it is not a valid CURIE, the
        # value must be ignored.
        uri = curie_to_resource_or_bnode(element, $1, options[:uri_mappings], evaluation_context.parent_subject, restrictions)
        add_debug(element, "process_uri: #{value} => safeCURIE => <#{uri}>")
        
        uri
      elsif options[:term_mappings] && NC_REGEXP.match(value.to_s) && restrictions.include?(:term)
        # TERMorCURIEorAbsURI
        # If the value is an NCName, then it is evaluated as a term according to General Use of Terms in
        # Attributes. Note that this step may mean that the value is to be ignored.
        uri = process_term(element, value.to_s, options)
        add_debug(element, "process_uri: #{value} => term => <#{uri}>")
        uri
      else
        # SafeCURIEorCURIEorURI or TERMorCURIEorAbsURI
        # Otherwise, the value is evaluated as a CURIE.
        # If it is a valid CURIE, the resulting URI is used; otherwise, the value will be processed as a URI.
        uri = curie_to_resource_or_bnode(element, value, options[:uri_mappings], evaluation_context.parent_subject, restrictions)
        if uri
          add_debug(element, "process_uri: #{value} => CURIE => <#{uri}>")
        elsif @version == :rdfa_1_0 && value.to_s.match(/^xml/i)
          # Special case to not allow anything starting with XML to be treated as a URI
        elsif restrictions.include?(:absuri) || restrictions.include?(:uri)
          begin
            # AbsURI does not use xml:base
            uri = URIRef.intern(value, restrictions.include?(:absuri) ? nil : evaluation_context.base, :normalize => false)
          rescue Addressable::URI::InvalidURIError => e
            add_warning(element, "Malformed prefix #{value}", RDFA_NS.UndefinedPrefixError)
          rescue ParserException => e
            add_debug(element, e.message)
            if value.to_s =~ /^\(^\w\):/
              add_warning(element, "Undefined prefix #{$1}", RDFA_NS.UndefinedPrefixError)
            else
              add_warning(element, "Relative URI #{value}")
            end
          end
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
    def process_term(element, value, options)
      case
      when options[:term_mappings].is_a?(Hash) && options[:term_mappings].has_key?(value.to_s.downcase)
        # If the term is in the local term mappings, use the associated URI.
        options[:term_mappings][value.to_s.downcase]
      when options[:vocab]
        # Otherwise, if there is a local default vocabulary the URI is obtained by concatenating that value and the term.
        URIRef.intern(options[:vocab].to_s + value)
      else
        # Finally, if there is no local default vocabulary, the term has no associated URI and must be ignored.
        add_warning(element, "Term #{value} is not defined", RDFA_NS.UndefinedTermError)
        nil
      end
    end

    # From section 6. CURIE Syntax Definition
    def curie_to_resource_or_bnode(element, curie, uri_mappings, subject, restrictions)
      # URI mappings for CURIEs default to XH_MAPPING, rather than the default doc namespace
      prefix, reference = curie.to_s.split(":")

      # consider the bnode situation
      if prefix == "_" && restrictions.include?(:bnode)
        # we force a non-nil name, otherwise it generates a new name
        # As a special case, _: is also a valid reference for one specific bnode.
        BNode.new(reference || "", @named_bnodes)
      elsif curie.to_s.match(/^:/)
        add_debug(element, "curie_to_resource_or_bnode: default prefix: defined? #{!!uri_mappings[""]}, defaults: #{@host_defaults[:prefix]}")
        # Default prefix
        if uri_mappings[""]
          uri_mappings[""].send("#{reference}_")
        elsif @host_defaults[:prefix]
          @host_defaults[:prefix].send("#{reference}_")
        else
          #add_warning(element, "Default namespace prefix is not defined", RDFA_NS.UndefinedPrefixError)
          nil
        end
      elsif !curie.to_s.match(/:/)
        # No prefix, undefined (in this context, it is evaluated as a term elsewhere)
        nil
      else
        # Prefixes always downcased
        prefix = prefix.to_s.downcase unless @version == :rdfa_1_0
        ns = uri_mappings[prefix.to_s]
        if ns
          ns + reference
        else
          #add_debug(element, "curie_to_resource_or_bnode No namespace mapping for #{prefix}")
          nil
        end
      end
    end
  end
end