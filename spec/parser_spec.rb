require File.join(File.dirname(__FILE__), 'spec_helper')
include Reddy

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe "RDF Parser" do
  it "should return N3 parser" do
    Parser.n3_parser.should be_a(N3Parser)
  end
  
  it "should return RdfXml parser" do
    Parser.rdfxml_parser.should be_a(RdfXmlParser)
  end
  
  it "should return Rdfa parser" do
    Parser.rdfa_parser.should be_a(RdfaParser)
  end

  it "should parse with specified type" do
    n3_string = "<http://example.org/> <http://xmlns.com/foaf/0.1/name> \"Gregg Kellogg\" . "
    graph = Parser.parse(n3_string, nil, :type => :n3)
    graph.size.should == 1
    graph[0].subject.to_s.should == "http://example.org/"
    graph[0].predicate.to_s.should == "http://xmlns.com/foaf/0.1/name"
    graph[0].object.to_s.should == "Gregg Kellogg"
  end
  
end

