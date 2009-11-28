module Reddy
  # Generic Reddy Parser class
  class Parser
    attr_reader :debug
    attr_accessor :doc, :graph

    ## 
    # Creates a new parser for N3 (or Turtle).
    #
    # @param [Hash] options
    # _graph_:: Graph to parse into, otherwise a new Reddy::Graph instance is created
    # _debug_:: Array to place debug messages
    # _strict_:: Raise Error if true, continue with lax parsing, otherwise
    def initialize(options = {})
      options = {:graph => Graph.new}.merge(options)
      BNode.reset # Start sequence anew

      # initialize the triplestore
      @graph = options[:graph]
      @debug = options[:debug]
      @strict = options[:strict]
    end
    
    # Instantiate Parser and parse document
    # _strict_:: Fail when error detected, otherwise just continue
    # @param  [IO] stream the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri the URI of the document
    # @param [Hash] options
    # _type_:: One of _rdfxml_, _html_, or _n3_
    def self.parse(stream, uri = nil, options = {}, &block) # :yields: triple
      parseClass = self unless self == Parser
      parseClass ||= case options[:type].to_s
      when "rdfxml" then RdfXmlParser
      when "html"   then RdfaParser
      when "n3"     then N3Parser
      else
        raise ParserException.new("type option must be one of :rdfxml, :html, or :n3")
      end
      parser = parseClass.new(:graph => @graph)
      parser.parse(stream, uri, options, &block)
    end
    
    # Parse RDF document from a string or input stream to closure or graph.
    # @param  [IO] stream the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
    # @param [String] uri the URI of the document
    # @param [Hash] options
    # _strict_:: Fail when error detected, otherwise just continue
    # @returns [Graph]
    #
    # @author Gregg Kellogg
    # 
    # Raises Reddy::RdfException or subclass
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      raise ParserException.new("virtual class, must instantiate sub-class of Reddy::Parser")
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
    
    # Add debug event
    def add_debug(node, message)
      puts "#{node_path(node)}: #{message}" if $DEBUG
      @debug << "#{node_path(node)}: #{message}" if @debug
    end

    # add a triple, object can be literal or URI or bnode
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
