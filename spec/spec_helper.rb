# coding: utf-8
require 'rubygems' unless ENV['NO_RUBYGEMS']
require 'rspec'
gem 'activesupport', "~> 2.3.8"
require 'active_support'

begin
  require 'rdf/redland'
  $redland_enabled = true
rescue LoadError
end


ActiveSupport::XmlMini.backend = 'Nokogiri'

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)
require 'rdf_context'
require 'matchers'

include RdfContext

TMP_DIR = File.join(File.dirname(__FILE__), 'tmp')

include Matchers

RSpec.configure do |c|
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
  c.exclusion_filter = {
    :ruby => lambda { |version| !(RUBY_VERSION.to_s =~ /^#{version.to_s}/) },
  }
  c.include(Matchers)
end
