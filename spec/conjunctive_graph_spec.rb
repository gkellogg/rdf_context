require File.join(File.dirname(__FILE__), 'spec_helper')

describe "ConjunctiveGraph" do
  before(:each) do
    @ex = Namespace.new("http://example.org/", "ex")
    @identifier = URIRef.new("http://store.identifier")
    @store = MemoryStore.new(@identifier)
  end
  
  subject { ConjunctiveGraph.new(:store => @store)}
  
  it "should require store supporting contexts" do
    lambda do
      ConjunctiveGraph.new(:store => ListStore.new)
    end.should raise_error(GraphException, "ConjunctiveGraph requires store supporting contexts")
  end
  
  it "should should have same identifier as store" do
    subject.identifier.should == @identifier
  end
  
  it "should have a default context" do
    subject.default_context.should be_a(Graph)
    subject.default_context.identifier.should == @identifier
    subject.default_context.store.should == @store
  end
  
  it "should add triples to default context" do
    t = Triple.new(@ex.a, @ex.b, @ex.c)
    subject.add(t)
    
    count = 0
    subject.triples do |t, ctx|
      t.should == t
      ctx.should be_a(Graph)
      ctx.identifier.should == @identifier
      count += 1
    end
    count.should == 1
  end
  
  it "should retrieve triples from all contexts" do
    g = Graph.new(:store => @store)
    t = Triple.new(@ex.a, @ex.b, @ex.c)
    g.add(t)
    
    count = 0
    subject.triples do |t, ctx|
      t.should == t
      ctx.should == g
      count += 1
    end
    count.should == 1
  end
  
  it "should parse into new context" do
    n3_string = "<http://example.org/> <http://xmlns.com/foaf/0.1/name> \"Gregg Kellogg\" . "
    graph = subject.parse(n3_string, "http://foo.bar", :type => :n3)
    graph.identifier.should == "http://foo.bar/"
    subject.size.should == 1
    t = subject.triples.first
    t.subject.to_s.should == "http://example.org/"
    t.predicate.to_s.should == "http://xmlns.com/foaf/0.1/name"
    t.object.to_s.should == "Gregg Kellogg"
  end
end