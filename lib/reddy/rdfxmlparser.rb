#require 'ruby-debug'
require 'xml'

module Reddy
  class RdfXmlParser < Parser
    CORE_SYNTAX_TERMS = %w(RDF ID about parseType resource nodeID datatype).map {|n| "http://www.w3.org/1999/02/22-rdf-syntax-ns##{n}"}
    OLD_TERMS = %w(aboutEach aboutEachPrefix bagID).map {|n| "http://www.w3.org/1999/02/22-rdf-syntax-ns##{n}"}

    # The Recursive Baggage
    class EvaluationContext # :nodoc:
      attr_reader :base
      attr :subject, true
      attr :uri_mappings, true
      attr :language, true
      attr :graph, true
      attr :li_counter, true

      def initialize(base, element, graph)
        # Initialize the evaluation context, [5.1]
        self.base = base
        @uri_mappings = {}
        @language = nil
        @graph = graph
        @li_counter = 0
        @uri_mappings = {}

        extract_from_element(element) if element
      end
      
      # Clone existing evaluation context adding information from element
      def clone(element, options = {})
        new_ec = EvaluationContext.new(@base, nil, @graph)
        new_ec.uri_mappings = self.uri_mappings.clone
        new_ec.language = self.language

        new_ec.extract_from_element(element) if element
        
        options.each_pair {|k, v| new_ec.send("#{k}=", v)}
        new_ec
      end
      
      # Extract Evaluation Context from an element by looking at ancestors recurively
      def extract_from_ancestors(el)
        ancestors = el.ancestors
        while ancestors.length > 0
          a = ancestors.pop
          next unless a.element?
          extract_from_element(a)
        end
        extract_from_element(el)
      end

      # Extract Evaluation Context from an element
      def extract_from_element(el)
        b = el.attribute_with_ns("base", XML_NS.uri.to_s)
        lang = el.attribute_with_ns("lang", XML_NS.uri.to_s)
        self.base = URIRef.new(b, self.base) if b
        self.language = lang if lang
        self.uri_mappings.merge!(extract_mappings(el))
      end
      
      # Extract the XMLNS mappings from an element
      def extract_mappings(element)
        mappings = {}

        # look for xmlns
        element.namespaces.each do |attr_name,attr_value|
          abbr, suffix = attr_name.to_s.split(":")
          if abbr == "xmlns"
            mappings[suffix] = Namespace.new(attr_value, suffix)
            @graph.bind(mappings[suffix])
          end
        end
        mappings
      end
      
      # Produce the next list entry for this context
      def li_next(predicate)
        @li_counter += 1
        predicate = Addressable::URI.parse(predicate.to_s)
        predicate.fragment = "_#{@li_counter}"
        predicate = URIRef.new(predicate)
      end

      # Set XML base. Ignore any fragment
      def base=(b)
        b = Addressable::URI.parse(b.to_s)
        b.fragment = nil
        @base = b.to_s
      end

      def inspect
        v = %w(base subject language).map {|a| "#{a}='#{self.send(a).nil? ? 'nil' : self.send(a)}'"}
        v << "uri_mappings[#{uri_mappings.keys.length}]"
        v.join(",")
      end
    end

    # Parse RDF/XML document from a string or input stream to closure or graph.
    #
    # Optionally, the stream may be a string or Nokogiri::XML::Document
    # With a block, yeilds each statement with URIRef, BNode or Literal elements
    # 
    # @param [IO] stream:: the RDF/XML IO stream, string or Nokogiri::XML::Document
    # @param [String] uri:: the URI of the document
    # @param [Hash] options:: Parser options, one of
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph]:: Returns the graph containing parsed triples
    # @raise [Error]:: Raises RdfError if _strict_
    #
    # @author Gregg Kellogg
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      super

      @doc = case stream
      when Nokogiri::XML::Document then stream
      else   Nokogiri::XML.parse(stream, uri)
      end
      
      @id_mapping = Hash.new

      raise ParserException, "Empty document" if @doc.nil? && @strict
      @callback = block
      
      root = @doc.root
      
      # Look for rdf:RDF elements and process each.
      rdf_nodes = root.xpath("//rdf:RDF", RDF_NS.prefix => RDF_NS.uri.to_s)
      if rdf_nodes.length == 0
        # If none found, root element may be processed as an RDF Node

        ec = EvaluationContext.new(@uri, root, @graph)
        nodeElement(root, ec)
      else
        rdf_nodes.each do |node|
          # XXX Skip this element if it's contained within another rdf:RDF element
          
          # Extract base, lang and namespaces from parents to create proper evaluation context
          ec = EvaluationContext.new(@uri, nil, @graph)
          ec.extract_from_ancestors(node)
          node.children.each {|el|
            next unless el.elem?
            new_ec = ec.clone(el)
            nodeElement(el, new_ec)
          }
        end
      end

      @graph
    end
  
    private
    # Is the node rdf:RDF?
    def is_rdf_root? (node)
      node.name == "RDF" && node.namespace.href == RDF_NS.uri.to_s
    end
    
    # XML nodeElement production
    #
    # @param [XML Element] el:: XMl Element to parse
    # @param [EvaluationContext] ec:: Evaluation context
    # @return [URIRef] subject:: The subject found for the node
    # @raise [RdfException]:: Raises Exception if _strict_
    #
    # @author Gregg Kellogg
    def nodeElement(el, ec)
      # subject
      subject = ec.subject || parse_subject(el, ec)
      
      add_debug(el, "nodeElement, ec: #{ec.inspect}")
      add_debug(el, "nodeElement, el: #{el.uri}")
      add_debug(el, "nodeElement, subject: #{subject.nil? ? 'nil' : subject.to_s}")

      unless el.uri == RDF_NS.Description.to_s
        add_triple(el, subject, RDF_TYPE, el.uri)
      end

      # produce triples for attributes
      el.attribute_nodes.each do |attr|
        add_debug(el, "propertyAttr: #{attr.uri}='#{attr.value}'")
        if attr.uri == RDF_TYPE
          # If there is an attribute a in propertyAttr with a.URI == rdf:type
          # then u:=uri(identifier:=resolve(a.string-value))
          # and the following tiple is added to the graph:
          u = URIRef.new(attr.value, ec.base)
          add_triple(attr, subject, RDF_TYPE, u)
        elsif is_propertyAttr?(attr)
          # Attributes not RDF_TYPE
          predicate = attr.uri
          lit = Literal.untyped(attr.value, ec.language)
          add_triple(attr, subject, predicate, lit)
        end
      end
      
      # Handle the propertyEltList children events in document order
      li_counter = 0 # this will increase for each li we iterate through
      el.children.each do |child|
        next unless child.elem?
        child_ec = ec.clone(child)
        predicate = child.uri
        add_debug(child, "propertyElt, predicate: #{predicate}")
        propertyElementURI_check(child)
        
        # Determine the content type of this property element
        text_nodes = child.children.select {|e| e.text? && !e.blank?}
        element_nodes = child.children.select(&:element?)

        # List expansion
        predicate = ec.li_next(predicate) if predicate == RDF_NS.li
        
        # Productions based on set of attributes
        
        # All remaining reserved XML Names (See Name in XML 1.0) are now removed from the set.
        # These are, all attribute information items in the set with property [prefix] beginning with xml
        # (case independent comparison) and all attribute information items with [prefix] property having
        # no value and which have [local name] beginning with xml (case independent comparison) are removed.
        # Note that the [base URI] accessor is computed by XML Base before any xml:base attribute information item
        # is deleted.
        attrs = {}
        id = datatype = parseType = resourceAttr = nodeID = nil
        
        child.attribute_nodes.each do |attr|
          if attr.namespace.to_s.empty?
            # The support for a limited set of non-namespaced names is REQUIRED and intended to allow
            # RDF/XML documents specified in [RDF-MS] to remain valid;
            # new documents SHOULD NOT use these unqualified attributes and applications
            # MAY choose to warn when the unqualified form is seen in a document.
            add_debug(el, "Unqualified attribute '#{attr}'")
            #attrs[attr.to_s] = attr.value unless attr.to_s.match?(/^xml/)
          elsif attr.namespace.href == XML_NS.uri.to_s
            # No production. Lang and base elements already extracted
          elsif attr.namespace.href == RDF_NS.uri.to_s
            case attr.name
            when "ID"         then id = attr.value
            when "datatype"   then datatype = attr.value
            when "parseType"  then parseType = attr.value
            when "resource"   then resourceAttr = attr.value
            when "nodeID"     then nodeID = attr.value
            else                   attrs[attr] = attr.value
            end
          else
            attrs[attr] = attr.value
          end
        end
        
        if nodeID && resourceAttr
          add_debug(el, "Cannot have rdf:nodeID and rdf:resource.")
          raise ParserException.new("Cannot have rdf:nodeID and rdf:resource.") if @strict
        end

        # Apply character transformations
        id = id_check(el, id.rdf_escape, nil) if id
        resourceAttr = resourceAttr.rdf_escape if resourceAttr
        nodeID = nodeID_check(el, nodeID.rdf_escape) if nodeID

        add_debug(el, "attrs: #{attrs.inspect}")
        add_debug(el, "datatype: #{datatype}") if datatype
        add_debug(el, "parseType: #{parseType}") if parseType
        add_debug(el, "resource: #{resourceAttr}") if resourceAttr
        add_debug(el, "nodeID: #{nodeID}") if nodeID
        add_debug(el, "id: #{id}") if id
        
        if attrs.empty? && datatype.nil? && parseType.nil? && element_nodes.length == 1
          # Production resourcePropertyElt

          new_ec = child_ec.clone(nil)
          new_node_element = element_nodes.first
          add_debug(child, "resourcePropertyElt: #{node_path(new_node_element)}")
          new_subject = nodeElement(new_node_element, new_ec)
          add_triple(child, subject, predicate, new_subject)
        elsif attrs.empty? && parseType.nil? && element_nodes.length == 0 && text_nodes.length > 0
          # Production literalPropertyElt
          add_debug(child, "literalPropertyElt")
          
          literal = datatype ? Literal.typed(child.inner_html, datatype) : Literal.untyped(child.inner_html, child_ec.language)
          add_triple(child, subject, predicate, literal)
          reify(id, child, subject, predicate, literal, ec) if id
        elsif parseType == "Resource"
          # Production parseTypeResourcePropertyElt
          add_debug(child, "parseTypeResourcePropertyElt")

          unless attrs.empty?
            warn = "Resource Property with extra attributes: '#{attrs.inspect}'"
            add_debug(child, warn)
            raise ParserException.new(warn) if @strict
          end

          # For element e with possibly empty element content c.
          n = BNode.new
          add_triple(child, subject, predicate, n)

          # Reification
          reify(id, child, subject, predicate, n, child_ec) if id
          
          # If the element content c is not empty, then use event n to create a new sequence of events as follows:
          #
          # start-element(URI := rdf:Description,
          #     subject := n,
          #     attributes := set())
          # c
          # end-element()
          add_debug(child, "compose new sequence with rdf:Description")
          node = child.clone
          pt_attr = node.attribute("parseType")
          node.namespace = pt_attr.namespace
          node.attributes.keys.each {|a| node.remove_attribute(a)}
          node.node_name = "Description"
          new_ec = child_ec.clone(nil, :subject => n)
          nodeElement(node, new_ec)
        elsif parseType == "Collection"
          # Production parseTypeCollectionPropertyElt
          add_debug(child, "parseTypeCollectionPropertyElt")

          unless attrs.empty?
            warn = "Resource Property with extra attributes: '#{attrs.inspect}'"
            add_debug(child, warn)
            raise ParserException.new(warn) if @strict
          end

          # For element event e with possibly empty nodeElementList l. Set s:=list().
          # For each element event f in l, n := bnodeid(identifier := generated-blank-node-id()) and append n to s to give a sequence of events.
          s = element_nodes.map { BNode.new }
          n = s.first || RDF_NS.send("nil")
          add_triple(child, subject, predicate, n)
          reify(id, child, subject, predicate, n, child_ec) if id
          
          # Add first/rest entries for all list elements
          s.each_index do |i|
            n = s[i]
            o = s[i+1]
            f = element_nodes[i]

            new_ec = child_ec.clone(nil)
            object = nodeElement(f, new_ec)
            add_triple(child, n, RDF_NS.first, object)
            add_triple(child, n, RDF_NS.rest, o ? o : RDF_NS.nil)
          end
        elsif parseType   # Literal or Other
          # Production parseTypeResourcePropertyElt
          add_debug(child, parseType == "Literal" ? "parseTypeResourcePropertyElt" : "parseTypeOtherPropertyElt (#{parseType})")

          unless attrs.empty?
            warn = "Resource Property with extra attributes: '#{attrs.inspect}'"
            add_debug(child, warn)
            raise ParserException.new(warn) if @strict
          end

          if resourceAttr
            warn = "illegal rdf:resource"
            add_debug(child, warn)
            raise ParserException.new(warn) if @strict
          end

          object = Literal.typed(child.children, XML_LITERAL, :namespaces => child_ec.uri_mappings)
          add_triple(child, subject, predicate, object)
        elsif text_nodes.length == 0 && element_nodes.length == 0
          # Production emptyPropertyElt
          add_debug(child, "emptyPropertyElt")

          if attrs.empty? && resourceAttr.nil? && nodeID.nil?
            literal = Literal.untyped("", ec.language)
            add_triple(child, subject, predicate, literal)
            
            # Reification
            reify(id, child, subject, predicate, literal, child_ec) if id
          else
            if resourceAttr
              resource = URIRef.new(resourceAttr, ec.base)
            elsif nodeID
              resource = BNode.new(nodeID, @named_bnodes)
            else
              resource = BNode.new
            end

            # produce triples for attributes
            attrs.each_pair do |attr, val|
              add_debug(el, "attr: #{attr.name}='#{val}'")
              
              if attr.uri.to_s == RDF_TYPE
                add_triple(child, resource, RDF_TYPE, val)
              else
                # Check for illegal attributes
                next unless is_propertyAttr?(attr)

                # Attributes not in RDF_TYPE
                lit = Literal.untyped(val, child_ec.language)
                add_triple(child, resource, attr.uri.to_s, lit)
              end
            end
            add_triple(child, subject, predicate, resource)
            
            # Reification
            reify(id, child, subject, predicate, resource, child_ec) if id
          end
        end
      end
      
      # Return subject
      subject
    end
    
    private
    # Reify subject, predicate, and object given the EvaluationContext (ec) and current XMl element (el)
    def reify(id, el, subject, predicate, object, ec)
      add_debug(el, "reify, id: #{id}")
      rsubject = URIRef.new("#" + id, ec.base)
      add_triple(el, rsubject, RDF_NS.subject, subject)
      add_triple(el, rsubject, RDF_NS.predicate, predicate)
      add_triple(el, rsubject, RDF_NS.object, object)
      add_triple(el, rsubject, RDF_TYPE, RDF_NS.Statement)
    end

    # Figure out the subject from the element.
    def parse_subject(el, ec)
      old_property_check(el)
      
      nodeElementURI_check(el)
      about = el.attribute("about")
      id = el.attribute("ID")
      nodeID = el.attribute("nodeID")
      
      if nodeID && about
        add_debug(el, "Cannot have rdf:nodeID and rdf:about.")
        raise ParserException.new("Cannot have rdf:nodeID and rdf:about.") if @strict
      elsif nodeID && id
        add_debug(el, "Cannot have rdf:nodeID and rdf:ID.")
        raise ParserException.new("Cannot have rdf:nodeID and rdf:ID.") if @strict
      end

      case
      when id
        add_debug(el, "parse_subject, id: '#{id.value.rdf_escape}'")
        id_check(el, id.value.rdf_escape, ec.base) # Returns URI
      when nodeID
        # The value of rdf:nodeID must match the XML Name production
        nodeID = nodeID_check(el, nodeID.value.rdf_escape)
        add_debug(el, "parse_subject, nodeID: '#{nodeID}")
        BNode.new(nodeID, @named_bnodes)
      when about
        about = about.value.rdf_escape
        add_debug(el, "parse_subject, about: '#{about}'")
        URIRef.new(about, ec.base)
      else
        add_debug(el, "parse_subject, BNode")
        BNode.new
      end
    end
    
    # ID attribute must be an NCName
    def id_check(el, id, base)
      if NC_REGEXP.match(id)
        # ID may only be specified once for the same URI
        if base
          uri = URIRef.new("##{id}", base)
          if @id_mapping[id] && @id_mapping[id] == uri
            warn = "ID addtribute '#{id}' may only be defined once for the same URI"
            add_debug(el, warn)
            raise Reddy::ParserException.new(warn) if @strict
          end
          
          @id_mapping[id] = uri
          # Returns URI, in this case
        else
          id
        end
      else
        warn = "ID addtribute '#{id}' must be a NCName"
        add_debug(el, "ID addtribute '#{id}' must be a NCName")
        add_debug(el, warn)
        raise Reddy::ParserException.new(warn) if @strict
        nil
      end
    end
    
    # nodeID must be an XML Name
    # nodeID must pass Production rdf-id
    def nodeID_check(el, nodeID)
      if NC_REGEXP.match(nodeID)
        nodeID
      else
        add_debug(el, "nodeID addtribute '#{nodeID}' must be an XML Name")
        raise Reddy::ParserException.new("nodeID addtribute '#{nodeID}' must be a NCName") if @strict
        nil
      end
    end
    
    # Is this attribute a Property Attribute?
    def is_propertyAttr?(attr)
      if ([RDF_NS.Description.to_s, RDF_NS.li.to_s] + OLD_TERMS).include?(attr.uri.to_s)
        warn = "Invalid use of rdf:#{attr.name}"
        add_debug(attr, warn)
        raise InvalidPredicate.new(warn) if @strict
        return false
      end
      !CORE_SYNTAX_TERMS.include?(attr.uri.to_s) &&
      attr.namespace.href != XML_NS.uri.to_s
    end
    
    # Check Node Element name
    def nodeElementURI_check(el)
      if (CORE_SYNTAX_TERMS + [RDF_NS.li.to_s] + OLD_TERMS).include?(el.uri.to_s)
        warn = "Invalid use of rdf:#{el.name}"
        add_debug(el, warn)
        raise InvalidSubject.new(warn) if @strict
      end
    end

    # Check Property Element name
    def propertyElementURI_check(el)
      if (CORE_SYNTAX_TERMS + [RDF_NS.Description.to_s] + OLD_TERMS).include?(el.uri.to_s)
        warn = "Invalid use of rdf:#{el.name}"
        add_debug(el, warn)
        raise InvalidPredicate.new(warn) if @strict
      end
    end

    # Check for the use of an obsolete RDF property
    def old_property_check(el)
      el.attribute_nodes.each do |attr|
        if OLD_TERMS.include?(attr.uri.to_s)
          add_debug(el, "Obsolete attribute '#{attr.uri}'")
          raise InvalidPredicate.new("Obsolete attribute '#{attr.uri}'") if @strict
        end
      end
    end
    
  end
end
