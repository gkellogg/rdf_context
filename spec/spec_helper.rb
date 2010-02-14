begin
  require 'spec'
  require 'active_support'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rspec'
  require 'spec'
  gem 'activesupport'
  require 'active_support'
end

ActiveSupport::XmlMini.backend = 'Nokogiri'

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)
require 'rdf_context'
require 'matchers'

include RdfContext

SWAP_DIR = File.join(File.dirname(__FILE__), 'swap_test')
SWAP_TEST = "http://www.w3.org/2000/10/swap/test/n3parser.tests"
CWM_TEST = "http://www.w3.org/2000/10/swap/test/regression.n3"

RDFCORE_DIR = File.join(File.dirname(__FILE__), 'rdfcore')
RDFCORE_TEST = "http://www.w3.org/2000/10/rdf-tests/rdfcore/Manifest.rdf"

Spec::Runner.configure do |config|
  config.include(Matchers)
end
