$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), 'store_helper')

describe ActiveRecordStore do
  before(:all) do
    FileUtils.rm_rf(TMP_DIR)
    Dir.mkdir(TMP_DIR)
    @dbfile = File.join(TMP_DIR, "sqlite3.db")
    @identifier = URIRef.new("http://identifier")
  end
  
  before(:each) do
    ActiveRecord::Base.establish_connection(
      :adapter  => 'sqlite3',
      :database => @dbfile)
    #::RdfContext::debug =true
    @store = ActiveRecordStore.new(@identifier)
    @store.setup
  end
  
  after(:all) do
    FileUtils.rm_rf(TMP_DIR)
  end
  
  after(:each) do
    FileUtils.rm(@dbfile) if File.file?(@dbfile)
  end
  
  subject { @store }
  it_should_behave_like "Store"
  it_should_behave_like "Context Aware Store"

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
