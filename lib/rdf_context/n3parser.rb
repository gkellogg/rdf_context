require 'treetop'
require File.join(File.dirname(__FILE__), 'parser')

Treetop.load(File.join(File.dirname(__FILE__), "n3_grammar"))

module RdfContext
  class Parser; end
  class N3Parser < Parser

    # Parse N3 document from a string or input stream to closure or graph.
    #
    # If the parser is called with a block, triples are passed to the block rather
    # than added to the graph.
    #
    # @param [String] n3_str:: the Notation3/Turtle string
    # @param [String] uri:: the URI of the document
    # @param [Hash] options:: Options include the following
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:strict]</em>:: Abort or proceed on error
    # @return [Graph]
    # @raise RdfContext::RdfException or subclass
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
      
      process_declarations(document)
      process_statements(document)
      @graph
    end

    protected

    def process_declarations(document)
      declarations = document.elements.find_all { |e| e.elements.first.respond_to? :declaration }
      declarations.map! { |d| d.elements.first }
      declarations.each do |d|
        if d.respond_to?(:nprefix)
          add_debug(*d.info("process_declarations[namespace]"))
          namespace(d.symbol.uri.text_value, d.nprefix.text_value)
        else
          add_debug(*d.info("process_declarations[base]"))
          # Base, set or update document URI
          @uri = process_expression(d)
          add_debug("", "base = #{@uri}")
          @uri
        end
      end
    end

    def namespace(uri, prefix)
      uri = @uri if uri == '#'
      @graph.bind(Namespace.new(uri, prefix))
    end

    def process_statements(document)
      subjects = document.elements.find_all { |e| e.elements.first.respond_to? :subject }
      subjects.map! { |s| s.elements.first }
      subjects.each do |s|
        subject = process_expression(s.subject)
        add_debug(*s.info("process_statements[#{subject}]"))
        properties = process_properties(s.property_list)
        properties.each do |p|
          predicate = process_verb(p.verb)
          add_debug(*p.info("process_statements[#{subject}][#{predicate}]"))
          objects = process_objects(p.object_list)
          objects.each { |object| add_triple("statement", subject, predicate, object) }
        end
      end
    end

    def process_anonnode(anonnode)
      add_debug(*anonnode.info("process_anonnode"))
      bnode = BNode.new
      properties = process_properties(anonnode.property_list)
      properties.each do |p|
        predicate = process_verb(p.verb)
        add_debug(*p.info("anonnode[#{predicate}]"))
        objects = process_objects(p.object_list)
        objects.each { |object| add_triple("anonnode", bnode, predicate, object) }
      end
      bnode
    end

    def process_verb(verb)
      add_debug(*verb.info("process_verb"))
      return URIRef.new('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') if (verb.text_value=='a')
      return process_expression(verb)
    end

    def process_expression(expression)
      add_debug(*expression.info("process_expression"))
      if (expression.respond_to? :uri)
        case expression.uri.text_value
        when /^#?$/ then URIRef.new(expression.uri.text_value, @uri)
        when /^#.*/ then URIRef.new(expression.uri.text_value, @uri)
        else             URIRef.new(expression.uri.text_value)
        end
      else
        prefix = (expression.respond_to? :nprefix) ? expression.nprefix.text_value : nil
        localname = expression.localname.text_value
        build_uri(prefix, localname)
      end
    end

    def process_properties(properties)
      add_debug(*properties.info("process_properties"))
      result = []
      result << properties if (properties.respond_to? :verb)
      result << process_properties(properties.property_list) if (properties.respond_to? :property_list)
      result.flatten
    end

    def process_objects(objects)
      add_debug(*objects.info("process_objects"))
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
      add_debug(*object.info("process_object"))
      if (object.respond_to? :localname or object.respond_to? :uri)
        process_expression(object)
      elsif (object.respond_to? :property_list)
        process_anonnode(object)
      else
        process_literal(object)
      end
    end
    
    def process_literal(object)
      add_debug(*object.info("process_literal"))
      encoding, language = nil, nil
      string, type = object.elements

      unless type.elements.nil?
        #puts type.elements.inspect
        if (type.elements[0].text_value=='@')
          language = type.elements[1].text_value
        else
          encoding = process_expression(type.elements[1])
        end
      end

      # Evaluate text_value to remove redundant escapes
      #puts string.elements[1].text_value.dump
      Literal.n3_encoded(string.elements[1].text_value, language, encoding)
    end
    
    def build_uri(prefix, localname)
      if (prefix=='_')
        BNode.new(localname, @named_bnodes)
      elsif @graph.nsbinding[prefix.to_s]
        @graph.nsbinding[prefix.to_s].send(localname)
      elsif prefix == "rdf"
        # A special case
        RDF_NS.send(localname)
      end
    end
  end
end


module Treetop
  module Runtime
    class SyntaxNode
      # Brief information about a syntax node
      def info(ctx = "")
        m = self.singleton_methods(true)
        if m.empty?
          ["@#{self.interval.first}", "#{ctx}['#{self.text_value}']"]
        else
          ["@#{self.interval.first}", "#{ctx}[" +
          self.singleton_methods(true).map do |m|
            v = self.send(m)
            v = v.text_value if v.is_a?(SyntaxNode)
            "#{m}='#{v}'"
          end.join(", ") +
          "]"]
        end
      end
    end
  end
end
