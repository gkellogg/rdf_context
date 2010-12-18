module RdfContext
  # The BNode class creates RDF blank nodes.
  class BNode < Resource
    attr_accessor :identifier
    
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
    # @param [String] identifier (nil) Legal NCName or nil for a named BNode
    # @param [Hash] context ({}) Context used to store named BNodes
    def initialize(identifier = nil, context = {})
      if identifier.nil?
        @identifier = generate_bn_identifier
      elsif identifier.match(/n?bn\d+[a-z]+(N\w+)?$/)
        @identifier = context[identifier] || identifier
      elsif self.valid_id?(identifier)
        @identifier = context[identifier] ||= generate_bn_identifier(identifier)
      else
        @identifier = generate_bn_identifier
      end
    end

    # Parse a BNode
    def self.parse(str)
      BNode.new($1) if str =~ /^_:(.*)$/
    end
    
    ##
    # Returns `true`
    #
    # @return [Boolean]
    def bnode?
      true
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
    alias_method :to_ntriples, :to_n3

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
      case other
      when BNode
        other.identifier == self.identifier
      else
        self.identifier == other.to_s
      end
    end
    alias_method :==, :eql?
    
    def <=>(other)
      self.to_s <=> other.to_s
    end
  
    # Needed for uniq
    def hash; self.to_s.hash; end
    
    def inspect
      "#{self.class}[#{self.to_n3}]"
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
