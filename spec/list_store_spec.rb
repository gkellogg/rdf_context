$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), 'store_helper')

describe ListStore do
  before(:all) do
    @identifier = URIRef.new("http://identifier")
  end
  
  subject { ListStore.new(@identifier) }
  it_should_behave_like "Store"
end
