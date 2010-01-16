require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Triples" do
  before(:all) { @graph = Graph.new(:store => ListStore.new) }
  it "should require that the subject is a URIRef or BNode" do
   lambda do
     Triple.new(Literal.new("foo"), URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new)
    end.should raise_error
  end

  it "should require that the predicate is a URIRef" do
    lambda do
      Triple.new(BNode.new, BNode.new, BNode.new)
    end.should raise_error
  end

  it "should require that the object is a URIRef, BNode, Literal or Typed Literal" do
    lambda do
      Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), [])
    end.should raise_error
  end

  describe "with BNodes" do
    subject do
      Triple.new(BNode.new, URIRef.new('http://xmlns.com/foaf/0.1/knows'), BNode.new)
    end

    it "should have a subject" do
      subject.subject.class.should == BNode
    end
    
    it "should emit an NTriple" do
      subject.to_ntriples.should == "#{subject.subject.to_n3} <http://xmlns.com/foaf/0.1/knows> #{subject.object.to_n3} ."
    end
  end

  describe "with URIRefs" do
    subject {
      s = URIRef.new("http://tommorris.org/foaf#me")
      p = URIRef.new("http://xmlns.com/foaf/0.1/name")
      o = Literal.untyped("Tom Morris")
      Triple.new(s,p,o)
    }

    it "should emit an NTriple" do
      subject.to_ntriples.should == "<http://tommorris.org/foaf#me> <http://xmlns.com/foaf/0.1/name> \"Tom Morris\" ."
    end
  end

  describe "with coerced subject" do
    it "should accept a URIRef" do
      ref = URIRef.new('http://localhost/')
      Triple.coerce_subject(ref).should == ref
    end

    it "should accept a BNode" do
      node = BNode.new('a')
      Triple.coerce_subject(node).should == node
    end

    it "should accept a uri string and make URIRef" do
      Triple.coerce_subject('http://localhost/').should == URIRef.new('http://localhost/')
    end

    it "should accept an Addressable::URI object and make URIRef" do
      Triple.coerce_subject(Addressable::URI.parse("http://localhost/")).should == URIRef.new("http://localhost/")
    end
    
    it "should raise an InvalidSubject exception with any other class argument" do
      lambda do
        Triple.coerce_subject(Object.new)
      end.should raise_error(Triple::InvalidSubject)
    end
  end

  describe "with coerced predicate" do
    it "should make a string into a URI ref" do
      Triple.coerce_predicate("http://localhost/").should == URIRef.new('http://localhost/')
    end

    it "should leave a URIRef alone" do
      ref = URIRef.new('http://localhost/')
      Triple.coerce_predicate(ref).should == ref
    end

    it "should barf on an illegal uri string" do
      lambda do
        Triple.coerce_predicate("I'm just a soul whose intention is good")
      end.should raise_error(InvalidPredicate)
    end
  end

  describe "with coerced object" do
    it 'should make a literal for Integer types' do
      ref = 5
      Triple.coerce_object(ref).should == Literal.build_from(ref)
    end
    
    it 'should make a literal for Float types' do
      ref = 15.4
      Triple.coerce_object(ref).should == Literal.build_from(ref)
    end
    
    it 'should make a literal for Date types' do
      ref = Date::civil(2010, 1, 2)
      Triple.coerce_object(ref).should == Literal.build_from(ref)
    end
    
    it 'should make a literal for DateTime types' do
      ref = DateTime.parse('2010-01-03T01:02:03')
      Triple.coerce_object(ref).should == Literal.build_from(ref)
    end
    
    it "should leave URIRefs alone" do
      ref = URIRef.new("http://localhost/")
      Triple.coerce_object(ref).should == ref
    end
    
    it "should accept an Addressable::URI object and make URIRef" do
      Triple.coerce_object(Addressable::URI.parse("http://localhost/")).should == URIRef.new("http://localhost/")
    end
    
    it "should leave BNodes alone" do
      ref = BNode.new()
      Triple.coerce_object(ref).should == ref
    end
    
    it "should leave Regexp alone" do
      ref = /foo/
      Triple.coerce_object(ref).should == ref
    end
    
    it "should leave Literals alone" do
      ref = Literal.untyped('foo')
      Triple.coerce_object(ref).should == ref
      
      typedref = Literal.build_from('foo')
      Triple.coerce_object(ref).should == ref
    end
    
  end
  
  describe "with wildcards" do
    it "should accept nil" do
      t = Triple.new(nil, nil, nil)
      t.is_patern?.should be_true
    end
  end
  
  describe "equivalence" do
    before(:all) do
      @test_cases = [
        Triple.new(URIRef.new("http://foo"),URIRef.new("http://bar"),URIRef.new("http://baz")),
        Triple.new(URIRef.new("http://foo"),URIRef.new("http://bar"),Literal.untyped("baz")),
        Triple.new(URIRef.new("http://foo"),"http://bar",Literal.untyped("baz")),
        Triple.new(BNode.new("foo"),URIRef.new("http://bar"),Literal.untyped("baz")),
        Triple.new(BNode.new,URIRef.new("http://bar"),Literal.untyped("baz")),
      ]
    end
    it "should be equal to itself" do
      @test_cases.each {|triple| triple.should == triple}
    end

    it "should not be equal to something else" do
      t = Triple.new(URIRef.new("http://fab"),URIRef.new("http://bar"),URIRef.new("http://baz")),
      @test_cases.each {|triple| triple.should_not == t}
    end

    it "should be equal to equivalent" do
      @test_cases.each do |triple|
        t = Triple.new(triple.subject, triple.predicate, triple.object)
        triple.should == t
      end
    end
    
    it "should be equal to paterns" do
      @test_cases.each do |triple|
        [
          Triple.new(triple.subject, triple.predicate, triple.object),

          Triple.new(nil, triple.predicate, triple.object),
          Triple.new(triple.subject, nil, triple.object),
          Triple.new(triple.subject, triple.predicate, nil),

          Triple.new(nil, nil, triple.object),
          Triple.new(triple.subject, nil, nil),
          Triple.new(nil, triple.predicate, nil),

          Triple.new(nil, nil, nil),
        ].each do |t|
          triple.should == t
          t.should == triple
        end
      end
    end
  end
end
