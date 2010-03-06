require File.join(File.dirname(__FILE__), 'abstract_serializer')

module RdfContext
  # Serialize RDF graphs in NTriples format
  class NTSerializer < AbstractSerializer
    def serialize(stream, base = nil)
      @graph.triples.collect do |t|
        stream.write(t.to_ntriples + "\n")
      end
    end
  end
end