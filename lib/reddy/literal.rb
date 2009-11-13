require 'iconv'

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
        content = c_style(content.to_s)
        quoted_content = should_quote? ? "\"#{content}\"" : content
        "#{quoted_content}^^<#{value}>#{lang ? "@#{lang}" : ""}"
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

      #private
      # "Borrowed" from JSON utf8_to_json
      MAP = {
        "\x0" => '\u0000',
        "\x1" => '\u0001',
        "\x2" => '\u0002',
        "\x3" => '\u0003',
        "\x4" => '\u0004',
        "\x5" => '\u0005',
        "\x6" => '\u0006',
        "\x7" => '\u0007',
        "\b"  =>  '\b',
        "\t"  =>  '\t',
        "\n"  =>  '\n',
        "\xb" => '\u000B',
        "\f"  =>  '\f',
        "\r"  =>  '\r',
        "\xe" => '\u000E',
        "\xf" => '\u000F',
        "\x10" => '\u0010',
        "\x11" => '\u0011',
        "\x12" => '\u0012',
        "\x13" => '\u0013',
        "\x14" => '\u0014',
        "\x15" => '\u0015',
        "\x16" => '\u0016',
        "\x17" => '\u0017',
        "\x18" => '\u0018',
        "\x19" => '\u0019',
        "\x1a" => '\u001A',
        "\x1b" => '\u001B',
        "\x1c" => '\u001C',
        "\x1d" => '\u001D',
        "\x1e" => '\u001E',
        "\x1f" => '\u001F',
        '"'   =>  '\"',
        '\\'  =>  '\\\\',
        '/'   =>  '/',
      } # :nodoc:

      # Convert a UTF8 encoded Ruby string _string_ to a C-style string, encoded with
      # UTF16 big endian characters as \U????, and return it.
      if String.method_defined?(:force_encoding)
        def c_style(string) # :nodoc:
          string << '' # XXX workaround: avoid buffer sharing
          string.force_encoding(Encoding::ASCII_8BIT)
          string.gsub!(/["\\\/\x0-\x1f]/) { MAP[$&] }
          string.gsub!(/(
                          (?:
                            [\xc2-\xdf][\x80-\xbf]    |
                            [\xe0-\xef][\x80-\xbf]{2} |
                            [\xf0-\xf4][\x80-\xbf]{3}
                          )+ |
                          [\x80-\xc1\xf5-\xff]       # invalid
                        )/nx) { |c|
                          c.size == 1 and raise TypeError, "invalid utf8 byte: '#{c}'"
                          s = Iconv.new('utf-16be', 'utf-8').iconv(c).unpack('H*')[0].upcase
                          s.gsub!(/.{4}/n, '\\\\u\&')
                        }
          string.force_encoding(Encoding::UTF_8)
          string
        end
      else
        def c_style(string) # :nodoc:
          string = string.gsub(/["\\\/\x0-\x1f]/) { MAP[$&] }
          string.gsub!(/(
                          (?:
                            [\xc2-\xdf][\x80-\xbf]    |
                            [\xe0-\xef][\x80-\xbf]{2} |
                            [\xf0-\xf4][\x80-\xbf]{3}
                          )+ |
                          [\x80-\xc1\xf5-\xff]       # invalid
                        )/nx) { |c|
                          c.size == 1 and raise TypeError, "invalid utf8 byte: '#{c}'"
                          s = Iconv.new('utf-16be', 'utf-8').iconv(c).unpack('H*')[0].upcase
                          s.gsub!(/.{4}/n, '\\\\u\&')
                        }
          string
       end
      end
    end
    
    class Null < Encoding
      def to_s
        ''
      end

      def format_as_n3(content, lang)
        "\"#{c_style(content)}\"" + (lang ? "@#{lang}" : "")
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
        "\"#{c_style(content)}\"^^<#{value}>"
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
        if contents.is_a?(String)
          ns_hash = options[:namespaces].values.inject({}) {|h, ns| h.merge(ns.xmlns_hash)}
          ns_strs = []
          ns_hash.each_pair {|a, u| ns_strs << "#{a}=\"#{u}\""}

          # Add inherited namespaces to created root element so that they're inherited to sub-elements
          contents = Nokogiri::XML::Document.parse("<foo #{ns_strs.join(" ")}>#{contents}</foo>").root.children
        end

        # Add already mapped namespaces and language
        @contents = contents.map do |c|
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
