module Reddy
  # A simple graph to hold triples.
  #
  # Graphs store triples, and the namespaces associated with those triples, where defined
  class Graph
    attr_accessor :triples, :nsbinding, :name

    # Create a Graph with the given type, name and options
    #
    # @param [Hash] options:: Options
    # <em>options[:store_type]</em>:: storage type, currently only <tt>:memory</tt> is supported
    # <em>options[:name]</em>:: Name for this graph
    def initialize(options = {})
      @triples = []
      @nsbinding = {}
      @name = options[:name]
    end

    # Number of Triples in the graph
    def size
      @triples.size
    end

    # List of distinct subjects in graph
    def subjects
      @triples.map {|t| t.subject}.uniq
    end
    
    # List of distinct predicates in graph
    def predicates
      @triples.map {|t| t.predicate}.uniq
    end
    
    # List of distinct objects in graph
    def objects
      @triples.map {|t| t.object}.uniq
    end
    
    # Indexed statement in serialized graph triples. Equivalent to graph.triples[item] 
    def [] (item)
      @triples[item]
    end

    ## 
    # Adds a triple to a graph directly from the intended subject, predicate, and object.
    #
    # ==== Example
    #   g = Graph.new; g.add_triple(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new) # => results in the triple being added to g; returns an array of g's triples
    #
    # @param [URIRef, BNode] subject:: the subject of the triple
    # @param [URIRef] predicate:: the predicate of the triple
    # @param [URIRef, BNode, Literal] object:: the object of the triple
    # @return [Array]:: An array of the triples (leaky abstraction? consider returning the graph instead)
    # @raise [Error]:: Checks parameter types and raises if they are incorrect.
    #
    # @author Tom Morris
    def add_triple(subject, predicate, object)
      @triples += [ Triple.new(subject, predicate, object) ]
    end

    ## 
    # Adds an extant triple to a graph
    #
    # ==== Example
    #   g = Graph.new; t = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new); g << t) # => results in the triple being added to g; returns an array of g's triples
    #
    # @param [Triple] t:: the triple to be added to the graph
    # @return [Array]:: An array of the triples (leaky abstraction? consider returning the graph instead)
    #
    # @author Tom Morris
    def << (triple)
      @triples << triple
    end
    
    ## 
    # Exports the graph to RDF in N-Triples form.
    #
    # ==== Example
    #   g = Graph.new; g.add_triple(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new); g.to_ntriples  # => returns a string of the graph in N-Triples form
    #
    # @return [String]:: The graph in N-Triples.
    #
    # @author Tom Morris
    def to_ntriples
      @triples.collect do |t|
        t.to_ntriples
      end * "\n" + "\n"
    end
    
    # Output graph using to_ntriples
    def to_s; self.to_ntriples; end

    ## 
    # Exports the graph to RDF in RDF/XML form.
    #
    # @return [String]:: The RDF/XML graph
    #
    # @author Gregg Kellogg
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
      uri_bindings = extended_bindings.values.inject({}) { |hash, ns| hash.merge(ns.uri.to_s => ns.prefix)}
      xml.instruct!
      xml.rdf(:RDF, rdf_attrs) do
        # Add statements for each subject
        subjects.each do |s|
          xml.rdf(:Description, (s.is_a?(BNode) ? "rdf:nodeID" : "rdf:about") => s) do
            triples(:subject => s) do |triple|
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
    # Creates a new namespace given a URI and the prefix and binds it to the graph.
    #
    # ==== Example
    #   g = Graph.new; g.namespace("http://xmlns.com/foaf/0.1/", "foaf") # => binds the Foaf namespace to g
    #
    # @param [String] uri:: the URI of the namespace
    # @param [String] prefix:: the prefix name of the namespace
    # @return [Namespace]:: The newly created namespace.
    # @raise [Error]:: Checks validity of the desired shortname and raises if it is incorrect.
    # @raise [Error]:: Checks that the newly created Namespace is of type Namespace and raises if it is incorrect.
    # @author Tom Morris
    def namespace(uri, prefix)
      self.bind(Namespace.new(uri, prefix))
    end

    # Bind a namespace to the graph
    def bind(namespace)
      if namespace.class == Namespace
        @nsbinding["#{namespace.prefix}"] = namespace
      else
        raise GraphException, "Can't bind #{namespace.inspect} as namespace"
      end
    end

    # Triples from graph, optionally matching subject, predicate, or object
    #
    # ==== Example
    #
    #
    # @param [Hash] options:: List of options for matching triples
    # <em>options[:subject]</em>:: If specified, limited to triples having the specified subject
    # <em>options[:predicate]</em>:: If specified, limited to triples having the specified predicate
    # <em>options[:object]</em>:: If specified, limited to triples having the specified object. May be a Regexp
    # @return [Array]:: List of matched triples
    #
    # @author Gregg Kellogg
    def triples(options = {})
      subject = options[:subject]
      predicate = options[:predicate]
      object = options[:object]
      if subject || predicate || object
        @triples.select do |triple|
          next if subject && triple.subject != subject
          next if predicate && triple.predicate != predicate
          case object
          when Regexp
            next unless object.match(triple.object.to_s)
          when URIRef, BNode, Literal, String
            next unless triple.object == object
          end
            
          yield triple if block_given?
          triple
        end.compact
      elsif block_given?
        @triples.each {|triple| yield triple}
      else
        @triples
      end
    end
    alias_method :find, :triples

    # Detect the presence of a BNode in the graph, either as a subject or an object
    #
    # @param [BNode, String] bn:: BNode or identifier to find
    def has_bnode_identifier?(bn)
      bn = BNode.new(bn) unless bn.is_a?(BNode)
      triples do |triple|
        return true if triple.subject.eql?(bn) || triple.object.eql?(bn)
      end
      false
    end

    # Get list of subjects having rdf:type == object
    #
    # @param [Resource, Regexp, String] object:: Type resource
    def get_by_type(object)
      triples(:predicate => RDF_TYPE, :object => object).map {|t| t.subject}
    end
    
    # Merge a graph into this graph
    def merge!(graph)
      raise GraphException.new("merge without a graph") unless graph.is_a?(Graph)
      @triples += graph.triples
    end
  end
end
