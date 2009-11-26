#require 'ruby-debug'
require 'xml'
include Reddy

module Reddy
  include LibXML
  
  class RdfXmlParser
    NC_REGEXP = Regexp.new("^([a-zA-Z_]|\\\\u[0-9a-fA-F])([a-zA-Z0-9_\.-]|\\\\u[0-9a-fA-F]{4})*$")

    CORE_SYNTAX_TERMS = %w(RDF ID about parseType resource nodeID datatype).map {|n| "http://www.w3.org/1999/02/22-rdf-syntax-ns##{n}"}
    OLD_TERMS = %w(aboutEach aboutEachPrefix bagID).map {|n| "http://www.w3.org/1999/02/22-rdf-syntax-ns##{n}"}

    attr_reader :debug
    attr_accessor :xml, :graph

    # The Recursive Baggage
    class EvaluationContext # :nodoc: all
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
      
      def extract_from_ancestors(el)
        ancestors = el.ancestors
        while ancestors.length > 0
          a = ancestors.pop
          next unless a.element?
          extract_from_element(a)
        end
        extract_from_element(el)
      end

      def extract_from_element(el)
        b = el.attribute_with_ns("base", XML_NS.uri.to_s)
        lang = el.attribute_with_ns("lang", XML_NS.uri.to_s)
        self.base = URIRef.new(b, self.base)
        self.language = lang if lang
        self.uri_mappings.merge!(extract_mappings(el))
      end
      
      # Extract the XMLNS mappings from an element
      def extract_mappings(element)
        mappings = {}

        # look for xmlns
        element.namespaces.each do |attr_name,attr_value|
          abbr, suffix = attr_name.to_s.split(":")
          mappings[suffix] = @graph.namespace(attr_value, suffix) if abbr == "xmlns"
        end
        mappings
      end
      
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

    # Create new parser instance. Options:
    # _graph_:: Graph to parse into, otherwie a new RdfaParser::Graph instance is created
    def initialize(options = {})
      options = {:graph => Graph.new}.merge(options)
      @debug = []
      @strict = true
      BNode.reset # Start sequence anew

      # initialize the triplestore
      @graph = options[:graph]
    end

    def parse(xml_str, uri, options = {}) # :yields: triple
      @uri = Addressable::URI.parse(uri).to_s
      @xml = Nokogiri::XML.parse(xml_str)
      @id_mapping = Hash.new

      root = @xml.root
      
      # Look for rdf:RDF elements and process each.
      rdf_nodes = root.xpath("//rdf:RDF", RDF_NS.short => RDF_NS.uri.to_s)
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
    def add_debug(node, message)
      puts "#{node_path(node)}: #{message}" if $DEBUG
      @debug << "#{node_path(node)}: #{message}"
    end

    def node_path(node)
      case node
      when Nokogiri::XML::Element, Nokogiri::XML::Attr then "#{node_path(node.parent)}/#{node.name}"
      else ""
      end
    end
    
    # add a triple, object can be literal or URI or bnode
    def add_triple(node, subject, predicate, object)
      triple = Triple.new(subject, predicate, object)
      add_debug(node, "triple: #{triple}")
      if @callback
        @callback.call(triple)  # Perform yield to saved block
      else
        @graph << triple
      end
      triple
    rescue RdfException => e
      add_debug(node, "add_triple raised #{e.class}: #{e.message}")
      raise if @strict
    end
  
    def is_rdf_root? (node)
      node.name == "RDF" && node.namespace.href == RDF_NS.uri.to_s
    end
    
    def nodeElement(el, ec)
      # subject
      subject = ec.subject || parse_subject(el, ec)
      
      add_debug(el, "nodeElement, ec: #{ec.inspect}")
      add_debug(el, "nodeElement, el: #{el.uri}")
      add_debug(el, "nodeElement, subject: #{subject.nil? ? 'nil' : subject.to_s}")

      # XXX xml.lang, xml.base?

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
          predicate = ec.li_next(predicate) if predicate == RDF_NS.li
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
          else
            attrs[attr.uri.to_s] = attr.value
          end
        end
        id = attrs.delete(RDF_NS.ID.to_s)
        datatype = attrs.delete(RDF_NS.datatype.to_s)
        parseType = attrs.delete(RDF_NS.parseType.to_s)
        resourceAttr = attrs.delete(RDF_NS.resource.to_s)
        nodeID = attrs.delete(RDF_NS.nodeID.to_s)
        
        # Apply character transformations
        id = id.rdf_escape if id
        resourceAttr = resourceAttr.rdf_escape if resourceAttr
        nodeID = nodeID.rdf_escape if nodeID

        add_debug(el, "attrs: #{attrs.inspect}")
        add_debug(el, "datatype: #{datatype}") if datatype
        add_debug(el, "parseType: #{parseType}") if parseType
        add_debug(el, "resource: #{resourceAttr}") if resourceAttr
        add_debug(el, "nodeID: #{nodeID}") if nodeID
        if id
          add_debug(el, "id: #{id}")
          # Satisfy constraint-id. id must be an NCName
          raise ParserException.new("ID addtribute '#{id}' must be a NCName") unless id_check?(id)
        end
        
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
              resource = BNode.new(nodeID)
            else
              resource = BNode.new
            end

            # produce triples for attributes
            attrs.each_pair do |attr, val|
              add_debug(el, "attr: #{attr}='#{val}'")
              if attr == RDF_TYPE
                add_triple(child, resource, RDF_TYPE, val)
              else
                # Attributes not in RDF_TYPE
                lit = Literal.untyped(val, child_ec.language)
                add_triple(child, resource, attr, lit)
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
    # reification
    def reify(id, el, subject, predicate, object, ec)
      add_debug(el, "reify, id: #{id}")
      rsubject = URIRef.new("#" + id, ec.base)
      add_triple(el, rsubject, RDF_NS.subject, subject)
      add_triple(el, rsubject, RDF_NS.predicate, predicate)
      add_triple(el, rsubject, RDF_NS.object, object)
      add_triple(el, rsubject, RDF_TYPE, RDF_NS.Statement)
    end

    def parse_subject(el, ec)
      old_property_check(el)
      
      about = el.attribute("about")
      id = el.attribute("ID")
      nodeID = el.attribute("nodeID")

      case
      when id
        id = id.value.rdf_escape if id

        add_debug(el, "parse_subject, id: '#{id}'")
        if id_check?(id)
          URIRef.new("##{id}", ec.base)
        else
          add_debug(el, "Bad ID format '#{id}'")
          raise Reddy::ParserException.new("Bad ID format '#{id}'") if @strict
          nil
        end
      when nodeID
        nodeID = nodeID.value.rdf_escape if nodeID
        add_debug(el, "parse_subject, nodeID: '#{nodeID}")
        BNode.new(nodeID)
      when about
        about = about.value.rdf_escape if about
        add_debug(el, "parse_subject, about: '#{about}'")
        URIRef.new(about, ec.base)
      else
        add_debug(el, "parse_subject, BNode")
        BNode.new
      end
    end
    
    def id_check?(id)
      NC_REGEXP.match(id)
    end
    
    def is_propertyAttr?(attr)
      !(CORE_SYNTAX_TERMS + OLD_TERMS).include?(attr.uri.to_s) &&
      attr.namespace.href != XML_NS.uri.to_s
    end

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
