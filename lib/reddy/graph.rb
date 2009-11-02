module Reddy
  # A simple graph to hold triples (from Reddy)
  class Graph
    attr_accessor :triples, :nsbinding

    def initialize
      @triples = []
      @nsbinding = {}
    end

    def self.load (uri)
      RdfXmlParser.new(open(uri)).graph
    end

    def size
      @triples.size
    end

    def each
      @triples.each { |value| yield value }
    end
    
    def subjects
      @triples.map {|t| t.subject}.uniq
    end
    
    def [] (item)
      @triples[item]
    end

    def each_with_subject(subject)
      @triples.each do |value|
        yield value if value.subject == subject
      end
    end

    def get_resource(subject)
      @triples.find_all { |i| true if i.subject == subject}
    end

    ## 
    # Adds a triple to a graph directly from the intended subject, predicate, and object.
    #
    # ==== Example
    #   g = Graph.new; g.add_triple(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new) # => results in the triple being added to g; returns an array of g's triples
    #
    # @param [URIRef, BNode] s the subject of the triple
    # @param [URIRef] p the predicate of the triple
    # @param [URIRef, BNode, Literal, TypedLiteral] o the object of the triple
    #
    # ==== Returns
    # @return [Array] An array of the triples (leaky abstraction? consider returning the graph instead)
    #
    # @raise [Error] Checks parameter types and raises if they are incorrect.
    # @author Tom Morris
    def add_triple(s, p, o)
      @triples += [ Triple.new(s, p, o) ]
    end


    ## 
    # Adds an extant triple to a graph
    #
    # ==== Example
    #   g = Graph.new; t = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new); g << t) # => results in the triple being added to g; returns an array of g's triples
    #
    # @param [Triple] t the triple to be added to the graph
    #
    # ==== Returns
    # @return [Array] An array of the triples (leaky abstraction? consider returning the graph instead)
    #
    # @author Tom Morris
    def << (triple)
  #    self.add_triple(s, p, o)
      @triples += [ triple ]
    end
    
    ## 
    # Exports the graph to RDF in N-Triples form.
    #
    # ==== Example
    #   g = Graph.new; g.add_triple(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new); g.to_ntriples  # => returns a string of the graph in N-Triples form
    #
    # ==== Returns
    # @return [String] The graph in N-Triples.
    #
    # @author Tom Morris

    def to_ntriples
      @triples.collect do |t|
        t.to_ntriples
      end * "\n" + "\n"
    end
    
    # Output graph using to_ntriples
    def to_s; self.to_ntriples; end

    # Dump model to RDF/XML
    def to_rdfxml
      replace_text = {}
      rdfxml = ""
      xml = builder = Builder::XmlMarkup.new(:target => rdfxml, :indent => 2)

      extended_bindings = nsbinding.merge(
        "rdf"   => RDF_NS,
        "rdfs"  => RDFS_NS,
        "xhv"   => XHV_NS,
        "xml"   => XML_NS
      )
      rdf_attrs = extended_bindings.values.inject({}) { |hash, ns| hash.merge(ns.xmlns_attr => ns.uri.to_s)}
      uri_bindings = extended_bindings.values.inject({}) { |hash, ns| hash.merge(ns.uri.to_s => ns.short)}
      xml.instruct!
      xml.rdf(:RDF, rdf_attrs) do
        # Add statements for each subject
        subjects.each do |s|
          xml.rdf(:Description, (s.is_a?(BNode) ? "rdf:nodeID" : "rdf:about") => s) do
            each_with_subject(s) do |triple|
              xml_args = triple.object.xml_args
              if triple.object.is_a?(Literal) && triple.object.xmlliteral?
                replace_text["__replace_with_#{triple.object.object_id}__"] = xml_args[0]
                xml_args[0] = "__replace_with_#{triple.object.object_id}__"
              end
              xml.tag!(triple.predicate.to_qname(uri_bindings), *xml_args)
            end
          end
        end
      end

      # Perform literal substitutions
      replace_text.each_pair do |match, value|
        rdfxml.sub!(match, value)
      end
      
      rdfxml
    end
    
    ## 
    # Creates a new namespace given a URI and the short name and binds it to the graph.
    #
    # ==== Example
    #   g = Graph.new; g.namespace("http://xmlns.com/foaf/0.1/", "foaf") # => binds the Foaf namespace to g
    #
    # @param [String] uri the URI of the namespace
    # @param [String] short the short name of the namespace
    #
    # ==== Returns
    # @return [Namespace] The newly created namespace.
    #
    # @raise [Error] Checks validity of the desired shortname and raises if it is incorrect.
    # @raise [Error] Checks that the newly created Namespace is of type Namespace and raises if it is incorrect.
    # @author Tom Morris

    def namespace(uri, short)
      self.bind Namespace.new(uri, short)
    end

    def bind(namespace)
      if namespace.class == Namespace
        @nsbinding["#{namespace.short}"] = namespace
      else
        raise GraphException, "Can't bind #{namespace.inspect} as namespace"
      end
    end

    def has_bnode_identifier?(bnodeid)
      temp_bnode = BNode.new(bnodeid)
      returnval = false
      @triples.each { |triple|
        if triple.subject.eql?(temp_bnode)
          returnval = true
          break
        end
        if triple.object.eql?(temp_bnode)
          returnval = true
          break
        end
      }
      return returnval
    end

    def get_bnode_by_identifier(bnodeid)
      temp_bnode = BNode.new(bnodeid)
      each do |triple|
        if triple.subject == temp_bnode
          return triple.subject
        end
        if triple.object == temp_bnode
          return triple.object
        end
      end
      return false
    end
    
    def get_by_type(object)
      out = []
      each do |t|
        next unless t.is_type?
        next unless case object
                    when String
                      object == t.object.to_s
                    when Regexp
                      object.match(t.object.to_s)
                    else
                      object == t.object
                    end
        out << t.subject
      end
      return out
    end
    
    def join(graph)
      if graph.class == Graph
        graph.each { |t| 
          self << t
        }
      else
        raise GraphException, "join requires you provide a graph object"
      end
    end

  end
end
