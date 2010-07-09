require File.join(File.dirname(__FILE__), 'abstract_serializer')

module RdfContext
  # Serialize RDF graphs in NTriples format
  class NTSerializer < AbstractSerializer
    # Serialize the graph
    #
    # @param [IO, StreamIO] stream Stream in which to place serialized graph
    # @option options [URIRef, String] :base (nil) Base URI of graph, used to shorting URI references
    # @return [void]
    def serialize(stream, base = nil)
      @graph.triples.collect do |t|
        stream.write(t.to_ntriples + "\n")
      end
    end
  end
end