module Reddy
  # An RDF Triple, or statement.
  #
  # Statements are composed of _subjects_, _predicates_ and _objects_.
  class Triple
    attr_accessor :subject, :object, :predicate

    ##
    # Creates a new triple directly from the intended subject, predicate, and object.
    #
    # ==== Example
    #   Triple.new(BNode.new, URIRef.new("http://xmlns.com/foaf/0.1/knows"), BNode.new) # => results in the creation of a new triple and returns it
    #
    # @param [URIRef, BNode] subject:: the subject of the triple
    # @param [URIRef] predicate:: the predicate of the triple
    # @param [URIRef, BNode, Literal, TypedLiteral] object:: the object of the triple
    # @return [Triple]:: An array of the triples (leaky abstraction? consider returning the graph instead)
    # @raise [Error]:: Checks parameter types and raises if they are incorrect.
    #
    # @author Tom Morris
    def initialize (subject, predicate, object)
      @subject   = self.class.coerce_subject(subject)
      @predicate = self.class.coerce_predicate(predicate)
      @object    = self.class.coerce_object(object)
    end

    # Serialize Triple to N-Triples
    def to_ntriples
      @subject.to_ntriples + " " + @predicate.to_ntriples + " " + @object.to_ntriples + " ."
    end
    
    def to_s; self.to_ntriples; end
    
    def inspect
      [@subject, @predicate, @object].inspect
    end

    # Is the predicate of this statment rdf:type?
    def is_type?
      @predicate.to_s == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    end

    # Two triples are equal if their of their subjects, predicates and objects are equal.
    def eql? (other)
      other.is_a?(self.class) &&
      other.subject == self.subject &&
      other.predicate == self.predicate &&
      other.object == self.object
    end

    alias_method :==, :eql?

    protected

    # Coerce a subject to the appropriate Reddy type.
    # 
    # @param[URI, URIRef, String] subject:: If a String looks like a URI, a URI is created, otherwise a BNode.
    # @raise[InvalidSubject]:: If subject can't be intuited.
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

    # Coerce a predicate to the appropriate Reddy type.
    # 
    # @param[URI, URIRef, String] subject:: If a String looks like a URI, a URI is created
    # @raise[InvalidSubject]:: If subject can't be predicate.
    def self.coerce_predicate(predicate)
      case predicate
      when Addressable::URI
        URIRef.new(predicate.to_s)
      when URIRef
        predicate
      when String
        URIRef.new predicate
      else
        raise InvalidPredicate, "Predicate should be a URI"
      end
    rescue ParserException => e
      raise InvalidPredicate, "Couldn't make a URIRef: #{e.message}"
    end

    # Coerce a object to the appropriate Reddy type.
    # 
    # @param[URI, URIRef, String, Integer, Float, BNode, Literal] object:: If a String looks like a URI, a URI is created, otherwise an untyped Literal.
    # @raise[InvalidSubject]:: If subject can't be predicate.
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
