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
      @default_ns = Namespace.new("#{uri}#", "")  if uri
      add_debug("@default_ns", "#{@default_ns.inspect}")
      
      document = parser.parse(@doc)
      unless document
        reason = parser.failure_reason
        raise ParserException.new(reason)
      end
      
      process_statements(document)
      @graph
    end

    protected

    def namespace(uri, prefix)
      add_debug("namesspace", "'#{prefix}' <#{uri}>")
      uri = @default_ns.uri if uri == '#'
      @graph.bind(Namespace.new(uri, prefix))
    end

    def process_statements(document)
      document.elements.find_all do |e|
        s = e.elements.first
        add_debug(*s.info("process_statements"))
        
        if s.respond_to?(:subject)
          subject = process_expression(s.subject)
          add_debug(*s.info("process_statements(#{subject})"))
          properties = process_properties(s.property_list)
          properties.each do |p|
            predicate = process_verb(p.verb)
            add_debug(*p.info("process_statements(#{subject}, #{predicate})"))
            objects = process_objects(p.object_list)
            objects.each do |object|
              if p.verb.respond_to?(:invert)
                add_triple("statement", object, predicate, subject)
              else
                add_triple("statement", subject, predicate, object)
              end
            end
          end
        elsif s.respond_to?(:declaration)
          if s.respond_to?(:nprefix)
            add_debug(*s.info("process_statements(namespace)"))
            uri = process_uri(s.explicituri.uri, false)
            namespace(uri, s.nprefix.text_value)
          elsif s.respond_to?(:base)
            add_debug(*s.info("process_statements(base)"))
            # Base, set or update document URI
            uri = s.explicituri.uri.text_value
            @default_ns = Namespace.new(process_uri(uri, false), "")  # Don't normalize
            add_debug("@default_ns", "#{@default_ns.inspect}")
            @uri = process_uri(uri)
            add_debug("@base", "#{@uri}")
            @uri
          end
        end
      end
    end

    def process_anonnode(anonnode)
      add_debug(*anonnode.info("process_anonnode"))
      bnode = BNode.new
      
      if anonnode.respond_to?(:property_list)
        properties = process_properties(anonnode.property_list)
        properties.each do |p|
          predicate = process_verb(p.verb)
          add_debug(*p.info("anonnode[#{predicate}]"))
          objects = process_objects(p.object_list)
          objects.each { |object| add_triple("anonnode", bnode, predicate, object) }
        end
      elsif anonnode.respond_to?(:path_list)
        objects = process_objects(anonnode.path_list)
        last = objects.pop
        first_bnode = bnode
        objects.each do |object|
          add_triple("anonnode", first_bnode, RDF_NS.first, object)
          rest_bnode = BNode.new
          add_triple("anonnode", first_bnode, RDF_NS.rest, rest_bnode)
          first_bnode = rest_bnode
        end
        if last
          add_triple("anonnode", first_bnode, RDF_NS.first, last)
          add_triple("anonnode", first_bnode, RDF_NS.rest, RDF_NS.nil)
        else
          bnode = RDF_NS.nil
        end
      end
      bnode
    end

    def process_verb(verb)
      add_debug(*verb.info("process_verb"))
      case verb.text_value
      when "a", "@a"  then RDF_TYPE
      when "="        then OWL_NS.sameAs
      when "=>"       then LOG_NS.implies
      when "<="       then LOG_NS.implies
      else
        if verb.respond_to?(:prop)
          process_expression(verb.prop)
        else
          process_expression(verb)
        end
      end
    end

    def process_expression(expression)
      add_debug(*expression.info("process_expression"))
      if expression.respond_to?(:uri)
        process_uri(expression.uri)
      elsif expression.respond_to?(:localname)
        build_uri(expression)
      elsif expression.respond_to?(:anonnode)
        process_anonnode(expression)
      elsif expression.respond_to?(:literal)
        process_literal(expression)
      else
        build_uri(expression)
      end
    end

    def process_uri(uri, normalize = true)
      uri = uri.text_value if uri.respond_to?(:text_value)
      # If we're not normalizing, take non-normalized URI from @default_ns
      base_uri = @default_ns ? @default_ns.uri : @uri
      URIRef.new(uri, base_uri, :normalize => normalize)
    end
    
    def process_properties(properties)
      add_debug(*properties.info("process_properties"))
      result = []
      result << properties if properties.respond_to?(:verb)
      result << process_properties(properties.property_list) if properties.respond_to?(:property_list)
      result.flatten
    end

    def process_objects(objects)
      add_debug(*objects.info("process_objects"))
      result = []
      if objects.respond_to?(:object)
        result << process_expression(objects.object)
      elsif objects.respond_to?(:expression)
        result << process_expression(objects.expression)
        result << process_objects(objects.path_list) if objects.respond_to?(:path_list)
      elsif !objects.text_value.empty?
        result << process_expression(objects)
      end
      result << process_objects(objects.object_list) if objects.respond_to?(:object_list)
      result.flatten
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
    
    def build_uri(expression)
      prefix = expression.respond_to?(:nprefix) ? expression.nprefix.text_value.to_s : ""
      localname = expression.localname.text_value

      uri = if @graph.nsbinding[prefix]
        @graph.nsbinding[prefix] + localname.to_s
      elsif prefix == '_'
        BNode.new(localname, @named_bnodes)
      elsif prefix == "rdf"
        # A special case
        RDF_NS + localname.to_s
      else
        @default_ns ||= Namespace.new("#{@uri}#", "")
        @default_ns + localname
      end
      add_debug(*expression.info("build_uri: #{uri.inspect}"))
      uri
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
