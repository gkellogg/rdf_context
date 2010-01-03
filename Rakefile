require 'rubygems'
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
    gemspec.add_dependency('addressable', '>= 2.0.0')
    gemspec.add_dependency('treetop',  '>= 1.4.0')
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

desc "Run specs through RCov"
Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
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
