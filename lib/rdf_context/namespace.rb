module RdfContext
  # From RdfContext
  class Namespace
    attr_accessor :prefix, :uri, :fragment
 
    ## 
    # Creates a new namespace given a URI and the prefix.
    #
    #  nil is a valid prefix to specify the default namespace
    # ==== Example
    #   Namespace.new("http://xmlns.com/foaf/0.1/", "foaf") # => returns a new Foaf namespace
    #
    # @param [String] uri:: the URI of the namespace
    # @param [String] prefix:: the prefix of the namespace
    # @param [Boolean] fragment:: are the identifiers on this resource fragment identifiers? (e.g. '#')  Defaults to false.
    # @return [Namespace]:: The newly created namespace.
    # @raise [Error]:: Checks validity of the desired prefix and raises if it is incorrect.
    #
    # @author Tom Morris, Pius Uzamere
    def initialize(uri, prefix, fragment = nil)
      prefix = prefix.to_s
      @uri = URIRef.new(uri) unless uri.is_a?(URIRef)
      @fragment = fragment
      @fragment = uri.to_s.match(/\#$/) ? true : false if fragment.nil?
      if prefix_valid?(prefix)
        @prefix = prefix
      else
        raise ParserException, "Invalid prefix '#{prefix}'"
      end
    end

    ## 
    # Allows the construction of arbitrary URIs on the namespace.
    #
    # ==== Example
    #   foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf"); foaf.knows # => returns a new URIRef with URI "http://xmlns.com/foaf/0.1/knows"
    #   foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf", true); foaf.knows # => returns a new URIRef with URI "http://xmlns.com/foaf/0.1/#knows"
    #
    # To avoid naming problems, a suffix may have an appended '_', which will be removed when the URI is generated.
    #
    # @return [URIRef]:: The newly created URIRegerence.
    # @raise [Error]:: Checks validity of the desired prefix and raises if it is incorrect.
    # @author Tom Morris, Pius Uzamere
    def method_missing(methodname, *args)
      self + methodname
    end

    # Construct a URIRef from a namespace as in method_missing, but without method collision issues
    def +(suffix)
      prefix = @uri.to_s
      prefix += '#' if fragment && !prefix.match(/\#$/)
      suffix = suffix.to_s.sub(/_$/, '')
      URIRef.new(prefix + suffix)
    end

    # Bind this namespace to a Graph
    def bind(graph)
      graph.bind(self)
    end

    # Compare namespaces
    def eql?(other)
      @prefix == other.prefix && @uri == other.uri && @fragment == other.fragment
    end
    alias_method :==, :eql?

    # Output xmlns attribute name
    def xmlns_attr
      prefix.empty? ? "xmlns" : "xmlns:#{prefix}"
    end
    
    # Output namespace definition as a hash
    def xmlns_hash
      {xmlns_attr => @uri.to_s}
    end
    
    def inspect
      "Namespace[abbr='#{prefix}',uri='#{uri}']"
    end
    
    private
    # The Namespace prefix must be an NCName
    def prefix_valid?(prefix)
      NC_REGEXP.match(prefix) || prefix.to_s.empty?
    end
  end
end
