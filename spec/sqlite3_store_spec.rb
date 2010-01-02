require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), 'store_helper')

describe "SQLite3 Store" do
  before(:all) do
    Dir.mkdir(File.dirname(__FILE__) + "/tmp")
    @dbfile = File.join(File.dirname(__FILE__), "tmp", "sqlite3.db")
    @identifier = URIRef.new("http://identifier")
    @ctx = @identifier
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

  describe "with context" do
    before(:all) do
        @ctx = URIRef.new("http://context")
    end

    it_should_behave_like "Store"
    it_should_behave_like "Context Aware Store"
  end
end
