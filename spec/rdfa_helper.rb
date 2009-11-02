require 'matchers'

module RdfaHelper
  # Class representing test cases in format http://www.w3.org/2006/03/test-description#
  class TestCase
    TEST_DIR = File.join(File.dirname(__FILE__), 'xhtml1-testcases')
    
    attr_accessor :about
    attr_accessor :name
    attr_accessor :contributor
    attr_accessor :title
    attr_accessor :informationResourceInput
    attr_accessor :informationResourceResults
    attr_accessor :purpose
    attr_accessor :reviewStatus
    attr_accessor :specificationReference
    attr_accessor :expected_results
    
    @@test_cases = []
    
    def initialize(triples)
      expected_results = true
      triples.each do |statement|
        next if statement.subject.is_a?(BNode)
        self.about ||= statement.subject
        self.name ||= statement.subject.short_name
        
        if statement.predicate.short_name == "informationResourceInput"
          self.informationResourceInput = statement.object.to_s.sub!(/^.*xhtml1-testcases/, TEST_DIR)
        elsif statement.predicate.short_name == "informationResourceResults"
          self.informationResourceResults = statement.object.to_s.sub!(/^.*xhtml1-testcases/, TEST_DIR)
          # Change .sparql to .nt, until we can do spaql tests
          self.informationResourceResults.sub!(/.sparql$/, ".nt")
        elsif self.respond_to?("#{statement.predicate.short_name}=")
          self.send("#{statement.predicate.short_name}=", statement.object.to_s)
        end
      end
    end
    
    def information
      %w(purpose specificationReference).map {|a| v = self.send(a); "#{a}: #{v}" if v}.compact.join("\n")
    end
    
    def self.parse_test_cases
      return unless @@test_cases.empty?
      
      manifest = File.read(File.join(TEST_DIR, "rdfa-xhtml1-test-manifest.rdf"))
      graph = RdfXmlParser.new(manifest).graph
      
      # Group by subject
      test_hash = graph.triples.inject({}) do |hash, st|
        a = hash[st.subject] ||= []
        a << st
        hash
      end
      
      @@test_cases = test_hash.values.map {|statements| TestCase.new(statements)}.
        compact.
        select{|t| t.reviewStatus == "http://www.w3.org/2006/03/test-description#approved"}.
        sort_by{|t| t.about.is_a?(URIRef) ? t.about.uri.to_s : "zzz"}
    end
    def self.test_cases;                parse_test_cases; @@test_cases; end
  end
end
