autoload :YAML, "yaml"
autoload :CGI, 'cgi'

SWAP_DIR = File.join(File.dirname(__FILE__), 'swap_test')
SWAP_TEST = "http://www.w3.org/2000/10/swap/test/n3parser.tests"
CWM_TEST = "http://www.w3.org/2000/10/swap/test/regression.n3"

TURTLE_DIR = File.join(File.dirname(__FILE__), 'turtle')
TURTLE_TEST = "http://www.w3.org/2001/sw/DataAccess/df1/tests/manifest.ttl"
TURTLE_BAD_TEST = "http://www.w3.org/2001/sw/DataAccess/df1/tests/manifest-bad.ttl"

RDFCORE_DIR = File.join(File.dirname(__FILE__), 'rdfcore')
RDFCORE_TEST = "http://www.w3.org/2000/10/rdf-tests/rdfcore/Manifest.rdf"

module RdfHelper
  # Class representing test cases in format http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#
  class TestCase
    include RdfContext
    
    MF_NS = Namespace.new("http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#", "mf")
    QT_NS = Namespace.new("http://www.w3.org/2001/sw/DataAccess/tests/test-query#", "qt")
    
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
    attr_accessor :compare
    
    def initialize(triples, uri_prefix, test_dir, options = {})
      case options[:test_type]
      when :mf
        parse_mf(triples, uri_prefix, test_dir, options[:graph])
      else
        parse_w3c(triples, uri_prefix, test_dir)
      end
    end
    
    def parse_w3c(triples, uri_prefix, test_dir)
      triples.each do |statement|
        next if statement.subject.is_a?(BNode)
        pred = statement.predicate.to_s.split(/[\#\/]/).last
        obj  = statement.object.to_s

        puts "#{pred.inspect}: #{obj}" if ::RdfContext::debug?
        pred = "outputDocument" if pred == "referenceOutput"
        if statement.is_type?
          self.rdf_type = statement.object.short_name
        elsif pred =~ /Document\Z/i
          puts "sub #{uri_prefix} in #{obj} for #{test_dir}" if ::RdfContext::debug?
          about = obj
          obj = obj.sub(uri_prefix, test_dir)
          puts " => #{obj}" if ::RdfContext::debug?
          self.send("#{pred}=", obj)
          if pred == "inputDocument"
            self.about ||= about
            self.name ||= statement.subject.to_s.split(/[\#\/]/).last
          end
        elsif self.respond_to?("#{statement.predicate.short_name}=")
          self.send("#{pred}=", obj)
        end
      end
    end

    def parse_mf(subject, uri_prefix, test_dir, graph)
      props = graph.properties(subject)
      puts "MF #{subject}: #{props.inspect}" if ::RdfContext::debug?
      @name = (props[MF_NS.name.to_s] || []).first.to_s
      @description =  (props[RDFS_NS.comment.to_s] || []).first.to_s
      @outputDocument = (props[MF_NS.result.to_s] || []).first
      @outputDocument = @outputDocument.to_s.sub(uri_prefix, test_dir) if @outputDocument
      action = (props[MF_NS.action.to_s] || []).first
      a_props = graph.properties(action)
      @about = (a_props[QT_NS.data.to_s] || []).first.to_s
      @inputDocument = @about.sub(uri_prefix, test_dir)
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
    
    # Read in file, and apply modifications reference either .html or .xhtml
    def input
      @input ||= File.read(inputDocument)
    end

    def output
      @output ||= outputDocument && File.read(outputDocument)
    end

    # Run test case, yields input for parser to create triples
    def run_test(options = {})
      rdf_string = input

      # Run
      @parser = Parser.new
      yield(rdf_string, @parser)

      return unless output

      case self.compare
      when :none
        # Don't check output, just parse to graph
      when :array
        @parser.graph.should be_equivalent_graph(self.output, self)
      else
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
      ext = test.split(".").last

      @positive_parser_tests = []
      @negative_parser_tests = []
      @positive_entailment_tests = []
      @negative_entailment_tests = []

      unless File.file?(File.join(test_dir, test.sub(ext, "yml")))
        manifest_file = File.join(test_dir, test)
        parser = Parser.new
        begin
          puts "parse #{manifest_file} @#{Time.now}"
          parser.parse(File.open(manifest_file), test_uri, :debug => [])
        rescue
          raise "Parse error: #{$!}\n\t#{[parser.debug].flatten.join("\t\n")}\n\n"
        end
        graph = parser.graph

        uri_base = Addressable::URI.join(test_uri, ".").to_s

        # If this is a turtle test (type mf:Manifest) parse with
        # alternative test case
        case graph.type_of(test_uri).first
        when MF_NS.Manifest
          # Get test entries
          entries = graph.triples(Triple.new(test_uri, MF_NS.entries, nil)) || []
          entries = entries.first
          raise "No entires found for MF Manifest" unless entries.is_a?(Triple)
        
          @test_cases = graph.seq(entries.object).map do |subject|
            TestCase.new(subject, uri_base, test_dir, :test_type => :mf, :graph => graph)
          end
        else
          # One of:
          #   http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema
          #   http://www.w3.org/2000/10/swap/test.n3#
          #   http://www.w3.org/2004/11/n3test#
          # Group by subject
          test_hash = graph.triples.inject({}) do |hash, st|
            a = hash[st.subject] ||= []
            a << st
            hash
          end

          @test_cases = test_hash.values.map do |statements|
            t = TestCase.new(statements, uri_base, test_dir)
            t.name ? t : nil
          end.
            compact.
            sort_by{|t| t.name.to_s}
        end
      else
        # Read tests from Manifest.yml
        self.from_yaml(File.join(test_dir, test.sub(ext, "yml")))
      end

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
    
    def self.to_yaml(test_uri, test_dir, file)
      test_cases = self.test_cases(test_uri, test_dir)
      puts "write test cases to #{file}"
      File.open(file, 'w') do |out|
        YAML.dump(test_cases, out )
      end
    end
    
    def self.from_yaml(file)
      YAML::add_private_type("RdfHelper::TestCase") do |type, val|
        TestCase.new( val )
      end
      File.open(file, 'r') do |input|
        @test_cases = YAML.load(input)
      end
    end
  end
end
