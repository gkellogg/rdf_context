module Reddy
  # Triple from Reddy, to aid it merger
  class Triple
    attr_accessor :subject, :object, :predicate

    ##
    # Creates a new triple directly from the intended subject, predicate, and object.
    #
    # ==== Example
    #   Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new) # => results in the creation of a new triple and returns it
    #
    # @param [URIRef, BNode] s the subject of the triple
    # @param [URIRef] p the predicate of the triple
    # @param [URIRef, BNode, Literal, TypedLiteral] o the object of the triple
    #
    # ==== Returns
    #
    # @return [Triple] An array of the triples (leaky abstraction? consider returning the graph instead)
    #
    # @raise [Error] Checks parameter types and raises if they are incorrect.
    # @author Tom Morris
    def initialize (subject, predicate, object)
      @subject   = self.class.coerce_subject(subject)
      @predicate = self.class.coerce_predicate(predicate)
      @object    = self.class.coerce_object(object)
    end

    def to_ntriples
      @subject.to_ntriples + " " + @predicate.to_ntriples + " " + @object.to_ntriples + " ."
    end
    
    def to_s; self.to_ntriples; end
    
    def inspect
      [@subject, @predicate, @object].inspect
    end

    def is_type?
      @predicate.to_s == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    end

    def eql? (other)
      other.is_a?(self.class) &&
      other.subject == self.subject &&
      other.predicate == self.predicate &&
      other.object == self.object
    end

    alias_method :==, :eql?

    protected

    def self.coerce_subject(subject)
      case subject
      when Addressable::URI
        URIRef.new(subject.to_s)
      when URIRef, BNode
        subject
      when String
        if subject =~ /^\w+:\/\/\S+/ # does it smell like a URI?
          URIRef.new subject
        else
          BNode.new subject
        end
      else
        raise InvalidSubject, "Subject is not of a known class (#{subject.class}: #{subject.inspect})"
      end
    end

    def self.coerce_predicate(uri_or_string)
      case uri_or_string
      when URIRef
        uri_or_string
      when String
        URIRef.new uri_or_string
      else
        raise InvalidPredicate, "Predicate should be a URI"
      end
    rescue ParserException => e
      raise InvalidPredicate, "Couldn't make a URIRef: #{e.message}"
    end

    def self.coerce_object(object)
      case object
      when Addressable::URI
        URIRef.new(object.to_s)
      when String
        if object.to_s =~ /^\w+:\/\/\S+/ # does it smell like a URI?
          URIRef.new(object.to_s)
        else
          Literal.untyped(object)
        end
      when Integer, Float
        Literal.build_from(object)
      when URIRef, BNode, Literal
        object
      else
        raise InvalidObject, "#{object.class}: #{object.inspect} is not a valid object"
      end
    end
  end
end
