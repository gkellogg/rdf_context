module RdfHelper
  # Class representing test cases in format http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#
  class TestCase
    include Matchers
    
    attr_accessor :about
    attr_accessor :approval
    attr_accessor :conclusionDocument
    attr_accessor :data
    attr_accessor :description
    attr_accessor :discussion
    attr_accessor :document
    attr_accessor :entailmentRules
    attr_accessor :inputDocument
    attr_accessor :issue
    attr_accessor :name
    attr_accessor :outputDocument
    attr_accessor :premiseDocument
    attr_accessor :rdf_type
    attr_accessor :status
    attr_accessor :warning
    attr_accessor :parser
    
    def initialize(triples, uri_prefix, test_dir)
      triples.each do |statement|
        next if statement.subject.is_a?(BNode)
#        self.about ||= statement.subject
#        self.name ||= statement.subject.short_name
        
        if statement.is_type?
          self.rdf_type = statement.object.short_name
        elsif statement.predicate.short_name =~ /Document\Z/i
          puts "#{statement.predicate.short_name}: #{statement.object.inspect}" if $DEBUG
          self.send("#{statement.predicate.short_name}=", statement.object.to_s.sub(uri_prefix, test_dir))
          puts "#{statement.predicate.short_name}: " + self.send("#{statement.predicate.short_name}") if $DEBUG
          if statement.predicate.short_name == "inputDocument"
            self.about ||= statement.object
            self.name ||= statement.subject.short_name
          end
        elsif statement.predicate.short_name == "referenceOutput"
          puts "referenceOutput: #{statement.object.inspect}" if $DEBUG
          outputDocument = statement.object.to_s.sub(uri_prefix, test_dir)
          puts "referenceOutput: " + self.send("#{statement.predicate.short_name}") if $DEBUG
        elsif self.respond_to?("#{statement.predicate.short_name}=")
          self.send("#{statement.predicate.short_name}=", statement.object.to_s)
        end
      end
    end
    
    def inspect
      "[Test Case " + %w(
        about
        name
        inputDocument
        outputDocument
        issue
        status
        approval
        description
        discussion
        issue
        warning
      ).map {|a| v = self.send(a); "#{a}='#{v}'" if v}.compact.join(", ") +
      "]"
    end
    
    def compare; :graph; end
    
    # Read in file, and apply modifications reference either .html or .xhtml
    def input
      @input ||= File.open(inputDocument)
    end

    def output
      @output ||= outputDocument && File.open(outputDocument)
    end

    # Run test case, yields input for parser to create triples
    def run_test
      rdf_string = input

      # Run
      @parser = Parser.new
      yield(rdf_string, @parser)

      if output
        output_parser = Parser.new
        output_fmt = output_parser.detect_format(self.output, self.outputDocument)
        output_parser.parse(self.output, about, :type => output_fmt)
        @parser.graph.should be_equivalent_graph(output_parser, self)
      end
    end

    def trace
      @parser.debug.to_a.join("\n")
    end
    
    def self.parse_test_cases(test_uri = nil, test_dir = nil)
      raise "Missing test_uri" unless test_uri
      raise "Missing test_dir" unless test_dir
      @test_cases = [] unless test_uri == @test_uri
      return unless @test_cases.empty?

      test = test_uri.to_s.split('/').last
      test_dir = test_dir + "/" unless test_dir.match(%r(/$))
      
      @positive_parser_tests = []
      @negative_parser_tests = []
      @positive_entailment_tests = []
      @negative_entailment_tests = []

      manifest = File.read(File.join(test_dir, test))
      parser = Parser.new
      begin
        puts "parse <#{test_uri}>" if $DEBUG
        parser.parse(manifest, test_uri)
      rescue
        raise "Parse error: #{$!}\n\t#{parser.debug.join("\t\n")}\n\n"
      end
      graph = parser.graph
      
      # Group by subject
      test_hash = graph.triples.inject({}) do |hash, st|
        a = hash[st.subject] ||= []
        a << st
        hash
      end
      
      uri_base = Addressable::URI.join(test_uri, ".").to_s
      @test_cases = test_hash.values.map do |statements|
        TestCase.new(statements, uri_base, test_dir)
      end.
      compact.
      sort_by{|t| t.name.to_s}
      
      @test_cases.each do |tc|
        next if tc.status && tc.status != "APPROVED"
        case tc.rdf_type
        when "PositiveParserTest" then @positive_parser_tests << tc
        when "NegativeParserTest" then @negative_parser_tests << tc
        when "PositiveEntailmentTest" then @positive_entailment_tests << tc
        when "NegativeEntailmentTest" then @negative_entailment_tests << tc
        end
      end
    end
    def self.test_cases(test_uri = nil, test_dir = nil);                parse_test_cases(test_uri, test_dir); @test_cases; end
    def self.positive_parser_tests(test_uri = nil, test_dir = nil);     parse_test_cases(test_uri, test_dir); @positive_parser_tests; end
    def self.negative_parser_tests(test_uri = nil, test_dir = nil);     parse_test_cases(test_uri, test_dir); @negative_parser_tests; end
    def self.positive_entailment_tests(test_uri = nil, test_dir = nil); parse_test_cases(test_uri, test_dir); @positive_entailment_tests; end
    def self.negative_entailment_tests(test_uri = nil, test_dir = nil); parse_test_cases(test_uri, test_dir); @negative_entailment_tests; end
  end
end
