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
    #
    # @param [IO, StreamIO] stream:: Stream in which to place serialized graph
    # @param [Hash] options:: Options for parser
    # <em>options[:base]</em>:: Base URI of graph, used to shorting URI references
    def serialize(stream, options = {})
    end
    
    def relativize(uri)
      uri = uri.to_s
      self.base ? uri.sub(/^#{self.base}/, "") : uri
    end
  end
end