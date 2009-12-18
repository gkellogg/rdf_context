module Reddy
  # Generic Reddy Parser class
  class Parser
    attr_reader :debug
    attr_accessor :doc, :graph

    ## 
    # Creates a new parser for N3 (or Turtle).
    #
    # @param [Hash] options:: Options from
    # <em>options[:graph]</em>:: Graph to parse into, otherwise a new Reddy::Graph instance is created
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:type]</em>:: One of _rdfxml_, _html_, or _n3_
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    #
    # @author Gregg Kellogg
    def initialize(options = {})
      # initialize the triplestore
      @graph = options[:graph]
      @debug = options[:debug]
      @strict = options[:strict]
    end
    
    # Instantiate Parser and parse document
    #
    # @param  [IO, String] stream:: the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri:: the URI of the document
    # @param [Hash] options::  Options from
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:type]</em>:: One of _rdfxml_, _html_, or _n3_
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph]:: Returns the graph containing parsed triples
    # @raise [Error]:: Raises RdfError if _strict_
    #
    # @author Gregg Kellogg
    def self.parse(stream, uri = nil, options = {}, &block) # :yields: triple
      parser = self.new(options)
      parser.parse(stream, uri, options, &block)
    end
    
    # Parse RDF document from a string or input stream to closure or graph.
    #
    # Virtual Class, prototype for Parser subclass.
    #
    # @param  [IO, String] stream:: the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri:: the URI of the document
    # @param [Hash] options::  Options from
    # <em>options[:debug]</em>:: Array to place debug messages
    # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
    # @return [Graph]:: Returns the graph containing parsed triples
    # @raise [Error]:: Raises RdfError if _strict_
    #
    # @author Gregg Kellogg
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      if self.class == Parser
        # Create a delegate of a specific parser class
        @delegate ||= case options[:type].to_s
        when "n3", "ntriples", "turtle" then N3Parser.new(options)
        when "rdfa", "html", "xhtml"    then RdfaParser.new(options)
        when "xml", "rdf", "rdfxml"     then RdfXmlParser.new(options)
        else
          RdfXmlParser.new(options)
          # raise ParserException.new("type option must be one of :rdfxml, :html, or :n3")
        end
        @delegate.parse(stream, uri, options, &block)
      else
        # Common parser operations
        @uri = Addressable::URI.parse(uri.to_s).to_s unless uri.nil?
        @strict = options[:strict] if options.has_key?(:strict)
        @debug = options[:debug] if options.has_key?(:debug)
        
        @graph ||= Graph.new(:identifier => @uri)
      end
    end
    
    # Return N3 Parser instance
    def self.n3_parser(options = {}); N3Parser.new(options); end
    # Return RDF/XML Parser instance
    def self.rdfxml_parser(options = {}); RdfXmlParser.new(options); end
    # Return Rdfa Parser instance
    def self.rdfa_parser(options = {}); RdfaParser.new(options); end

    protected
    # Figure out the document path, if it is a Nokogiri::XML::Element or Attribute
    def node_path(node)
      case node
      when Nokogiri::XML::Element, Nokogiri::XML::Attr then "#{node_path(node.parent)}/#{node.name}"
      when String then node
      else ""
      end
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [XML Node, any] node:: XML Node or string for showing context
    # @param [String] message::
    def add_debug(node, message)
      puts "#{node_path(node)}: #{message}" if $DEBUG
      @debug << "#{node_path(node)}: #{message}" if @debug
    end

    # add a triple, object can be literal or URI or bnode
    #
    # @param [Nokogiri::XML::Node, any] node:: XML Node or string for showing context
    # @param [URIRef, BNode] subject:: the subject of the triple
    # @param [URIRef] predicate:: the predicate of the triple
    # @param [URIRef, BNode, Literal] object:: the object of the triple
    # @return [Array]:: An array of the triples (leaky abstraction? consider returning the graph instead)
    # @raise [Error]:: Checks parameter types and raises if they are incorrect if parsing mode is _strict_.
    #
    # @author Gregg Kellogg
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
      raise if @strict
    end
  end
end
