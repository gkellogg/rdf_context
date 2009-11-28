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
end

