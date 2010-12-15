$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

require 'rdfa_helper'

# Time to add your specs!
# http://rspec.info/
describe RdfaParser do
  before(:each) do
     @parser = RdfaParser.new
   end
  
   it "should parse simple doc" do
    sampledoc = <<-EOF;
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:dc="http://purl.org/dc/elements/1.1/">
    <head>
    	<title>Test 0001</title>
    </head>
    <body>
    	<p>This photo was taken by <span class="author" about="photo1.jpg" property="dc:creator">Mark Birbeck</span>.</p>
    </body>
    </html>
    EOF

    @parser.parse(sampledoc, "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0001.xhtml", :strict => true)
    @parser.graph.size.should == 1
    
    @parser.graph.to_rdfxml.should be_valid_xml
  end

  it "should parse simple doc without a base URI" do
    sampledoc = <<-EOF;
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:dc="http://purl.org/dc/elements/1.1/">
    <body>
    	<p>This photo was taken by <span class="author" about="_:photo" property="dc:creator">Mark Birbeck</span>.</p>
    </body>
    </html>
    EOF

    @parser.parse(sampledoc, nil, :strict => true)
    @parser.graph.size.should == 1
    
    @parser.graph.to_rdfxml.should be_valid_xml
  end

  it "should parse XML Literal and generate valid XML" do
    sampledoc = <<-EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:dc="http://purl.org/dc/elements/1.1/"
          xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    	<head>
    		<title>Test 0011</title>
    	</head>
      <body>
      	<div about="">
          Author: <span property="dc:creator">Albert Einstein</span>
          <h2 property="dc:title" datatype="rdf:XMLLiteral">E = mc<sup>2</sup>: The Most Urgent Problem of Our Time</h2>
    	</div>
      </body>
    </html>
    EOF

    @parser.parse(sampledoc, "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :strict => true)
    @parser.graph.size.should == 2
    
    xml = @parser.graph.to_rdfxml

    # Ensure that enclosed literal is also valid
    xml.should include("E = mc")
  end

  it "should parse BNodes" do
    sampledoc = <<-EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:foaf="http://xmlns.com/foaf/0.1/">
      <head>
    	<title>Test 0017</title>   
      </head>
      <body>
      	 <p>
              <span about="[_:a]" property="foaf:name">Manu Sporny</span>
               <span about="[_:a]" rel="foaf:knows"
    resource="[_:b]">knows</span>
               <span about="[_:b]" property="foaf:name">Ralph Swick</span>.
            </p>
      </body>
    </html>
    EOF

    @parser.parse(sampledoc, "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :strict => true)
    @parser.graph.size.should == 3
    
    xml = @parser.graph.to_rdfxml
    xml.should be_valid_xml
    
    xml.should include("Ralph Swick")
    xml.should include("Manu Sporny")
  end
  
  describe :profiles do
    before(:all) do
      @prof = %(<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html>
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>Test mappings</title>
        </head>
        <body prefix="rdfa: http://www.w3.org/ns/rdfa#">
          <p typeof=""><span property="rdfa:uri">#{DC_NS.uri}</span><span property="rdfa:prefix">dc</span></p>
          <p typeof=""><span property="rdfa:uri">#{DC_NS.title}</span><span property="rdfa:term">title</span></p>
        </body>
      </html>
      )
      @doc = %(<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html>
      <html xmlns="http://www.w3.org/1999/xhtml">
        <body profile="http://example.com/profile">
          <div about ="http://example.com/doc" typeof="dc:Agent">
            <p property="title">A particular agent</p>
          </div>
        </body>
      </html>
      )
    end

    before(:each) do
      @profile_graph = ConjunctiveGraph.new(:store => MemoryStore.new)
      @parser = RdfaParser.new(:profile_graph => @profile_graph)
      OpenURI.stub!(:open_uri).with("http://example.com/profile").and_return(@prof)
    end
    
    describe "new profile" do
      before(:each) do
        # Clear vocabulary cache
        #RdfContext.debug = true
        RdfaParser.send(:class_variable_set, :@@vocabulary_cache, {})
        @parser.parse(@doc, "http://example.com/doc")
        #RdfContext.debug = false
      end
      
      describe "profile graph" do
        it "should have context http://example.com/profile" do
          @profile_graph.contexts.map(&:identifier).should include("http://example.com/profile")
        end
      end
      
      describe "processed graph" do
        it "should have type dc:Agent" do
          @parser.graph.should be_contains(Triple.new("http://example.com/doc", RDF_TYPE, DC_NS.Agent))
        end
      
        it "should have property dc:title" do
          @parser.graph.should be_contains(Triple.new("http://example.com/doc", DC_NS.title, nil))
        end
      end
    end
    
    describe "cached profile" do
      before(:each) do
        # Clear vocabulary cache
        RdfaParser.send(:class_variable_set, :@@vocabulary_cache, {})
        @parser.parse(@doc, "http://example.com/doc")
      end
      
      it "should not re-parse profile" do
        RdfaParser.send(:class_variable_set, :@@vocabulary_cache, {})
        Parser.should_not_receive(:parse).with(@prof, "http://example.com/profile", :profile_graph => @parser.profile_graph).and_return(@prof_graph)
        RdfaParser.new.parse(@doc, "http://example.com/doc")
      end
      
      it "should create vocab_cache" do
        RdfaParser.send(:class_variable_get, :@@vocabulary_cache).should be_a(Hash)
      end
      
    end
    
    describe "profile content" do
      before(:each) do
        @prof_graph = Graph.new
        bn_p = BNode.new("prefix")
        bn_t = BNode.new("term")
        @prof_graph.add(
          Triple.new(bn_p, RDFA_NS.prefix_, "dc"),
          Triple.new(bn_p, RDFA_NS.uri_, Literal.untyped(DC_NS.uri.to_s)),
          Triple.new(bn_t, RDFA_NS.term_, "title"),
          Triple.new(bn_t, RDFA_NS.uri_, Literal.untyped(DC_NS.title.to_s))
        )
        Parser.should_receive(:parse).with(@prof, "http://example.com/profile", :profile_graph => @profile_graph, :graph => instance_of(Graph)).and_return(@prof_graph)
        
        # Clear vocabulary cache
        RdfaParser.send(:class_variable_set, :@@vocabulary_cache, {})
        #RdfContext.debug = true
        @parser.parse(@doc, "http://example.com/doc")
        #RdfContext.debug = false
      end
      
      it "should have type dc:Agent" do
        @parser.graph.should be_contains(Triple.new("http://example.com/doc", RDF_TYPE, DC_NS.Agent))
      end
      
      it "should have property dc:title" do
        @parser.graph.should be_contains(Triple.new("http://example.com/doc", DC_NS.title, nil))
      end
    end
  end
  
  def self.test_cases(suite)
    RdfaHelper::TestCase.test_cases(suite)
  end

  # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
  %w(xhtml html5 html5 svgtiny).each do |suite| #html4 html5
    describe "w3c #{suite} testcases" do
      describe "that are required" do
        test_cases(suite).each do |t|
          next unless t.classification =~ /required/
          #next unless t.name =~ /0001/
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            #puts t.input
            #puts t.results
            begin
              t.run_test do |rdfa_string, rdfa_parser|
                rdfa_parser.parse(rdfa_string, t.informationResourceInput, :debug => [], :version => t.version)
              end
            rescue RSpec::Expectations::ExpectationNotMetError => e
              if t.input =~ /XMLLiteral/
                pending("XMLLiteral canonicalization not implemented yet")
              else
                raise
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            end
          end
        end
      end

      describe "that are optional" do
        test_cases(suite).each do |t|
          next unless t.classification =~ /optional/
          #next unless t.name =~ /0185/
          #puts t.inspect
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            begin
              t.run_test do |rdfa_string, rdfa_parser|
                rdfa_parser.parse(rdfa_string, t.informationResourceInput, :debug => [], :version => t.version)
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            rescue RSpec::Expectations::ExpectationNotMetError => e
              if t.name =~ /01[789]\d/
                raise
              else
                pending() {  raise }
              end
            end
          end
        end
      end

      describe "that are buggy" do
        test_cases(suite).each do |t|
          next unless t.classification =~ /buggy/
          #next unless t.name =~ /0185/
          #puts t.inspect
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            begin
              t.run_test do |rdfa_string, rdfa_parser|
                rdfa_parser.parse(rdfa_string, t.informationResourceInput, :debug => [], :version => t.version)
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            rescue RSpec::Expectations::ExpectationNotMetError => e
              if t.name =~ /01[789]\d/
                raise
              else
                pending() {  raise }
              end
            end
          end
        end
      end
    end
  end
end