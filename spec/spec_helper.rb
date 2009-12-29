begin
  require 'spec'
  require 'active_support'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rspec'
  require 'spec'
  gem 'active_support'
  require 'active_support'
end

ActiveSupport::XmlMini.backend = 'Nokogiri'

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)
require 'reddy'
require 'matchers'

include Reddy

Spec::Runner.configure do |config|
  config.include(Matchers)
end
