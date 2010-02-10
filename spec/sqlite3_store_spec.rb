require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), 'store_helper')

describe "SQLite3 Store" do
  before(:all) do
    Dir.mkdir(File.dirname(__FILE__) + "/tmp")
    @dbfile = File.join(File.dirname(__FILE__), "tmp", "sqlite3.db")
    @identifier = URIRef.new("http://identifier")
  end
  
  before(:each) do
    @store = SQLite3Store.new(@identifier, :path => @dbfile)
  end
  
  after(:all) do
    FileUtils.rm_rf(File.dirname(__FILE__) + "/tmp")
  end
  
  after(:each) do
    FileUtils.rm(@dbfile) if File.exists?(@dbfile)
  end
  
  subject { @store }
  it_should_behave_like "Store"
  it_should_behave_like "Context Aware Store"

  it "should destroy DB file" do
    subject.destroy
    File.exists?(@dbfile).should be_false
  end

  it "should close db" do
    subject.close
  end
  
  it "should find contexts with type" do
    triple = Triple.new("http://foo", RDF_TYPE, "http://baz")
    subject.add(triple, nil)
    subject.contexts(triple).length.should == 1
  end
  
  it "should find triples with typed literal" do
    triple = Triple.new("http://foo", RDF_TYPE, Literal.build_from(1.1))
    subject.add(triple, nil)
    subject.contexts(triple).length.should == 1
  end
  
  it "should find triples with untyped literal and lang" do
    triple = Triple.new("http://foo", RDF_TYPE, Literal.untyped("foo", "en-US"))
    subject.add(triple, nil)
    subject.contexts(triple).length.should == 1
  end
  
  it "should find contexts pattern triple" do
    triple = Triple.new("http://foo", RDF_TYPE, "http://baz")
    subject.add(triple, nil)
    subject.contexts(Triple.new(nil, nil, nil)).length.should == 1
  end
end
