require File.join(File.dirname(__FILE__), 'spec_helper')
include Reddy

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe "RDF Parser" do
  it "should raise exception if parsing virtual class" do
    p = Parser.new
    lambda { p.parse("a", "b") }.should raise_error(ParserException, "virtual class, must instantiate sub-class of Reddy::Parser")
  end
  
  it "should raise exception if no type specified" do
    lambda { Parser.parse("a", "b") }.should raise_error(ParserException, "type option must be one of :rdfxml, :html, or :n3")
  end
  
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

