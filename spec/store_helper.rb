shared_examples_for "Store" do
  before(:all) do
    @ex = Namespace.new("http://example.org/", "ex")
    @foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
  end
  
  it "should be an AbstractStore" do
    subject.should be_a(AbstractStore)
  end

  it "should allow you to add a triple" do
    subject.add(Triple.new(@ex.a, @ex.b, @ex.c), nil)
    subject.add(Triple.new(@ex.a, @ex.b, @ex.d), nil)
    subject.size.should == 2
  end
  
  it "should allow you to create and bind Namespace objects" do
    foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
    subject.bind(foaf).should == foaf
  end

  it "should retrieve identifier" do
    subject.identifier.should == @identifier
  end
  
  describe "namespaces" do
    before(:each) do
      subject.bind(@ex)
    end
    
    it "should return namespace by prefix" do
      subject.namespace(@ex.prefix).should == @ex
    end
    
    it "should return prefix by uri" do
      subject.prefix(@ex.uri).should == @ex.prefix
    end
    
    it "should bind namespace" do
      subject.bind(@foaf).should == @foaf
    end
    
    it "should return all namespaces" do
      subject.nsbinding.should == { @ex.prefix => @ex}
    end
  end

  describe "with triples" do
    before(:each) do
      subject.add(Triple.new(@ex.john, @foaf.knows, @ex.jane), nil)
      subject.add(Triple.new(@ex.john, @foaf.knows, @ex.rick), nil)
      subject.add(Triple.new(@ex.jane, @foaf.knows, @ex.rick), nil)
      subject.bind(@foaf)
    end
    
    it "should detect included triple" do
      subject.contains?(Triple.new(@ex.john, @foaf.knows, @ex.jane), nil).should be_true
    end
    
    it "should contain different triple paterns" do
      [
        Triple.new(URIRef.new("http://foo"),URIRef.new("http://bar"),URIRef.new("http://baz")),
        Triple.new(URIRef.new("http://foo"),URIRef.new("http://bar"),Literal.untyped("baz")),
        Triple.new(URIRef.new("http://foo"),"http://bar",Literal.untyped("baz")),
        Triple.new(BNode.new("foo"),URIRef.new("http://bar"),Literal.untyped("baz")),
        Triple.new(BNode.new,URIRef.new("http://bar"),Literal.untyped("baz")),
        Triple.new(URIRef.new("http://foo"),URIRef.new("http://bar"),Literal.typed(5, "http://www.w3.org/2001/XMLSchema#int")),
        Triple.new(URIRef.new("http://foo"),URIRef.new("http://bar"),Literal.typed("gregg", "http://www.w3.org/2001/XMLSchema#string")),
        Triple.new(URIRef.new("http://foo"),URIRef.new("http://bar"),"gregg"),
      ].each do |t|
        subject.add(t, nil)
        subject.contains?(t, nil)
      end
    end
    
    it "should tell you how large the store is" do
      subject.size.should == 3
    end
    
    it "should allow you to select resources" do
      subject.triples(Triple.new(@ex.john, nil, nil), nil).size.should == 2
    end
    
    it "should allow iteration" do
      count = 0
      subject.triples(Triple.new(nil, nil, nil), nil) do |t, context|
        count = count + 1
        t.class.should == Triple
      end
      count.should == 3
    end
    
    it "should allow iteration over a particular subject" do
      count = 0
      subject.triples(Triple.new(@ex.john, nil, nil), nil) do |t, context|
        count = count + 1
        t.class.should == Triple
      end
      count.should == 2
    end
    
    it "should allow iteration over a particular predicate" do
      count = 0
      subject.triples(Triple.new(nil, @foaf.knows, nil), nil) do |t, context|
        count = count + 1
        t.class.should == Triple
      end
      count.should == 3
    end
    
    it "should allow iteration over a particular object" do
      count = 0
      subject.triples(Triple.new(nil, nil, @ex.jane), nil) do |t, context|
        count = count + 1
        t.class.should == Triple
      end
      count.should == 1
    end
    
    it "should find combinations" do
      subject.triples(Triple.new(@ex.john, @foaf.knows, nil), nil).length.should == 2
      subject.triples(Triple.new(@ex.john, nil, @ex.jane), nil).length.should == 1
      subject.triples(Triple.new(nil, @foaf.knows, @ex.jane), nil).length.should == 1
    end
    
    it "should retrieve indexed item" do
      subject.item(0).should be_a(Triple)
    end

    it "should detect included triple" do
      t = subject.item(0)
      subject.contains?(t).should be_true
    end
  end

  describe "with typed triples" do
    before(:each) do
      subject.add(Triple.new(@ex.john, RDF_TYPE, @foaf.Person), nil)
      subject.add(Triple.new(@ex.jane, RDF_TYPE, @foaf.Person), nil)
      subject.add(Triple.new(@ex.rick, RDF_TYPE, @foaf.Person), nil)
      subject.add(Triple.new(@ex.john, @foaf.knows, @ex.jane), nil)
      subject.add(Triple.new(@ex.john, @foaf.knows, @ex.rick), nil)
      subject.add(Triple.new(@ex.jane, @foaf.knows, @ex.rick), nil)
      subject.bind(@foaf)
      subject.bind(@ex)
    end
    
    it "should find subjects by type" do
      count = 0
      subject.triples(Triple.new(nil, RDF_TYPE, nil), nil) do |triple, ctx|
        count += 1
        [@ex.john, @ex.jane, @ex.rick].should include(triple.subject)
        triple.predicate.should == RDF_TYPE
        triple.object.should == @foaf.Person
      end
      count.should == 3
    end
    
    it "should remove types" do
      subject.remove(Triple.new(nil, RDF_TYPE, nil), nil)
      subject.size.should == 3
    end
  end
  
  it "should remove a triple" do
    subject.add(Triple.new(@ex.john, RDF_TYPE, @foaf.Person), nil)
    subject.size.should == 1
    subject.remove(Triple.new(@ex.john, RDF_TYPE, @foaf.Person), nil)
    subject.size.should == 0
  end
end

shared_examples_for "Context Aware Store" do
  before(:all) do
    @ex = Namespace.new("http://example.org/", "ex")
    @foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
  end

  describe "is context aware" do
    before(:each) do
      @triple = Triple.new(@ex.a, @ex.b, @ex.c)
      @ctx1 = Graph.new(:identifier => URIRef.new("http://new1.ctx"), :store => subject)
      @ctx2 = Graph.new(:identifier => URIRef.new("http://new2.ctx"), :store => subject)
    end
    
    it "should add triple to default context" do
      subject.add(@triple, nil)
      found = false
      subject.triples(@triple, nil) do |triple, context|
        @triple.should == @triple
        context.should == Graph.new(:store => subject, :identifier => subject.identifier)
        found = true
      end
      found.should be_true
    end
    
    it "should add to multiple contexts" do
      subject.add(@triple, @ctx1)
      subject.add(@triple, @ctx2)
      subject.triples(@triple, @ctx1).length.should == 1
      subject.triples(@triple, @ctx2).length.should == 1
      
      found = 0
      subject.triples(@triple, nil) do |triple, context|
        found += 1
      end
      found.should == 2
    end
    
    it "should return contexts" do
      subject.add(@triple, @ctx1)
      subject.add(@triple, @ctx2)
      subject.contexts.should include(@ctx1, @ctx2)
      subject.contexts.length.should == 2
    end
    
    it "should find contexts containing triple" do
      subject.add(@triple, @ctx1)
      subject.contexts(@triple).should == [@ctx1]
    end
    
    it "should remove from specific context" do
      subject.add(@triple, @ctx1)
      subject.add(@triple, @ctx2)
      subject.remove(@triple, @ctx1)
      subject.triples(@triple, @ctx1).length.should == 0
      subject.triples(@triple, @ctx2).length.should == 1
      found = 0
      subject.triples(@triple, nil) do |triple, context|
        found += 1
      end
      found.should == 1
    end
    
    it "should remove from multiple contexts" do
      subject.add(@triple, @ctx1)
      subject.add(@triple, @ctx2)
      subject.remove(@triple, nil)
      subject.triples(@triple, @ctx1).length.should == 0
      subject.triples(@triple, @ctx2).length.should == 0
      found = 0
      subject.triples(@triple, nil) do |triple, context|
        found += 1
      end
      found.should == 0
    end

    it "should remove context" do
      subject.add(@triple, @ctx1)
      subject.add(@triple, @ctx2)
      #subject.dump
      subject.remove(Triple.new(nil, nil, nil), @ctx2)
      subject.contexts.should include(@ctx1)
      subject.contexts.should_not include(@ctx2)
      #subject.dump
      subject.triples(@triple, @ctx1).length.should == 1
      subject.triples(@triple, @ctx2).length.should == 0
    end

  end
end
