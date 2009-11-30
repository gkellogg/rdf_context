module Reddy
  ##
  # An RDFa parser in Ruby
  #
  # Based on processing rules described here: http://www.w3.org/TR/rdfa-syntax/#s_model
  #
  # Ben Adida
  # 2008-05-07
  # Gregg Kellogg
  # 2009-08-04
  class RdfaParser < Parser
    attr_reader :namespace

    # The Recursive Baggage
    class EvaluationContext # :nodoc:
      attr :base, true
      attr :parent_subject, true
      attr :parent_object, true
      attr :uri_mappings, true
      attr :incomplete_triples, true
      attr :language, true

      def initialize(base)
        # Initialize the evaluation context, [5.1]
        @base = base
        @parent_subject = @base
        @parent_object = nil
        @uri_mappings = {}
        @incomplete_triples = []
        @language = nil
      end

      # Copy this Evaluation Context
      def initialize_copy(from)
          # clone the evaluation context correctly
          @uri_mappings = from.uri_mappings.clone
          @incomplete_triples = from.incomplete_triples.clone
      end
      
      def inspect
        v = %w(base parent_subject parent_object language).map {|a| "#{a}='#{self.send(a).nil? ? 'nil' : self.send(a)}'"}
        v << "uri_mappings[#{uri_mappings.keys.length}]"
        v << "incomplete_triples[#{incomplete_triples.length}]"
        v.join(",")
      end
    end

    # Parse XHTML+RDFa document from a string or input stream to closure or graph.
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
    #
    # @author Gregg Kellogg
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      @uri = Addressable::URI.parse(uri).to_s unless uri.nil?
      @strict = options[:strict] if options.has_key?(:strict)
      @debug = options[:debug] if options.has_key?(:debug)

      @doc = case stream
      when Nokogiri::HTML::Document then stream
      when Nokogiri::XML::Document then stream
      else   Nokogiri::XML.parse(stream, uri)
      end
      
      raise ParserException, "Empty document" if @doc.nil? && @strict
      @callback = block

      # If the doc has a default, use that as "html"
      ns = @doc.namespaces["xmlns"]
      ns ||= "http://www.w3.org/1999/xhtml" # FIXME: intuite from DOCTYPE, or however
      @namespace = Namespace.new(ns, "html") if ns
      
      # parse
      parse_whole_document(@doc, @uri)

      @graph
    end
    
    private
  
    # Parsing an RDFa document (this is *not* the recursive method)
    def parse_whole_document(doc, base)
      # find if the document has a base element
      base_el = doc.xpath('/html:html/html:head/html:base', @namespace.xmlns_hash).first
      if (base_el)
        base = base_el.attributes['href']
        # Strip any fragment from base
        base = base.to_s.split("#").first
        add_debug(base_el, "parse_whole_doc: base='#{base}'")
      end

      # initialize the evaluation context with the appropriate base
      evaluation_context= EvaluationContext.new(base)

      traverse(doc.root, evaluation_context)
    end
  
    # Extract the XMLNS mappings from an element
    def extract_mappings(element)
      mappings = {}
    
      # look for xmlns
      element.namespaces.each do |attr_name,attr_value|
        begin
          abbr, suffix = attr_name.split(":")
          mappings[suffix] = @graph.namespace(attr_value, suffix) if abbr == "xmlns"
        rescue RdfException => e
          add_debug(element, "extract_mappings raised #{e.class}: #{e.message}")
          raise if @strict
        end
      end

      add_debug(element, "mappings: #{mappings.keys.join(", ")}")
      mappings
    end

    # The recursive helper function
    def traverse(element, evaluation_context)
      if element.nil?
        add_debug(element, "traverse nil element")
        raise ParserException, "Can't parse nil element" if @strict
        return nil
      end
      
      # local variables [5.5 Step 1]
      recurse = true
      skip = false
      new_subject = nil
      current_object_resource = nil
      uri_mappings = evaluation_context.uri_mappings.clone
      incomplete_triples = []
      language = evaluation_context.language
    
      # shortcut
      attrs = element.attributes

      about = attrs['about']
      src = attrs['src']
      resource = attrs['resource']
      href = attrs['href']

      # Pull out the attributes needed for the skip test.
      property = attrs['property'].to_s if attrs['property']
      typeof = attrs['typeof'].to_s if attrs['typeof']
      datatype = attrs['datatype'].to_s if attrs['datatype']
      content = attrs['content'].to_s if attrs['content']
      rel = attrs['rel'].to_s if attrs['rel']
      rev = attrs['rev'].to_s if attrs['rev']

      # SPEC CONFUSION: not sure what to initialize this value to
      current_object_literal = nil

      # XMLNS mappings [5.5 Step 2]
      uri_mappings.merge!(extract_mappings(element))
    
      # Language information [5.5 Step 3]
      add_debug(element, "traverse, lang: #{attrs['lang']}") if attrs['lang']
      language = attrs['lang'] || language
    
      # rels and revs
      rels = parse_curies(rel, uri_mappings, evaluation_context.base, true)
      revs = parse_curies(rev, uri_mappings, evaluation_context.base, true)
      valid_rel_or_rev = !(rel.nil? && rev.nil?)
    
      add_debug(element, "traverse, ec: #{evaluation_context.inspect}")
      add_debug(element, "traverse, about: #{about.nil? ? 'nil' : about}, src: #{src.nil? ? 'nil' : src}, resource: #{resource.nil? ? 'nil' : resource}, href: #{href.nil? ? 'nil' : href}")
      add_debug(element, "traverse, property: #{property.nil? ? 'nil' : property}, typeof: #{typeof.nil? ? 'nil' : typeof}, datatype: #{datatype.nil? ? 'nil' : datatype}, content: #{content.nil? ? 'nil' : content}")
      add_debug(element, "traverse, rels: #{rels.join(" ")}, revs: #{revs.join(" ")}")

      if not valid_rel_or_rev
        # Establishing a new subject if no valid rel/rev [5.5 Step 4]
        if about
          new_subject = uri_or_safe_curie(about, evaluation_context, uri_mappings)
        elsif src
          new_subject = URIRef.new(src, evaluation_context.base)
        elsif resource
          new_subject =  uri_or_safe_curie(resource, evaluation_context, uri_mappings)
        elsif href
          new_subject = URIRef.new(href, evaluation_context.base)
        end

        # SPEC CONFUSION: not sure what "If no URI is provided by a resource attribute" means, I assume 
        # it means that new_subject is still null
        if new_subject.nil?
          if element.name =~ /^(head|body)$/
            new_subject = URIRef.new(evaluation_context.base)
          elsif element.attributes['typeof']
            new_subject = @graph.bnode
          else
            # if it's null, it's null and nothing changes
            new_subject = evaluation_context.parent_object
            skip = true unless property
          end
        end
        add_debug(element, "new_subject: #{new_subject}, skip = #{skip}")
      else
        # Establish both new subject and current object resource [5.5 Step 5]
      
        if about
          new_subject =  uri_or_safe_curie(about, evaluation_context, uri_mappings)
        elsif src
          new_subject =  uri_or_safe_curie(src, evaluation_context, uri_mappings)
        end
      
        # If no URI is provided then the first match from the following rules will apply
        if new_subject.nil?
          if element.name =~ /^(head|body)$/
            new_subject = URIRef.new(evaluation_context.base)
          elsif element.attributes['typeof']
            new_subject = @graph.bnode
          else
            # if it's null, it's null and nothing changes
            new_subject = evaluation_context.parent_object
            # no skip flag set this time
          end
        end
      
        if resource
          current_object_resource =  uri_or_safe_curie(resource, evaluation_context, uri_mappings)
        elsif href
          current_object_resource = URIRef.new(href, evaluation_context.base)
        end

        add_debug(element, "new_subject: #{new_subject}, current_object_resource = #{current_object_resource.nil? ? 'nil' : current_object_resource}")
      end
    
      # Process @typeof if there is a subject [Step 6]
      if new_subject and typeof
        types = parse_curies(typeof, uri_mappings, evaluation_context.base, false)
        add_debug(element, "typeof: #{typeof}")
        types.each do |one_type|
          add_triple(element, new_subject, RDF_TYPE, one_type)
        end
      end
    
      # Generate triples with given object [Step 7]
      if current_object_resource
        rels.each do |rel|
          add_triple(element, new_subject, rel, current_object_resource)
        end
      
        revs.each do |rev|
          add_triple(element, current_object_resource, rev, new_subject)
        end
      else
        # Incomplete triples and bnode creation [Step 8]
        add_debug(element, "step 8: valid: #{valid_rel_or_rev}, rels: #{rels}, revs: #{revs}")
        current_object_resource = @graph.bnode if valid_rel_or_rev
      
        rels.each do |rel|
          # SPEC CONFUSION: we don't store the subject here?
          incomplete_triples << {:predicate => rel, :direction => :forward}
        end
      
        revs.each do |rev|
          # SPEC CONFUSION: we don't store the object here?
          incomplete_triples << {:predicate => rev, :direction => :reverse}
        end

      end
    
      # Establish current object literal [Step 9]
      if property
        properties = parse_curies(property, uri_mappings, evaluation_context.base, false)

        # get the literal datatype
        type = datatype
        children_node_types = element.children.collect{|c| c.class}.uniq
      
        # the following 3 IF clauses should be mutually exclusive. Written as is to prevent extensive indentation.
      
        # SPEC CONFUSION: have to special case XML Literal, not clear right away.
        # SPEC CONFUSION: specify that the conditions are in order of priority
        type_resource = curie_to_resource_or_bnode(type, uri_mappings, evaluation_context.base) if type
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
        properties.each do |property|
          add_triple(element, new_subject, property, current_object_literal)
        end
      
        # SPEC CONFUSION: "the triple has been created" ==> there may be more than one
        # set the recurse flag above in the IF about xmlliteral, as it is the only place that can happen
      end
    
      # Complete the incomplete triples from the evaluation context [Step 10]
      add_debug(element, "10: skip=#{skip}, new_subject=#{new_subject}")
      if not skip and new_subject
        evaluation_context.incomplete_triples.each do |trip|
          if trip[:direction] == :forward
            add_triple(element, evaluation_context.parent_subject, trip[:predicate], new_subject)
          elsif trip[:direction] == :reverse
            add_triple(element, new_subject, trip[:predicate], evaluation_context.parent_subject)
          end
        end
      end
    
      # Create a new evaluation context and proceed recursively [Step 11]
      if recurse
        # SPEC CONFUSION: new evaluation context for each child? Probably not necessary,
        # but maybe needs to be pointed out?

        if skip
          new_ec = evaluation_context.clone
          new_ec.language = language
          new_ec.uri_mappings = uri_mappings
          add_debug(element, "skip: cloned ec: #{evaluation_context.inspect}")
        else
          # create a new evaluation context
          new_ec = EvaluationContext.new(evaluation_context.base)
          new_ec.parent_subject = new_subject || evaluation_context.parent_subject
          new_ec.parent_object = current_object_resource || new_subject || evaluation_context.parent_subject
          new_ec.uri_mappings = uri_mappings
          new_ec.incomplete_triples = incomplete_triples
          new_ec.language = language
          #add_debug(element, "new ec: #{new_ec.inspect}")
        end
      
        element.children.each do |child|
          # recurse only if it's an element
          traverse(child, new_ec) if child.class == Nokogiri::XML::Element
        end
      end
    end
    
    # space-separated CURIEs or Link Types
    def parse_curies(value, uri_mappings, base, with_link_types=false)
      return [] unless value
      resource_array = []
      value.to_s.split(' ').each do |curie|
        if curie.include?(":")
          resource_array << curie_to_resource_or_bnode(curie, uri_mappings, base)
        elsif with_link_types
          # Reserved words are all mapped to lower case
          curie = curie.to_s.downcase
          link_type_curie = curie_to_resource_or_bnode(":#{curie}", XH_MAPPING, base) if LINK_TYPES.include?(curie)
          resource_array << link_type_curie if link_type_curie
        end
      end
      resource_array
    end

    def curie_to_resource_or_bnode(curie, uri_mappings, subject)
      # URI mappings for CURIEs default to XH_MAPPING, rather than the default doc namespace
      uri_mappings = uri_mappings.merge(XH_MAPPING)
      prefix, suffix = curie.to_s.split(":")

      # consider the bnode situation
      if prefix == "_"
        # we force a non-nil name, otherwise it generates a new name
        @graph.bnode(suffix || "")
      elsif curie.to_s.empty?
        add_debug(nil, "curie_to_resource_or_bnode #{URIRef.new(subject)}")
        # Empty curie resolves to current subject (No, an empty curie should be ignored)
#        URIRef.new(subject)
        nil
      else
        ns = uri_mappings[prefix.to_s]
        unless ns
          add_debug(nil, "curie_to_resource_or_bnode No namespace mapping for #{prefix}")
          raise ParserException, "No namespace mapping for #{prefix}" if @strict
          return nil
        end
        ns + suffix
      end
    end

    def uri_or_safe_curie(value, evaluation_context, uri_mappings)
      return nil if value.nil?
      
      # check if the value is [foo:bar]
      if value.to_s.match(/^\[(.*)\]$/)
        curie_to_resource_or_bnode($1, uri_mappings, evaluation_context.parent_subject)
      else
        URIRef.new(value, evaluation_context.base)
      end
    end
  end
end