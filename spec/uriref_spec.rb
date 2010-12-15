# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'webrick'
include WEBrick
#require 'lib/uriref'

describe URIRef do
  it "should output NTriples" do
    f = URIRef.new("http://tommorris.org/foaf/")
    f.to_ntriples.should == "<http://tommorris.org/foaf/>"
  end
  
  it "should handle Unicode symbols inside URLs" do
    lambda do
      f = URIRef.new("http://example.org/#Andr%E9")
    end.should_not raise_error
  end
  
  it "should return the 'last fragment' name" do
    fragment = URIRef.new("http://example.org/foo#bar")
    fragment.short_name.should == "bar"
    
    path = URIRef.new("http://example.org/foo/bar")
    path.short_name.should == "bar"
    
    nonetest = URIRef.new("http://example.org/")
    nonetest.short_name.should == false
  end
  
  it "should append fragment to uri" do
    URIRef.new("foo", "http://example.org").should == "http://example.org/foo"
  end
  
  it "must not be a relative URI" do
    lambda do
      URIRef.new("foo")
    end.should raise_error
  end
  
  it "should allow another URIRef to be added" do
    uri = URIRef.new("http://example.org/") + "foo#bar"
    uri.to_s.should == "http://example.org/foo#bar"
    uri.class.should == URIRef
    
    uri2 = URIRef.new("http://example.org/") + Addressable::URI.parse("foo#bar")
    uri2.to_s.should == "http://example.org/foo#bar"
  end

  describe "descriminators" do
    subject { URIRef.new("http://example.org/") }

    it "returns false for bnode?" do
      subject.should_not be_bnode
    end
    it "returns false for graph?" do
      subject.should_not be_graph
    end
    it "returns false for literal?" do
      subject.should_not be_literal
    end
    it "returns true for uri?" do
      subject.should be_uri
    end
  end
  
  describe ".parse" do
    it "returns nil if invalid" do
      URIRef.parse("foo").should be_nil
    end

    it "returns URIRef for 'http://example.com/'" do
      URIRef.parse('http://example.com/').to_n3.should == '<http://example.com/>'
    end
    it "returns URIRef for '<http://example.com/>'" do
      URIRef.parse('<http://example.com/>').to_n3.should == '<http://example.com/>'
    end
  end
  
  describe "short_name" do
    specify { URIRef.new("http://foo/bar").short_name.should == "bar"}
    specify { URIRef.new("http://foo").short_name.should == false}
  end
  
  describe "base" do
    specify { URIRef.new("http://foo/bar").base.should == "http://foo/"}
    specify { URIRef.new("http://foo/").base.should == "http://foo/"}
    specify { URIRef.new("http://foo").base.should == "http://foo"}
  end
  
  describe "QName" do
    it "should find with trailing /" do
      ex = Namespace.new("http://example.org/foo/", "ex")
      ex.bar.to_qname(ex.uri.to_s => ex).should == "ex:bar"
    end

    it "should find with trailing #" do
      ex = Namespace.new("http://example.org/foo#", "ex")
      ex.bar.to_qname(ex.uri.to_s => ex).should == "ex:bar"
    end

    it "should find with trailing word" do
      ex = Namespace.new("http://example.org/foo", "ex")
      ex.bar.to_qname(ex.uri.to_s => ex).should == "ex:bar"
    end
  end
  
  describe "namespace" do
    it "should find with trailing /" do
      ex = Namespace.new("http://example.org/foo/", "ex")
      ex.bar.namespace(ex.uri.to_s => ex).should == ex
    end

    it "should find with trailing #" do
      ex = Namespace.new("http://example.org/foo#", "ex")
      ex2 = ex.bar.namespace(ex.uri.to_s => ex)
      ex.bar.namespace(ex.uri.to_s => ex).should == ex
    end

    it "should find with trailing word" do
      ex = Namespace.new("http://example.org/foo", "ex")
      ex.bar.namespace(ex.uri.to_s => ex).should == ex
    end
  end
  
  describe "utf-8 escaped" do
    {
      %(http://a/D%C3%BCrst)                => %("http://a/D%C3%BCrst"),
      %(http://a/D\u00FCrst)                => %("http://a/D\\\\u00FCrst"),
      %(http://b/Dürst)                     => %("http://b/D\\\\u00FCrst"),
      %(http://a/\u{15678}another) => %("http://a/\\\\U00015678another"),
    }.each_pair do |uri, dump|
      it "should dump #{uri} as #{dump}" do
        URIRef.new(uri).to_s.dump.should == dump
      end
    end
  end if defined?(::Encoding) # Only works properly in Ruby 1.9
  
  describe "join" do
    {
      %w(http://foo ) =>  "http://foo",
      %w(http://foo a) => "http://foo/a",
      %w(http://foo /a) => "http://foo/a",
      %w(http://foo #a) => "http://foo#a",

      %w(http://foo/ ) =>  "http://foo/",
      %w(http://foo/ a) => "http://foo/a",
      %w(http://foo/ /a) => "http://foo/a",
      %w(http://foo/ #a) => "http://foo/#a",

      %w(http://foo# ) =>  "http://foo#",
      %w(http://foo# a) => "http://foo/a",
      %w(http://foo# /a) => "http://foo/a",
      %w(http://foo# #a) => "http://foo#a",

      %w(http://foo/bar ) =>  "http://foo/bar",
      %w(http://foo/bar a) => "http://foo/a",
      %w(http://foo/bar /a) => "http://foo/a",
      %w(http://foo/bar #a) => "http://foo/bar#a",

      %w(http://foo/bar/ ) =>  "http://foo/bar/",
      %w(http://foo/bar/ a) => "http://foo/bar/a",
      %w(http://foo/bar/ /a) => "http://foo/a",
      %w(http://foo/bar/ #a) => "http://foo/bar/#a",

      %w(http://foo/bar# ) =>  "http://foo/bar#",
      %w(http://foo/bar# a) => "http://foo/a",
      %w(http://foo/bar# /a) => "http://foo/a",
      %w(http://foo/bar# #a) => "http://foo/bar#a",

      %w(http://foo/bar# #D%C3%BCrst) => "http://foo/bar#D%C3%BCrst",
      %w(http://foo/bar# #Dürst) => "http://foo/bar#D\\u00FCrst",
    }.each_pair do |input, result|
      it "should create <#{result}> from <#{input[0]}> and '#{input[1]}'" do
        URIRef.new(input[1], input[0], :normalize => false).to_s.should == result
      end
    end
  end
  
  it "should create resource hash for RDF/XML" do
    uri = URIRef.new("http://example.org/foo#bar")
    uri.xml_args.should == [{"rdf:resource" => uri.to_s}]
  end
  
  it "should be equivalent to string" do
    URIRef.new("http://example.org/foo#bar").should == "http://example.org/foo#bar"
  end
end
