require File.join(File.dirname(__FILE__), 'spec_helper')
include RdfContext

describe "N3 parser" do
  # W3C Turtle Test suite from http://www.w3.org/2000/10/swap/test/regression.n3
  describe "w3c turtle tests" do
    require 'rdf_helper'

    def self.positive_tests
      RdfHelper::TestCase.test_cases(TURTLE_TEST, TURTLE_DIR) rescue []
    end

    def self.negative_tests
      RdfHelper::TestCase.test_cases(TURTLE_BAD_TEST, TURTLE_DIR) rescue []
    end

    describe "positive parser tests" do
      positive_tests.each do |t|
        #puts t.inspect
        
        specify "#{t.name}: " + (t.description || "#{t.inputDocument} against #{t.outputDocument}") do
          # Skip tests for very long files, too long
          if %w(test-14 test-15 test-16 rdfq-results).include?(t.name)
            pending("Skip very long input file")
          else
            t.run_test do |rdf_string, parser|
              parser.parse(rdf_string, t.about.uri.to_s, :strict => true, :debug => [])
            end
          end
        end
      end
    end

    describe "negative parser tests" do
      negative_tests.each do |t|
        #puts t.inspect
        specify "#{t.name}: " + (t.description || t.inputDocument) do
          t.run_test do |rdf_string, parser|
            lambda do
              parser.parse(rdf_string, t.about.uri.to_s, :strict => true, :debug => [])
            end.should raise_error(RdfException)
          end
        end
      end
    end
  end

end