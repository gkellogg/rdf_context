require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Namespace" do
  subject { Namespace.new("http://xmlns.com/foaf/0.1/", "foaf") }

  describe "method_missing" do
    it "should create URIRef" do
      subject.knows.to_s.should == "http://xmlns.com/foaf/0.1/knows"
    end
    
    it "should create URIRef for frag" do
      foaf_frag = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf", true)
      foaf_frag.knows.to_s.should == "http://xmlns.com/foaf/0.1/#knows"
    end
  end
  
  it "should have a URI" do
    lambda do
      test = Namespace.new(prefix='foaf')
    end.should raise_error
  end
  
  it "should have equality with URIRefs" do
    foaf_name = URIRef.new("http://xmlns.com/foaf/0.1/name")
    subject.name.should == foaf_name
  end
  
  it "should have an XML and N3-friendly prefix" do
    lambda do
      test = Namespace.new('http://xmlns.com/foaf/0.1/', '*~{')
    end.should raise_error
  end
  
  it "should be able to attach to the graph for substitution" do
    # rdflib does this using graph.bind('prefix', namespace)
    g = Graph.new
    subject.bind(g)
    #puts g.nsbinding.inspect
    should == g.nsbinding["foaf"]
  end
  
  it "should not allow you to attach to non-graphs" do
    lambda do
      subject.bind("cheese")
    end.should raise_error
  end
  
  it "should construct URI" do
    subject.foo.class.should == URIRef
    subject.foo.should == "http://xmlns.com/foaf/0.1/foo"
  end
  
  it "should construct URI with +" do
    (subject + "foo").class.should == URIRef
    (subject + "foo").should == "http://xmlns.com/foaf/0.1/foo"
  end
  
  it "will cause method conflict" do
    (subject + "class").should == "http://xmlns.com/foaf/0.1/class"
    subject.class.should ==  Namespace
  end
  
  it "should be be equivalent" do
    Namespace.new("http://a", "aa").should == Namespace.new("http://a", "aa")
  end
end
