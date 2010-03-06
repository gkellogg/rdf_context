require File.join(File.dirname(__FILE__), '..', 'uriref')

module RdfContext
  # Abstract serializer
  class AbstractSerializer
    attr_accessor :graph, :base
    
    def initialize(graph)
      @graph = graph
      @base = nil
    end
    
    # Serialize the graph
    def serialize(stream, base = nil)
    end
    
    def relativaize(uri)
      self.base ? URIRef.new(uri.to_s.sub(/^#{self.base}/, "")) : (uri.is_a?(URIRef) ? uri : URIRef.new(uri.to_s))
    end
  end
end