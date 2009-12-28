require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Store" do
  {
    "List Store" => { :klass => ListStore, :configuration => {}, :context_aware => false, :ctx => URIRef.new("http://identifier")},
    "Memory Store" => { :klass => MemoryStore, :configuration => {}, :context_aware => true, :ctx => URIRef.new("http://identifier")},
    "Memory Store with ctx" => { :klass => MemoryStore, :configuration => {}, :context_aware => true, :ctx => URIRef.new("http://context")},
  }.each_pair do |label, hash|
    describe label.to_s do
      before(:all) do
        @identifier = URIRef.new("http://identifier")
        @ctx = hash[:ctx]
        @ex = Namespace.new("http://example.org/", "ex")
        @foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
      end
    
      subject { hash[:klass].new(@identifier, hash[:configuration]) }
    
      it "should be an AbstractStore" do
        subject.should be_a(AbstractStore)
      end
    
      it "should allow you to add a triple" do
        subject.add(Triple.new(@ex.a, @ex.b, @ex.c), @ctx)
        subject.add(Triple.new(@ex.a, @ex.b, @ex.d), @ctx)
        subject.size.should == 2
      end
      
      it "should allow you to create and bind Namespace objects" do
        foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
        subject.bind(foaf).should == foaf
      end

      it "should retrieve identifier" do
        subject.identifier.should == @identifier
      end
      
      describe "with triples" do
        before(:each) do
          subject.add(Triple.new(@ex.john, @foaf.knows, @ex.jane), @ctx)
          subject.add(Triple.new(@ex.john, @foaf.knows, @ex.rick), @ctx)
          subject.add(Triple.new(@ex.jane, @foaf.knows, @ex.rick), @ctx)
          subject.bind(@foaf)
        end
        
        it "should detect included triple" do
          subject.contains?(Triple.new(@ex.john, @foaf.knows, @ex.jane), @ctx).should be_true
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
            subject.add(t, @ctx)
            subject.contains?(t, @ctx)
          end
        end
        
        it "should tell you how large the store is" do
          subject.size.should == 3
        end
        
        it "should allow you to select resources" do
          subject.triples(Triple.new(@ex.john, nil, nil), @ctx).size.should == 2
        end
        
        it "should allow iteration" do
          count = 0
          subject.triples(Triple.new(nil, nil, nil), @ctx) do |t, context|
            count = count + 1
            t.class.should == Triple
          end
          count.should == 3
        end
        
        it "should allow iteration over a particular subject" do
          count = 0
          subject.triples(Triple.new(@ex.john, nil, nil), @ctx) do |t, context|
            count = count + 1
            t.class.should == Triple
          end
          count.should == 2
        end
        
        it "should allow iteration over a particular predicate" do
          count = 0
          subject.triples(Triple.new(nil, @foaf.knows, nil), @ctx) do |t, context|
            count = count + 1
            t.class.should == Triple
          end
          count.should == 3
        end
        
        it "should allow iteration over a particular object" do
          count = 0
          subject.triples(Triple.new(nil, nil, @ex.jane), @ctx) do |t, context|
            count = count + 1
            t.class.should == Triple
          end
          count.should == 1
        end
        
        it "should find combinations" do
          subject.triples(Triple.new(@ex.john, @foaf.knows, nil), @ctx).length.should == 2
          subject.triples(Triple.new(@ex.john, nil, @ex.jane), @ctx).length.should == 1
          subject.triples(Triple.new(nil, @foaf.knows, @ex.jane), @ctx).length.should == 1
        end
        
        it "should retrieve indexed item" do
          subject.item(0).should be_a(Triple)
        end

        it "should detect included triple" do
          t = subject.item(0)
          subject.contains?(t).should be_true
        end
      end

      it "should remove a triple" do
        subject.add(Triple.new(@ex.john, RDF_TYPE, @foaf.Person), @ctx)
        subject.size(@ctx).should == 1
        subject.remove(Triple.new(@ex.john, RDF_TYPE, @foaf.Person), @ctx)
        subject.size(@ctx).should == 0
      end

      if hash[:context_aware]
        describe "is context aware" do
          before(:all) do
            @triple = Triple.new(@ex.a, @ex.b, @ex.c)
            @ctx1 = URIRef.new("http://new1.ctx")
            @ctx2 = URIRef.new("http://new2.ctx")
          end
          
          it "should add triple to default context" do
            subject.add(@triple, nil)
            found = false
            subject.triples(@triple, nil) do |triple, context|
              @triple.should == @triple
              context.should == @identifier
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
            subject.contexts.should_not include(@ctx2)
            #subject.dump
            subject.triples(@triple, @ctx1).length.should == 1
            subject.triples(@triple, @ctx2).length.should == 0
          end

        end
      end
    end
  end
end