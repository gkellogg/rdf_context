module Reddy
  # The BNode class creates RDF blank nodes.
  class BNode
    @@next_generated = "a"
    @@named_nodes = {}
    
    # Create a new BNode, optionally accept a identifier for the BNode.
    # Otherwise, generated sequentially
    #
    # ==== Example
    #  BNode.new("foo")
    def initialize(identifier = nil)
      if identifier != nil && self.valid_id?(identifier)
        # Generate a name if it's blank
        @identifier = (@@named_nodes[identifier] ||= identifier.to_s.length > 0 ? identifier : self )
      else
        # Don't actually allocate the name until it's used, to save generation space
        # (and make checking test cases easier)
        @identifier = self
      end
    end

    # Return BNode identifier
    def to_s
      return self.identifier.to_s
    end

    ## 
    # Exports the BNode in N-Triples form.
    #
    # ==== Example
    #   b = BNode.new; b.to_n3  # => returns a string of the BNode in n3 form
    #
    # @return [String] The BNode in n3.
    #
    # @author Tom Morris
    def to_n3
      "_:#{self.identifier}"
    end

    ## 
    # Exports the BNode in N-Triples form.
    #
    # Syonym for to_n3
    def to_ntriples
      self.to_n3
    end

    # Output URI as resource reference for RDF/XML
    #
    # ==== Example
    #   b = BNode.new("foo"); b.xml_args  # => [{"rdf:nodeID" => "foo"}]
    def xml_args
      [{"rdf:nodeID" => self.identifier}]
    end
    
    # The identifier used used for this BNode. Not evaluated until this is called, which means
    # that BNodes that are never used in a triple won't polute the sequence.
    def identifier
      return @identifier unless @identifier.is_a?(BNode)
      if @identifier.equal?(self)
        # Generate from the sequence a..zzz, unless already taken
        @@next_generated = @@next_generated.succ while @@named_nodes.has_key?(@@next_generated)
        @identifier, @@next_generated = @@next_generated, @@next_generated.succ
      else
        # Previously allocated node
        @identifier = @identifier.identifier
      end
      @identifier
    end
    
    # Compare BNodes. BNodes are equivalent if their identifiers are equivalent
    def eql?(other)
      other.is_a?(self.class) && self.identifier == other.identifier
    end
    alias_method :==, :eql?
    
    # Needed for uniq
    def hash; to_s.hash; end
    
    # Start _identifier_ sequence from scratch.
    # Identifiers are created using String::succ on start valuie.
    def self.reset(init = "a")
      @@next_generated = init
      @@named_nodes = {}
    end

    protected
    def valid_id?(name)
      NC_REGEXP.match(name) || name.empty?
    end
  end
end
