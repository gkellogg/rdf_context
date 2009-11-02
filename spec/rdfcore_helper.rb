require 'matchers'

module RdfCoreHelper
  # Class representing test cases in format http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#
  class TestCase
    RDFCORE_DIR = File.join(File.dirname(__FILE__), 'rdfcore')
    
    attr_accessor :about
    attr_accessor :approval
    attr_accessor :conclusion_document
    attr_accessor :data
    attr_accessor :description
    attr_accessor :discussion
    attr_accessor :document
    attr_accessor :entailmentRules
    attr_accessor :input_document
    attr_accessor :issue
    attr_accessor :name
    attr_accessor :output_document
    attr_accessor :premise_document
    attr_accessor :rdf_type
    attr_accessor :status
    attr_accessor :warning
    
    @@test_cases = []
    
    def initialize(triples)
      triples.each do |statement|
        next if statement.subject.is_a?(BNode)
        self.about ||= statement.subject
        self.name ||= statement.subject.short_name
        
        if statement.is_type?
          self.rdf_type = statement.object.short_name
        elsif statement.predicate.short_name == "inputDocument"
          self.input_document = statement.object.to_s.sub!(/^.*rdfcore/, RDFCORE_DIR)
        elsif statement.predicate.short_name == "outputDocument"
          self.output_document = statement.object.to_s.sub!(/^.*rdfcore/, RDFCORE_DIR)
        elsif statement.predicate.short_name == "premiseDocument"
          self.premise_document = statement.object.to_s.sub!(/^.*rdfcore/, RDFCORE_DIR)
        elsif statement.predicate.short_name == "conclusionDocument"
          self.conclusion_document = statement.object.to_s.sub!(/^.*rdfcore/, RDFCORE_DIR)
        elsif statement.predicate.short_name == "document"
          self.document = statement.object.to_s.sub!(/^.*rdfcore/, RDFCORE_DIR)
        elsif self.respond_to?("#{statement.predicate.short_name}=")
          self.send("#{statement.predicate.short_name}=", statement.object.to_s)
        end
      end
    end
    
    def information
      %w(description discussion issue warning).map {|a| v = self.send(a); "#{a}: #{v}" if v}.compact.join("\n")
    end
    
    def self.parse_test_cases
      return unless @@test_cases.empty?
      
      @@positive_parser_tests = []
      @@negative_parser_tests = []
      @@positive_entailment_tests = []
      @@negative_entailment_tests = []

      manifest = File.read(File.join(RDFCORE_DIR, "Manifest.rdf"))
      graph = RdfXmlParser.new(manifest).graph
      
      # Group by subject
      test_hash = graph.triples.inject({}) do |hash, st|
        a = hash[st.subject] ||= []
        a << st
        hash
      end
      
      @@test_cases = test_hash.values.map {|statements| TestCase.new(statements)}.compact.sort_by{|t| t.about.is_a?(URIRef) ? t.about.uri.to_s : "zzz"}
      
      @@test_cases.each do |tc|
        next unless tc.status == "APPROVED"
        case tc.rdf_type
        when "PositiveParserTest" then @@positive_parser_tests << tc
        when "NegativeParserTest" then @@negative_parser_tests << tc
        when "PositiveEntailmentTest" then @@positive_entailment_tests << tc
        when "NegativeEntailmentTest" then @@negative_entailment_tests << tc
        end
      end
    end
    def self.test_cases;                parse_test_cases; @@test_cases; end
    def self.positive_parser_tests;     parse_test_cases; @@positive_parser_tests; end
    def self.negative_parser_tests;     parse_test_cases; @@negative_parser_tests; end
    def self.positive_entailment_tests; parse_test_cases; @@positive_entailment_tests; end
    def self.negative_entailment_tests; parse_test_cases; @@negative_entailment_tests; end
  end
end
