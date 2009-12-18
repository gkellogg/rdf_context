require 'reddy/graph'

module Reddy
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
  #
  # A ConjunctiveGraph has a _default_graph_ and a _default_context_
  class ConjunctiveGraph < Graph
    attr_reader :default_context
    attr_reader :default_graph
  
    # Store for ConjunctiveGraph must support contexts.
    def initialize(options = {})
      if options[:store] && options[:store].context_aware?
        raise GraphException.new("Conjuective Graph requires store supporting contexts")
      end
    
      super
      
      # Create the default_context for this Conjunctive Graph
      default_context = Graph.new(options.merge(:identifier => self.identifier))
      
      @context_aware = true
    end
  
    ## 
    # Adds an extant triples to the default context. Delegates to Store.
    #
    # ==== Example
    #   g = Graph.new;
    #   t = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new);
    #   g << t
    #
    # @param [Triple] t:: the triple to be added to the graph
    # @return [Graph]:: Returns the graph
    def << (triple)
      @store.add_triple(triple, @default_context)
      self
    end
    
    # Removes from all its contexts.
    def remove(triple); @store.remove(triple, nil); end

    # Triples from entire conjunctive graph, optionally matching subject, predicate, or object.
    # Delegates to Store#triples.
    #
    # @param [Hash] options:: List of options for matching triples
    # <em>options[:subject]</em>:: If specified, limited to triples having the specified subject
    # <em>options[:predicate]</em>:: If specified, limited to triples having the specified predicate
    # <em>options[:object]</em>:: If specified, limited to triples having the specified object. May be a Regexp
    # @return [Array]:: List of matched triples
    def triples(options = {}, &block) # :yields: triple
      @store.triples(options.merge(:context => nil), &block) || []
    end

    # ConjunctiveGraphs have a _quads_ method which returns quads instead of triples, wher the fourth
    # item is the Graph (or subclass) instance in which the triple is asserted
    #
    # Quads from graph, optionally matching subject, predicate, or object.
    # Delegates to Store#quads.
    #
    #  unique_graph_names = ConjunctiveGraph(store).quads.map(&:last).uniq
    #  union_graph = ReadOnlyGraphAggregate(g1, g2)
    #  unique_graph_names = union_graph.quads.map(&:last).uniq
    #
    # @param [Hash] options:: List of options for matching triples
    # <em>options[:subject]</em>:: If specified, limited to quads having the specified subject
    # <em>options[:predicate]</em>:: If specified, limited to quads having the specified predicate
    # <em>options[:object]</em>:: If specified, limited to quads having the specified object. May be a Regexp
    # <em>options[:graph]</em>:: If specified, limited to quads having the specified graph identifier. May be a Regexp
    # @return [Array]:: List of matched triples
    def quads(options = {}, &block) # :yields: triple, context
      @store.quads(options.merge(:context => nil), &block) || []
    end
    
    # Number of triples in the entire conjunctive graph
    def size
      @store.respond_to?(:size) ? @store.size(nil) : triples.size
    end

    # Removes the given context from the store
    def remove_context(context)
      @store.remove(nil, context)
    end
    
    # URI#context
    def context_id(uri, context_id = nil)
      uri = Addressable::URI.parse(uri.to_s)
      uri.fragment = context_id || "context"
      URIRef(uri)
    end
    
    # Parse source into a new context.
    #
    # If Graph is context-aware, create a new context (Graph) and parse into that. Otherwise,
    # merges results into a common Graph
    #
    # @param  [IO, String] stream:: the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri:: the URI of the document
    # @param [Hash] options:: Options from
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:type]</em>:: One of _rdfxml_, _html_, or _n3_
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    def parse(stream, uri, options = {}, &block) # :yields: triple
      id = self.context_id(uri)
      Parser.parse(stream, uri, options.merge(:graph => self), &block)
    end
  end
end
