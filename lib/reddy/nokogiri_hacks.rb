require 'nokogiri'
class Nokogiri::XML::Node
  # URI of namespace + node_name
  def uri
    ns = self.namespace ? self.namespace.href : XML_NS.uri.to_s
    URIRef.new(ns + self.node_name)
  end
end