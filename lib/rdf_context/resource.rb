module RdfContext
  # Common super-class for things that are RDF Resources
  class Resource

    ##
    # Returns `true` to indicate that this value is a resource.
    #
    # @return [Boolean]
    def resource?
      true
    end

    ##
    # Returns `false`, overridden in Literal
    #
    # @return [Boolean]
    def literal?
      false
    end

    ##
    # Returns `false`, overridden in URIref
    #
    # @return [Boolean]
    def uri?
      false
    end

    ##
    # Returns `false`, overridden in BNode
    #
    # @return [Boolean]
    def bnode?
      false
    end
    
    ##
    # Returns `false`, overridden in BNode
    #
    # @return [Boolean]
    def graph?
      false
    end
    
    # Parse a string to a resource, in NTriples format
    def self.parse(str)
      case str
      when /^_:/    then BNode.parse(str)
      when /^</     then URIRef.parse(str)
      when /^http:/ then URIRef.parse(str)
      when /^\"/    then Literal.parse(str)
      else               Literal.parse(str)
      end
    end
  end
end