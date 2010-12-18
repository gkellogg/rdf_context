module RdfContext
  # Abstract serializer
  class TurtleSerializer < RecursiveSerializer
    SUBJECT = 0
    VERB = 1
    OBJECT = 2
    
    # Serialize the graph
    #
    # @param [IO, StreamIO] stream Stream in which to place serialized graph
    # @option options [URIRef, String] :base (nil) Base URI of graph, used to shorting URI references
    # @return [void]
    def serialize(stream, options = {})
      puts "\nserialize: #{@graph.inspect}" if ::RdfContext::debug?
      reset
      @stream = stream
      @base = options[:base]
      
      @graph.bind(RDF_NS)
      @graph.bind(RDFS_NS)
      
      preprocess
      start_document

      order_subjects.each do |subject|
        #puts "subj: #{subject.inspect}"
        unless is_done?(subject)
          statement(subject)
        end
      end
      
      end_document
    end

    protected
    def reset
      super
      @shortNames = {}
      @started = false
    end
    
    def get_qname(uri)
      if uri.is_a?(URIRef)
        md = relativize(uri)
        return "<#{md}>" unless md == uri.to_s
        
        super(uri)
      end
    end
    
    def preprocess_triple(triple)
      super
      
      # Pre-fetch qnames, to fill namespaces
      get_qname(triple.subject)
      get_qname(triple.predicate)
      get_qname(triple.object)

      @references[triple.predicate] = ref_count(triple.predicate) + 1
    end
    
    def label(node)
      get_qname(node) || node.to_n3
    end
    
    def start_document
      @started = true
      
      write("#{indent}@base <#{@base}> .\n") if @base
      
      ns_list = @namespaces.values.sort_by {|ns| ns.prefix}
      unless ns_list.empty?
        ns_str = ns_list.map do |ns|
          "#{indent}@prefix #{ns.prefix}: <#{ns.uri}> ."
        end.join("\n") + "\n"
        write(ns_str)
      end
    end
    
    def end_document; end
    
    # Checks if l is a valid RDF list, i.e. no nodes have other properties.
    def is_valid_list(l)
      props = @graph.properties(l)
      #puts "is_valid_list: #{props.inspect}" if ::RdfContext::debug?
      return false unless props.has_key?(RDF_NS.first.to_s) || l == RDF_NS.nil
      while l && l != RDF_NS.nil do
        #puts "is_valid_list(length): #{props.length}" if ::RdfContext::debug?
        return false unless props.has_key?(RDF_NS.first.to_s) && props.has_key?(RDF_NS.rest.to_s)
        n = props[RDF_NS.rest.to_s]
        #puts "is_valid_list(n): #{n.inspect}" if ::RdfContext::debug?
        return false unless n.is_a?(Array) && n.length == 1
        l = n.first
        props = @graph.properties(l)
      end
      #puts "is_valid_list: valid" if ::RdfContext::debug?
      true
    end
    
    def do_list(l)
      puts "do_list: #{l.inspect}" if ::RdfContext::debug?
      position = SUBJECT
      while l do
        p = @graph.properties(l)
        item = p.fetch(RDF_NS.first.to_s, []).first
        if item
          path(item, position)
          subject_done(l)
          position = OBJECT
        end
        l = p.fetch(RDF_NS.rest.to_s, []).first
      end
    end
    
    def p_list(node, position)
      return false if !is_valid_list(node)
      #puts "p_list: #{node.inspect}, #{position}" if ::RdfContext::debug?

      write(position == SUBJECT ? "(" : " (")
      @depth += 2
      do_list(node)
      @depth -= 2
      write(')')
    end
    
    def p_squared?(node, position)
      node.is_a?(BNode) &&
        !@serialized.has_key?(node) &&
        ref_count(node) <= 1
    end
    
    def p_squared(node, position)
      return false unless p_squared?(node, position)

      #puts "p_squared: #{node.inspect}, #{position}" if ::RdfContext::debug?
      subject_done(node)
      write(position == SUBJECT ? '[' : ' [')
      @depth += 2
      predicate_list(node)
      @depth -= 2
      write(']')
      
      true
    end
    
    def p_default(node, position)
      #puts "p_default: #{node.inspect}, #{position}" if ::RdfContext::debug?
      l = (position == SUBJECT ? "" : " ") + label(node)
      write(l)
    end
    
    def path(node, position)
      puts "path: #{node.inspect}, pos: #{position}, []: #{is_valid_list(node)}, p2?: #{p_squared?(node, position)}, rc: #{ref_count(node)}" if ::RdfContext::debug?
      raise RdfException, "Cannot serialize node '#{node}'" unless p_list(node, position) || p_squared(node, position) || p_default(node, position)
    end
    
    def verb(node)
      puts "verb: #{node.inspect}" if ::RdfContext::debug?
      if node == RDF_TYPE
        write(" a")
      else
        path(node, VERB)
      end
    end
    
    def object_list(objects)
      puts "object_list: #{objects.inspect}" if ::RdfContext::debug?
      return if objects.empty?

      objects.each_with_index do |obj, i|
        write(",\n#{indent(4)}") if i > 0
        path(obj, OBJECT)
      end
    end
    
    def predicate_list(subject)
      properties = @graph.properties(subject)
      prop_list = sort_properties(properties) - [RDF_NS.first.to_s, RDF_NS.rest.to_s]
      puts "predicate_list: #{prop_list.inspect}" if ::RdfContext::debug?
      return if prop_list.empty?

      prop_list.each_with_index do |prop, i|
        write(";\n#{indent(2)}") if i > 0
        verb(URIRef.new(prop))
        object_list(properties[prop])
      end
    end
    
    def s_squared?(subject)
      ref_count(subject) == 0 && subject.is_a?(BNode) && !is_valid_list(subject)
    end
    
    def s_squared(subject)
      return false unless s_squared?(subject)
      
      write("\n#{indent} [")
      @depth += 1
      predicate_list(subject)
      @depth -= 1
      write("] .")
      true
    end
    
    def s_default(subject)
      write("\n#{indent}")
      path(subject, SUBJECT)
      predicate_list(subject)
      write(" .")
      true
    end
    
    def statement(subject)
      puts "statement: #{subject.inspect}, s2?: #{s_squared(subject)}" if ::RdfContext::debug?
      subject_done(subject)
      s_squared(subject) || s_default(subject)
    end
  end
end