module Reddy
  # An RDF Literal, with value, encoding and language elements.
  class Literal
    class Encoding
      attr_reader :value

      def self.integer
        @integer ||= coerce "http://www.w3.org/2001/XMLSchema#int"
      end

      def self.float
        @float ||= coerce "http://www.w3.org/2001/XMLSchema#float"
      end

      def self.string
        @string ||= coerce "http://www.w3.org/2001/XMLSchema#string"
      end

      def self.coerce(string_or_nil)
        if string_or_nil.nil? || string_or_nil == ''
          the_null_encoding
        elsif xmlliteral == string_or_nil.to_s
          xmlliteral
        else
          new string_or_nil
        end
      end
      
      def inspect
        to_s()
      end
      
      def self.the_null_encoding
        @the_null_encoding ||= Null.new(nil)
      end

      def self.xmlliteral
        @xmlliteral ||= XMLLiteral.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")
      end
      
      def initialize(value)
        @value = URIRef.new(value.to_s) if value
      end

      def should_quote?
        #@value != self.class.integer.to_s
        true  # All non-XML literals are quoted per W3C RDF Test Cases
      end

      def ==(other)
        case other
        when String
          other == @value.to_s
        when self.class
          other.value.to_s == @value.to_s
        else
          false
        end
      end

      def hash
        @value.hash
      end

      def to_s
        @value.to_s
      end

      # Serialize literal, adding datatype and language elements, if present.
      # XMLLiteral and String values are encoding using C-style strings with
      # non-printable ASCII characters escaped.
      def format_as_n3(content, lang)
        content = content.to_s.rdf_escape
        quoted_content = should_quote? ? "\"#{content}\"" : content
        "#{quoted_content}^^<#{value}>"
      end

      def format_as_trix(content, lang)
        lang = " xml:lang=\"#{lang}\"" if lang
        "<typedLiteral datatype=\"#{@value}\"#{lang}>#{content}</typedLiteral>"
      end
      
      def xml_args(content, lang)
        hash = {"rdf:datatype" => @value.to_s}
        hash["xml:lang"] = lang if lang
        [content.to_s, hash]
      end
      
      def compare_contents(a, b, same_lang)
        a == b && same_lang
      end
      
      def encode_contents(contents, options)
        contents
      end

      def xmlliteral?
        false
      end
    end
    
    class Null < Encoding
      def to_s
        ''
      end

      def format_as_n3(content, lang)
        "\"#{content.to_s.rdf_escape}\"" + (lang ? "@#{lang}" : "")
        # Perform translation on value if it's typed
      end

      def format_as_trix(content, lang)
        if lang
          "<plainLiteral xml:lang=\"#{lang}\"\>#{content}</plainLiteral>"
        else
          "<plainLiteral>#{content}</plainLiteral>"
        end
      end

      def xml_args(content, lang)
        hash = {}
        hash["xml:lang"] = lang if lang
        [content, hash]
      end
      
      def inspect
        "<theReddy::TypeLiteral::Encoding::Null>"
      end

      def xmlliteral?
        false
      end
    end

    class XMLLiteral < Encoding
      # Compare XMLLiterals
      # FIXME: Nokogiri doesn't do a deep compare of elements
      def compare_contents(a, b, same_lang)
        begin
          a_hash = ActiveSupport::XmlMini.parse("<foo>#{a}</foo>")
          b_hash = ActiveSupport::XmlMini.parse("<foo>#{b}</foo>")
          a_hash == b_hash
        rescue
          super
        end
      end
      
      def format_as_n3(content, lang)
        "\"#{content.to_s.rdf_escape}\"^^<#{value}>"
      end

      def format_as_trix(content, lang)
        "<typedLiteral datatype=\"#{@value}\">#{content}</typedLiteral>"
      end

      def xml_args(content, lang)
        hash = {"rdf:parseType" => "Literal"}
        [content, hash]
      end

      # Map namespaces from context to each top-level element found within snippet
      def encode_contents(contents, options)
        #puts "encode_contents: '#{contents}'"
        if contents.is_a?(String)
          ns_hash = options[:namespaces].values.inject({}) {|h, ns| h.merge(ns.xmlns_hash)}
          ns_strs = []
          ns_hash.each_pair {|a, u| ns_strs << "#{a}=\"#{u}\""}

          # Add inherited namespaces to created root element so that they're inherited to sub-elements
          contents = Nokogiri::XML::Document.parse("<foo #{ns_strs.join(" ")}>#{contents}</foo>").root.children
        end

        # Add already mapped namespaces and language
        @contents = contents.map do |c|
          c = Nokogiri::XML.parse(c.copy(true).to_s) if c.is_a?(LibXML::XML::Node)
          if c.is_a?(Nokogiri::XML::Element)
            # Gather namespaces from self and decendant nodes
            c.traverse do |n|
              ns = n.namespace
              next unless ns
              prefix = ns.prefix ? "xmlns:#{ns.prefix}" : "xmlns"
              c[prefix] = ns.href unless c.namespaces[prefix]
            end
            
            # Add lanuage
            if options[:language] && c["lang"].to_s.empty?
              c["xml:lang"] = options[:language]
            end
          end
          c.to_html
        end.join("")
      end

      def xmlliteral?
        true
      end
    end

    class Language
      attr_accessor :value
      def initialize(string)
        @value = string.to_s.downcase
      end

      def clean(string)
        case string
        when "eng"; "en"
        else string
        end
      end

      def == (other)
        case other
        when String
          other == @value
        when self.class
          other.value == @value
        end
      end
      
      def to_s; @value; end
    end

    attr_accessor :contents, :encoding, :lang
    
    # Create a new Literal. Optinally pass a namespaces hash
    # for use in applying to rdf::XMLLiteral values.
    def initialize(contents, encoding, options = {})
      unless encoding.is_a?(Encoding)
        raise TypeError, "#{encoding.inspect} should be an instance of Encoding"
      end
      @encoding = encoding
      lang = options[:language]
      @lang = Language.new(lang) if lang
      options = {:namespaces => {}}.merge(options)

      @contents = @encoding.encode_contents(contents, options)
    end
    
    def self.n3_encoded(contents, language, encoding = nil)
      encoding = encoding.nil? ? Encoding.the_null_encoding : Encoding.coerce(encoding)
      options = {}
      options[:language] = language if language
      #puts "encoded: #{contents.dump}"
      contents = contents.rdf_unescape
      #puts "unencoded: #{contents.dump}"
      new(contents, encoding, options)
    end
    
    def self.untyped(contents, language = nil)
      options = {}
      options[:language] = language if language
      new(contents, Encoding.the_null_encoding, options)
    end
    
    # Options include:
    # _namespaces_:: A hash of namespace entries (for XMLLiteral)
    # _language_:: Language encoding
    def self.typed(contents, encoding, options = {})
      encoding = Encoding.coerce(encoding)
      new(contents, encoding, options)
    end
    
    def self.build_from(object)
      new(object.to_s, infer_encoding_for(object))
    end

    def self.infer_encoding_for(object)
      case object
      when Integer  then Encoding.new("http://www.w3.org/2001/XMLSchema#int")
      when Float    then Encoding.new("http://www.w3.org/2001/XMLSchema#float")
      when Time     then Encoding.new("http://www.w3.org/2001/XMLSchema#time")
      when DateTime then Encoding.new("http://www.w3.org/2001/XMLSchema#dateTime")
      when Date     then Encoding.new("http://www.w3.org/2001/XMLSchema#date")
      else               Encoding.new("http://www.w3.org/2001/XMLSchema#string")
      end
    end

   class << self
      protected :new
    end

    def ==(other)
      case other
      when String     then other == self.contents
      when self.class
        other.encoding == @encoding &&
        @encoding.compare_contents(self.contents, other.contents, other.lang == @lang)
      else false
      end
    end

    def to_n3
      encoding.format_as_n3(self.contents, @lang)
    end
    alias_method :to_ntriples, :to_n3

    def to_trix
      encoding.format_as_trix(@contents, @lang)
    end
    
    def xml_args
      encoding.xml_args( @contents, @lang)
    end

    def xmlliteral?
      encoding.xmlliteral?
    end
    
    # Output value
    def to_s
      self.contents.to_s
    end
  end
end
