require 'rdf/redland'
require 'matchers'

module RdfaHelper
  # Class representing test cases in format http://www.w3.org/2006/03/test-description#
  class TestCase
    include Matchers
    
    TEST_DIR = File.join(File.dirname(__FILE__), 'rdfa-test-suite')
    NT_DIR = File.join(File.dirname(__FILE__), 'rdfa-triples')
    BASE_MANIFEST_URL = "http://rdfa.digitalbazaar.com/test-suite/"
    BASE_TEST_CASE_URL = "#{BASE_MANIFEST_URL}test-cases/"
    
    attr_accessor :about
    attr_accessor :name
    attr_accessor :contributor
    attr_accessor :title
    attr_accessor :informationResourceInput
    attr_accessor :informationResourceResults
    attr_accessor :purpose
    attr_accessor :reviewStatus
    attr_accessor :suite
    attr_accessor :specificationReference
    attr_accessor :expectedResults
    attr_accessor :parser
    
    @@test_cases = []
    @@suite = ""
    
    def initialize(statements, suite)
      self.suite = suite
      self.expectedResults = true
      statements.each do |statement|
        next if statement.subject.is_a?(Redland::BNode)
        #next unless statement.subject.uri.to_s.match(/0001/)
        unless self.about
          self.about = URI.parse(statement.subject.uri.to_s)
          self.name = statement.subject.uri.short_name
        end
        
        if statement.predicate.uri.short_name == "expectedResults"
          self.expectedResults = statement.object.literal.value == "true"
          #puts "expectedResults = #{statement.object.literal.value}"
        elsif self.respond_to?("#{statement.predicate.uri.short_name}=")
          s = case
          when statement.object.literal?  then statement.object.literal
          when statement.object.resource? then statement.object.uri
          when statement.object.blank?    then statement.object.blank_identifier
          else false
          end
          self.send("#{statement.predicate.uri.short_name}=", s.to_s)
          #puts "#{statement.predicate.uri.short_name} = #{s.to_s}"
        end
      end
    end
    
    def inspect
      "[Test Case " + %w(
        about
        name
        contributor
        title
        informationResourceInput
        informationResourceResults
        purpose
        reviewStatus
        specificationReference
        expectedResults
      ).map {|a| v = self.send(a); "#{a}='#{v}'" if v}.compact.join(", ") +
      "]"
    end
    
    def status
      reviewStatus.to_s.split("#").last
    end
    
    def information
      %w(purpose specificationReference).map {|a| v = self.send(a); "#{a}: #{v}" if v}.compact.join("\n")
    end
    
    def tcpath
      BASE_TEST_CASE_URL + (suite == "xhtml" ? "xhtml1" : suite)
    end
    
    # Read in file, and apply modifications to create a properly formatted HTML
    def input
      f = self.name + ".txt"
      found_head = false
      namespaces = ""
      body = File.readlines(File.join(TEST_DIR, "tests", f)).map do |line|
        found_head ||= line.match(/<head/)
        if found_head
          line.chop
        else
          namespaces << line
          nil
        end
      end.compact.join("\n")

      namespaces.chop!  # Remove trailing newline
      htmlre = Regexp.new('([0-9]{4,4})\.xhtml')
      tcpathre = Regexp.compile('\$TCPATH')
      
      case suite
      when "xhtml"
        head = "" +
        %(<?xml version="1.0" encoding="UTF-8"?>\n) +
        %(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">\n) +
        %(<html xmlns="http://www.w3.org/1999/xhtml" version="XHTML+RDFa 1.0"\n)
        head + "#{namespaces}>\n#{body.gsub(tcpathre, tcpath)}\n</html>"
      when "html4"
        head ="" +
        %(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">\n) +
        %(<html version="XHTML+RDFa 1.0"\n)
        head + "#{namespaces}>\n#{body.gsub(tcpathre, tcpath).gsub(htmlre, '\1.html')}\n</html>"
      when "html5"
        head = "<!DOCTYPE html>\n"
        head += namespaces.empty? ? %(<html version="HTML+RDFa 1.0">) : "<html\n#{namespaces}>"
        head + "\n#{body.gsub(tcpathre, tcpath).gsub(htmlre, '\1.html')}\n</html>"
      else
        nil
      end
    end
    
    # Read in file, and apply modifications reference either .html or .xhtml
    def results
      htmlre = Regexp.new('([0-9]{4,4})\.xhtml')
      tcpathre = Regexp.compile('\$TCPATH')

      f = self.name + ".sparql"
      body = File.read(File.join(TEST_DIR, "tests", f)).gsub(tcpathre, tcpath)
      
      suite == "xhtml" ? body : body.gsub(htmlre, '\1.html')
    end
    
    def triples
      tcpathre = Regexp.compile('\$TCPATH')
      f = self.name + ".nt"
      File.read(File.join(NT_DIR, f)).gsub(tcpathre, tcpath)
    end
    
    # Run test case, yields input for parser to create triples
    def run_test
      rdfa_string = input
      
      # Run
      @parser = RdfaParser::RdfaParser.new
      yield(rdfa_string, @parser)

      query_string = results

      triples = self.triples rescue nil
      
      if (query_string.match(/UNION|OPTIONAL/) || title.match(/XML/)) && triples
        # Check triples, as Rasql doesn't implement UNION
        @parser.graph.should be_equivalent_graph(triples, self)
      else
        # Run SPARQL query
        @parser.graph.should pass_query(query_string, self)
      end

      @parser.graph.to_rdfxml.should be_valid_xml
    end
    
    def trace
      @parser.debug.join("\n")
    end
    
    def self.test_cases(suite)
      @@test_cases = [] unless @@suite == suite
      return @@test_cases unless @@test_cases.empty?
      
      @@suite = suite # Process the given test suite
      @@manifest_url = "#{BASE_MANIFEST_URL}#{suite}-manifest.rdf"
      
      manifest_str = File.read(File.join(TEST_DIR, "#{suite}-manifest.rdf"))
      rdfxml_parser = Redland::Parser.new
      test_hash = {}
      # Replace with different logic for URI
      rdfxml_parser.parse_string_as_stream(manifest_str, @@manifest_url) do |st|
        a = test_hash[st.subject.uri.to_s] ||= []
        a << st
      end
      
      @@test_cases = test_hash.values.map {|statements| TestCase.new(statements, suite)}.
        compact.
        sort_by{|t| t.about.is_a?(URI) ? t.about.to_s : "zzz"}
    end
  end
end


class Redland::Uri
  def short_name
    u = URI.parse(self.to_s)
    if u.fragment
      return u.fragment
    elsif u.path.split("/").last.class == String and u.path.split("/").last.length > 0
      return u.path.split("/").last
    else
      return false
    end
  end
end

# Simple parser for NTriples
class NTriplesParser
  attr_reader :graph

  def initialize(string, uri)
    @graph = RdfaParser::Graph.new
    RdfaParser::BNode.reset
    
    ntriples_parser = Redland::Parser.ntriples
    ntriples_parser.parse_string_as_stream(string, uri) do |st|
      s = redland_to_native(st.subject)
      p = redland_to_native(st.predicate)
      o = redland_to_native(st.object)
      @graph.add_triple(s, p, o)
    end
  end
  
  def redland_to_native(resource)
    case
    when resource.literal?
      node_type = Redland.librdf_node_get_literal_value_datatype_uri(resource.literal.node)
      node_type = Redland.librdf_uri_to_string(node_type) if node_type
      RdfaParser::Literal.typed(resource.literal.value, node_type, :language => resource.literal.language)
    when resource.blank?
      # Cache anonymous blank identifiers
      @bn_hash ||= {}
      id = resource.blank_identifier.to_s
      id = nil if id.match(/^r[r\d]+$/)
      bn = @bn_hash[resource.blank_identifier.to_s] ||= RdfaParser::BNode.new(id)
      bn.identifier
      bn
    when resource.resource?
      RdfaParser::URIRef.new(resource.uri.to_s)
    else
      nil
    end
  end
end