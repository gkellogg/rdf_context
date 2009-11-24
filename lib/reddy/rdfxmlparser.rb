#require 'ruby-debug'
require 'xml'
include Reddy

module Reddy
  include LibXML
  
  NC_START_CHARS = %w(
    A-Z _ a-z \xc0-\xd6 \xd8-\xf6
  ).join("")
  NC_CHARS = NC_START_CHARS + %w(
    0-9 \xb7
    \- \.
  ).join("")
  NC_REGEXP = Regexp.new("^[#{NC_START_CHARS}][#{NC_CHARS}]*$")
  
  class RdfXmlParser

    attr_reader :debug
    attr_accessor :xml, :graph

    # The Recursive Baggage
    class EvaluationContext # :nodoc: all
      attr :base, true
      attr :parent_subject, true
      attr :parent_object, true
      attr :uri_mappings, true
      attr :language, true
      attr :graph, true

      def initialize(base, element, graph)
        # Initialize the evaluation context, [5.1]
        @base = base
        @uri_mappings = {}
        @language = nil
        @graph = graph
        if element
          b = element.attribute_with_ns("base", XML_NS.uri.to_s)
          lang = element.attribute_with_ns("lang", XML_NS.uri.to_s)
          @base = b if b
          @language = lang if lang
          @uri_mappings = extract_mappings(element)
        end
      end
      
      # Clone existing evaluation context adding information from element
      def clone(element, options = {})
        new_ec = EvaluationContext.new(@base, nil, @graph)
        new_ec.uri_mappings = self.uri_mappings.clone
        new_ec.language = self.language
        new_ec.parent_subject = self.parent_subject

        if element
          b = element.attribute_with_ns("base", XML_NS.uri.to_s)
          lang = element.attribute_with_ns("lang", XML_NS.uri.to_s)
          new_ec.base = URIRef.new(b, self.base)
          new_ec.lang = lang if lang
          new_ec.uri_mappings.merge!(extract_mappings(element))
        end
        
        options.each_pair {|k, v| new_ec.send("#{k}=", v)}
        new_ec
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

      def inspect
        v = %w(base parent_subject language).map {|a| "#{a}='#{self.send(a).nil? ? 'nil' : self.send(a)}'"}
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
      
      # Extract namespaces from root
      ec = EvaluationContext.new(@uri, root, @graph)

      if is_rdf_root?(root)
        root.children.each {|el|
          next unless el.elem?
          new_ec = ec.clone(el)
          nodeElement(el, new_ec)
        }
      else
        root.children.each {|n|
          if is_rdf_root?(n)
            new_ec = ec.clone(n)
            
            n.children.each {|el|
              next unless el.elem?
              el_ec = new_ec.clone(el)
              nodeElement(el, el_ec)
            }
          end
        }
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
      subject = parse_subject(el, ec) || ec.parent_subject
      
      add_debug(el, "nodeElement, ec: #{ec.inspect}")
      add_debug(el, "nodeElement, el: #{el.uri}")
      add_debug(el, "nodeElement, subject: #{subject.nil? ? 'nil' : subject.to_s}")

      # XXX xml.lang, xml.base?

      unless el.uri == RDF_NS.Description.to_s
        add_triple(el, subject, RDF_TYPE, el.uri)
      end

      # produce triples for attributes
      el.attribute_nodes.each do |attr|
        add_debug(el, "attr: #{attr.uri}")
        if attr.namespace.href == RDF_NS.uri.to_s
          add_triple(att, subject, RDF_TYPE, att.value) if attr.name == "type"
        else
          # Attributes not in RDF_TYPE
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
        
        # Determine the content type of this property element
        text_nodes = child.children.select {|e| e.text? && !e.blank?}
        element_nodes = child.children.select(&:element?)

        # List expansion
        if predicate == RDF_NS.li
          li_counter += 1
          predicate = Addressable::URI.parse(predicate.to_s)
          predicate.fragment = "_#{li_counter.to_s}"
          predicate = URIRef.new(predicate)
        end
        
        # Productions based on set of attributes
        attrs = {}
        child.attribute_nodes.each { |attr| attrs[attr.uri.to_s] = attr.value}
        id = attrs.delete(RDF_NS.ID.to_s)
        datatype = attrs.delete(RDF_NS.datatype.to_s)
        parseType = attrs.delete(RDF_NS.parseType.to_s)
        resourceAttr = attrs.delete(RDF_NS.resource.to_s)
        nodeID = attrs.delete(RDF_NS.nodeID.to_s)
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

          new_ec = child_ec.clone(nil, :parent_subject => nil)
          new_node_element = element_nodes.first
          add_debug(child, "resourcePropertyElt: #{node_path(new_node_element)}")
          new_subject = nodeElement(new_node_element, new_ec)
          add_triple(child, subject, predicate, new_subject)
        elsif attrs.empty? && parseType.nil? && element_nodes.length == 0 && text_nodes.length > 0
          # Production literalPropertyElt
          add_debug(child, "literalPropertyElt")

          literal = datatype ? Literal.typed(child.inner_html, datatype) : Literal.untyped(child.inner_html, ec.language)
          add_triple(child, subject, predicate, literal)
          reify(id, child, subject, predicate, literal, ec) if id
        elsif parseType == "Resource"
          # Production parseTypeResourcePropertyElt
          add_debug(child, "parseTypeResourcePropertyElt")

          # For element e with possibly empty element content c.
          element_nodes.each do |cel|
            cel_ec = child_ec.clone(cel)
            object = BNode.new
            add_triple(cel, subject, predicate, object)

            # Reification
            reify(id, child, subject, predicate, object, cel_ec) if id
            
            # If the element content c is not empty, then use event n to create a new sequence of events
            cl.children.select(&:element?).each do |c|
              new_ec = cel_ec.clone(c, :parent_subject => object)
              nodeElement(c, new_ec)
            end
          end
        elsif parseType == "Collection"
          # Production parseTypeCollectionPropertyElt
          add_debug(child, "parseTypeCollectionPropertyElt")

          raise ParserError.new("parseType Collection not implemented")
        elsif parseType   # Literal or Other
          # Production parseTypeResourcePropertyElt
          add_debug(child, parseType == "Literal" ? "parseTypeResourcePropertyElt" : "parseTypeOtherPropertyElt (#{parseType})")

          object = Literal.typed(child.children, XML_LITERAL, :namespaces => uri_mappings)
          add_triple(child, subject, predicate, object)
        elsif text_nodes.length == 0 && element_nodes.length == 0
          # Production emptyPropertyElt
          add_debug(child, "emptyPropertyElt")

          if attrs.empty? && resourceAttr.nil? && nodeID.nil?
            literal = Literal.untyped("", ec.language)
            add_triple(child, subject, predicate, literal)
            
            # Reification
            reify(id, child, subject, predicate, literal, child_ec) if id
          elsif resourceAttr
            resource = URIRef.new(resourceAttr, ec.base)
            add_triple(child, subject, predicate, resource)
          elsif nodeID
          else
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

    def fail_check(el)
      if el.attribute("aboutEach")
        add_debug(el, "obsolete aboutEach")
        raise Reddy::AboutEachException if @strict
      end
      if el.attribute("aboutEachPrefix")
        add_debug(el, "obsolete aboutEachPrefix")
        raise Reddy::AboutEachException if @strict
      end
      if el.attribute("bagID")
        unless el.attribute("bagID").value =~ /^[a-zA-Z_][a-zA-Z0-9]*$/
          add_debug(el, "Bad bagID")
          raise Reddy::ParserException.new("Bad BagID") if @strict
        end
      end
    end
    
    def parse_subject(el, ec)
      fail_check(el)
      
      about = el.attribute("about")
      id = el.attribute("ID")
      nodeID = el.attribute("nodeID")

      case
      when id
        add_debug(el, "parse_subject, id: #{id.value || 'nil'}")
        if id_check?(id.value)
          URIRef.new("##{id.value}", ec.base)
        else
          add_debug(el, "Bad ID format '#{id.value}'")
          raise Reddy::ParserException.new("Bad ID format '#{id.value}'") if @strict
          nil
        end
      when nodeID
        add_debug(el, "parse_subject, nodeID: #{nodeID.value || 'nil'}")
        BNode.new(nodeID.value)
      when about
        add_debug(el, "parse_subject, about: #{about.value || 'nil'}")
        URIRef.new(about.value, ec.base)
      else
        add_debug(el, "parse_subject, BNode")
        BNode.new
      end
    end
    
    def id_check?(id)
      NC_REGEXP.match(id)
    end
  end
end
