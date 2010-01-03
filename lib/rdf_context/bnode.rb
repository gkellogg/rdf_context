module RdfContext
  # The BNode class creates RDF blank nodes.
  class BNode
    attr_reader :identifier
    
    # Create a new BNode, optionally accept a identifier for the BNode.
    # Otherwise, generated sequentially.
    #
    # A BNode may have a bank (empty string) identifier, which will be equivalent to another
    # blank identified BNode.
    #
    # Identifiers only have meaning within a particular parsing context, and are used
    # to lookup previoiusly defined BNodes using the same identifier. Names are *not* preserved
    # within the underlying storage model.
    #
    # @param [String] identifier:: Legal NCName or nil for a named BNode
    # @param [Hash] context:: Context used to store named BNodes
    def initialize(identifier = nil, context = {})
      if identifier != nil && self.valid_id?(identifier)
        identifier = identifier.sub(/nbn\d+[a-z]+N/, '')  # creating a named BNode from a named BNode
        # Generate a name if it's blank. Always prepend "named" to avoid generation overlap
        @identifier = context[identifier] ||= generate_bn_identifier(identifier)
      else
        @identifier = generate_bn_identifier
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
    # @return [String]:: The BNode in n3.
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
    
    # The identifier used used for this BNode.
    def identifier
      @identifier
    end
    
    # Compare BNodes. BNodes are equivalent if they have the same identifier
    def eql?(other)
      other.class == self.class &&
      other.identifier == self.identifier
    end
    alias_method :==, :eql?
    
    # Needed for uniq
    def hash; self.to_s.hash; end
    
    def inspect
      "[bn:#{identifier}]"
    end
    
    protected
    def valid_id?(name)
      NC_REGEXP.match(name) || name.empty?
    end

    # Generate a unique identifier (time with milliseconds plus generated increment)
    def generate_bn_identifier(name = nil)
      @@base ||= "bn#{(Time.now.to_f * 1000).to_i}"
      @@next_generated ||= "a"
      if name
        bn = "n#{@@base}#{@@next_generated}N#{name}"
      else
        bn = "#{@@base}#{@@next_generated}"
      end
      @@next_generated = @@next_generated.succ
      bn
    end
  end
end
