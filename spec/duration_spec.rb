$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
describe "Duration" do
  it "should create from Hash" do
    Duration.new(:seconds => 10, :minutes => 1).to_i.should == 70
  end

  it "should create from Duration" do
    d = Duration.new(:seconds => 10, :minutes => 1)
    Duration.new(d).to_i.should == 70
  end
  it "should create from Numeric" do
    Duration.new(70.2).to_i.should == 70
    Duration.new(70.2).to_f.should == 70.2
  end
  
  it "should create from Integer string" do
    Duration.new("70").to_f.should == 70
  end
  
  it "should parse formatted string" do
    Duration.parse('-P1111Y11M23DT4H55M16.666S').to_i.should == -34587060916
  end
  
  describe "normalization" do
  end
  
  describe "output format" do
    subject { Duration.parse('P1111Y11M23DT4H55M16.666S') }
    
    it "should output xml" do
      subject.to_s(:xml).should == "P1111Y11M23DT4H55M16.666S"
    end
    
    it "should output human readable" do
      subject.to_s.should == "1111 years, 11 months, 23 days, 4 hours, 55 minutes and 16.666 seconds"
    end
    
    it "should output integer" do
      subject.to_i.should == 34587060916
    end
    
    it "should output float" do
      subject.to_f.should == 34587060916.666
    end
  end
end
