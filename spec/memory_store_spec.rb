$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), 'store_helper')

describe "Memory Store" do
  before(:all) do
    @identifier = URIRef.new("http://identifier")
  end
  
  subject { MemoryStore.new(@identifier) }
  it_should_behave_like "Store"
  it_should_behave_like "Context Aware Store"
end
