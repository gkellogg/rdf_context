require 'net/http'
require File.join(File.dirname(__FILE__), "string_hacks")

module RdfContext
  class URIRef < Resource
    attr_accessor :uri
    attr_reader   :namespace
    
    # Create a URIRef from a URI  or a fragment and a URI
    #
    # @example
    #   u = URIRef.new("http://example.com")
    #   u = URIRef.new("foo", u) => "http://example.com/foo"
    # 
    # Last argument may be an options hash to set:
    # @param [Array<#to_s>] args One or two URIs to create. Last is joined with first
    # @option options[Boolean] :normalize Normalize URI when transforming to string, defaults to true
    # @option options[Namespace] :namespace Namespace used to create this URI, useful for to_qname
    def initialize (*args)
      options = args.last.is_a?(Hash) ? args.pop : { :normalize => false }
      @normalize = options[:normalize]
      @namespace = options[:namespace]

      args.each {|s| test_string(s)}
      if args.size == 1
        uri = Addressable::URI.parse(args[0].to_s.rdf_unescape.rdf_escape)
      else
        uri = Addressable::URI.join(*args.compact.map{|s| s.to_s.rdf_unescape.rdf_escape}.reverse)
      end

      raise ParserException, "<" + uri.to_s + "> is a relative URI" if uri.relative?

      # Unique URI through class hash to ensure that URIRefs can be easily compared
      @@uri_hash ||= {}
      @uri = @@uri_hash["#{uri}#{@normalize}"] ||= begin
        # Special case if URI has no path, and the authority ends with a '#'
        #uri = Addressable::URI.parse($1) if @normalize && uri.to_s.match(/^(.*)\#$/)

        #@normalize ? uri.normalize : uri
        uri
      end.freeze
    end
    
    ##
    # Returns `true`
    #
    # @return [Boolean]
    def uri?
      true
    end

    # Parse a URIRef
    def self.parse(str)
      URIRef.new($1) if str =~ /^<?([^>]*)>?$/ rescue nil
    end
    
    # Internalized version of URIRef
    def self.intern(*args)
      @@uri_hash ||= {}
      @@uri_hash[args.to_s] ||= URIRef.new(*args)
    end
    
    # Create a URI, either by appending a fragment, or using the input URI
    # @param [#to_s] input
    # @return [URIRef]
    def + (input)
      input_uri = Addressable::URI.parse(input.to_s)
      return URIRef.intern(input_uri, self.to_s)
    end
    
    # short_name of URI for creating QNames.
    #   "#{base]{#short_name}}" == uri
    # @return [String, false]
    def short_name
      @short_name ||= begin
        path = @uri.path.split("/")
        if @namespace
          self.to_s.sub(@namespace.uri.to_s, "")
        elsif @uri.fragment
          @uri.fragment
        elsif path && path.length > 1 && path.last.class == String && path.last.length > 0 && path.last.index("/") != 0
          path.last
        else
          false
        end
      end
    end
    
    # base of URI for creating QNames.
    #   "#{base]{#short_name}}" == uri
    # @return [String]
    def base
      @base ||= begin
        uri_base = self.to_s
        sn = short_name ? short_name.to_s : ""
        uri_base[0, uri_base.length - sn.length]
      end
    end
  
    # @param [URIRef] other
    # @return [Boolean]
    def eql?(other)
      self.to_s == other.to_s
    end
    alias_method :==, :eql?
    
    # @param [#to_s] other
    # @return [-1, 0 1]
    def <=>(other)
      self.to_s <=> other.to_s
    end
  
    # Needed for uniq
    # @return [String]
    def hash; to_s.hash; end
  
    # @return [String]
    def to_s
      @to_s ||= @uri.to_s
    end
  
    # @return [String]
    def to_n3
      "<" + self.to_s + ">"
    end
    alias_method :to_ntriples, :to_n3
  
    # Output URI as QName using URI binding
    # @return [String]
    def to_qname(uri_binding = [])
      namespaces = case uri_binding
      when Hash then uri_binding.values
      when Array then uri_binding
      else []
      end
      ns = namespace(namespaces)
      "#{ns.prefix}:#{short_name}" if ns
    end
    
    # Look at namespaces and find first that matches this URI, ordering by longest URI first
    # @param [Array<Namespace>] namespaces ([])
    # @return [Namespace]
    def namespace(namespaces = [])
      @namespace ||=
        namespaces.sort_by {|ns| -ns.uri.to_s.length}.detect {|ns| self.to_s.index(ns.uri.to_s) == 0}
    end
    
    def inspect
      "#{self.class}[#{self.to_n3}, ns=#{namespace.inspect}]"
    end
    
    # Output URI as resource reference for RDF/XML
    # @return [Array<Hash{String => String}>]
    def xml_args
      [{"rdf:resource" => self.to_s}]
    end
    
    protected
    def test_string (string)
      string.to_s.each_byte do |b|
        if b >= 0 and b <= 31
          raise ParserException, "URI '#{string}' must not contain control characters"
        end
      end
    end
  end
end
