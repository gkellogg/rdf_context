$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
include RdfContext

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
  
  describe "File detection" do
    subject { Parser.new }
    {
      "File with .rdf extension"  => [nil, "foo.rdf", :rdfxml],
      "File with .xml extension"  => [nil, "foo.xml", :rdfxml],
      "File with .html extension"  => [nil, "foo.html", :rdfa],
      "File with .xhtml extension"  => [nil, "foo.xhtml", :rdfa],
      "File with .nt extension"  => [nil, "foo.nt", :n3],
      "File with .n3 extension"  => [nil, "foo.n3", :n3],
      "File with .txt extension"  => [nil, "foo.txt", :n3],
      "File with rdf:RDF content"  => ["<rdf:RDF", "foo", :rdfxml],
      "File with foo:RDF content"  => ["<foo:RDF", "foo", :rdfxml],
      "File with RDF content"  => ["<RDF", "foo", :rdfxml],
      "File with HTML content"  => ["<HTML", "foo", :rdfa],
      "File with html content"  => ["<html", "foo", :rdfa],
      "File with hTmL content"  => ["<hTmL", "foo", :rdfa],
      "File with nt content"  => ["<http::/foo> _:bar \"1\" .", "foo", :n3],
    }.each_pair do |what, args|
      it "should detect format of #{what}" do
        type = args.pop
        subject.detect_format(*args).should == type
      end
    end
  end
end

