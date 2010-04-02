require File.join(File.dirname(__FILE__), 'spec_helper')
describe "Blank nodes" do
  before(:all) { @context = {} }
  
  describe "which have custom identifiers" do
    subject { BNode.new("foo", @context) }
  
    it "should return identifier" do
      subject.identifier.should =~ /foo/
      subject.to_s.should =~ /foo/
    end

    it "should be rejected if they are not acceptable" do
      b = BNode.new("4cake", @context)
      b.identifier.should_not =~ /4cake/
    end

    it "should be expressible in NT syntax" do
      subject.to_ntriples.should =~ /foo/
    end

    it "should be able to determine equality" do
      other = BNode.new(subject.to_s, @context)
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

  it "should accept valid bnode identifier" do
    bn = BNode.new
    BNode.new(bn.to_s).should == bn
  end

  it "should accept valid named bnode identifier" do
    bn = BNode.new("foo")
    BNode.new(bn.to_s).should == bn
  end

  describe "which has a blank identifier" do
    subject { BNode.new("", @context) }
    it "should not be the same as an anonymous identifier" do should_not == BNode.new end
    it "should not be the same as another blank identifier" do should_not == BNode.new("", @context) end
  end

  describe "which are anonymous" do
    subject { BNode.new(@graph)}
    it "should not be equivalent to another anonymous node" do
      should_not == BNode.new
    end
    
    it "should be equivalent it's clone" do
      should == subject.clone
    end
    
    it "should create resource hash for RDF/XML anonymous bnode" do
      b = BNode.new
      b.xml_args.should == [{"rdf:nodeID" => b.identifier}]
    end
  end
end
