require File.join(File.dirname(__FILE__), 'spec_helper')
describe "String RDF encoding" do
  {
    "Gregg" => 'Gregg',
    "Dürst" => 'D\u00FCrst',
    "simple literal"  => 'simple literal',
    "backslash:\\" => 'backslash:\\\\',
    "dquote:\"" => 'dquote:\\"',
    "newline:\n" => 'newline:\\n',
    "return:\r" => 'return:\\r',
    "tab:\t" => 'tab:\\t',
  }.each_pair do |raw, encoded|
    specify "'#{raw}' should escape to '#{encoded}'" do
      raw.rdf_escape.should == encoded
    end

    specify "'#{encoded}' should unescape to '#{raw}'" do
      encoded.rdf_unescape.should == raw
    end
  end
end