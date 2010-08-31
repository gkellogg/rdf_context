require File.join(File.dirname(__FILE__), 'graph')

module RdfContext
  # Generic RdfContext Parser class
  class Parser
    attr_reader :debug
    
    # URI of parsed document
    # @return [RdfContext::URIRef]
    attr_reader :uri
    
    # Source of parsed document
    # @return [Nokogiri::XML::Document, #read]
    attr_accessor :doc

    # Graph instance containing parsed statements
    # @return [RdfContext::Graph]
    attr_accessor :graph
    
    # Graph instance containing informationa, warning and error statements
    # @return [RdfContext::Graph]
    attr_accessor :processor_graph
    
    ## 
    # Creates a new parser
    #
    # @option options [Graph] :graph (nil) Graph to parse into, otherwise a new RdfContext::Graph instance is created
    # @option options [Graph] :processor_graph (nil) Graph to record information, warnings and errors.
    # @option options [:rdfxml, :html, :n3] :type (nil)
    # @option options [Boolean] :strict (false) Raise Error if true, continue with lax parsing, otherwise
    def initialize(options = {})
      # initialize the triplestore
      @graph = options[:graph]
      @processor_graph = options[:processor_graph] if options[:processor_graph]
      @debug = options[:debug] # XXX deprecated
      @strict = options[:strict]
      @named_bnodes = {}
    end
    
    # Instantiate Parser and parse document
    #
    # @param  [#read, #to_s] stream the HTML+RDFa IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri (nil) the URI of the document
    # @option options [Graph] :processor_graph (nil) Graph to record information, warnings and errors.
    # @option options [:rdfxml, :html, :n3] :type (nil)
    # @option options [Boolean] :strict (false) Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph] Returns the graph containing parsed triples
    # @yield  [triple]
    # @yieldparam [Triple] triple
    # @raise [Error]:: Raises RdfError if _strict_
    # @return [Graph]:: Returns the graph containing parsed triples
    # @raise [Error]:: Raises RdfError if _strict_
    def self.parse(stream, uri = nil, options = {}, &block) # :yields: triple
      parser = self.new(options)
      parser.parse(stream, uri, options, &block)
    end
    
    # Parse RDF document from a string or input stream to closure or graph.
    #
    # If the parser is called with a block, triples are passed to the block rather
    # than added to the graph.
    #
    # Virtual Class, prototype for Parser subclass.
    #
    # @param  [#read, #to_s] stream the HTML+RDFa IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri (nil) the URI of the document
    # @option options [Graph] :processor_graph (nil) Graph to record information, warnings and errors.
    # @option options [:rdfxml, :html, :n3] :type (nil)
    # @option options [Boolean] :strict (false) Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph] Returns the graph containing parsed triples
    # @yield  [triple]
    # @yieldparam [Triple] triple
    # @raise [Error]:: Raises RdfError if _strict_
    # @return [Graph]:: Returns the graph containing parsed triples
    # @raise [Error]:: Raises RdfError if _strict_
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      if self.class == Parser
        
        options[:strict] ||= @strict if @strict
        options[:graph] ||= @graph if @graph
        options[:debug] ||= @debug if @debug  # XXX deprecated
        @processor_graph = options[:processor_graph] if options[:processor_graph]
        # Intuit type, if not provided
        options[:type] ||= detect_format(stream, uri)
        
        # Create a delegate of a specific parser class
        @delegate ||= case options[:type].to_s
        when "n3", "ntriples", "turtle", "ttl", "n3", "notation3" then N3Parser.new(options)
        when "rdfa", "html", "xhtml"                        then RdfaParser.new(options)
        when "xml", "rdf", "rdfxml"                         then RdfXmlParser.new(options)
        else
          RdfXmlParser.new(options)
          # raise ParserException.new("type option must be one of :rdfxml, :html, or :n3")
        end
        @delegate.parse(stream, uri, options, &block)
      else
        # Common parser operations
        @uri = URIRef.new(uri.to_s) unless uri.nil?
        @strict = options[:strict] if options.has_key?(:strict)
        @debug = options[:debug] if options.has_key?(:debug)
        
        @graph ||= Graph.new(:identifier => @uri)
      end
    end
    
    
    # @return [Graph]
    def graph; @delegate ? @delegate.graph : (@graph || Graph.new); end
    # @return [Graph]
    def processor_graph; @delegate ? @delegate.processor_graph : (@processor_graph || Graph.new); end
    
    # @return [Array<String>]
    def debug; @delegate ? @delegate.debug : @debug; end

    # Return N3 Parser instance
    # @return [N3Parser]
    def self.n3_parser(options = {}); N3Parser.new(options); end
    # Return RDF/XML Parser instance
    # @return [RdfXmlParser]
    def self.rdfxml_parser(options = {}); RdfXmlParser.new(options); end
    # Return Rdfa Parser instance
    # @return [RdfaParser]
    def self.rdfa_parser(options = {}); RdfaParser.new(options); end

    # Heuristically detect the format of the uri
    # @param [#read, #to_s] stream
    # @param [#to_s] uri (nil)
    # @return [:rdfxml, :rdfa, :n3]
    def detect_format(stream, uri = nil)
      uri ||= stream.path if stream.respond_to?(:path)
      format = case uri.to_s
      when /\.(rdf|xml)$/      then :rdfxml
      when /\.(html|xhtml)$/   then :rdfa
      when /\.(nt|n3|txt)$/    then :n3
      else
        # Got to look into the file to see
        if stream.is_a?(IO) || stream.is_a?(StringIO)
          stream.rewind
          string = stream.read(1000)
          stream.rewind
        else
          string = stream.to_s
        end
        case string
        when /<\w+:RDF/ then :rdfxml
        when /<RDF/     then :rdfxml
        when /<html/i   then :rdfa
        else                 :n3
        end
      end
    end

    protected
    # Figure out the document path, if it is a Nokogiri::XML::Element or Attribute
    def node_path(node)
      case node
      when Nokogiri::XML::Node then node.display_path
      else node.to_s
      end
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [XML Node, any] node:: XML Node or string for showing context
    # @param [String] message::
    def add_debug(node, message)
      add_processor_message(node, message, RDFA_NS.InformationalMessage)
    end

    def add_info(node, message, process_class = RDFA_NS.InformationalMessage)
      add_processor_message(node, message, process_class)
    end
    
    def add_warning(node, message, process_class = RDFA_NS.MiscellaneousWarning)
      add_processor_message(node, message, process_class)
    end
    
    def add_error(node, message, process_class = RDFA_NS.MiscellaneousError)
      add_processor_message(node, message, process_class)
      raise ParserException, message if @strict
    end
    
    def add_processor_message(node, message, process_class)
      puts "#{node_path(node)}: #{message}" if $DEBUG
      @debug << "#{node_path(node)}: #{message}" if @debug.is_a?(Array)
      if @processor_graph
        @processor_sequence ||= 0
        n = BNode.new
        @processor_graph << Triple.new(n, RDF_TYPE, process_class)
        @processor_graph << Triple.new(n, DC_NS.description, message)
        @processor_graph << Triple.new(n, DC_NS.date, Literal.build_from(DateTime.now.to_date))
        @processor_graph << Triple.new(n, RDFA_NS.sequence, Literal.build_from(@processor_sequence += 1))
        @processor_graph << Triple.new(n, RDFA_NS.source, node_path(node))
      end
    end
    
    # add a triple, object can be literal or URI or bnode
    #
    # If the parser is called with a block, triples are passed to the block rather
    # than added to the graph.
    #
    # @param [Nokogiri::XML::Node, any] node:: XML Node or string for showing context
    # @param [URIRef, BNode] subject:: the subject of the triple
    # @param [URIRef] predicate:: the predicate of the triple
    # @param [URIRef, BNode, Literal] object:: the object of the triple
    # @return [Array]:: An array of the triples (leaky abstraction? consider returning the graph instead)
    # @raise [Error]:: Checks parameter types and raises if they are incorrect if parsing mode is _strict_.
    def add_triple(node, subject, predicate, object)
      triple = Triple.new(subject, predicate, object)
      add_debug(node, "triple: #{triple}")
      if @callback
        @callback.call(triple)  # Perform yield to saved block
      else
        @graph << triple
      end
      triple
    rescue RdfException => e
      add_debug(node, "add_triple raised #{e.class}: #{e.message}")
      puts e.backtrace if $DEBUG
      raise if @strict
    end
  end
end
