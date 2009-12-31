require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), 'store_helper')

describe "List Store" do
  before(:all) do
      @identifier = URIRef.new("http://identifier")
      @ctx = @identifier
  end
  
  subject { ListStore.new(@identifier) }
  it_should_behave_like "Store"
end
