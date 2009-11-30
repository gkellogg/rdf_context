module Reddy
  # A simple graph to hold triples.
  #
  # Graphs store triples, and the namespaces associated with those triples, where defined
  class Graph
    attr_accessor :triples, :nsbinding, :identifier
    attr_accessor :next_generated, :named_nodes

    # Create a Graph with the given store_type and identifier.
    #
    # The constructor accepts one argument, the 'store'
    # that will be used to store the graph data (see the 'store'
    # package for stores currently shipped with rdflib).
    #
    # Stores can be context-aware or unaware.  Unaware stores take up
    # (some) less space but cannot support features that require
    # context, such as true merging/demerging of sub-graphs and
    # provenance.
    #
    # The Graph constructor can take an identifier which identifies the Graph
    # by name.  If none is given, the graph is assigned a BNode for it's identifier.
    # For more on named graphs, see: http://www.w3.org/2004/03/trix/
    #
    # @param [Hash] options:: Options
    # <em>options[:store_type]</em>:: storage type, currently only <tt>:memory</tt> is supported
    # <em>options[:identifier]</em>:: Identifier for this graph, Literal, BNode or URIRef
    #
    # @author Gregg Kellogg
    def initialize(options = {})
      @triples = []
      @nsbinding = {}

      # For BNode identifier generation
      @next_generated = "a"
      @named_nodes = {}
      
      @identifier = options[:identifier] || BNode.new(self)
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
      self << Triple.new(subject, predicate, object)
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
      @triples << triple unless contains?(triple)
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
      bn = bnode(bn) unless bn.is_a?(BNode)
      triples do |triple|
        return true if triple.subject.eql?(bn) || triple.object.eql?(bn)
      end
      false
    end

    # Check to see if this graph contains the specified triple
    def contains?(triple)
      triples {|t| return true if t == triple}
      false
    end
    
    # Get all BNodes with usage count used within graph
    def bnodes
      bn = {}
      triples do |t|
        if t.subject.is_a?(BNode)
          bn[t.subject] ||= 0
          bn[t.subject] += 1
        end
        if t.object.is_a?(BNode)
          bn[t.object] ||= 0
          bn[t.object] += 1
        end
      end
      bn
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
      
      # Map BNodes from source Graph to new BNodes
      bn = graph.bnodes
      bn.keys.each {|k| bn[k] = self.bnode}
      
      graph.triples do |triple|
        # If triple contains bnodes, remap to new values
        if triple.subject.is_a?(BNode) || triple.object.is_a?(BNode)
          triple = triple.clone
          triple.subject = bn[triple.subject] if triple.subject.is_a?(BNode)
          triple.object = bn[triple.object] if triple.object.is_a?(BNode)
        end
        self << triple
      end
    end
    
    # Clone the graph, including cloning each triple
    def clone
      g = Graph.new
      triples {|t| g << t.clone}
    end

    # Two graphs are equal if each is an instance of the other, considering BNode equivalence.
    # This is done by creating a new graph an substituting each permutation of BNode identifiers
    # from self to other until every permutation is exhausted, or a textual equivalence is found
    # after sorting each graph.
    #
    # We just follow Python librdf's lead and do a simple comparison
    def eql? (other)
      return false if !other.is_a?(Graph) || self.size != other.size
      bn_self = bnodes.values.sort
      bn_other = other.bnodes.values.sort
      return false unless bn_self == bn_other
      
      # Check each triple to see if it's contained in the other graph
      triples do |t|
        next if t.subject.is_a?(BNode) || t.object.is_a?(BNode)
        return false unless other.contains?(t)
      end
      true
    end

    alias_method :==, :eql?
  end
  
  # Generate a BNode in this graph
  def bnode(id = nil)
    BNode.new(self, id)
  end
end
