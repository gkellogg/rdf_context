$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
describe BNode do
  before(:all) { @context = {} }
  
  describe "descriminators" do
    subject { BNode.new }

    it "returns true for bnode?" do
      subject.should be_bnode
    end
    it "returns false for graph?" do
      subject.should_not be_graph
    end
    it "returns false for literal?" do
      subject.should_not be_literal
    end
    it "returns false for uri?" do
      subject.should_not be_uri
    end
  end
  
  describe ".parse" do
    subject {BNode.parse("_:bn1292025322717a")}
    it "returns nil if unrecognized pattern" do
      BNode.parse("foo").should be_nil
    end
    
    it "returns a BNode" do
      subject.should be_a(BNode)
    end
    
    it "returns node with same identifier" do
      subject.identifier.should == "bn1292025322717a"
    end

    it "returns node with different identifier if not native" do
      BNode.parse("_:a").identifier.should_not == "a"
    end
  end
  
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
      other = URIRef.intern('http://somehost.com/wherever.xml')
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

  describe "which has a nil identifier" do
    subject { BNode.new("", @context) }
    it "should not be the same as an anonymous identifier" do should_not == BNode.new end
    it "should not be the same as another nil identifier" do should_not == BNode.new(nil, @context) end
  end

  describe "which has a blank identifier" do
    subject { BNode.new("", @context) }
    it "should not be the same as an anonymous identifier" do should_not == BNode.new end
    it "should be the same as another blank identifier" do should == BNode.new("", @context) end
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
