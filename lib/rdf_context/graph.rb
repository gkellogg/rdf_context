require File.join(File.dirname(__FILE__), 'store', 'list_store')
require File.join(File.dirname(__FILE__), 'store', 'memory_store')

module RdfContext
  # A simple graph to hold triples.
  #
  # Graphs store triples, and the namespaces associated with those triples, where defined
  class Graph
    attr_reader :triples
    attr_reader :nsbinding
    attr_reader :identifier
    attr_reader :store

    # Create a Graph with the given store and identifier.
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
    def initialize(options = {})
      @nsbinding = {}

      # Instantiate triple store
      @store = case options[:store]
      when AbstractStore  then options[:store]
      when :list_store    then ListStore.new
      when :memory_store  then MemoryStore.new
      else                     ListStore.new
      end
      
      @identifier = options[:identifier] || BNode.new
    end

    def inspect
      "#{self.class}[id=#{identifier},store=#{store.inspect}]"
    end
    
    # Hash of graph, based on graph type and identifier
    def hash
      [self.class.to_s, self.identifier].hash
    end
    
    def context_aware?; @context_aware; end
    
    # Data Store interface
    def nsbinding; @store.nsbinding; end

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
    def open(configuration = {})
      @store.open(configuration)
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
            triples(Triple.new(s, nil, nil)) do |triple, context|
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
    # Bind a namespace to the graph.
    #
    # ==== Example
    #   g = Graph.new; g.bind(Namespace.new("http://xmlns.com/foaf/0.1/", "foaf")) # => binds the Foaf namespace to g
    #
    # @param [String] namespace:: the namespace to bind
    # @return [Namespace]:: The newly bound or pre-existing namespace.
    def bind(namespace)
      raise GraphException, "Can't bind #{namespace.inspect} as namespace" unless namespace.is_a?(Namespace)
      @store.bind(namespace)
    end

    # Namespace for prefix
    def namespace(prefix); @store.namespace(prefix); end

    # Prefix for namespace
    def prefix(namespace); @store.prefix(namespace); end
    
    # Number of Triples in the graph
    def size; @store.size(self); end

    # List of distinct subjects in graph
    def subjects; @store.subjects(self); end
    
    # List of distinct predicates in graph
    def predicates; @store.predicates(self); end
    
    # List of distinct objects in graph
    def objects; @store.objects(self); end
    
    # Indexed statement in serialized graph triples. Equivalent to graph.triples[item] 
    def [] (item); @store.item(item, self); end

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
      self.add(Triple.new(subject, predicate, object))
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
      @store.add(triple, self)
      self
    end
    
    ## 
    # Adds one or more extant triples to a graph. Delegates to Store.
    #
    # ==== Example
    #   g = Graph.new;
    #   t1 = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new);
    #   t2 = Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new);
    #   g.add(t1, t2, ...)
    #
    # @param [Triple] triples:: one or more triples. Last element may be a hash for options
    # <em>options[:context]</em>:: Graph context in which to deposit triples, defaults to default_context or self
    # @return [Graph]:: Returns the graph
    def add(*triples)
      options = triples.last.is_a?(Hash) ? triples.pop : {}
      ctx = options[:context] || @default_context || self
      triples.each {|t| @store.add(t, ctx)}
      self
    end
    
    # Remove a triple from the graph. Delegates to store.
    # Nil matches all triples and thus empties the graph
    def remove(triple); @store.remove(triple, self); end
    
    # Triples from graph, optionally matching subject, predicate, or object.
    # Delegates to Store#triples.
    #
    # @param [Triple, nil] triple:: Triple to match, may be a patern triple or nil
    # @return [Array]:: List of matched triples
    def triples(triple = Triple.new(nil, nil, nil), &block) # :yields: triple, context
      @store.triples(triple, self, &block) || []
    end
    alias_method :find, :triples

    # Detect the presence of a BNode in the graph, either as a subject or an object
    #
    # @param [BNode] bn:: BNode to find
    #
    def has_bnode_identifier?(bn)
      triples do |triple, context|
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
      @store.bnodes(self)
    end
    
    # Get list of subjects having rdf:type == object
    #
    # @param [Resource, Regexp, String] object:: Type resource
    def get_by_type(object)
      triples(Triple.new(nil, RDF_TYPE, object)).map {|t, ctx| t.subject}
    end
    
    # Merge a graph into this graph
    def merge!(graph)
      raise GraphException.new("merge without a graph") unless graph.is_a?(Graph)
      
      # Map BNodes from source Graph to new BNodes
      bn = graph.bnodes
      bn.keys.each {|k| bn[k] = BNode.new}
      
      graph.triples do |triple, context|
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
    # This may be done by creating a new graph an substituting each permutation of BNode identifiers
    # from self to other until every permutation is exhausted, or a textual equivalence is found
    # after sorting each graph.
    #
    # We just follow Python RDFlib's lead and do a simple comparison
    def eql? (other)
      #puts "eql? size #{self.size} vs #{other.size}"
      return false if !other.is_a?(Graph) || self.size != other.size
      return false unless other.identifier.to_s == identifier.to_s
      
      bn_self = bnodes.values.sort
      bn_other = other.bnodes.values.sort
      #puts "eql? bnodes '#{bn_self.to_sentence}' vs '#{bn_other.to_sentence}'"
      return false unless bn_self == bn_other
      
      # Check each triple to see if it's contained in the other graph
      triples do |t, ctx|
        next if t.subject.is_a?(BNode) || t.object.is_a?(BNode)
        #puts "eql? contains '#{t.to_ntriples}'"
        return false unless other.contains?(t)
      end
      true
    end

    alias_method :==, :eql?
  end
  
  # Parse source into Graph.
  #
  # Merges results into a common Graph
  #
  # @param  [IO, String] stream:: the RDF IO stream, string, Nokogiri::HTML::Document or Nokogiri::XML::Document
  # @param [String] uri:: the URI of the document
  # @param [Hash] options:: Options from
  # <em>options[:debug]</em>:: Array to place debug messages
  # <em>options[:type]</em>:: One of _rdfxml_, _html_, or _n3_
  # <em>options[:strict]</em>:: Raise Error if true, continue with lax parsing, otherwise
  # @return [Graph]:: Returns the graph containing parsed triples
  def parse(stream, uri, options = {}, &block) # :yields: triple
    Parser.parse(stream, uri, options.merge(:graph => self), &block)
  end
end
