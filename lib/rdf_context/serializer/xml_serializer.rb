require File.join(File.dirname(__FILE__), 'abstract_serializer')

module RdfContext
  # Serialize RDF graphs in NTriples format
  class XmlSerializer < AbstractSerializer
    def serialize(stream, base = nil)
      replace_text = {}
      rdfxml = ""
      xml = builder = Builder::XmlMarkup.new(:target => rdfxml, :indent => 2)

      extended_bindings = @graph.nsbinding.merge(
        "rdf"   => RDF_NS,
        "rdfs"  => RDFS_NS,
        "xhv"   => XHV_NS,
        "xml"   => XML_NS
      )
      rdf_attrs = extended_bindings.values.inject({}) { |hash, ns| hash.merge(ns.xmlns_attr => ns.uri.to_s)}
      uri_bindings = @graph.uri_binding.merge(
        RDF_NS.uri.to_s => RDF_NS,
        RDFS_NS.uri.to_s => RDFS_NS,
        XHV_NS.uri.to_s => XHV_NS,
        XML_NS.uri.to_s => XML_NS
      )
      
      # Add bindings for predicates not already having bindings
      tmp_ns = "ns0"
      @graph.predicates.each do |p|
        raise "Attempt to serialize graph containing non-strict RDF compiant BNode as predicate" unless p.is_a?(URIRef)
        if !p.namespace(uri_bindings)
          uri_bindings[p.base] = Namespace.new(p.base, tmp_ns)
          rdf_attrs["xmlns:#{tmp_ns}"] = p.base
          tmp_ns = tmp_ns.succ
        end
      end

      xml.instruct!
      xml.rdf(:RDF, rdf_attrs) do
        # Add statements for each subject
        @graph.subjects.each do |s|
          xml.rdf(:Description, (s.is_a?(BNode) ? "rdf:nodeID" : "rdf:about") => s) do
            @graph.triples(Triple.new(s, nil, nil)) do |triple, context|
              xml_args = triple.object.xml_args
              qname = triple.predicate.to_qname(uri_bindings)
              if triple.object.is_a?(Literal) && triple.object.xmlliteral?
                replace_text["__replace_with_#{triple.object.object_id}__"] = xml_args[0]
                xml_args[0] = "__replace_with_#{triple.object.object_id}__"
              end
              xml.tag!(qname, *xml_args)
            end
          end
        end
      end

      # Perform literal substitutions
      replace_text.each_pair do |match, value|
        rdfxml.sub!(match, value)
      end
      
      stream.write(rdfxml)
    end
  end
end