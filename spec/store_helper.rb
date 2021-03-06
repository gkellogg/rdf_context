# coding: utf-8
shared_examples_for "Store" do
  before(:all) do
    @ex = Namespace.new("http://example.org/", "ex")
    @foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
  end
  
  it "should be an AbstractStore" do
    subject.should be_a(AbstractStore)
  end

  describe "#add" do
    it "adds URIRefs" do
      subject.add(Triple.new(@ex.a, @ex.b, @ex.c), nil)
      subject.add(Triple.new(@ex.a, @ex.b, @ex.d), nil)
      subject.size.should == 2
    end
  
    it "adds BNodes" do
      subject.add(Triple.new(BNode.new, @ex.b, @ex.c), nil)
      subject.add(Triple.new(@ex.a, BNode.new, @ex.c), nil)
      subject.add(Triple.new(@ex.a, @ex.b, BNode.new), nil)
      subject.size.should == 3
    end
  end
  
  it "should retrieve identifier" do
    subject.identifier.should == @identifier
  end
  
  describe "namespaces" do
    before(:each) do
      subject.bind(@ex)
    end
    
    it "should allow you to create and bind Namespace objects" do
      foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
      subject.bind(foaf).should == foaf
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
    
    it "should contain different triple patterns" do
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
    
    it "destroys triples" do
      subject.destroy
      subject.size.should == 0
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
  
  describe "triple round-trip" do
    {
      "UUU"   => Triple.new(RDF_NS.a, RDF_NS.b, RDF_NS.c),
      "UUB"   => Triple.new(RDF_NS.a, RDF_NS.b, BNode.new),
      "UUBn"  => Triple.new(RDF_NS.a, RDF_NS.b, BNode.new("foo")),
      "BUU"   => Triple.new(BNode.new, RDF_NS.b, RDF_NS.c),
      "BUB"   => Triple.new(BNode.new, RDF_NS.b, BNode.new),
      "untyped" => Triple.new(RDF_NS.a, RDF_NS.b, "Gregg"),
      "int"   => Triple.new(RDF_NS.a, RDF_NS.b, 1),
      "float" => Triple.new(RDF_NS.a, RDF_NS.b, 1.1),
      "xml"   => Triple.new(RDF_NS.a, RDF_NS.b,
                        Literal.typed("foo <sup <sup xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")),
      "Dürst"         => Triple.new(RDF_NS.a, RDF_NS.b, Literal.untyped("Dürst")),
      "lang"          => Triple.new(RDF_NS.a, RDF_NS.b, Literal.untyped("Gregg", "de-ch")),
      "backslash:\\"  => Triple.new(RDF_NS.a, RDF_NS.b, "backslash:\\"),
      "dquote:\""     => Triple.new(RDF_NS.a, RDF_NS.b, "dquote:\""),
      "newline:\n"    => Triple.new(RDF_NS.a, RDF_NS.b, "newline:\n"),
      "return:\r"     => Triple.new(RDF_NS.a, RDF_NS.b, "return:\r"),
      "tab:\t"        => Triple.new(RDF_NS.a, RDF_NS.b, "tab:\t"),
    }.each_pair do |desc, triple|
      it "should retrieve #{desc}" do
        subject.add(triple, nil)
        subject.triples(triple, nil).should include(triple)
        #subject.triples(Triple.new(nil, nil, nil), nil).should include(triple)
      end
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
      subject.contexts.length.should == 1
      subject.contexts.should include(@ctx2)
    end
    
    it "should destroy from specific context" do
      subject.add(@triple, @ctx1)
      subject.add(@triple, @ctx2)
      subject.destroy(:context => @ctx1)
      subject.triples(@triple, @ctx1).length.should == 0
      subject.triples(@triple, @ctx2).length.should == 1
      found = 0
      subject.triples(@triple, nil) do |triple, context|
        found += 1
      end
      found.should == 1
      subject.contexts.length.should == 1
      subject.contexts.should include(@ctx2)
    end

    it "should remove context when graph destroyed" do
      subject.add(@triple, @ctx1)
      subject.add(@triple, @ctx2)
      @ctx1.destroy
      subject.triples(@triple, @ctx1).length.should == 0
      subject.triples(@triple, @ctx2).length.should == 1
      found = 0
      subject.triples(@triple, nil) do |triple, context|
        found += 1
      end
      found.should == 1
      subject.contexts.length.should == 1
      subject.contexts.should include(@ctx2)
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
      subject.contexts.length.should == 0
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

    it "should return new context after equivalent context destroyed" do
      ctx1 = Graph.new(:identifier => URIRef.new("http://new1.ctx"), :store => subject)
      subject.add(@triple, ctx1)
      subject.contexts.length.should == 1
      subject.contexts.should include(ctx1)
      
      ctx1.destroy
      subject.contexts.should be_empty

      ctx1 = Graph.new(:identifier => URIRef.new("http://new1.ctx"), :store => subject)
      subject.add(@triple, ctx1)
      subject.contexts.length.should == 1
      subject.contexts.should include(ctx1)
    end
  end
end
