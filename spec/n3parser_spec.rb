require File.join(File.dirname(__FILE__), 'spec_helper')
include Reddy

describe "N3 parser" do
  before(:each) { @parser = N3Parser.new(:strict => true) }
  
  describe "parse simple ntriples" do
    it "should parse simple triple" do
      n3_string = "<http://example.org/> <http://xmlns.com/foaf/0.1/name> \"Tom Morris\" . "
      @parser.parse(n3_string)
      @parser.graph[0].subject.to_s.should == "http://example.org/"
      @parser.graph[0].predicate.to_s.should == "http://xmlns.com/foaf/0.1/name"
      @parser.graph[0].object.to_s.should == "Tom Morris"
      @parser.graph.size.should == 1
    end

    # NTriple tests from http://www.w3.org/2000/10/rdf-tests/rdfcore/ntriples/test.nt
    describe "recognize blank lines" do
      {
        "comment"                   => "# comment lines",
        "comment after whitespace"  => "            # comment after whitespace",
        "empty line"                => "",
        "line with spaces"          => "      "
      }.each_pair do |name, statement|
        specify "test #{name}" do
          @parser.parse(statement)
          @parser.graph.size.should == 0
        end
      end
    end

    it "should create named subject bnode" do
      @parser.parse("_:anon <http://example.org/property> <http://example.org/resource2> .")
      @parser.graph.should_not be_nil
      @parser.graph.size.should == 1
      triple = @parser.graph[0]
      triple.subject.should be_a(BNode)
      triple.subject.identifier.should =~ /anon/
      triple.predicate.should == "http://example.org/property"
      triple.object.should == "http://example.org/resource2"
    end

    it "should create named object bnode" do
      @parser.parse("<http://example.org/resource2> <http://example.org/property> _:anon .")
      @parser.graph.should_not be_nil
      @parser.graph.size.should == 1
      triple = @parser.graph[0]
      triple.subject.should == "http://example.org/resource2"
      triple.predicate.should == "http://example.org/property"
      triple.object.should be_a(BNode)
      triple.object.identifier.should =~ /anon/
    end

    {
      "three uris"  => "<http://example.org/resource1> <http://example.org/property> <http://example.org/resource2> .",
      "spaces and tabs throughout" => " 	 <http://example.org/resource3> 	 <http://example.org/property>	 <http://example.org/resource2> 	.	 ",
      "line ending with CR NL" => "<http://example.org/resource4> <http://example.org/property> <http://example.org/resource2> .\r\n",
      "literal escapes (1)" => '<http://example.org/resource7> <http://example.org/property> "simple literal" .',
      "literal escapes (2)" => '<http://example.org/resource8> <http://example.org/property> "backslash:\\\\" .',
      "literal escapes (3)" => '<http://example.org/resource9> <http://example.org/property> "dquote:\"" .',
      "literal escapes (4)" => '<http://example.org/resource10> <http://example.org/property> "newline:\n" .',
      "literal escapes (5)" => '<http://example.org/resource11> <http://example.org/property> "return:\r" .',
      "literal escapes (6)" => '<http://example.org/resource12> <http://example.org/property> "tab:\t" .',
      "Space is optional before final . (1)" => ['<http://example.org/resource13> <http://example.org/property> <http://example.org/resource2>.', '<http://example.org/resource13> <http://example.org/property> <http://example.org/resource2> .'],
      "Space is optional before final . (2)" => ['<http://example.org/resource14> <http://example.org/property> "x".', '<http://example.org/resource14> <http://example.org/property> "x" .'],

      "XML Literals as Datatyped Literals (1)" => '<http://example.org/resource21> <http://example.org/property> ""^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (2)" => '<http://example.org/resource22> <http://example.org/property> " "^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (3)" => '<http://example.org/resource23> <http://example.org/property> "x"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (4)" => '<http://example.org/resource23> <http://example.org/property> "\""^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (5)" => '<http://example.org/resource24> <http://example.org/property> "<a></a>"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (6)" => '<http://example.org/resource25> <http://example.org/property> "a <b></b>"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (7)" => '<http://example.org/resource26> <http://example.org/property> "a <b></b> c"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (8)" => '<http://example.org/resource26> <http://example.org/property> "a\n<b></b>\nc"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      "XML Literals as Datatyped Literals (9)" => '<http://example.org/resource27> <http://example.org/property> "chat"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .',
      
      "Plain literals with languages (1)" => '<http://example.org/resource30> <http://example.org/property> "chat"@fr .',
      "Plain literals with languages (2)" => '<http://example.org/resource31> <http://example.org/property> "chat"@en .',
      
      "Typed Literals" => '<http://example.org/resource32> <http://example.org/property> "abc"^^<http://example.org/datatype1> .',
    }.each_pair do |name, statement|
      specify "test #{name}" do
        @parser.parse([statement].flatten.first)
        @parser.graph.should_not be_nil
        @parser.graph.size.should == 1
        #puts @parser.graph[0].to_ntriples
        @parser.graph[0].to_ntriples.should == [statement].flatten.last.gsub(/\s+/, " ").strip
      end
    end
  end
  
  describe "literal encodings" do
    {
      'Dürst' => '_:a <http://example.org/named> "D\u00FCrst" .',
      'simple literal' => '<http://example.org/resource7> <http://example.org/property> "simple literal" .',
      'backslash:\\' => '<http://example.org/resource8> <http://example.org/property> "backslash:\\\\" .',
      'dquote:"' => '<http://example.org/resource9> <http://example.org/property> "dquote:\"" .',
      "newline:\n" => '<http://example.org/resource10> <http://example.org/property> "newline:\n" .',
      "return\r" => '<http://example.org/resource11> <http://example.org/property> "return\r" .',
      "tab:\t" => '<http://example.org/resource12> <http://example.org/property> "tab:\t" .',
      "é" => '<http://example.org/resource16> <http://example.org/property> "\u00E9" .',
      "€" => '<http://example.org/resource17> <http://example.org/property> "\u20AC" .',
    }.each_pair do |contents, triple|
      specify "test #{contents}" do
        @parser.parse(triple)
        @parser.graph.should_not be_nil
        @parser.graph.size.should == 1
        @parser.graph[0].object.contents.should == contents
      end
    end
  end
  
  # n3p tests taken from http://inamidst.com/n3p/test/
  describe "parsing n3p test" do
   dir_name = File.join(File.dirname(__FILE__), '..', 'test', 'n3_tests', 'n3p', '*.n3')
    Dir.glob(dir_name).each do |n3|    
      it n3 do
        test_file(n3)
      end
    end
  end
  
  describe "parsing real data tests" do
    dirs = [ 'misc', 'lcsh' ]
    dirs.each do |dir|
      dir_name = File.join(File.dirname(__FILE__), '..', 'test', 'n3_tests', dir, '*.n3')
      Dir.glob(dir_name).each do |n3|
        it "#{dir} #{n3}" do
          test_file(n3)
        end
      end
    end
  end
  
  it "should throw an exception when presented with a BNode as a predicate" do
    n3doc = "_:a _:b _:c ."
    lambda { @parser.parse(n3doc) }.should raise_error(Reddy::Triple::InvalidPredicate)
  end

  it "should create BNodes" do
    n3doc = "_:a a _:c ."
    @parser.parse(n3doc)
    @parser.graph[0].subject.class.should == Reddy::BNode
    @parser.graph[0].object.class.should == Reddy::BNode
  end
  
  it "should create URIRefs" do
    n3doc = "<http://example.org/joe> <http://xmlns.com/foaf/0.1/knows> <http://example.org/jane> ."
    @parser.parse(n3doc)
    @parser.graph[0].subject.class.should == Reddy::URIRef
    @parser.graph[0].object.class.should == Reddy::URIRef
  end
  
  it "should create literals" do
    n3doc = "<http://example.org/joe> <http://xmlns.com/foaf/0.1/name> \"Joe\"."
    @parser.parse(n3doc)
    @parser.graph[0].object.class.should == Reddy::Literal
  end
  
  it "should create typed literals" do
    n3doc = "<http://example.org/joe> <http://xmlns.com/foaf/0.1/name> \"Joe\"^^<http://www.w3.org/2001/XMLSchema#string> ."
    @parser.parse(n3doc)
    @parser.graph[0].object.class.should == Reddy::Literal
  end
  
  it "should map <#> to document uri" do
    n3doc = "@prefix : <#> ."
    @parser.parse(n3doc, "http://the.document.itself")
    @parser.graph.nsbinding.should == {"__local__", Namespace.new("http://the.document.itself", "__local__")}
  end

  it "should parse testcase" do
    sampledoc = <<-EOF;
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#PositiveParserTest> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#approval> <http://lists.w3.org/Archives/Public/w3c-rdfcore-wg/2002Mar/0235.html> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#inputDocument> <http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/test001.rdf> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#issue> <http://www.w3.org/2000/03/rdf-tracking/#rdfms-xml-base> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#outputDocument> <http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/test001.nt> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/Manifest.rdf#test001> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#status> "APPROVED" .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/test001.nt> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#NT-Document> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/xmlbase/test001.rdf> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema#RDF-XML-Document> .
EOF
    @parser.parse(sampledoc, "http://www.w3.org/2000/10/rdf-tests/rdfcore/amp-in-url/Manifest.rdf")
    ntriples = @parser.graph.to_ntriples
    ntriples = sort_ntriples(ntriples)

    nt_string = sort_ntriples(sampledoc)
    ntriples.should == nt_string    
  end
  
  def test_file(filepath)
    n3_string = File.read(filepath)
    @parser.parse(n3_string, "file:#{filepath}")
    ntriples = @parser.graph.to_ntriples
    ntriples.gsub!(/_\:named_*/, '_:')
    ntriples = sort_ntriples(ntriples)

    nt_string = File.read(filepath.sub('.n3', '.nt'))
    nt_string = sort_ntriples(nt_string)

    ntriples.should == nt_string    
  end
  
  def sort_ntriples(string)
    string.split("\n").sort.join("\n")
  end

end
