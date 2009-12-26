module Reddy
  # The BNode class creates RDF blank nodes.
  class BNode
    attr_reader :store
    
    # Create a new BNode, optionally accept a identifier for the BNode.
    # Otherwise, generated sequentially.
    #
    # A BNode may have a bank (empty string) identifier, which will be equivalent to another
    # blank identified BNode.
    #
    # BNodes only have meaning within a Store, and must be bound to a Store to be resolved.
    # This can be done from the Graph as follows:
    #  Graph.new.bnode(identifier)</tt>
    # or
    #  g = Graph.new
    #  BNode.new(identifier, g)
    # or
    #  l = ListStore.new
    #  BNode.new(identifier, l)
    #
    # @param [Graph, Store] graph:: Graph or Store with which to bind BNode
    # @param [String] identifier:: Legal NCName or nil for a named BNode
    #
    # @author Gregg Kellogg
    def initialize(graph, identifier = nil)
      case graph
      when Graph  then @store = graph.store
      when AbstractStore  then @store = graph
      else
        raise BNodeException.new("BNode must be bound to a graph")
      end
      if identifier != nil && self.valid_id?(identifier)
        # Generate a name if it's blank. Always prepend "named" to avoid generation overlap
        identifier = "named#{identifier}" unless identifier.match(/^named/)
        @identifier = (@store.named_nodes[identifier] ||= identifier.to_s.length > 0 ? identifier : self)
      else
        # Don't actually allocate the name until it's used, to save generation space
        # (and make checking test cases easier)
        @identifier = self
      end
    end

    # Return BNode identifier
    def to_s
      return self.identifier.to_s
    end

    ## 
    # Exports the BNode in N-Triples form.
    #
    # ==== Example
    #   b = BNode.new; b.to_n3  # => returns a string of the BNode in n3 form
    #
    # @return [String] The BNode in n3.
    #
    # @author Tom Morris
    def to_n3
      "_:#{self.identifier}"
    end

    ## 
    # Exports the BNode in N-Triples form.
    #
    # Syonym for to_n3
    def to_ntriples
      self.to_n3
    end

    # Output URI as resource reference for RDF/XML
    #
    # ==== Example
    #   b = BNode.new("foo"); b.xml_args  # => [{"rdf:nodeID" => "foo"}]
    def xml_args
      [{"rdf:nodeID" => self.identifier}]
    end
    
    # The identifier used used for this BNode. Not evaluated until this is called, which means
    # that BNodes that are never used in a triple won't polute the sequence.
    def identifier
      return @identifier unless @identifier.is_a?(BNode)
      if @identifier.equal?(self)
        # Generate from the sequence a..zzz
        @identifier = @store.generate_bn_identifier
      else
        # Previously allocated node
        @identifier = @identifier.identifier
      end
      @identifier
    end
    
    # Compare BNodes. BNodes are equivalent if they have the same identifier in the same store
    def eql?(other)
      other.class == self.class &&
      other.store.equal?(self.store) &&
      other.identifier == self.identifier
    end
    alias_method :==, :eql?
    
    # Needed for uniq
    def hash; (store.identifier.to_s + self.to_s).hash; end
    
    def inspect
      "[bn:#{identifier},store:#{store.identifier}]"
    end
    
    protected
    def valid_id?(name)
      NC_REGEXP.match(name) || name.empty?
    end
  end
end
