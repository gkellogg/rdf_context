module RdfContext
  # Abstract storage module, superclass of other storage classes
  class AbstractStore
    attr_reader :nsbinding, :uri_binding, :identifier
    
    # Create a new AbstractStore Store, should be subclassed
    # @param [Resource] identifier
    # @param[Hash] configuration Specific to type of storage
    # @return [AbstractStore]
    def initialize(identifier = nil, configuration = {})
      @nsbinding = {}
      # Reverse namespace binding
      @uri_binding = {}
      
      @identifier = identifier || BNode.new
    end
    
    # Is store Context Aware, capable of being used for named graphs?
    # @return [false]
    def context_aware?; false; end
    
    # Is store Formulae Aware, capable of storing variables?
    # @return [false]
    def formula_aware?; false; end
    
    # Is store Transaction Aware, capable of rollback?
    # @return [false]
    def transaction_aware?; false; end

    # Interfaces that must be implemented

    # A generator over all matching triples
    # @param [Triple] triple
    # @param [Graph] context (nil)
    # @return [Array<Triplle>]
    # @raise [StoreException] Not Implemented
    # @yield [triple, context]
    # @yieldparam [Triple] triple
    # @yieldparam [Graph] context
    def triples(triple, context = nil)  # :yields: triple, context
      raise StoreException, "not implemented"
    end
    
    # Add triple to store
    # @param [Triple] triple
    # @param [Graph] context (nil)
    # @param [Boolean] quoted (false) A quoted triple, for Formulae
    # @raise [StoreException] Not Implemented
    # @return [Triple]
    def add(triple, context = nil, quoted = false); raise StoreException, "not implemented"; end
    
    # Remove a triple from the store
    # @param [Triple] triple
    # @param [Graph] context (nil)
    # @raise [StoreException] Not Implemented
    # @return [nil]
    def remove(triple, context = nil); raise StoreException, "not implemented"; end
    
    # Check to see if this store contains the specified triple
    # @param [Triple] triple
    # @param [Graph] context (nil) ignored
    # @raise [StoreException] Not Implemented
    # @return [Boolean]
    def contains?(triple, context = nil); raise StoreException, "not implemented"; end

    # Default (sub-optimal) implemenations of interfaces
    def inspect
      "#{self.class}[identifier=#{identifier.inspect}]"
    end
    
    def destroy(configuration = {}); end
    def open(configuration = {}); end
    def close(commit_pending_transactions = false); end
    def commit; end
    def rollback; end

    ## 
    # Bind a namespace to the store.
    #
    # @param [Nameespace] namespace the namespace to bind
    # @return [Namespace] The newly bound or pre-existing namespace.
    def bind(namespace)
      # Over-write an empty prefix
      uri = namespace.uri.to_s
      @uri_binding.delete(uri)
      @nsbinding.delete_if {|prefix, ns| namespace.prefix == prefix}

      @uri_binding[uri] = namespace
      @nsbinding[namespace.prefix.to_s] = namespace
    end

    # Namespace for prefix
    # @param [String] prefix
    # @return [Namespace]
    def namespace(prefix)
      @nsbinding[prefix.to_s]
    end
    
    # Prefix for namespace
    # @param [Namespace] namespcae
    # @return [String]
    def prefix(namespace)
      namespace.is_a?(Namespace) ? @uri_binding[namespace.uri.to_s].prefix : @uri_binding[namespace].prefix
    end
    
    # Get all BNodes with usage count used within graph
    # @param [Graph] context (nil)
    # @return [Array<BNode>]
    def bnodes(context = nil)
      bn = {}
      triples(Triple.new(nil, nil, nil), context) do |t, ctx|
        if t.subject.is_a?(BNode)
          bn[t.subject] ||= 0
          bn[t.subject] += 1
        end
        if t.predicate.is_a?(BNode)
          bn[t.predicate] ||= 0
          bn[t.predicate] += 1
        end
        if t.object.is_a?(BNode)
          bn[t.object] ||= 0
          bn[t.object] += 1
        end
      end
      bn
    end

    
    # Number of Triples in the graph
    # @param [Graph] context (nil)
    # @return [Integer]
    def size(context = nil); triples(Triple.new(nil, nil, nil), context).size; end

    # List of distinct subjects in graph
    # @param [Graph] context (nil)
    # @return [Array<Resource>]
    def subjects(context = nil); triples(Triple.new(nil, nil, nil), context).map {|t| t.subject}.uniq; end
    
    # List of distinct predicates in graph
    # @param [Graph] context (nil)
    # @return [Array<Resource>]
    def predicates(context = nil); triples(Triple.new(nil, nil, nil), context).map {|t| t.predicate}.uniq; end
    
    # List of distinct objects in graph
    # @param [Graph] context (nil)
    # @return [Array<Resource>]
    def objects(context = nil); triples(Triple.new(nil, nil, nil), context).map {|t| t.object}.uniq; end
    
    # Return an indexed element from the graph
    # @param [Integer] item Index into the serialized store
    # @param [Graph] context
    # @return [Array<Triple>]
    def item(item, context = nil) triples(Triple.new(nil, nil, nil), context)[item]; end
  end
end