# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
include RdfContext

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe RdfXmlParser do
  before(:each) { @parser = RdfXmlParser.new }

  it "should recognise and create single triple for empty non-RDF root" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
<NotRDF />
EOF
    graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    graph.size.should == 1
    statement = graph[0]
    statement.subject.class.should == BNode
    statement.predicate.to_s.should == RDF_TYPE.to_s
    statement.object.to_s.should == XML_NS.uri.to_s + "NotRDF"
  end
  
  it "should parse simple doc without a base URI" do
        sampledoc = %(<?xml version="1.0" ?>
    <NotRDF />)
        graph = @parser.parse(sampledoc, nil, :strict => true)
        graph.size.should == 1
        statement = graph[0]
        statement.subject.class.should == BNode
        statement.predicate.to_s.should == RDF_TYPE.to_s
        statement.object.to_s.should == XML_NS.uri.to_s + "NotRDF"
  end
  
  it "should trigger parsing on XML documents with multiple RDF nodes" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
<GenericXML xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.org/">
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/one">
      <ex:name>Foo</ex:name>
    </rdf:Description>
  </rdf:RDF>
  <blablabla />
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/two">
      <ex:name>Bar</ex:name>
    </rdf:Description>
  </rdf:RDF>
</GenericXML>
    EOF
    graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    [graph[0].object.to_s, graph[1].object.to_s].sort.should == ["Bar", "Foo"].sort
  end
  
  it "should be able to parse a simple single-triple document" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns:ex="http://www.example.org/" xml:lang="en" xml:base="http://www.example.org/foo">
  <ex:Thing rdf:about="http://example.org/joe" ex:name="bar">
    <ex:belongsTo rdf:resource="http://tommorris.org/" />
    <ex:sampleText rdf:datatype="http://www.w3.org/2001/XMLSchema#string">foo</ex:sampleText>
    <ex:hadADodgyRelationshipWith>
      <rdf:Description>
        <ex:name>Tom</ex:name>
        <ex:hadADodgyRelationshipWith>
          <rdf:Description>
            <ex:name>Rob</ex:name>
            <ex:hadADodgyRelationshipWith>
              <rdf:Description>
                <ex:name>Mary</ex:name>
              </rdf:Description>
            </ex:hadADodgyRelationshipWith>
          </rdf:Description>
        </ex:hadADodgyRelationshipWith>
      </rdf:Description>
    </ex:hadADodgyRelationshipWith>
  </ex:Thing>
</rdf:RDF>
    EOF

    graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    #puts @parser.debug
    graph.size.should == 10
    # print graph.to_ntriples
    # TODO: add datatype parsing
    # TODO: make sure the BNode forging is done correctly - an internal element->nodeID mapping
    # TODO: proper test
  end
  
  it "should raise an error if rdf:aboutEach is used, as per the negative parser test rdfms-abouteach-error001 (rdf:aboutEach attribute)" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:eg="http://example.org/">
  
      <rdf:Bag rdf:ID="node">
        <rdf:li rdf:resource="http://example.org/node2"/>
      </rdf:Bag>
  
      <rdf:Description rdf:aboutEach="#node">
        <dc:rights xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:rights>
  
      </rdf:Description>
  
    </rdf:RDF>
    EOF
    
    lambda do
      graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    end.should raise_error(InvalidPredicate, /Obsolete attribute .*aboutEach/)
  end
  
  it "should raise an error if rdf:aboutEachPrefix is used, as per the negative parser test rdfms-abouteach-error002 (rdf:aboutEachPrefix attribute)" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:eg="http://example.org/">
  
      <rdf:Description rdf:about="http://example.org/node">
        <eg:property>foo</eg:property>
      </rdf:Description>
  
      <rdf:Description rdf:aboutEachPrefix="http://example.org/">
        <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:creator>
  
      </rdf:Description>
  
    </rdf:RDF>
    EOF
    
    lambda do
      graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    end.should raise_error(InvalidPredicate, /Obsolete attribute .*aboutEachPrefix/)
  end
  
  it "should fail if given a non-ID as an ID (as per rdfcore-rdfms-rdf-id-error001)" do
    sampledoc = <<-EOF;
<?xml version="1.0"?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
     <rdf:Description rdf:ID='333-555-666' />
    </rdf:RDF>
    EOF
    
    lambda do
      graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    end.should raise_error(ParserException, /ID addtribute '.*' must be a NCName/)
  end
  
  it "should make sure that the value of rdf:ID attributes match the XML Name production (child-element version)" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:eg="http://example.org/">
     <rdf:Description>
       <eg:prop rdf:ID="q:name" />
     </rdf:Description>
    </rdf:RDF>
    EOF
    
    lambda do
      graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    end.should raise_error(ParserException, /ID addtribute '.*' must be a NCName/)
  end
  
  it "should be able to reify according to §2.17 of RDF/XML Syntax Specification" do
    sampledoc = <<-EOF;
<?xml version="1.0"?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:ex="http://example.org/stuff/1.0/"
             xml:base="http://example.org/triples/">
      <rdf:Description rdf:about="http://example.org/">
        <ex:prop rdf:ID="triple1">blah</ex:prop>
      </rdf:Description>
    </rdf:RDF>
    EOF

    triples = <<-EOF
<http://example.org/> <http://example.org/stuff/1.0/prop> \"blah\" .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <http://example.org/> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <http://example.org/stuff/1.0/prop> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> \"blah\" .
EOF

    graph = @parser.parse(sampledoc, "http://example.com/", :strict => true)
    graph.should be_equivalent_graph(triples, :about => "http://example.com/", :trace => @parser.debug)
  end
  
  it "should make sure that the value of rdf:ID attributes match the XML Name production (data attribute version)" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:eg="http://example.org/">
     <rdf:Description rdf:ID="a/b" eg:prop="val" />
    </rdf:RDF>
    EOF
    
    lambda do
      graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    end.should raise_error(ParserException, "ID addtribute 'a/b' must be a NCName")
  end
  
  it "should be able to handle Bags/Alts etc." do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:eg="http://example.org/">
  <rdf:Bag>
    <rdf:li rdf:resource="http://tommorris.org/" />
    <rdf:li rdf:resource="http://twitter.com/tommorris" />
  </rdf:Bag>
</rdf:RDF>
    EOF
    graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
    graph.predicates.should include("http://www.w3.org/1999/02/22-rdf-syntax-ns#_1", "http://www.w3.org/1999/02/22-rdf-syntax-ns#_2")
  end
  
  # # when we have decent Unicode support, add http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfms-rdf-id/error005.rdf
  # 
  # it "should support reification" do
  #   pending
  # end
  # 
  it "should detect bad bagIDs" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
     <rdf:Description rdf:bagID='333-555-666' />
    </rdf:RDF>
    EOF
    
    lambda do
      graph = @parser.parse(sampledoc, "http://example.com", :strict => true)
      puts @parser.debug
    end.should raise_error(InvalidPredicate, /Obsolete attribute .*bagID/)
  end

  it "should parse testcase" do
    sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF
		xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
		xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
		xmlns:test="http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#"
>
<!-- amp-in-url/Manifest.rdf -->
<test:PositiveParserTest rdf:about="http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001">

   <test:status>APPROVED</test:status>
   <test:approval rdf:resource="http://lists.w3.org/Archives/Public/w3c-rdfcore-wg/2001Sep/0326.html" />
   <!-- <test:discussion rdf:resource="pointer to archived email or other discussion" /> -->
   <!-- <test:description>
	-if we have a description, fill it in here -
   </test:description> -->

   <test:inputDocument>
      <test:RDF-XML-Document rdf:about="http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.rdf" />
   </test:inputDocument>

   <test:outputDocument>
      <test:NT-Document rdf:about="http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.nt" />
   </test:outputDocument>

</test:PositiveParserTest>
</rdf:RDF>
EOF

    triples = <<-EOF
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#PositiveParserTest> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#approval> <http://lists.w3.org/Archives/Public/w3c-rdfcore-wg/2001Sep/0326.html> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#inputDocument> <http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.rdf> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#outputDocument> <http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.nt> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#status> "APPROVED" .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.nt> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#NT-Document> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/test001.rdf> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#RDF-XML-Document> .
EOF
    uri = "http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001"

    graph = @parser.parse(sampledoc, uri, :strict => true)
    graph.should be_equivalent_graph(triples, :about => uri, :trace => @parser.debug)
  end
  
  describe "parsing rdf files" do
    def test_file(filepath, uri)
      rdf_string = File.read(filepath)
      graph = @parser.parse(rdf_string, uri, :strict => true)

      nt_string = File.read(filepath.sub('.rdf', '.nt'))
      nt_graph = N3Parser.parse(nt_string, uri)

      graph.should be_equivalent_graph(nt_graph, :about => uri, :trace => @parser.debug)
    end

    before(:all) do
      @rdf_dir = File.join(File.dirname(__FILE__), '..', 'test', 'rdf_tests')
    end

    it "should parse Coldplay's BBC Music profile" do
      gid = 'cc197bad-dc9c-440d-a5b5-d52ba2e14234'
      file = File.join(@rdf_dir, "#{gid}.rdf")
      test_file(file, "http://www.bbc.co.uk/music/artists/#{gid}")
    end

    it "should parse xml literal test" do
     file = File.join(@rdf_dir, "xml-literal-mixed.rdf")
     test_file(file, "http://www.example.com/books#book12345")
    end
  end

  # W3C Test suite from http://www.w3.org/2000/10/rdf-tests/rdfcore/
  describe "w3c rdfcore tests" do
    require 'rdf_helper'
    
    def self.positive_tests
      RdfHelper::TestCase.positive_parser_tests(RDFCORE_TEST, RDFCORE_DIR) rescue []
    end

    def self.negative_tests
      RdfHelper::TestCase.negative_parser_tests(RDFCORE_TEST, RDFCORE_DIR) rescue []
    end
    
    # Negative parser tests should raise errors.
    describe "positive parser tests" do
      positive_tests.each do |t|
        #next unless t.about.uri.to_s =~ /rdfms-rdf-names-use/
        #next unless t.name =~ /11/
        #puts t.inspect
        specify "test #{t.name}: " + (t.description || "#{t.inputDocument} against #{t.outputDocument}") do
          t.run_test do |rdf_string, parser|
            parser.parse(rdf_string, t.about, :strict => true, :debug => [])
          end
        end
      end
    end
    
    describe "negative parser tests" do
      negative_tests.each do |t|
        #next unless t.about.uri.to_s =~ /rdfms-empty-property-elements/
        #next unless t.name =~ /1/
        #puts t.inspect
        specify "test #{t.name}: " + (t.description || t.inputDocument) do
          t.run_test do |rdf_string, parser|
            lambda do
              parser.parse(rdf_string, t.about, :strict => true, :debug => [])
              parser.graph.should be_equivalent_graph("", t)
            end.should raise_error(RdfException)
          end
        end
      end
    end
  end
end

