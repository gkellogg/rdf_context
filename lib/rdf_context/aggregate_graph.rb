module RdfContext
  # AggregateGraph - A read-only graph composed of multiple other graphs.
  #
  # Essentially a ConjunctiveGraph over an explicit subset of the entire store.
  class AggregateGraph < Graph
    # List of constituent graphs
    # @return [Array<Graph>]
    attr_reader :graphs
    
    # List of graphs to aggregate
    # @param [Array<Graph>] graph List of constituent graphs
    def initialize(*graph)
      @graphs = graph
    end
    
    # @raise [ReadOnlyGraphException]
    def destroy(configuration = nil); raise ReadOnlyGraphException; end
    # @raise [ReadOnlyGraphException]
    def commit; raise ReadOnlyGraphException; end
    # @raise [ReadOnlyGraphException]
    def rollback; raise ReadOnlyGraphException; end
    # @raise [ReadOnlyGraphException]
    def add; raise ReadOnlyGraphException; end
    # @raise [ReadOnlyGraphException]
    def remove; raise ReadOnlyGraphException; end
    # @param [Namespace] namespace
    # @raise [ReadOnlyGraphException]
    def bind(namespace); raise ReadOnlyGraphException; end
    # @param [#read, #to_s] stream
    # @param [URIRef, String] uri
    # @raise [ReadOnlyGraphException]
    def parse(stream, uri, options = {}); raise ReadOnlyGraphException; end
    # @raise [ReadOnlyGraphException]
    def n3; raise ReadOnlyGraphException; end
    
    # Open the graphs
    # @return [void]
    def open(configuration = {})
      @graphs.each {|g| g.open(configuration)}
    end
    
    # Close the graphs
    # @return [void]
    def close(configuration = {})
      @graphs.each {|g| g.close(configuration)}
    end

    # Number of Triples in the graph
    # @return [Integer]
    def size
      @graphs.inject(0) {|memo, g| memo += g.size}
    end

    # List of distinct subjects in graph
    # @return [Array<Resource>]
    def subjects
      @graphs.inject([]) {|memo, g| memo += g.subjects}
    end
    
    # List of distinct predicates in graph
    # @return [Array<Resource>]
    def predicates
      @graphs.inject([]) {|memo, g| memo += g.predicates}
    end
    
    # List of distinct objects in graph
    # @return [Array<Resource>]
    def objects
      @graphs.inject([]) {|memo, g| memo += g.objects}
    end

    # Triples from graph, optionally matching subject, predicate, or object.
    # Delegates to Store#triples.
    #
    # @param [Triple] triple (Triple.new) Triple to match, may be a pattern triple or nil
    # @yield [triple, context]
    # @yieldparam [Triple] triple
    # @yieldparam [Resource] context
    # @return [Array<Triple>] List of matched triples
    def triples(triple = Triple.new(nil, nil, nil), &block) # :yields: triple, context
      @graphs.inject([]) {|memo, g| memo += g.triples(triple, &block)}
    end

    # Check to see if this graph contains the specified triple
    # @param [Triple] triple Triple to match, may be a pattern triple or nil
    def contains?(triple)
      @graphs.any? {|g| g.contains?(triple) }
    end
    
    # Get all BNodes with usage count used within graph
    # @return [Array<BNode>]
    def bnodes
      @graphs.inject([]) {|memo, g| memo += g.bnodes}
    end
    
    # Only compares to another AggregateGraph. Compares each sub-graph
    # @param [AggregateGraph, Object] other Graph to compare with
    # @return [Boolean]
    def eql?(other)
      other.is_a?(AggregateGraph) ? super : false
    end
    
    # @return [Hash{String => Namespace}]
    def nsbinding
      @graphs.inject({}) {|memo, g| memo.merge(g.nsbinding)}
    end
    
    # @return [Hash{URIRef => Namespace}]
    def uri_binding
      @graphs.inject({}) {|memo, g| memo.merge(g.uri_binding)}
    end
  end
end
