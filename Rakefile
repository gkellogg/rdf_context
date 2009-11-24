require 'rubygems'
begin
  gem 'jeweler'
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "reddy"
    gemspec.summary = "RDFa parser written in pure Ruby."
    gemspec.description = " Yields each triple, or generate in-memory graph"
    gemspec.email = "gregg@kellogg-assoc.com"
    gemspec.homepage = "http://github.com/tommorris/reddy"
    gemspec.authors = ["Tom Morris", "Gregg Kellogg"]
    gemspec.add_dependency('addressable', '>= 2.0.0')
    gemspec.add_dependency('treetop',  '>= 1.4.0')
    gemspec.add_dependency('libxml-ruby',  '>= 0.8.3')
    gemspec.add_dependency('whatlanguage', '>= 1.0.0')
    gemspec.add_dependency('nokogiri', '>= 1.3.3')
    gemspec.add_dependency('builder', '>= 2.1.2')
    gemspec.add_development_dependency('rspec')
    gemspec.add_development_dependency('activesupport', '>= 2.3.0')
    gemspec.extra_rdoc_files     = %w(README.rdoc History.txt)
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

# TODO - want other tests/tasks run by default? Add them to the list
#task :default => [:spec, :features]

desc "Pushes to git"
task :push do
  sh "git push --all"
  sh "growlnotify -m \"Updates pushed\" \"Git\""
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

desc "Turns spec results into HTML and publish to web (Tom only!)"
task :spec_html do
  sh "spec --format html:reddy_new_spec.html spec"
  sh "scp reddy_new_spec.html bbcityco@bbcity.co.uk:www/tom/files/rena_new_spec.html"
  sh "rm reddy_new_spec.html"
end

desc "Turns spec results into local HTML"
task :spec_local do
  sh "spec --format html:reddy_new_spec.html spec/"
#  sh "open reddy_new_spec.html"
end

desc "Run specs through RCov"
Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

desc "Runs specs on JRuby"
task :jspec do
  sh "jruby -S `whereis spec` --colour spec"
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = RdfaParser::VERSION
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rdfa_parser #{version}"
  rdoc.rdoc_files.include('README*', "History.txt")
  rdoc.rdoc_files.include('lib/**/*.rb')
end

# vim: syntax=Ruby
