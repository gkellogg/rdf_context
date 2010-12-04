require 'rubygems'
require 'yard'

begin
  gem 'jeweler'
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "rdf_context"
    gemspec.summary = "RdfContext is an RDF library for Ruby supporting contextual graphs, multiple datastores and compliant RDF/XML, RDFa and N3 parsers."
    gemspec.description = <<-DESCRIPTION
    RdfContext parses RDF/XML, RDFa and N3-rdf into a Graph object. It also serializes RDF/XML and N-Triples from the Graph.

      * Fully compliant RDF/XML parser.
      * Fully compliant XHTML/RDFa 1.0 parser.
      * N3-rdf parser
      * N-Triples and RDF/XML serializer
      * Graph serializes into RDF/XML and N-Triples.
      * ConjunctiveGraph, named Graphs and contextual storage modules.
    
    Install with 'gem install rdf_context'
    DESCRIPTION
    gemspec.email = "gregg@kellogg-assoc.com"
    gemspec.homepage = "http://github.com/gkellogg/rdf_context"
    gemspec.authors = ["Gregg Kellogg"]
    gemspec.add_dependency('addressable', '>= 2.2.0')
    gemspec.add_dependency('treetop',  '>= 1.4.0')
    gemspec.add_dependency('nokogiri', '>= 1.4.3')
    gemspec.add_dependency('builder', '>= 2.1.2')
    gemspec.add_development_dependency('rspec', '>= 2.1.0')
    gemspec.add_development_dependency('activesupport', '>= 2.3.0')
    gemspec.add_development_dependency('yard')
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

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
end

desc "Generate HTML report specs"
RSpec::Core::RakeTask.new("spec") do |spec|
  spec.rspec_opts = ["--format", "html:doc/spec.html"]
end

task :spec => :check_dependencies

task :default => :spec

desc "Update N3 grammar"
task :grammar do
  sh "tt -o lib/rdf_context/n3_grammar.rb lib/rdf_context/n3_grammar.treetop"
end

namespace :doc do
  require 'rake/rdoctask'
  Rake::RDocTask.new("rdoc") do |rdoc|
    if File.exist?('VERSION')
      version = File.read('VERSION')
    else
      version = RdfContext::VERSION
    end

    rdoc.rdoc_dir = 'doc/rdoc'
    rdoc.title = "rdf_context #{version}"
    rdoc.rdoc_files.include('README*', "History.rdoc")
    rdoc.rdoc_files.include('lib/**/*.rb')
  end

  YARD::Rake::YardocTask.new do |t|
    t.files   = %w(lib/**/*.rb README.rdoc History.rdoc)   # optional
  end
end

desc "Generate RDF Core Manifest.yml"
namespace :spec do
  task :prepare do
    $:.unshift(File.join(File.dirname(__FILE__), 'lib'))
    $:.unshift(File.join(File.dirname(__FILE__), 'spec'))
    require 'rdf_context'
    require 'rdfa_helper'
    require 'rdf_helper'
    require 'fileutils'

    %w(xhtml xhtml11 html4 html5).each do |suite|
      yaml = manifest_file = File.join(File.dirname(__FILE__), "spec", "#{suite}-manifest.yml")
      FileUtils.rm_f(yaml)
      RdfaHelper::TestCase.to_yaml(suite, yaml)
    end

    yaml = File.join(RDFCORE_DIR, "Manifest.yml")
    FileUtils.rm_f(yaml)
    RdfHelper::TestCase.to_yaml(RDFCORE_TEST, RDFCORE_DIR, yaml)

    yaml = File.join(SWAP_DIR, "n3parser.yml")
    FileUtils.rm_f(yaml)
    RdfHelper::TestCase.to_yaml(SWAP_TEST, SWAP_DIR, yaml)
    
    yaml = File.join(SWAP_DIR, "regression.yml")
    FileUtils.rm_f(yaml)
    RdfHelper::TestCase.to_yaml(CWM_TEST, SWAP_DIR, yaml)
    
    yaml = File.join(TURTLE_DIR, "manifest.yml")
    FileUtils.rm_f(yaml)
    RdfHelper::TestCase.to_yaml(TURTLE_TEST, TURTLE_DIR, yaml)
    
    yaml = File.join(TURTLE_DIR, "manifest-bad.yml")
    FileUtils.rm_f(yaml)
    RdfHelper::TestCase.to_yaml(TURTLE_BAD_TEST, TURTLE_DIR, yaml)
  end
end

