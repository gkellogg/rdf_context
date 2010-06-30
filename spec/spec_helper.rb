# coding: utf-8
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

Spec::Runner.configure do |config|
  config.include(Matchers)
end
