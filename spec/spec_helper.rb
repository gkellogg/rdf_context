$:.unshift "#{File.dirname(__FILE__)}/../lib"
$:.unshift "#{File.dirname(__FILE__)}"
require 'reddy'
require 'ruby-debug'
require 'matchers'

Spec::Runner.configure do |config|
  config.include(Matchers)
end