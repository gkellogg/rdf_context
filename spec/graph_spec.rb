require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Graphs" do
  before(:all) do
    @ex = Namespace.new("http://example.org/", "ex")
    @foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
  end
  
  subject { Graph.new }
  it "should allow you to add one or more triples" do
    lambda do
      subject.add_triple(subject.bnode, URIRef.new("http://xmlns.com/foaf/0.1/knows"), subject.bnode)
    end.should_not raise_error
  end
  
  it "should support << as an alias for add_triple" do
    lambda do
      subject << Triple.new(subject.bnode, URIRef.new("http://xmlns.com/foaf/0.1/knows"), subject.bnode)
    end.should_not raise_error
    subject.size.should == 1
  end
  
  it "should return bnode subjects" do
    bn = subject.bnode
    subject.add_triple(bn, URIRef.new("http://xmlns.com/foaf/0.1/knows"), bn)
    subject.subjects.should == [bn]
  end
  
  it "should be able to determine whether or not it has existing BNodes" do
    foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
    subject << Triple.new(subject.bnode('john'), foaf.knows, subject.bnode('jane'))
    subject.has_bnode_identifier?('john').should be_true
    subject.has_bnode_identifier?('jane').should be_true
    subject.has_bnode_identifier?('jack').should_not be_true
  end
  
  it "should allow you to create and bind Namespace objects on-the-fly" do
    subject.namespace("http://xmlns.com/foaf/0.1/", "foaf")
    subject.nsbinding["foaf"].uri.should == "http://xmlns.com/foaf/0.1/"
  end
  
  it "should not allow you to bind things other than namespaces" do
    lambda do
      subject.bind(false)
    end.should raise_error
  end
    
  it "should follow the specification as to output identical triples" do
    subject.add_triple(@ex.a, @ex.b, @ex.c)
    subject.add_triple(@ex.a, @ex.b, @ex.c)
    subject.size.should == 1
  end
  
  describe "with XML Literal objects" do
    subject {
      dc = Namespace.new("http://purl.org/dc/elements/1.1/", "dc")
      xhtml = Namespace.new("http://www.w3.org/1999/xhtml", "")
      g = Graph.new
      g << Triple.new(
        URIRef.new("http://www.w3.org/2006/07/SWD/RDFa/testsuite/xhtml1-testcases/0011.xhtml"),
        URIRef.new("http://purl.org/dc/elements/1.1/title"),
        Literal.typed("E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">2</sup>: The Most Urgent Problem of Our Time",
                      "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral",
                      g.nsbinding)
      )
      g.bind(dc)
      g.bind(xhtml)
      g
    }
    
    it "should output NTriple" do
      nt = '<http://www.w3.org/2006/07/SWD/RDFa/testsuite/xhtml1-testcases/0011.xhtml> <http://purl.org/dc/elements/1.1/title> "E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">2</sup>: The Most Urgent Problem of Our Time"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral> .' + "\n"
      subject.to_ntriples.should == nt
    end

    it "should output RDF/XML" do
      rdfxml = <<-HERE
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:xml=\"http://www.w3.org/XML/1998/namespace\" xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:xhv=\"http://www.w3.org/1999/xhtml/vocab#\">
  <rdf:Description rdf:about="http://www.w3.org/2006/07/SWD/RDFa/testsuite/xhtml1-testcases/0011.xhtml">
    <dc:title rdf:parseType="Literal">E = mc<sup xmlns="http://www.w3.org/1999/xhtml" xmlns:dc="http://purl.org/dc/elements/1.1/">2>/sup>: The Most Urgent Problem of Our Time</dc:title>
  </rdf:Description>
</rdf:RDF>
HERE
      subject.to_rdfxml.should include("E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">2</sup>: The Most Urgent Problem of Our Time")
    end
  end
  
  describe "with bnodes" do
    subject {
      g = Graph.new
      a = g.bnode("a")
      b = g.bnode("b")
      
      g << Triple.new(a, @foaf.name, Literal.untyped("Manu Sporny"))
      g << Triple.new(a, @foaf.knows, b)
      g << Triple.new(b, @foaf.name, Literal.untyped("Ralph Swick"))
      g.bind(@foaf)
      g
    }
    
    it "should return bnodes" do
      subject.bnodes.keys.length.should == 2
      subject.bnodes.values.should == [2, 2]
    end

    it "should output RDF/XML" do
      rdfxml = <<-HERE
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:xml="http://www.w3.org/XML/1998/namespace" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:xhv="http://www.w3.org/1999/xhtml/vocab#">
  <rdf:Description rdf:nodeID="a">
    <foaf:name>Manu Sporny</foaf:name>
    <foaf:knows rdf:nodeID="b"/>
  </rdf:Description>
  <rdf:Description rdf:nodeID="b">
    <foaf:name>Ralph Swick</foaf:name>
  </rdf:Description>
</rdf:RDF>
HERE
      xml = subject.to_rdfxml
      xml.should include("Ralph Swick")
      xml.should include("Manu Sporny")
    end
  end
  
  describe "with triples" do
    subject {
      g = Graph.new
      g.add_triple(@ex.john, @foaf.knows, @ex.jane)
      g.add_triple(@ex.john, @foaf.knows, @ex.rick)
      g.add_triple(@ex.jane, @foaf.knows, @ex.rick)
      g.bind(@foaf)
      g
    }

    it "should detect included triple" do
      subject.contains?(subject[0]).should be_true
    end
    
    it "should tell you how large the graph is" do
      subject.size.should == 3
    end
  
    it "should return unique subjects" do
      subject.subjects.should == [@ex.john.uri.to_s, @ex.jane.uri.to_s]
    end
    
    it "should allow you to select one resource" do
      subject.triples(:subject => @ex.john).size.should == 2
    end

    it "should allow iteration" do
      count = 0
      subject.triples do |t|
        count = count + 1
        t.class.should == Triple
      end
      count.should == 3
    end

    it "should allow iteration over a particular subject" do
      count = 0
      subject.triples(:subject => @ex.john) do |t|
        count = count + 1
        t.class.should == Triple
        t.subject.should == @ex.john
      end
      count.should == 2
    end

    it "should give you a list of resources of a particular type" do
      subject.add_triple(@ex.john, RDF_TYPE, @foaf.Person)
      subject.add_triple(@ex.jane, RDF_TYPE, @foaf.Person)

      subject.get_by_type("http://xmlns.com/foaf/0.1/Person").should == [@ex.john, @ex.jane]
    end

    describe "find triples" do
      it "should find subjects" do
        subject.triples(:subject => @ex.john).size.should == 2
        subject.triples(:subject => @ex.jane).size.should == 1
      end
      
      it "should find predicates" do
        subject.triples(:predicate => @foaf.knows).size.should == 3
      end
      
      it "should find objects" do
        subject.triples(:object => @ex.rick).size.should == 2
      end
      
      it "should find object with regexp" do
        subject.triples(:object => /rick/).size.should == 2
      end
      
      it "should find with combinations" do
        subject.triples(:subject => @ex.john, :object => @ex.rick).size.should == 1
      end
    end
    
    describe "encodings" do
      it "should output NTriple" do
        nt = "<http://example.org/john> <http://xmlns.com/foaf/0.1/knows> <http://example.org/jane> .\n<http://example.org/john> <http://xmlns.com/foaf/0.1/knows> <http://example.org/rick> .\n<http://example.org/jane> <http://xmlns.com/foaf/0.1/knows> <http://example.org/rick> .\n"
        subject.to_ntriples.should == nt
      end
    
      it "should output RDF/XML" do
        rdfxml = <<HERE
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:xml="http://www.w3.org/XML/1998/namespace" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:xhv="http://www.w3.org/1999/xhtml/vocab#">
  <rdf:Description rdf:about="http://example.org/john">
    <foaf:knows rdf:resource="http://example.org/jane"/>
  </rdf:Description>
  <rdf:Description rdf:about="http://example.org/john">
    <foaf:knows rdf:resource="http://example.org/rick"/>
  </rdf:Description>
  <rdf:Description rdf:about="http://example.org/jane">
    <foaf:knows rdf:resource="http://example.org/rick"/>
  </rdf:Description>
</rdf:RDF>
HERE
        subject.to_rdfxml.should be_equivalent_xml(rdfxml)
      end
    end
  end

  describe "which are merged" do
    it "should be able to integrate another graph" do
      subject.add_triple(subject.bnode, URIRef.new("http://xmlns.com/foaf/0.1/knows"), subject.bnode)
      g = Graph.new
      g.merge!(subject)
      g.size.should == 1
    end
    
    it "should not merge with non graph" do
      lambda do
        h.merge!("")
      end.should raise_error
    end
    
    # One does not, in general, obtain the merge of a set of graphs by concatenating their corresponding
    # N-Triples documents and constructing the graph described by the merged document. If some of the
    # documents use the same node identifiers, the merged document will describe a graph in which some of the
    # blank nodes have been 'accidentally' identified. To merge N-Triples documents it is necessary to check
    # if the same nodeID is used in two or more documents, and to replace it with a distinct nodeID in each
    # of them, before merging the documents.
    it "should remap bnodes to avoid duplicate bnode identifiers" do
      subject.add_triple(subject.bnode("a1"), URIRef.new("http://xmlns.com/foaf/0.1/knows"), subject.bnode("a2"))
      g = Graph.new
      g.add_triple(subject.bnode("a1"), URIRef.new("http://xmlns.com/foaf/0.1/knows"), subject.bnode("a2"))
      g.merge!(subject)
      g.size.should == 2
      s1, s2 = g.triples.map(&:subject)
      p1, p2 = g.triples.map(&:predicate)
      o1, o2 = g.triples.map(&:object)
      s1.should_not == s2
      p1.should == p1
      o1.should_not == o2
    end

    it "should remove duplicate triples" do
      subject.add_triple(@ex.a, URIRef.new("http://xmlns.com/foaf/0.1/knows"), @ex.b)
      g = Graph.new
      g.add_triple(@ex.a, URIRef.new("http://xmlns.com/foaf/0.1/knows"), @ex.b)
      g.merge!(subject)
      g.size.should == 1
    end
  end
  
  describe "that can be compared" do
    it "should be true for empty graphs" do
      should be_equivalent_graph(Graph.new)
    end

    it "should be false for different graphs" do
      f = Graph.new
      f.add_triple(URIRef.new("http://example.org/joe"), URIRef.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), URIRef.new("http://xmlns.com/foaf/0.1/Person"))
      should_not be_equivalent_graph(f)
    end
    
    it "should be true for equivalent graphs with different BNode identifiers" do
      subject.add_triple(@ex.a, @foaf.knows, subject.bnode("a1"))
      subject.add_triple(subject.bnode("a1"), @foaf.knows, @ex.a)

      f = Graph.new
      f.add_triple(@ex.a, @foaf.knows, subject.bnode("a2"))
      f.add_triple(subject.bnode("a2"), @foaf.knows, @ex.a)
      should be_equivalent_graph(f)
    end
  end
end
