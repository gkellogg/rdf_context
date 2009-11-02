require File.join(File.dirname(__FILE__), 'spec_helper')
describe "Blank nodes" do
  describe "which have custom identifiers" do
    subject { BNode.new("foo") }
    
    it "should return identifier" do
      subject.identifier.should == "foo"
      subject.to_s.should == "foo"
    end

    it "should be rejected if they are not acceptable" do
      b = BNode.new("4cake")
      b.identifier.should_not == "4cake"
    end

    it "should be expressible in NT syntax" do
      subject.to_ntriples.should == "_:foo"
    end

    it "should be able to determine equality" do
      other = BNode.new(subject.to_s)
      should == other
    end

    it "should be able to determine inequality" do
      other = URIRef.new('http://somehost.com/wherever.xml')
      should_not == other
    end

    it "should resource hash for RDF/XML named bnode" do
      subject.xml_args.should == [{"rdf:nodeID" => subject.to_s}]
    end
  end
  
  describe "which has a blank identifier" do
    subject { BNode.new("") }
    it "should not be the same as an anonymous identifier" do should_not == BNode.new end
    it "should be the same as nother blank identifier" do should == BNode.new("") end
  end
  
  it "should create a single BNode for a blank identifier" do
    BNode.new("").should_not == BNode
  end
  
  describe "which are anonymous" do
    it "should resource hash for RDF/XML anonymous bnode" do
      b = BNode.new
      b.xml_args.should == [{"rdf:nodeID" => b.identifier}]
    end
  end
end
