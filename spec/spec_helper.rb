begin
  require 'spec'
  require 'activesupport'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rspec'
  require 'spec'
  gem 'activesupport'
  require 'activesupport'
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
