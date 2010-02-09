require File.join(File.dirname(__FILE__), "graph")

module RdfContext
  # AggregateGraph - A read-only graph composed of multiple other graphs.
  #
  # Essentially a ConjunctiveGraph over an explicit subset of the entire store.
  class AggregateGraph < Graph
    attr_reader :graphs
    
    # List of graphs to aggregate
    def initialize(*graph)
      @graphs = graph
    end
    
    def destroy(configuration = nil); raise ReadOnlyGraphException; end
    def commit; raise ReadOnlyGraphException; end
    def rollback; raise ReadOnlyGraphException; end
    def add; raise ReadOnlyGraphException; end
    def remove; raise ReadOnlyGraphException; end
    def bind(namespace); raise ReadOnlyGraphException; end
    def parse(stream, uri, options = {}); raise ReadOnlyGraphException; end
    def n3; raise ReadOnlyGraphException; end
    
    # Open the graphs
    def open(configuration = {})
      @graphs.each {|g| g.open(configuration)}
    end
    
    # Close the graphs
    def close(configuration = {})
      @graphs.each {|g| g.close(configuration)}
    end

    # Number of Triples in the graph
    def size
      @graphs.inject(0) {|memo, g| memo += g.size}
    end

    # List of distinct subjects in graph
    def subjects
      @graphs.inject([]) {|memo, g| memo += g.subjects}
    end
    
    # List of distinct predicates in graph
    def predicates
      @graphs.inject([]) {|memo, g| memo += g.predicates}
    end
    
    # List of distinct objects in graph
    def objects
      @graphs.inject([]) {|memo, g| memo += g.objects}
    end

    # Triples from graph, optionally matching subject, predicate, or object.
    # Delegates to Store#triples.
    #
    # @param [Triple, nil] triple:: Triple to match, may be a patern triple or nil
    # @return [Array]:: List of matched triples
    def triples(triple = Triple.new(nil, nil, nil), &block) # :yields: triple, context
      @graphs.inject([]) {|memo, g| memo += g.triples(triple, &block)}
    end

    # Check to see if this graph contains the specified triple
    def contains?(triple)
      @graphs.any? {|g| g.contains?(triple) }
    end
    
    # Get all BNodes with usage count used within graph
    def bnodes
      @graphs.inject([]) {|memo, g| memo += g.bnodes}
    end
    
    # Only compares to another AggregateGraph. Compares each sub-graph
    def eql?(other)
      other.is_a?(AggregateGraph) ? super : false
    end
    
    def nsbinding
      @graphs.inject({}) {|memo, g| memo.merge(g.nsbinding)}
    end
    
    def uri_binding
      @graphs.inject({}) {|memo, g| memo.merge(g.uri_binding)}
    end
  end
end
