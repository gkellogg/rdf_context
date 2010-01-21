require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Literals: " do
  describe "an untyped string" do
    subject {Literal.untyped("tom")}
    it "should be equal if they have the same contents" do should == Literal.untyped("tom") end
    it "should not be equal if they do not have the same contents" do should_not == Literal.untyped("tim") end
    it "should match a string" do should == "tom" end
    it "should return a string using to_s" do subject.to_s.should == "tom" end
    
    it "should infer type" do
      other = Literal.build_from("foo")
      other.encoding.should == "http://www.w3.org/2001/XMLSchema#string"
    end
    
    describe "should handle specific cases" do
      {
        '"Gregg"' => Literal.untyped("Gregg"),
        '"\u677E\u672C \u540E\u5B50"' => Literal.untyped("松本 后子"),
        '"D\u00FCrst"' => Literal.untyped("Dürst")
      }.each_pair do |encoded, literal|
        it "should encode '#{literal.contents}'" do
          literal.to_n3.should == encoded
        end
      end
    end

    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"tom\"" end
      it "should return ntriples" do subject.to_ntriples.should == "\"tom\"" end
      it "should return xml_args" do subject.xml_args.should == ["tom", {}] end
      it "should return TriX" do subject.to_trix.should == "<plainLiteral>tom</plainLiteral>" end
    end

    describe "with extended characters" do
      subject { Literal.untyped("松本 后子") }
      
      describe "encodings" do
        it "should return n3" do subject.to_n3.should == '"\u677E\u672C \u540E\u5B50"' end
        it "should return ntriples" do subject.to_ntriples.should == '"\u677E\u672C \u540E\u5B50"' end
        it "should return xml_args" do subject.xml_args.should == ["松本 后子", {}] end
        it "should return TriX" do subject.to_trix.should == "<plainLiteral>" + "松本 后子" + "</plainLiteral>" end
      end
    end
    
    describe "with a language" do
      subject { Literal.untyped("tom", "en") }

      it "should accept a language tag" do
        subject.lang.should == "en"
      end
  
      it "should be equal if they have the same contents and language" do
        should == Literal.untyped("tom", "en")
      end
  
      it "should not be equal if they do not have the same contents" do
        should_not == Literal.untyped("tim", "en")
      end
    
      it "should not be equal if they do not have the same language" do
        should_not == Literal.untyped("tom", "fr")
      end

      describe "encodings" do
        it "should return n3" do subject.to_n3.should == "\"tom\"@en" end
        it "should return ntriples" do subject.to_ntriples.should == "\"tom\"@en" end
        it "should return xml_args" do subject.xml_args.should == ["tom", {"xml:lang" => "en"}] end
        it "should return TriX" do subject.to_trix.should == "<plainLiteral xml:lang=\"en\">tom</plainLiteral>" end
      end

      it "should normalize language tags to lower case" do
        f = Literal.untyped("tom", "EN")
        f.lang.should == "en"
      end
    end
  end
  
  describe "a typed string" do
    subject { Literal.typed("tom", "http://www.w3.org/2001/XMLSchema#string") }
    
    it "accepts an encoding" do
      subject.encoding.to_s.should == "http://www.w3.org/2001/XMLSchema#string"
    end

    it "should be equal if they have the same contents and datatype" do
      should == Literal.typed("tom", "http://www.w3.org/2001/XMLSchema#string")
    end

    it "should not be equal if they do not have the same contents" do
      should_not == Literal.typed("tim", "http://www.w3.org/2001/XMLSchema#string")
    end

    it "should not be equal if they do not have the same datatype" do
      should_not == Literal.typed("tom", "http://www.w3.org/2001/XMLSchema#token")
    end

    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"tom\"^^<http://www.w3.org/2001/XMLSchema#string>" end
      it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
      it "should return xml_args" do subject.xml_args.should == ["tom", {"rdf:datatype" => "http://www.w3.org/2001/XMLSchema#string"}] end
      it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/2001/XMLSchema#string\">tom</typedLiteral>" end
    end
  end
  
  describe "a boolean" do
    subject { Literal.typed(true, "http://www.w3.org/2001/XMLSchema#boolean") }
    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"true\"^^<http://www.w3.org/2001/XMLSchema#boolean>" end
      it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
      it "should return xml_args" do subject.xml_args.should == ["true", {"rdf:datatype" => "http://www.w3.org/2001/XMLSchema#boolean"}] end
      it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/2001/XMLSchema#boolean\">true</typedLiteral>" end
    end

    it "should infer type" do
      int = Literal.build_from(true)
      int.encoding.should == "http://www.w3.org/2001/XMLSchema#boolean"
    end

    it "should have string contents" do subject.contents.should == "true" end
    it "should have native contents" do subject.to_native.should == true end
    it "should coerce 1" do Literal.typed("1", XSD_NS.boolean).contents.should == "true" end
    it "should coerce 1" do Literal.typed("0", XSD_NS.boolean).contents.should == "false" end
  end
    
  describe "an integer" do
    subject { Literal.typed(5, "http://www.w3.org/2001/XMLSchema#int") }
    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"5\"^^<http://www.w3.org/2001/XMLSchema#int>" end
      it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
      it "should return xml_args" do subject.xml_args.should == ["5", {"rdf:datatype" => "http://www.w3.org/2001/XMLSchema#int"}] end
      it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/2001/XMLSchema#int\">5</typedLiteral>" end
    end

    it "should infer type" do
      int = Literal.build_from(15)
      int.encoding.should == "http://www.w3.org/2001/XMLSchema#int"
    end

    it "should have string contents" do subject.contents.should == "5" end
    it "should have native contents" do subject.to_native.should == 5 end
  end
    
  describe "a float" do
    subject { Literal.typed(15.4, "http://www.w3.org/2001/XMLSchema#float") }
    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"15.4\"^^<http://www.w3.org/2001/XMLSchema#float>" end
      it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
      it "should return xml_args" do subject.xml_args.should == ["15.4", {"rdf:datatype" => "http://www.w3.org/2001/XMLSchema#float"}] end
      it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/2001/XMLSchema#float\">15.4</typedLiteral>" end
    end

    it "should infer type" do
      float = Literal.build_from(15.4)
      float.encoding.should == "http://www.w3.org/2001/XMLSchema#float"
    end

    it "should have string contents" do subject.contents.should == "15.4" end
    it "should have native contents" do subject.to_native.should == 15.4 end
  end

  describe "a date" do
    before(:each) { @value = Date.parse("2010-01-02Z") }
    subject { Literal.typed(@value, "http://www.w3.org/2001/XMLSchema#date") }
    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"2010-01-02Z\"^^<http://www.w3.org/2001/XMLSchema#date>" end
      it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
      it "should return xml_args" do subject.xml_args.should == ["2010-01-02Z", {"rdf:datatype" => "http://www.w3.org/2001/XMLSchema#date"}] end
      it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/2001/XMLSchema#date\">2010-01-02Z</typedLiteral>" end
    end

    it "should infer type" do
      int = Literal.build_from(@value)
      int.encoding.should == "http://www.w3.org/2001/XMLSchema#date"
    end

    it "should have string contents" do subject.contents.should == "2010-01-02Z" end
    it "should have native contents" do subject.to_native.should ==  @value end
  end
  
  describe "a dateTime" do
    before(:each) { @value = DateTime.parse('2010-01-03T01:02:03Z') }
    subject { Literal.typed(@value, "http://www.w3.org/2001/XMLSchema#dateTime") }
    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"2010-01-03T01:02:03Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>" end
      it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
      it "should return xml_args" do subject.xml_args.should == ["2010-01-03T01:02:03Z", {"rdf:datatype" => "http://www.w3.org/2001/XMLSchema#dateTime"}] end
      it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/2001/XMLSchema#dateTime\">2010-01-03T01:02:03Z</typedLiteral>" end
    end
    
    it "should infer type" do
      int = Literal.build_from(@value)
      int.encoding.should == "http://www.w3.org/2001/XMLSchema#dateTime"
    end

    it "should have string contents" do subject.contents.should == "2010-01-03T01:02:03Z" end
    it "should have native contents" do subject.to_native.should ==  @value end
  end
  
  describe "a time" do
    before(:each) { @value = Time.parse('01:02:03Z') }
    subject { Literal.typed(@value, "http://www.w3.org/2001/XMLSchema#time") }
    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"01:02:03Z\"^^<http://www.w3.org/2001/XMLSchema#time>" end
      it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
      it "should return xml_args" do subject.xml_args.should == ["01:02:03Z", {"rdf:datatype" => "http://www.w3.org/2001/XMLSchema#time"}] end
      it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/2001/XMLSchema#time\">01:02:03Z</typedLiteral>" end
    end
    
    it "should infer type" do
      int = Literal.build_from(@value)
      int.encoding.should == "http://www.w3.org/2001/XMLSchema#time"
    end

    it "should have string contents" do subject.contents.should == "01:02:03Z" end
    it "should have native contents" do subject.to_native.should ==  @value end
  end
  
  describe "a duration" do
    before(:each) { @value = Duration.parse('-P1111Y11M23DT4H55M16.666S') }
    subject { Literal.typed(@value, "http://www.w3.org/2001/XMLSchema#duration") }
    describe "encodings" do
      it "should return n3" do subject.to_n3.should == "\"-P1111Y11M23DT4H55M16.666S\"^^<http://www.w3.org/2001/XMLSchema#duration>" end
      it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
      it "should return xml_args" do subject.xml_args.should == ["-P1111Y11M23DT4H55M16.666S", {"rdf:datatype" => "http://www.w3.org/2001/XMLSchema#duration"}] end
      it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/2001/XMLSchema#duration\">-P1111Y11M23DT4H55M16.666S</typedLiteral>" end
    end
    
    it "should infer type" do
      int = Literal.build_from(@value)
      int.encoding.should == "http://www.w3.org/2001/XMLSchema#duration"
    end

    it "should have string contents" do subject.contents.should == "-P1111Y11M23DT4H55M16.666S" end
    it "should have native contents" do subject.to_native.should ==  @value end
  end
  
  describe "XML Literal" do
    describe "with no namespace" do
      subject { Literal.typed("foo <sup>bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral") }
      it "should indicate xmlliteral?" do
        subject.xmlliteral?.should == true
      end
      
      describe "encodings" do
        it "should return n3" do subject.to_n3.should == "\"foo <sup>bar</sup> baz!\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>" end
        it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
        it "should return xml_args" do subject.xml_args.should == ["foo <sup>bar</sup> baz!", {"rdf:parseType" => "Literal"}] end
        it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral\">foo <sup>bar</sup> baz!</typedLiteral>" end
      end
      
      it "should be equal if they have the same contents" do
        should == Literal.typed("foo <sup>bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")
      end

      it "should be a XMLLiteral encoding" do
        subject.encoding.should == "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral"
      end
    end
      
    describe "with a namespace" do
      subject {
        Literal.typed("foo <sup>bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral",
                      :namespaces => {"dc" => Namespace.new("http://purl.org/dc/elements/1.1/", "dc")})
      }
    
      describe "encodings" do
        it "should return n3" do subject.to_n3.should == "\"foo <sup>bar</sup> baz!\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>" end
        it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
        it "should return xml_args" do subject.xml_args.should == ["foo <sup>bar</sup> baz!", {"rdf:parseType" => "Literal"}] end
        it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral\">foo <sup>bar</sup> baz!</typedLiteral>" end
      end
      
      describe "and language" do
        subject {
          Literal.typed("foo <sup>bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral",
                        :namespaces => {"dc" => Namespace.new("http://purl.org/dc/elements/1.1/", "dc")},
                        :language => "fr")
        }

        describe "encodings" do
          it "should return n3" do subject.to_n3.should == "\"foo <sup xml:lang=\\\"fr\\\">bar</sup> baz!\"\^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>" end
          it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
          it "should return xml_args" do subject.xml_args.should == ["foo <sup xml:lang=\"fr\">bar</sup> baz!", {"rdf:parseType" => "Literal"}] end
          it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral\">foo <sup xml:lang=\"fr\">bar</sup> baz!</typedLiteral>" end
        end
      end
      
      describe "and language with an existing language embedded" do
        subject {
          Literal.typed("foo <sup>bar</sup><sub xml:lang=\"en\">baz</sub>",
                        "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral",
                        :language => "fr")
        }

        describe "encodings" do
          it "should return n3" do subject.to_n3.should == "\"foo <sup xml:lang=\\\"fr\\\">bar</sup><sub xml:lang=\\\"en\\\">baz</sub>\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>" end
          it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
          it "should return xml_args" do subject.xml_args.should == ["foo <sup xml:lang=\"fr\">bar</sup><sub xml:lang=\"en\">baz</sub>", {"rdf:parseType" => "Literal"}] end
          it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral\">foo <sup xml:lang=\"fr\">bar</sup><sub xml:lang=\"en\">baz</sub></typedLiteral>" end
        end
      end
      
      describe "and namespaced element" do
        subject {
          root = Nokogiri::XML.parse(%(
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
          <html xmlns="http://www.w3.org/1999/xhtml"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
          	  xmlns:ex="http://example.org/rdf/"
          	  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
          	  xmlns:svg="http://www.w3.org/2000/svg">
          	<head profile="http://www.w3.org/1999/xhtml/vocab http://www.w3.org/2005/10/profile">
          		<title>Test 0100</title>
          	</head>
            <body>
            	<div about="http://www.example.org">
                <h2 property="ex:example" datatype="rdf:XMLLiteral"><svg:svg/></h2>
          	</div>
            </body>
          </html>
          ), nil, nil, Nokogiri::XML::ParseOptions::DEFAULT_XML).root
          content = root.css("h2").children
          Literal.typed(content,
                        "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral",
                        :namespaces => {
                          "svg" => Namespace.new("http://www.w3.org/2000/svg", "svg"),
                          "dc" => Namespace.new("http://purl.org/dc/elements/1.1/", "dc")
                        })
        }
        it "should return xml_args" do subject.xml_args.should == ["<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"></svg:svg>", {"rdf:parseType" => "Literal"}] end
      end
      
      describe "and existing namespace definition" do
        subject {
          Literal.typed("<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"/>",
                        "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral",
                        :namespaces => {"svg" => Namespace.new("http://www.w3.org/2000/svg", "svg")})
        }
        it "should return xml_args" do subject.xml_args.should == ["<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"></svg:svg>", {"rdf:parseType" => "Literal"}] end
      end
    end
      
    describe "with a default namespace" do
      subject {
        Literal.typed("foo <sup>bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral",
                      :namespaces => {"" => Namespace.new("http://purl.org/dc/elements/1.1/", "")})
      }
    
      describe "encodings" do
        it "should return n3" do subject.to_n3.should == "\"foo <sup xmlns=\\\"http://purl.org/dc/elements/1.1/\\\">bar</sup> baz!\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>" end
        it "should return ntriples" do subject.to_ntriples.should == subject.to_n3 end
        it "should return xml_args" do subject.xml_args.should == ["foo <sup xmlns=\"http://purl.org/dc/elements/1.1/\">bar</sup> baz!", {"rdf:parseType" => "Literal"}] end
        it "should return TriX" do subject.to_trix.should == "<typedLiteral datatype=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral\">foo <sup xmlns=\"http://purl.org/dc/elements/1.1/\">bar</sup> baz!</typedLiteral>" end
      end
    end
    
    describe "with multiple namespaces" do
      subject {
        Literal.typed("foo <sup <sup xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")
      }
      it "should ignore namespace order" do
        g = Literal.typed("foo <sup <sup xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")
        should == g
      end
    end
    
    describe "with multiple attributes" do
      it "should ignore attribute order" do
        f = Literal.typed("foo <sup a=\"a\" b=\"b\">bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")
        g = Literal.typed("foo <sup b=\"b\" a=\"a\">bar</sup> baz!", "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")
        f.should == g
      end
    end
  end
  
  describe "an n3 literal" do
    {
      "Gregg" => ['Gregg', nil, nil],
      "Dürst" => ['D\u00FCrst', nil, nil],
      "simple literal"  => ['simple literal', nil, nil],
      "backslash:\\" => ['backslash:\\\\', nil, nil],
      "dquote:\"" => ['dquote:\\"', nil, nil],
      "newline:\n" => ['newline:\\n', nil, nil],
      "return:\r" => ['return:\\r', nil, nil],
      "tab:\t" => ['tab:\\t', nil, nil],
    }.each_pair do |name, args|
      specify "test #{name}" do
        Literal.n3_encoded(*args).contents.should == name
      end
    end
  end
  
  describe "Encodings" do
    specify "integer" do
      Literal::Encoding.integer.should == Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#int")
    end
    specify "float" do
      Literal::Encoding.float.should == Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#float")
    end
    specify "string" do
      Literal::Encoding.string.should == Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#string")
    end
    specify "date" do
      Literal::Encoding.date.should == Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#date")
    end
    specify "date time" do
      Literal::Encoding.datetime.should == Literal::Encoding.new("http://www.w3.org/2001/XMLSchema#dateTime")
    end
    specify "xmlliteral" do
      Literal::Encoding.xmlliteral.should == Literal::XMLLiteral.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")
    end
    specify "null" do
      Literal::Encoding.the_null_encoding.should == Literal::Null.new(nil)
    end
  end
  
end
