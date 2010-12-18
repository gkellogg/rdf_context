module RdfContext
  # ConjunctiveGraph - The top level container for all named Graphs sharing a _Store_
  #
  # A ConjuctiveGraph is a graph that can contain other graphs. Graphs are kept distinct
  # by a _context_, which is the identifier of the sub-graph. It is the union of all graphs in a _Store_.
  #
  # For the sake of persistence, Conjunctive Graphs must be distinguished by identifiers (that may not
  # necessarily be RDF identifiers or may be an RDF identifier normalized - SHA1/MD5 perhaps - for database
  # naming purposes ) which could be referenced to indicate conjunctive queries (queries made across the
  # entire conjunctive graph) or appear as nodes in asserted statements. In this latter case, such
  # statements could be interpreted as being made about the entire 'known' universe.
  class ConjunctiveGraph < Graph
    # Store for ConjunctiveGraph must support contexts.
    def initialize(options = {})
      unless options[:store] && options[:store].context_aware?
        raise GraphException.new("ConjunctiveGraph requires store supporting contexts")
      end
    
      super(:identifier => options[:store].identifier, :store => options[:store])
      @context_aware = true
    end

    # The  default_context is a Graph having an _identifier_ the same as the
    # _identifier_ of the _store_.
    def default_context
      @@default_context = Graph.new(:identifier => @store.identifier, :store => @store)
    end
    
    # Contexts contained within the store
    def contexts
      @store.contexts
    end
    
    # Triples across all contexts in store, optionally matching subject, predicate, or object.
    # Delegates to Store#triples.
    #
    # @param [Triple] triple (nil) Triple to match, may be a pattern triple or nil
    # @return [Array] List of matched triples
    def triples(triple = Triple.new(nil, nil, nil), &block) # :yields: triple, context
      @store.triples(triple, nil, &block) || []
    end

    # Adds a quad from the intended subject, predicate, object, and context.
    #
    # @example
    #   g = Graph.new
    #   cg = ConjunctiveGraph.new
    #   cg.add_quad(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new, g)
    #   # => results in the triple being added to g
    #
    # @param [URIRef, BNode] subject the subject of the triple
    # @param [URIRef] predicate the predicate of the triple
    # @param [URIRef, BNode, Literal] object the object of the triple
    # @param [Graph, URIRef] context Graph or URIRef of graph context
    # @return [Graph] Returns the graph
    # @raise [Error] Checks parameter types and raises if they are incorrect.
    def add_quad(subject, predicate, object, context)
      graph = context if context.is_a?(Graph)
      graph ||= contexts.detect {|g| g.identifier == context}
      graph ||= Graph.new(:identifier => context, :store => @store)
      graph.add_triple(subject, predicate, object)
      graph
    end

    # Parse source into a new context.
    #
    # Create a new context (Graph) and parse into that.
    #
    # @param  [IO, String] stream the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [URIRef, String] uri the URI of the document
    # @param [Hash] options:: Options from
    # @option options [Array] :debug (nil) Array to place debug messages
    # @option options [:rdfxml, :html, :n3] :type (nil)
    # @option options [Boolean] :strict (false) Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph] Returns the graph containing parsed triples
    def parse(stream, uri, options = {}, &block) # :yields: triple
      graph = Graph.new(:identifier => uri, :store => self.store)
      Parser.parse(stream, uri, options.merge(:graph => graph), &block)
    end
  end
end
