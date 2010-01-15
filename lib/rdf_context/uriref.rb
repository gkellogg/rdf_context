require 'net/http'

module RdfContext
  class URIRef
    attr_accessor :uri
    attr_reader   :namespace
    
    # Create a URIRef from a URI  or a fragment and a URI
    #
    # ==== Example
    #   u = URIRef.new("http://example.com")
    #   u = URIRef.new("foo", u) => "http://example.com/foo"
    # 
    def initialize (*args)
      args.each {|s| test_string(s)}
      if args.size == 1
        @uri = Addressable::URI.parse(args[0].to_s)
      else
        @uri = Addressable::URI.join(*args.map{|s| s.to_s}.reverse)
      end
      if @uri.relative?
        raise ParserException, "<" + @uri.to_s + "> is a relative URI"
      end
      if !@uri.to_s.match(/^javascript/).nil?
        raise ParserException, "Javascript pseudo-URIs are not acceptable"
      end
      
      # Unique URI through class hash to ensure that URIRefs can be easily compared
      @@uri_hash ||= {}
      @@uri_hash[@uri.to_s] ||= @uri.freeze
      @uri = @@uri_hash[@uri.to_s]
    end
    
    # Create a URI, either by appending a fragment, or using the input URI
    def + (input)
      input_uri = Addressable::URI.parse(input.to_s)
      return URIRef.new(input_uri, self.to_s)
    end
    
    # short_name of URI for creating QNames.
    #   "#{base]{#short_name}}" == uri
    def short_name
      @short_name ||= if @uri.fragment()
        @uri.fragment()
      elsif @uri.path.split("/").last.class == String and @uri.path.split("/").last.length > 0
        @uri.path.split("/").last
      else
        false
      end
    end
    
    # base of URI for creating QNames.
    #   "#{base]{#short_name}}" == uri
    def base
      @base ||= begin
        uri_base = @uri.to_s
        sn = short_name.to_s
        uri_base[0, uri_base.length - sn.length]
      end
    end
  
    def eql?(other)
      @uri.to_s == other.to_s
    end
    alias_method :==, :eql?
  
    # Needed for uniq
    def hash; to_s.hash; end
  
    def to_s
      @uri.to_s
    end
  
    def to_n3
      "<" + @uri.to_s + ">"
    end
    alias_method :to_ntriples, :to_n3
  
    # Output URI as QName using URI binding
    def to_qname(uri_binding = {})
      @namespace ||= uri_binding[self.base]
      raise RdfException, "Couldn't find QName for #{@uri}" unless @namespace
      "#{@namespace.prefix}:#{self.short_name}"
    end
    
    def inspect
      "#{self.class}[#{self.to_n3}]"
    end
    
    # Output URI as resource reference for RDF/XML
    def xml_args
      [{"rdf:resource" => @uri.to_s}]
    end
    
    def test_string (string)
      string.to_s.each_byte do |b|
        if b >= 0 and b <= 31
          raise ParserException, "URI '#{string}' must not contain control characters"
        end
      end
    end

#    def load_graph
#      get = Net::HTTP.start(@uri.host, @uri.port) {|http| [:xml, http.get(@uri.path)] }
#      return RdfContext::RdfXmlParser.new(get[1].body, @uri.to_s).graph if get[0] == :xml
#    end
  end
end
