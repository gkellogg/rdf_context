module RdfContext
  # An RDF Literal, with value, encoding and language elements.
  class Literal
    class Encoding
      attr_reader :value

      # New Encoding for a literal, typed, untyped or XMLLiteral
      def initialize(value)
        @value = URIRef.new(value.to_s) if value
      end

      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#int")</tt>
      def self.integer
        @integer ||= coerce "http://www.w3.org/2001/XMLSchema#int"
      end

      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#float")</tt>
      def self.float
        @float ||= coerce "http://www.w3.org/2001/XMLSchema#float"
      end

      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#string")</tt>
      def self.string
        @string ||= coerce "http://www.w3.org/2001/XMLSchema#string"
      end

      # Create from URI, empty or nil string
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

      # Compare against another encoding, or a URI of a literal type
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

      # Generate hash of type to determine uniqueness
      def hash
        @value.hash
      end

      def to_s
        @value.to_s
      end

      # Serialize literal, adding datatype and language elements, if present.
      # XMLLiteral and String values are RDF-escaped.
      def format_as_n3(content, lang)
        quoted_content = "\"#{content.to_s.rdf_escape}\"^^<#{value}>"
      end

      # Serialize literal to TriX
      def format_as_trix(content, lang)
        lang = " xml:lang=\"#{lang}\"" if lang
        "<typedLiteral datatype=\"#{@value}\"#{lang}>#{content}</typedLiteral>"
      end
      
      # Return content and hash appropriate for encoding in XML
      #
      # ==== Example
      #  Encoding.string.xml_args("foo", "en-US") => ["foo", {"rdf:datatype" => "xs:string"}]
      def xml_args(content, lang)
        hash = {"rdf:datatype" => @value.to_s}
        [content.to_s, hash]
      end
      
      # Compare literal contents, ignore language
      def compare_contents(a, b, same_lang)
        a == b
      end
      
      # Encode literal contents
      def encode_contents(contents, options)
        contents
      end
    end
    
    # The null encoding
    class Null < Encoding
      def to_s
        ''
      end

      # Format content for n3/N-Triples. Quote an RDF-escape and include language
      def format_as_n3(content, lang)
        "\"#{content.to_s.rdf_escape}\"" + (lang ? "@#{lang}" : "")
      end

      # Format content for TriX
      def format_as_trix(content, lang)
        if lang
          "<plainLiteral xml:lang=\"#{lang}\"\>#{content}</plainLiteral>"
        else
          "<plainLiteral>#{content}</plainLiteral>"
        end
      end

      # Return content and hash appropriate for encoding in XML
      #
      # ==== Example
      #  Encoding.the_null_encoding.xml_args("foo", "en-US") => ["foo", {"xml:lang" => "en-US"}]
      def xml_args(content, lang)
        hash = {}
        hash["xml:lang"] = lang if lang
        [content, hash]
      end
      
      # Compare literal contents, requiring languages to match
      def compare_contents(a, b, same_lang)
        a == b && same_lang
      end
      
      def inspect
        "<Literal::Encoding::Null>"
      end
    end

    class XMLLiteral < Encoding
      # Compare XMLLiterals
      #
      # Nokogiri doesn't do a deep compare of elements
      #
      # Convert node-sets to hash using ActiveSupport::XmlMini and compare hashes.
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

      # Map namespaces from context to each top-level element found within node-set
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
    
    # Create literal from a string that is already N3 encoded.
    def self.n3_encoded(contents, language, encoding = nil)
      encoding = encoding.nil? ? Encoding.the_null_encoding : Encoding.coerce(encoding)
      options = {}
      options[:language] = language if language
      #puts "encoded: #{contents.dump}"
      contents = contents.rdf_unescape
      #puts "unencoded: #{contents.dump}"
      new(contents, encoding, options)
    end
    
    # Create an un-typed literal with a language
    def self.untyped(contents, language = nil)
      options = {}
      options[:language] = language if language
      new(contents, Encoding.the_null_encoding, options)
    end
    
    # Create a typed literal
    # Options include:
    # _namespaces_:: A hash of namespace entries (for XMLLiteral)
    def self.typed(contents, encoding, options = {})
      encoding = Encoding.coerce(encoding)
      new(contents, encoding, options)
    end
    
    # Create a literal appropriate for type of object by datatype introspection
    def self.build_from(object)
      new(object.to_s, infer_encoding_for(object))
    end

    # Infer the proper XML datatype for the given object
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

    # Compare literal with another literal or a string.
    # If a string is passed, only contents must match.
    # Otherwise, compare encoding types, contents and languages.
    def ==(other)
      case other
      when String     then other == self.contents
      when self.class
        other.encoding == @encoding &&
        @encoding.compare_contents(self.contents, other.contents, other.lang == @lang)
      else false
      end
    end
    
    def hash
      [@contents, @encoding, @lang].hash
    end

    # Output literal in N3 format
    def to_n3
      encoding.format_as_n3(self.contents, @lang)
    end
    alias_method :to_ntriples, :to_n3

    # Output literal in TriX format
    def to_trix
      encoding.format_as_trix(@contents, @lang)
    end
    
    # Return content and hash appropriate for encoding in XML
    #
    # ==== Example
    #  Encoding.the_null_encoding.xml_args("foo", "en-US") => ["foo", {"xml:lang" => "en-US"}]
    def xml_args
      encoding.xml_args( @contents, @lang)
    end

    # Is this an XMLLiteral?
    def xmlliteral?
      encoding.is_a?(XMLLiteral)
    end
    
    # Output literal contents as a string
    def to_s
      self.contents.to_s
    end
  end
end
