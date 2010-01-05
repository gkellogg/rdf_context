$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

begin
  require 'nokogiri'
  require 'addressable/uri'
  require 'builder'
  require 'treetop'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'nokogiri'
  gem 'addressable'
  require 'nokogiri'
  require 'addressable/uri'
  require 'builder'
  require 'treetop'
end

Dir.glob(File.join(File.dirname(__FILE__), 'rdf_context/**.rb')).sort.each { |f| require f }

# Include Storage types, but be tollerant of failure to load as dependencies might not be available
Dir.glob(File.join(File.dirname(__FILE__), "rdf_context/store/**.rb")).each do |f|
  begin
    require f
  rescue LoadError
    puts "Error loading #{f}: #{$!}"
  end
end

module RdfContext
  VERSION = File.read(File.join(File.dirname(__FILE__), "..", "VERSION")).chop  # Version in parent directory
  
  LINK_TYPES = %w(
    alternate appendix bookmark cite chapter contents copyright first glossary
    help icon index last license meta next p3pv1 prev role section stylesheet subsection
    start top up
  )

  NC_REGEXP = Regexp.new(
    %{^
      (?!\\\\u0301)             # &#x301; is a non-spacing acute accent.
                                # It is legal within an XML Name, but not as the first character.
      (  [a-zA-Z_]
       | \\\\u[0-9a-fA-F]
      )
      (  [0-9a-zA-Z_\.-]
       | \\\\u([0-9a-fA-F]{4})  # \u followed by a sequence of four hex digits
      )*
    $},
    Regexp::EXTENDED)

  RDF_TYPE    = URIRef.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
  XML_LITERAL = Literal::Encoding.xmlliteral

  RDF_NS      = Namespace.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#", "rdf")
  RDFS_NS     = Namespace.new("http://www.w3.org/2000/01/rdf-schema#", "rdfs")
  XHV_NS      = Namespace.new("http://www.w3.org/1999/xhtml/vocab#", "xhv")
  XML_NS      = Namespace.new("http://www.w3.org/XML/1998/namespace", "xml")

  XH_MAPPING  = {"" => Namespace.new("http://www.w3.org/1999/xhtml/vocab\#", nil)}
end
