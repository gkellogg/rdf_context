require 'treetop'
require File.join(File.dirname(__FILE__), 'parser')

Treetop.load(File.join(File.dirname(__FILE__), "n3_grammar"))

module Reddy
  class Parser; end
  class N3Parser < Parser

    # Parse N3 document from a string or input stream to closure or graph.
    #
    # Optionally, the stream may be a Nokogiri::HTML::Document or Nokogiri::XML::Document
    # With a block, yeilds each statement with URIRef, BNode or Literal elements
    # 
    # @param [String] n3_str:: the Notation3/Turtle string
    # @param [String] uri:: the URI of the document
    # @param [Hash] options:: Options include the following
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:strict]</em>:: Abort or proceed on error
    # @return [Graph]
    # @raise Reddy::RdfException or subclass
    #
    # @author Patrick Sinclair (metade)
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      super

      @callback = block
      parser = N3GrammerParser.new

      @doc = stream.respond_to?(:read) ? stream.read : stream
      
      document = parser.parse(@doc)
      unless document
        reason = parser.failure_reason
        raise ParserException.new(reason)
      end
      
      process_directives(document)
      process_statements(document)
      @graph
    end

    protected

    def process_directives(document)
      directives = document.elements.find_all { |e| e.elements.first.respond_to? :directive }
      directives.map! { |d| d.elements.first }
      directives.each { |d| namespace(d.uri_ref.uri.text_value, d.nprefix.text_value) }
    end

    def namespace(uri, prefix)
      uri = @uri if uri == '#'
      prefix = '__local__' if prefix == ''
      @graph.bind(Namespace.new(uri, prefix))
    end

    def process_statements(document)
      subjects = document.elements.find_all { |e| e.elements.first.respond_to? :subject }
      subjects.map! { |s| s.elements.first }
      subjects.each do |s|
        subject = process_node(s.subject)
        properties = process_properties(s.property_list)
        properties.each do |p|      
          predicate = process_verb(p.verb)
          objects = process_objects(p.object_list)
          objects.each { |object| add_triple("statement", subject, predicate, object) }
        end
      end
    end

    def process_anonnode(anonnode)
      bnode = BNode.new
      properties = process_properties(anonnode.property_list)
      properties.each do |p|      
        predicate = process_node(p.verb)
        objects = process_objects(p.object_list)
        objects.each { |object| add_triple("anonnode", bnode, predicate, object) }
      end
      bnode
    end

    def process_verb(verb)
      return URIRef.new('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') if (verb.text_value=='a')
      return process_node(verb)
    end

    def process_node(node)
      if (node.respond_to? :uri)
        URIRef.new(node.uri.text_value)
      else      
        prefix = (node.respond_to? :nprefix) ? node.nprefix.text_value : nil
        localname = node.localname.text_value
        build_uri(prefix, localname)
      end
    end

    def process_properties(properties)
      result = []
      result << properties if (properties.respond_to? :verb)
      result << process_properties(properties.property_list) if (properties.respond_to? :property_list)
      result.flatten
    end

    def process_objects(objects)
      result = []
      if (objects.respond_to? :object)
        result << process_object(objects.object)
      else
        result << process_object(objects)
      end
      result << process_objects(objects.object_list) if (objects.respond_to? :object_list)
      result.flatten
    end

    def process_object(object)
      if (object.respond_to? :localname or object.respond_to? :uri)
        process_node(object)
      elsif (object.respond_to? :property_list)
        process_anonnode(object)
      else
        process_literal(object)
      end
    end
    
    def process_literal(object)
      encoding, language = nil, nil
      string, type = object.elements

      unless type.elements.nil?
        #puts type.elements.inspect
        if (type.elements[0].text_value=='@')
          language = type.elements[1].text_value
        else
          encoding = type.elements[1].text_value
        end
      end

      # Evaluate text_value to remove redundant escapes
      #puts string.elements[1].text_value.dump
      Literal.n3_encoded(string.elements[1].text_value, language, encoding)
    end
    
    def build_uri(prefix, localname)
      prefix = '__local__' if prefix.nil?
      if (prefix=='_')
        BNode.new(localname, @named_bnodes)
      else
        @graph.nsbinding[prefix].send(localname)
      end
    end
  end
end
