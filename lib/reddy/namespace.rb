module Reddy
  # From Reddy
  class Namespace
    attr_accessor :short, :uri, :fragment
 
    ## 
    # Creates a new namespace given a URI and the short name.
    #
    # ==== Example
    #   Namespace.new("http://xmlns.com/foaf/0.1/", "foaf") # => returns a new Foaf namespace
    #
    # @param [String] uri the URI of the namespace
    # @param [String] short the short name of the namespace
    # @param [Boolean] fragment are the identifiers on this resource fragment identifiers? (e.g. '#')  Defaults to false.
    #
    # ==== Returns
    # @return [Namespace] The newly created namespace.
    #
    # @raise [Error] Checks validity of the desired shortname and raises if it is incorrect.
    # [gk] nil is a valid shortname to specify the default namespace
    # @author Tom Morris, Pius Uzamere

    def initialize(uri, short, fragment = nil)
      @uri = URIRef.new(uri) unless uri.is_a?(URIRef)
      @fragment = fragment
      @fragment = uri.to_s.match(/\#$/) ? true : false if fragment.nil?
      short = nil if short.to_s.empty?
      if shortname_valid?(short)
        @short = short
      else
        raise ParserException, "Invalid shortname '#{short}'"
      end
    end

    ## 
    # Allows the construction of arbitrary URIs on the namespace.
    #
    # ==== Example
    #   foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf"); foaf.knows # => returns a new URIRef with URI "http://xmlns.com/foaf/0.1/knows"
    #   foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf", true); foaf.knows # => returns a new URIRef with URI "http://xmlns.com/foaf/0.1/#knows"
    #
    # @param [String] uri the URI of the namespace
    # @param [String] short the short name of the namespace
    # @param [Boolean] fragment are the identifiers on this resource fragment identifiers? (e.g. '#')  Defaults to false.
    #
    # ==== Returns
    # @return [URIRef] The newly created URIRegerence.
    #
    # @raise [Error] Checks validity of the desired shortname and raises if it is incorrect.
    # @author Tom Morris, Pius Uzamere

    def method_missing(methodname, *args)
      self + methodname
    end

    # Construct a URIRef from a namespace as in method_missing, but without method collision issues
    def +(suffix)
      URIRef.new((fragment ? "##{suffix}" : suffix.to_s), @uri)
    end

    def bind(graph)
      if graph.class == Graph
        graph.bind(self)
      else
        raise GraphException, "Can't bind namespace to graph of type #{graph.class}"
      end
    end

    def eql?(other)
      @short == other.short && @uri == other.uri && @fragment == other.fragment
    end
    alias_method :==, :eql?

    # Output xmlns attribute name
    def xmlns_attr
      short.nil? ? "xmlns" : "xmlns:#{short}"
    end
    
    def xmlns_hash
      {xmlns_attr => @uri.to_s}
    end
    
    def inspect
      "Namespace[abbr='#{short}',uri='#{uri}']"
    end
    
    private
    def shortname_valid?(shortname)
      if shortname =~ /\A[a-zA-Z_][a-zA-Z0-9_]*\Z/ || shortname.nil?
        return true
      else
        return false
      end
    end
  end
end
