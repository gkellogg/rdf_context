module Reddy
  # A simple graph to hold triples.
  #
  # Graphs store triples, and the namespaces associated with those triples, where defined
  class Graph
    attr_accessor :triples, :nsbinding, :identifier, :store
    attr_accessor :next_generated, :named_nodes

    # Create a Graph with the given store_type and identifier.
    #
    # The constructor accepts a _store_ option,
    # that will be used to store the graph data.
    #
    # Stores can be context-aware or unaware.  Unaware stores take up
    # (some) less space but cannot support features that require
    # context, such as true merging/demerging of sub-graphs and
    # provenance.
    #
    # The Graph constructor can take an identifier which identifies the Graph
    # by name.  If none is given, the graph is assigned a BNode for it's identifier.
    # For more on named graphs, see: http://en.wikipedia.org/wiki/RDFLib
    #
    # @param [Hash] options:: Options
    # <em>options[:store]</em>:: storage, defaults to a new ListStore instance
    # <em>options[:identifier]</em>:: Identifier for this graph, Literal, BNode or URIRef
    #
    # @author Gregg Kellogg
    def initialize(options = {})
      options[:store] ||= ListStore.new
      @nsbinding = {}

      # For BNode identifier generation
      @next_generated = "a"
      @named_nodes = {}
      
      @identifier = options[:identifier] || BNode.new(self)

      # Instantiate triple store
      @store = options[:store] || ListStore.new(self)
    end

    def context_aware?; @context_aware; end
    
    # Data Store interface

    # Destroy the store identified by _configuration_ if supported
    def destroy(configuration = nil)
      @store.destroy(configuration)
      self.freeze
    end

    # Commit changes to graph
    def commit; @store.commit; end

    # Rollback active transactions
    def rollback; @store.rollback; end

    # Open the graph store
    #
    # Might be necessary for stores that require opening a connection to a
    # database or acquiring some resource.
    def open(configuration, create=false)
      @store.open(configuration, create)
    end

    # Close the graph store
    #
    # Might be necessary for stores that require closing a connection to a
    # database or releasing some resource.
    def close(commit_pending_transaction=false)
      @store.open(commit_pending_transaction)
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
      triples.collect do |t|
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
      raise GraphException, "Can't bind #{namespace.inspect} as namespace" unless namespace.is_a?(Namespace)
      @nsbinding["#{namespace.prefix}"] = namespace
    end

    # Number of Triples in the graph
    def size
      @store.respond_to?(:size) ? @store.size(self) : triples.size
    end

    # List of distinct subjects in graph
    def subjects
      @store.respond_to?(:subjects) ? @store.subjects(self) : triples.map {|t| t.subject}.uniq
    end
    
    # List of distinct predicates in graph
    def predicates
      @store.respond_to?(:predicates) ? @store.predicates(self) : triples.map {|t| t.predicate}.uniq
    end
    
    # List of distinct objects in graph
    def objects
      @store.respond_to?(:objects) ? @store.objects(self) : triples.map {|t| t.object}.uniq
    end
    
    # Indexed statement in serialized graph triples. Equivalent to graph.triples[item] 
    def [] (item)
      @store.respond_to?(:item) ? @store.item(item, self) : triples[item]
    end

    # Adds a triple to a graph directly from the intended subject, predicate, and object.
    #
    # ==== Example
    #   g = Graph.new; g.add_triple(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new) # => results in the triple being added to g; returns an array of g's triples
    #
    # @param [URIRef, BNode] subject:: the subject of the triple
    # @param [URIRef] predicate:: the predicate of the triple
    # @param [URIRef, BNode, Literal] object:: the object of the triple
    # @return [Graph]:: Returns the graph
    # @raise [Error]:: Checks parameter types and raises if they are incorrect.
    def add_triple(subject, predicate, object)
      self << Triple.new(subject, predicate, object)
      self
    end

    ## 
    # Adds an more extant triples to a graph. Delegates to Store.
    #
    # ==== Example
    #   g = Graph.new;
    #   t = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new);
    #   g << t
    #
    # @param [Triple] t:: the triple to be added to the graph
    # @return [Graph]:: Returns the graph
    def << (triple)
      @store.add_triple(triple, self)
      self
    end
    
    ## 
    # Adds one or more extant triples to a graph. Delegates to Store.
    #
    # ==== Example
    #   g = Graph.new;
    #   t1 = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new);
    #   t2 = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new);
    #   g.add_triples(t1, t2, ...)
    #
    # @param [Triple] triples:: one or more triples. Last element may be a hash for options
    # <em>options[:context]</em>:: Graph context in which to deposit triples, defaults to default_context or self
    # @return [Graph]:: Returns the graph
    def add_triples(*triples)
      triples.last.is_a?(Hash) ? options = triples.pop : {}
      ctx = options[:context] || @default_context || self
      triples.each {|t| @store.add_triple(t, ctx)}
      self
    end
    
    # Remove a triple from the graph. Delegates to store.
    # Nil matches all triples and thus empties the graph
    def remove(triple); @store.remove(triple, self); end
    
    # Triples from graph, optionally matching subject, predicate, or object.
    # Delegates to Store#triples.
    #
    # @param [Hash] options:: List of options for matching triples
    # <em>options[:subject]</em>:: If specified, limited to triples having the specified subject
    # <em>options[:predicate]</em>:: If specified, limited to triples having the specified predicate
    # <em>options[:object]</em>:: If specified, limited to triples having the specified object. May be a Regexp
    # @return [Array]:: List of matched triples
    def triples(options = {}, &block) # :yields: triple
      @store.triples(options.merge(:context => self), &block) || []
    end
    alias_method :find, :triples

    # Detect the presence of a BNode in the graph, either as a subject or an object
    #
    # @param [BNode, String] bn:: BNode or identifier to find
    #
    def has_bnode_identifier?(bn)
      bn = bnode(bn) unless bn.is_a?(BNode)
      triples do |triple|
        return true if triple.subject.eql?(bn) || triple.object.eql?(bn)
      end
      false
    end

    # Check to see if this graph contains the specified triple
    def contains?(triple)
      @store.contains?(triple, self)
    end
    
    # Get all BNodes with usage count used within graph
    def bnodes
      if @store.respond_to?(:bnodes?)
        @store.bnodes(self)
      else
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
    
    # Two graphs are equal if each is an instance of the other, considering BNode equivalence.
    # This is done by creating a new graph an substituting each permutation of BNode identifiers
    # from self to other until every permutation is exhausted, or a textual equivalence is found
    # after sorting each graph.
    #
    # We just follow Python RDFlib's lead and do a simple comparison
    def eql? (other)
      #puts "eql? size #{self.size} vs #{other.size}"
      return false if !other.is_a?(Graph) || self.size != other.size
      bn_self = bnodes.values.sort
      bn_other = other.bnodes.values.sort
      #puts "eql? bnodes '#{bn_self.to_sentence}' vs '#{bn_other.to_sentence}'"
      return false unless bn_self == bn_other
      
      # Check each triple to see if it's contained in the other graph
      triples do |t|
        next if t.subject.is_a?(BNode) || t.object.is_a?(BNode)
        #puts "eql? contains '#{t.to_ntriples}'"
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
  
  # Parse source into Graph.
  #
  # If Graph is context-aware, create a new context (Graph) and parse into that. Otherwise,
  # merges results into a common Graph
  #
  # @param  [IO, String] stream:: the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
  # @param [String] uri:: the URI of the document
  # @param [Hash] options:: Options from
  # <em>options[:debug]</em>:: Array to place debug messages
  # <em>options[:type]</em>:: One of _rdfxml_, _html_, or _n3_
  # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
  #
  # @author Gregg Kellogg
  def parse(stream, uri, options = {}, &block) # :yields: triple
    Parser.parse(stream, uri, options.merge(:graph => self), &block)
  end
end
