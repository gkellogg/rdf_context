require File.join(File.dirname(__FILE__), "graph.rb")

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
      unless options[:store] && options[:store].context_aware?
        raise GraphException.new("Conjuective Graph requires store supporting contexts")
      end
    
      super(:identifier => options[:store].identifier)
      @context_aware = true
    end
  
    # Parse source into a new context.
    #
    # Create a new context (Graph) and parse into that.
    #
    # @param  [IO, String] stream:: the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri:: the URI of the document
    # @param [Hash] options:: Options from
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:type]</em>:: One of _rdfxml_, _html_, or _n3_
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph]:: Returns the graph containing parsed triples
    def parse(stream, uri, options = {}, &block) # :yields: triple
      graph = Graph.new(:identifier => uri, :store => self.store)
      Parser.parse(stream, uri, options.merge(:graph => graph), &block)
    end
  end
end
