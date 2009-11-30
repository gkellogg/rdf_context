require File.join(File.dirname(__FILE__), 'spec_helper')
describe "Blank nodes" do
  before(:all) { @graph = Graph.new }
  
  it "should be bound to a Graph when created" do
    lambda { BNode.new(nil) }.should raise_error(BNodeException,"BNode must be bound to a graph")
  end
  
  describe "which have custom identifiers" do
    subject { BNode.new(@graph, "foo") }
  
    it "should return identifier" do
      subject.identifier.should =~ /foo/
      subject.to_s.should =~ /foo/
    end

    it "should be rejected if they are not acceptable" do
      b = BNode.new(@graph, "4cake")
      b.identifier.should_not =~ /4cake/
    end

    it "should be expressible in NT syntax" do
      subject.to_ntriples.should =~ /foo/
    end

    it "should be able to determine equality" do
      other = BNode.new(@graph, subject.to_s)
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
    subject { BNode.new(@graph, "") }
    it "should not be the same as an anonymous identifier" do should_not == BNode.new(@graph) end
    it "should be the same as nother blank identifier" do should == BNode.new(@graph, "") end
  end

  describe "which are anonymous" do
    subject { BNode.new(@graph)}
    it "should not be equivalent to another anonymous node" do
      should_not == BNode.new(@graph)
    end
    
    it "should be equivalent it's clone" do
      should == subject.clone
    end
    
    it "should create resource hash for RDF/XML anonymous bnode" do
      b = BNode.new(@graph)
      b.xml_args.should == [{"rdf:nodeID" => b.identifier}]
    end
  end
end
