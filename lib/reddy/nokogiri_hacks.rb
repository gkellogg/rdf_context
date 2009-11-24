require 'nokogiri'
class Nokogiri::XML::Node
  # URI of namespace + node_name
  def uri
    URIRef.new(self.namespace.href + self.node_name)
  end
end