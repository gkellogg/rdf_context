require 'net/http'

module Reddy
  class URIRef
    attr_accessor :uri
    
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
        raise UriRelativeException, "<" + @uri.to_s + "> is a relative URI"
      end
      if !@uri.to_s.match(/^javascript/).nil?
        raise ParserException, "Javascript pseudo-URIs are not acceptable"
      end
      
      # Unique URI through class hash to ensure that URIRefs can be easily compared
      @@uri_hash ||= {}
      @@uri_hash[@uri.to_s] ||= @uri
      @uri = @@uri_hash[@uri.to_s]
    end
    
    def + (input)
      input_uri = Addressable::URI.parse(input.to_s)
      return URIRef.new(input_uri, self.to_s)
    end
    
    def short_name
      if @uri.fragment()
        return @uri.fragment()
      elsif @uri.path.split("/").last.class == String and @uri.path.split("/").last.length > 0
        return @uri.path.split("/").last
      else
        return false
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
  
    def to_ntriples
      "<" + @uri.to_s + ">"
    end
  
    # Output URI as QName using URI binding
    def to_qname(uri_binding = {})
      uri_base = @uri.to_s
      sn = short_name.to_s
      uri_base = uri_base[0, uri_base.length - sn.length]
      if uri_binding.has_key?(uri_base)
        "#{uri_binding[uri_base]}:#{sn}"
      else
        raise ParserException, "Couldn't find QName for #{@uri}"
      end
    end
    
    # Output URI as resource reference for RDF/XML
    def xml_args
      [{"rdf:resource" => @uri.to_s}]
    end
    
    def test_string (string)
      string.to_s.each_byte do |b|
        if b >= 0 and b <= 31
          raise ParserException, "URI must not contain control characters"
        end
      end
    end

#    def load_graph
#      get = Net::HTTP.start(@uri.host, @uri.port) {|http| [:xml, http.get(@uri.path)] }
#      return Reddy::RdfXmlParser.new(get[1].body, @uri.to_s).graph if get[0] == :xml
#    end
  end
end
