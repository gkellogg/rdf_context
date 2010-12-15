begin
  require 'xml'
  $libxml_enabled = true
rescue LoadError
end

require File.join(File.dirname(__FILE__), 'duration')
require File.join(File.dirname(__FILE__), "resource")

module RdfContext
  # An RDF Literal, with value, encoding and language elements.
  class Literal < Resource
    class Encoding
      attr_reader :value

      # New Encoding for a literal, typed, untyped or XMLLiteral
      def initialize(value)
        @value = URIRef.new(value.to_s) if value
      end

      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#boolean")</tt>
      def self.boolean
        @boolean ||= coerce XSD_NS.boolean
      end

      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#double")</tt>
      def self.double
        @double ||= coerce XSD_NS.double
      end

      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#float")</tt>
      def self.float
        @float ||= coerce XSD_NS.float
      end

      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#int")</tt>
      def self.integer
        @integer ||= coerce XSD_NS.int
      end

      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#date")</tt>
      def self.date
        @date ||= coerce XSD_NS.date
      end
      
      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#dateTime")</tt>
      def self.datetime
        @datetime ||= coerce XSD_NS.dateTime
      end
      
      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#duration")</tt>
      def self.duration
        @duration ||= coerce XSD_NS.duration
      end
      
      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#string")</tt>
      def self.string
        @string ||= coerce XSD_NS.string
      end
      
      # Shortcut for <tt>Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#time")</tt>
      def self.time
        @time ||= coerce XSD_NS.time
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
      alias_method :eql?, :==

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
        return contents.to_s unless valid?(contents)
        
        case @value
        when XSD_NS.boolean then %(1 true).include?(contents.to_s.downcase) ? "true" : "false"
        when XSD_NS.integer then contents.to_i.to_s
        when XSD_NS.decimal
          # Can't use simple %f transformation do to special requirements from N3 tests in representation
          i, f = contents.to_s.split(".")
          f = f.to_s[0,16]  # Truncate after 15 decimal places
          i.sub!(/^\+?0+(\d)$/, '\1')
          f.sub!(/0*$/, '')
          f = "0" if f.empty?
          "#{i}.#{f}"
        when XSD_NS.double
          i, f, e = ("%.16E" % contents.to_f).split(/[\.E]/)
          f.sub!(/0*$/, '')
          f = "0" if f.empty?
          e.sub!(/^\+?0+(\d)$/, '\1')
          "#{i}.#{f}E#{e}"
        when XSD_NS.time      then contents.is_a?(Time) ? contents.strftime("%H:%M:%S%Z").sub(/\+00:00|UTC/, "Z") : contents.to_s
        when XSD_NS.dateTime  then contents.is_a?(DateTime) ? contents.strftime("%Y-%m-%dT%H:%M:%S%Z").sub(/\+00:00|UTC/, "Z") : contents.to_s
        when XSD_NS.date      then contents.is_a?(Date) ? contents.strftime("%Y-%m-%d%Z").sub(/\+00:00|UTC/, "Z") : contents.to_s
        when XSD_NS.duration  then contents.is_a?(Duration) ? contents.to_s(:xml) : contents.to_s
        else                       contents.to_s
        end
      end
      
      # Validate format of content
      def valid?(contents)
        case @value
        when XSD_NS.boolean   then %w(1 true 0 false).include?(contents.to_s.downcase)
        when XSD_NS.decimal   then !!contents.to_s.match(/^[\+\-]?\d+(\.\d*)?$/)
        when XSD_NS.double    then !!contents.to_s.match(/^[\+\-]?\d+(\.\d*([eE][\+\-]?\d+)?)?$/)
        when XSD_NS.integer   then !!contents.to_s.match(/^[\+\-]?\d+$/)
        else                       true
        end
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
      #
      # @param  [Object] contents
      # @option options [Hash] :namespaces ({}) Use :__default__ or "" to declare default namespace
      # @option options [String] :language (nil)
      # @option options [Array<URIRef>] :profiles ([]) Profiles to add to elements
      # @option options [Hash] :prefixes (nil) Prefixes to add to elements
      # @option options [String] :default_vocabulary (nil) Default vocabulary to add to elements
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
          if $libxml_enabled
            c = Nokogiri::XML.parse(c.copy(true).to_s) if c.is_a?(LibXML::XML::Node)
          end
          if c.is_a?(Nokogiri::XML::Element)
            c = Nokogiri::XML.parse(c.dup.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS)).root
            # Gather namespaces from self and decendant nodes
            #
            # prefix mappings
            # Look for @xmlns and @prefix mappings. Add any other mappings from options[:prefixes]
            # that aren't already defined on this node
            defined_mappings = {}
            prefix_mappings = {}
            
            c.traverse do |n|
              ns = n.namespace
              next unless ns
              prefix = ns.prefix ? "xmlns:#{ns.prefix}" : "xmlns"
              defined_mappings[ns.prefix.to_s] = ns.href.to_s
              c[prefix] = ns.href unless c.namespaces[prefix]
            end
            
            mappings = c["prefix"].to_s.split(/\s+/)
            while mappings.length > 0 do
              prefix, uri = mappings.shift.downcase, mappings.shift
              #puts "uri_mappings prefix #{prefix} <#{uri}>"
              next unless prefix.match(/:$/)
              prefix.chop!

              # A Conforming RDFa Processor must ignore any definition of a mapping for the '_' prefix.
              next if prefix == "_"

              defined_mappings[prefix] = uri
              prefix_mappings[prefix] = uri
            end

            # Add prefixes, being careful to honor mappings defined on the element
            if options[:prefixes]
              options[:prefixes].each_pair do |p, ns|
                prefix_mappings[p] = ns.uri unless defined_mappings.has_key?(p)
              end
              if prefix_mappings.length
                c["prefix"] = prefix_mappings.keys.sort.map {|p| "#{p}: #{prefix_mappings[p]}"}.join(" ")
              end
            end
            
            # Add profiles, being careful to honor profiles defined on the element
            if options[:profiles].is_a?(Array) && options[:profiles].length > 0
              profiles = c["profile"].to_s.split(" ")
              profiles += options[:profiles]
              c["profile"] = profiles.join(" ")
            end
            
            # Add default vocabulary, being careful to honor any defined on the element
            if options[:default_vocabulary] && !c["vocab"]
              c["vocab"] = options[:default_vocabulary].to_s
            end
            
            if options[:language] && c["lang"].to_s.empty?
              c["xml:lang"] = options[:language]
            end
          end
          c.to_xml(:save_with => (Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS))
        end.join("")
      end
    end

    # @private
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

    # Contents of Literal
    attr_accessor :contents
    
    # Encoding defined for literal
    # @return [Literal::Encoding]
    attr_accessor :encoding
    
    # Language associated with literal
    # @return [String]
    attr_accessor :lang
    
    # Create a new Literal. Optinally pass a namespaces hash
    # for use in applying to rdf::XMLLiteral values.
    # @param [Object] contents
    # @param [Encoding] encoding
    # @option options [String] :language
    # @option options [Hash{String => Namespace}] :namespaces
    # @return [Literal]
    # @raise [TypeError]
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
    # @param [Object] contents
    # @param [String] language
    # @param [Encoding] encoding (nil)
    # @return [Literal]
    # @raise [TypeError]
    def self.n3_encoded(contents, language, encoding = nil)
      encoding = encoding.nil? ? Encoding.the_null_encoding : Encoding.coerce(encoding)
      options = {}
      options[:language] = language if language
      #puts "encoded: #{contents.dump}"
      contents = contents.rdf_unescape
      #puts "unencoded: #{contents.dump}"
      new(contents, encoding, options)
    end
    
    # Parse a Literal in NTriples format
    def self.parse(str)
      case str
        when LITERAL_WITH_LANGUAGE
          Literal.n3_encoded($1, $2)
        when LITERAL_WITH_DATATYPE
          Literal.n3_encoded($1, nil, $2)
        when LITERAL_PLAIN
          Literal.n3_encoded($1, nil)
      end
    end
    
    # Create an un-typed literal with a language
    # @param [Object] contents
    # @param [String] language (nil)
    # @return [Literal]
    # @raise [TypeError]
    def self.untyped(contents, language = nil)
      options = {}
      options[:language] = language if language
      new(contents, Encoding.the_null_encoding, options)
    end
    
    # Create a typed literal
    # @param [Object] contents
    # @param [Encoding] encoding (nil)
    # @option options [Hash{String => Namespace}] :namespaces
    # @return [Literal]
    # @raise [TypeError]
    def self.typed(contents, encoding, options = {})
      encoding = Encoding.coerce(encoding)
      new(contents, encoding, options)
    end
    
    # Create a literal appropriate for type of object by datatype introspection
    # @param [Object] contents
    # @return [Literal]
    # @raise [TypeError]
    def self.build_from(object)
      new(object.to_s, infer_encoding_for(object))
    end

    # Infer the proper XML datatype for the given object
    # @param [Object] contents
    # @return [Encoding]
    def self.infer_encoding_for(object)
      case object
      when TrueClass  then Encoding.boolean
      when FalseClass then Encoding.boolean
      when Integer    then Encoding.integer
      when Float      then Encoding.float
      when Time       then Encoding.time
      when DateTime   then Encoding.datetime
      when Date       then Encoding.date
      when Duration   then Encoding.duration
      else                 Encoding.string
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
    
    def <=>(other)
      self.to_s <=> other.to_s
    end
  
    def hash
      [@contents, @encoding, @lang].hash
    end

    # Output literal in N3 format
    def to_n3
      encoding.format_as_n3(self.contents, @lang)
    end
    alias_method :to_ntriples, :to_n3

    def inspect
      "#{self.class}[#{self.to_n3}]"
    end
    
    def valid?
      encoding.valid?(@contents)
    end
    
    # Output literal in TriX format
    def to_trix
      encoding.format_as_trix(@contents, @lang)
    end
    
    # Create native representation for value
    def to_native
      case encoding
      when Encoding.boolean   then @contents.to_s == "true"
      when Encoding.double    then @contents.to_s.to_f
      when Encoding.integer   then @contents.to_s.to_i
      when Encoding.float     then @contents.to_s.to_f
      when Encoding.time      then Time.parse(@contents.to_s)
      when Encoding.datetime  then DateTime.parse(@contents.to_s)
      when Encoding.date      then Date.parse(@contents.to_s)
      when Encoding.duration  then Duration.parse(@contents.to_s)
      else                         @contents.to_s
      end
    end
    
    # Return content and hash appropriate for encoding in XML
    #
    # ==== Example
    #  Encoding.the_null_encoding.xml_args("foo", "en-US") => ["foo", {"xml:lang" => "en-US"}]
    def xml_args
      encoding.xml_args(@contents, @lang)
    end

    ##
    # Returns `true`
    #
    # @return [Boolean]
    def literal?
      true
    end

    def untyped?; encoding == Encoding.the_null_encoding; end
    def typed?; encoding != Encoding.the_null_encoding; end
    
    # Is this an XMLLiteral?
    def xmlliteral?; encoding == Encoding.xmlliteral; end
    
    # Output literal contents as a string
    def to_s
      self.contents.to_s
    end
  end
end
