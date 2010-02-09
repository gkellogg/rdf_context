require File.join(File.dirname(__FILE__), 'spec_helper')

describe "AggregateGraph" do
  before(:all) do
    @store = MemoryStore.new(@identifier)
    @graph1 = Graph.new(:store => @store)
    @graph2 = Graph.new(:store => @store)
    @graph3 = Graph.new(:store => @store)
    
    @graph1.parse(%(
    @prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix : <http://test/> .
    :foo a rdfs:Class.
    :bar :d :c.
    :a :d :c.
    ), "http://test/")
    
    @graph2.parse(%(
    @prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix : <http://test/> .
    @prefix log: <http://www.w3.org/2000/10/swap/log#>.
    :foo a rdfs:Resource.
    :bar rdfs:isDefinedBy [ a log:Formula ].
    :a :d :e.
    ), "http://test/")
    
    @graph3.parse(%(
    @prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix log: <http://www.w3.org/2000/10/swap/log#>.
    @prefix : <http://test/> .
    <> a log:N3Document.
    ), "http://test/")
  end
  
  subject { AggregateGraph.new(@graph1, @graph2, @graph3)}
  
  it "should return types" do
    subject.triples(Triple.new(nil, RDF_TYPE, nil)).length.should == 4
  end

  it "should return subjects" do
    subject.triples(Triple.new("http://test/bar", nil, nil)).length.should == 2
  end

  it "should return predicates" do
    subject.triples(Triple.new(nil, "http://test/d", nil)).length.should == 3
  end
  
  it "should have size sum of graphs" do
    subject.size.should == @graph1.size + @graph2.size + @graph3.size
  end
  
  it "should contain a triple" do
    subject.contains?(Triple.new("http://test/foo", RDF_TYPE, RDFS_NS.Resource)).should be_true
  end
end