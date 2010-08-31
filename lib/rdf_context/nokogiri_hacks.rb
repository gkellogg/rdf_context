require 'nokogiri'
class Nokogiri::XML::Node
  # URI of namespace + node_name
  def uri
    ns = self.namespace ? self.namespace.href : RdfContext::XML_NS.uri.to_s
    RdfContext::URIRef.new(ns + self.node_name, :normalize => false)
  end
  def display_path
    @display_path ||= case self
    when Nokogiri::XML::Document then ""
    when Nokogiri::XML::Element then parent ? "#{parent.display_path}/#{name}" : name
    when Nokogiri::XML::Attr then "#{parent.display_path}@#{name}"
    end
  end
end