module RdfContext
  # From RdfContext
  class Namespace
    attr_accessor :prefix, :fragment
 
    ## 
    # Creates a new namespace given a URI and the prefix.
    #
    #  nil is a valid prefix to specify the default namespace
    # ==== Example
    #   Namespace.new("http://xmlns.com/foaf/0.1/", "foaf") # => returns a new Foaf namespace
    #
    # @param [#to_s] uri the URI of the namespace
    # @param [#to_s] prefix the prefix of the namespace
    # @return [Namespace] The newly created namespace.
    # @raise [ParserException] Checks validity of the desired prefix and raises if it is incorrect.
    #
    # @author Tom Morris, Pius Uzamere
    def initialize(uri, prefix)
      prefix = prefix.to_s

      @uri = uri.to_s

      raise ParserException, "Invalid prefix '#{prefix}'" unless prefix_valid?(prefix)
      @prefix = prefix
    end

    ## 
    # Allows the construction of arbitrary URIs on the namespace.
    #
    # @example
    #   foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf"); foaf.knows # => returns a new URIRef with URI "http://xmlns.com/foaf/0.1/knows"
    #   foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf", true); foaf.knows # => returns a new URIRef with URI "http://xmlns.com/foaf/0.1/#knows"
    #
    # To avoid naming problems, a suffix may have an appended '_', which will be removed when the URI is generated.
    #
    # @param [#to_s] methodname to append to NS URI to create a new URI
    # @param [Array] args Ignored arguments
    # @return [URIRef] The newly created URI.
    # @raise [Error] Checks validity of the desired prefix and raises if it is incorrect.
    # @author Tom Morris
    # @author Pius Uzamere
    def method_missing(methodname, *args)
      self + methodname
    end

    # Construct a URIRef from a namespace as in method_missing, but without method collision issues.
    # Rules are somewhat different than for normal URI unions, as the raw URI is used as the source,
    # not a normalized URI, and the result is not normalized
    # @param [#to_s] methodname to append to NS URI to create a new URI
    # @return [URIRef] The newly created URI.
    def +(suffix)
      prefix = @uri
      suffix = suffix.to_s.sub(/^\#/, "") if prefix.index("#")
      suffix = suffix.to_s.sub(/_$/, '')
      URIRef.new(prefix + suffix.to_s, :normalize => false, :namespace => self)
    end

    # Make sure to attach fragment
    # @return [URIRef] The newly created URI.
    def uri
      self + ""
    end
    
    # Bind this namespace to a Graph
    # @param [Graph] graph
    # @return [Namespace] The newly created URI.
    def bind(graph)
      graph.bind(self)
    end

    # Compare namespaces
    # @param [Namespace] other
    # @return [Boolean]
    def eql?(other)
      self.uri == other.uri
    end
    alias_method :==, :eql?

    # Output xmlns attribute name
    # @return [String]
    def xmlns_attr
      prefix.empty? ? "xmlns" : "xmlns:#{prefix}"
    end
    
    # Output namespace definition as a hash
    # @return [Hash{String => String}]
    def xmlns_hash
      {xmlns_attr => @uri.to_s}
    end
    
    # @return [String]
    def to_s
      "#{prefix}: #{@uri}"
    end
    
    def inspect
      "Namespace[abbr='#{prefix}',uri='#{@uri}']"
    end
    
    private
    # The Namespace prefix must be an NCName
    def prefix_valid?(prefix)
      NC_REGEXP.match(prefix.to_s) || prefix.to_s.empty?
    end
  end
end
