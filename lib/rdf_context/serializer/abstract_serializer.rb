module RdfContext
  # Abstract serializer
  class AbstractSerializer
    # @return [Graph]
    attr_accessor :graph
    
    # @return [String]
    attr_accessor :base
    
    # New AbstractSerializer
    # @param [Graph] graph
    # @return [AbstractSerializer]
    def initialize(graph)
      @graph = graph
      @base = nil
    end
    
    # Serialize the graph
    #
    # @param [IO, StreamIO] stream Stream in which to place serialized graph
    # @option options [URIRef, String] :base (nil) Base URI of graph, used to shorting URI references
    # @return [void]
    def serialize(stream, options = {})
    end
    
    # Create a relative version of the _uri_ parameter if a _base_ URI is defined
    # @param [#to_s] uri
    # @return [String]
    def relativize(uri)
      uri = uri.to_s
      self.base ? uri.sub(self.base, "") : uri
    end
  end
end