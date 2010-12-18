module RdfContext
  # QuotedGraph - Supports N3 Formulae.
  #
  # QuotedGraphs behave like other graphs, except that the triples are not considered for inference rules
  # and their statements are not held has _truth_. Triples from a QuotedGraph are not returned from
  # a ConjunctiveGraph in the same store space.
  #
  # Within N3, a QuotedGraph is represented as a set of statements contained between _{_ and _}_
  #
  #   { [ x:firstname  "Ora" ] dc:wrote [ dc:title  "Moby Dick" ] } a n3:falsehood .
  class QuotedGraph < Graph
    ## 
    # Adds one or more extant triples to a graph. Delegates to Store.
    #
    # @example
    #   g = Graph.new;
    #   t1 = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new);
    #   t2 = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new);
    #   g.add(t1, t2, ...)
    #
    # @param [Array<Triple>] triples one or more triples. Last element may be a hash for options
    # @option [Resource] :context Graph context in which to deposit triples, defaults to default_context or self
    # @return [Graph] Returns the graph
    def add(*triples)
      options = triples.last.is_a?(Hash) ? triples.pop : {}
      ctx = options[:context] || @default_context || self
      triples.each {|t| @store.add(t, ctx, true)}
      self
    end
    
    # Return an n3 identifier for the Graph
    # @return [String]
    def n3
      "{#{self.identifier.to_n3}}"
    end
  end
end
