require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Graphs" do
  before(:all) do
    @ex = Namespace.new("http://example.org/", "ex")
    @foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
  end
  
  subject { Graph.new }
  it "should allow you to add one or more triples" do
    lambda do
      subject.add_triple(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new)
    end.should_not raise_error
  end
  
  it "should give you a list of resources of a particular type" do
    subject.add_triple(URIRef.new("http://example.org/joe"), URIRef.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), URIRef.new("http://xmlns.com/foaf/0.1/Person"))
    subject.add_triple(URIRef.new("http://example.org/jane"), URIRef.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), URIRef.new("http://xmlns.com/foaf/0.1/Person"))

    subject.get_by_type("http://xmlns.com/foaf/0.1/Person").size.should == 2
    subject.get_by_type("http://xmlns.com/foaf/0.1/Person")[0].to_s.should == "http://example.org/joe"
    subject.get_by_type("http://xmlns.com/foaf/0.1/Person")[1].to_s.should == "http://example.org/jane"
  end

  it "should support << as an alias for add_triple" do
    lambda do
      subject << Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new)
    end.should_not raise_error
    subject.size.should == 1
  end
  
  it "should return bnode subjects" do
    bn = BNode.new
    subject.add_triple bn, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new
    subject.subjects.should == [bn]
  end
  
  it "should be able to determine whether or not it has existing BNodes" do
    foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
    subject << Triple.new(BNode.new('john'), foaf.knows, BNode.new('jane'))
    subject.has_bnode_identifier?('john').should be_true
    subject.has_bnode_identifier?('jane').should be_true
    subject.has_bnode_identifier?('jack').should_not be_true
  end
  
  it "should be able to return BNodes on demand" do
    john = BNode.new('john')
    jane = BNode.new('jane')
    foaf = Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")
    subject << Triple.new(john, foaf.knows, jane)
    subject.get_bnode_by_identifier('john').should == john
    subject.get_bnode_by_identifier('jane').should == jane
    subject.get_bnode_by_identifier('barny').should == false
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
    pending
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
      a = BNode.new("a")
      b = BNode.new("b")
      
      g = Graph.new
      g << Triple.new(a, @foaf.name, Literal.untyped("Manu Sporny"))
      g << Triple.new(a, @foaf.knows, b)
      g << Triple.new(b, @foaf.name, Literal.untyped("Ralph Swick"))
      g.bind(@foaf)
      g
    }
    
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

    it "should tell you how large the graph is" do
      subject.size.should == 3
    end
  
    it "should return unique subjects" do
      subject.subjects.should == [@ex.john.uri.to_s, @ex.jane.uri.to_s]
    end
    
    it "should allow you to select one resource" do
      subject.get_resource(@ex.john).size.should == 2
    end

    it "should allow iteration" do
      count = 0
      subject.each do |t|
        count = count + 1
        t.class.should == Triple
      end
      count.should == 3
    end

    it "should allow iteration over a particular subject" do
      count = 0
      subject.each_with_subject(@ex.john) do |t|
        count = count + 1
        t.class.should == Triple
      end
      count.should == 2
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

  describe "which are joined" do
    it "should be able to integrate another graph" do
      subject.add_triple(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new)
      g = Graph.new
      g.join(subject)
      g.size.should == 1
    end
    
    it "should not join with non graph" do
      lambda do
        h.join("")
      end.should raise_error
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
  end
end
