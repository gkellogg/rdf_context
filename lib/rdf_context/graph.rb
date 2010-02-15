require File.join(File.dirname(__FILE__), 'namespace')
require File.join(File.dirname(__FILE__), 'triple')
require File.join(File.dirname(__FILE__), 'array_hacks')
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
    # <em>options[:store]</em>:: storage, defaults to a new ListStore instance. May be symbol :list_store or :memory_store
    # <em>options[:identifier]</em>:: Identifier for this graph, BNode or URIRef
    def initialize(options = {})
      @nsbinding = {}

      # Instantiate triple store
      @store = case options[:store]
      when AbstractStore  then options[:store]
      when :list_store    then ListStore.new
      when :memory_store  then MemoryStore.new
      else                     ListStore.new
      end
      
      @identifier = Triple.coerce_node(options[:identifier]) || BNode.new
    end

    def inspect
      "#{self.class}[id=#{identifier},store=#{store.inspect}]"
    end
    
    # Hash of graph, based on graph type and identifier
    def hash
      [self.class.to_s, self.identifier].hash
    end
    
    def context_aware?; @store.context_aware?; end
    
    # Data Store interface
    def nsbinding; @store.nsbinding; end

    # Destroy the store identified by _configuration_ if supported
    # If configuration is nil, remove the graph context
    def destroy(configuration = nil)
      if configuration
        @store.destroy(configuration)
      else
        @store.remove(Triple.new(nil, nil, nil), self)
      end
      
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
      uri_bindings = self.uri_binding.merge(
        RDF_NS.uri.to_s => RDF_NS,
        RDFS_NS.uri.to_s => RDFS_NS,
        XHV_NS.uri.to_s => XHV_NS,
        XML_NS.uri.to_s => XML_NS
      )
      
      # Add bindings for predicates not already having bindings
      tmp_ns = "ns0"
      predicates.each do |p|
        unless p.namespace(uri_bindings)
          uri_bindings[p.base] = Namespace.new(p.base, tmp_ns)
          rdf_attrs["xmlns:#{tmp_ns}"] = p.base
          tmp_ns = tmp_ns.succ
        end
      end

      xml.instruct!
      xml.rdf(:RDF, rdf_attrs) do
        # Add statements for each subject
        subjects.each do |s|
          xml.rdf(:Description, (s.is_a?(BNode) ? "rdf:nodeID" : "rdf:about") => s) do
            triples(Triple.new(s, nil, nil)) do |triple, context|
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

    # Hash of prefix => Namespace bindings
    def nsbinding; @store.nsbinding; end
    
    # Hash of uri => Namespace bindings
    def uri_binding; @store.uri_binding; end
    
    # QName for a URI
    def qname(uri)
      uri.to_qname(self.uri_binding)
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
    # @param [Triple, nil] triple:: Triple to match, may be a pattern triple or nil
    # @return [Array]:: List of matched triples
    def triples(triple = Triple.new(nil, nil, nil), &block) # :yields: triple, context
      @store.triples(triple, self, &block) || []
    end
    alias_method :find, :triples
    
    # Returns ordered rdf:_n objects or rdf:first, rdf:rest for a given subject
    def seq(subject)
      props = properties(subject)
      rdf_type = props[RDF_TYPE.to_s] || []

      if rdf_type.include?(RDF_NS.Seq)
        props.keys.select {|k| k.match(/#{RDF_NS.uri}_(\d)$/)}.
          sort_by {|i| i.sub(RDF_NS._.to_s, "").to_i}.
          map {|key| props[key]}.
          flatten
      elsif self.triples(Triple.new(subject, RDF_NS.first, nil))
        # N3-style first/rest chain
        list = []
        while subject != RDF_NS.nil
          props = properties(subject)
          list += props[RDF_NS.first.to_s]
          subject = props[RDF_NS.rest.to_s].first
        end
        list
      else
        []
      end
    end

    # Resource properties
    #
    # Properties arranged as a hash with the predicate Term as index to an array of resources
    #
    def properties(subject)
      @properties ||= {}
      @properties[subject.to_s] ||= begin
        hash = Hash.new
        self.triples(Triple.new(subject, nil, nil)).map do |t, ctx|
          pred = t.predicate.to_s

          hash[pred] ||= []
          hash[pred] << t.object
        end
        hash
      end
    end
    
    # Return an n3 identifier for the Graph
    def n3
      "[#{self.identifier.to_n3}]"
    end

    # Detect the presence of a BNode in the graph, either as a subject or an object
    #
    # @param [BNode] bn:: BNode to find
    #
    def has_bnode_identifier?(bn)
      self.triples do |triple, context|
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
    
    # Get type(s) of subject, returns a list of symbols
    def type_of(subject)
      triples(Triple.new(subject, RDF_TYPE, nil)).map {|t, ctx| t.object}
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
    def eql?(other)
      puts "eql? size #{self.size} vs #{other.size}" if $DEBUG
      return false if !other.is_a?(Graph) || self.size != other.size
      return false unless other.identifier.to_s == identifier.to_s unless other.identifier.is_a?(BNode) && identifier.is_a?(BNode)
      
      bn_self = bnodes.values.sort
      bn_other = other.bnodes.values.sort
      puts "eql? bnodes '#{bn_self.to_sentence}' vs '#{bn_other.to_sentence}'" if $DEBUG
      return false unless bn_self == bn_other
      
      # Check each triple to see if it's contained in the other graph
      triples do |t, ctx|
        next if t.subject.is_a?(BNode) || t.object.is_a?(BNode)
        puts "eql? contains '#{t.to_ntriples}: #{other.contains?(t)}'" if $DEBUG
        return false unless other.contains?(t)
      end
      
      # For each BNode, check permutations of similar bnodes in other graph
      bnode_permutations(bnodes, other.bnodes) do |bn_map|
        puts "bnode permutations: #{bn_map.inspect}" if $DEBUG
        # bn_map contains 1-1 mapping of bnodes from self to other
        catch :next_perm do
          triples do |t, ctx|
            next unless t.subject.is_a?(BNode) || t.object.is_a?(BNode)
            subject, object = t.subject, t.object
            subject = bn_map[subject] if bn_map.has_key?(subject)
            object = bn_map[object] if bn_map.has_key?(object)
            tn = Triple.new(subject, t.predicate, object)
            puts "  eql? contains '#{tn.inspect}': #{other.contains?(tn)}" if $DEBUG
            next if other.contains?(tn)
          
            puts "  no, next permutation" if $DEBUG
            # Not a match, try next permutation
            throw :next_perm
          end
          
          # If we matched all triples in the graph using this permutation, we're done
          return true
        end
      end
      
      # Exhausted all permutations, unless there were no bnodes
      bn_self.length == 0
    end

    alias_method :==, :eql?
    
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
    def parse(stream, uri = nil, options = {}, &block) # :yields: triple
      Parser.parse(stream, uri, options.merge(:graph => self), &block)
    end
  end
  
  protected

    # Permutations of two BNode lists
    #
    # Take source keys and run permutations mapping to other keys, if the permutation
    # maps to the same counts for each
    def bnode_permutations(bn_source, bn_other)
      puts "compare #{bn_source.inspect}\n   with #{bn_other.inspect}" if $DEBUG

      source_keys = bn_source.keys
      other_keys = bn_other.keys
      values = bn_source.values.uniq

      # Break key lists into groups based on sharing equivalent usage counts
      case values.length
      when 0
        {}
      when 1
        # All keys have equivalent counts, yield permutations
        if source_keys.length == 1
          puts "yield #{{source_keys.first => other_keys.first}.inspect}" if $DEBUG
          yield({source_keys.first => other_keys.first})
        else
          (0..(source_keys.length-1)).to_a.permute do |indicies|
            puts "indicies #{indicies.inspect}" if $DEBUG
            ok = other_keys.dup
            map = indicies.inject({}) { |hash, i| hash[source_keys[i]] = ok.shift; hash}
            puts "yield #{map.inspect}" if $DEBUG
            yield(map)
          end
        end
      else
        # Break bnodes into 2 arrays sharing a common usage count and permute each separately
        max = values.max
        bn_source_min = bn_source.clone
        bn_other_min = bn_other.clone
        bn_source_max = {}
        bn_other_max = {}
        bn_source.each_pair do |bn, v|
          bn_source_max[bn] = bn_source_min.delete(bn) if v == max
        end
        bn_other.each_pair do |bn, v|
          bn_other_max[bn] = bn_other_min.delete(bn) if v == max
        end

        puts "yield permutations of multiple with max #{bn_source_max.inspect}\n  and #{bn_other_max.inspect}" if $DEBUG
        # Yield for each permutation of max joined with permutations of min
        bnode_permutations(bn_source_max, bn_other_max) do |bn_perm_max|
          bnode_permutations(bn_source_min, bn_other_min) do |bn_perm_min|
            yield bn_perm_max.merge(bn_perm_min)
          end
        end
      end
    end
end
