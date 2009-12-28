module Reddy
  # An RDF Triple, or statement.
  #
  # Statements are composed of _subjects_, _predicates_ and _objects_.
  class Triple
    attr_accessor :subject, :object, :predicate

    ##
    # Creates a new triple directly from the intended subject, predicate, and object.
    #
    # Any or all of _subject_, _predicate_ or _object_ may be nil, to create a triple patern.
    # A patern may not be added to a graph.
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
      @patern = subject.nil? || predicate.nil? || object.nil?
    end

    def is_patern?
      @patern
    end
    
    # Serialize Triple to N-Triples
    def to_ntriples
      raise RdfException.new("Can't serialize patern triple") if is_patern?
      @subject.to_ntriples + " " + @predicate.to_ntriples + " " + @object.to_ntriples + " ."
    end
    
    def to_s; self.to_ntriples; end
    
    def inspect
      [@subject, @predicate, @object, @patern].inspect
    end

    # Is the predicate of this statment rdf:type?
    def is_type?
      @predicate.to_s == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    end

    # Two triples are equal if their of their subjects, predicates and objects are equal.
    # Or self or other is a patern and subject, predicate, object matches
    def eql? (other)
      other.is_a?(Triple) &&
      (other.subject == self.subject || other.subject.nil? || self.subject.nil?) &&
      (other.predicate == self.predicate || other.predicate.nil? || self.predicate.nil?) &&
      (other.object == self.object || other.object.nil? || self.object.nil?)
    end

    alias_method :==, :eql?

    # Clone triple, keeping references to literals and URIRefs, but cloning BNodes
    def clone
      raise RdfException.new("Can't clone patern triple") if is_patern?
      s = subject.is_a?(BNode) ? subject.clone : subject
      p = predicate.is_a?(BNode) ? predicate.clone : predicate
      o = object.is_a?(BNode) ? object.clone : object
      Triple.new(subject, predicate, object)
    end
    
    # For indexes
    def hash
      [subject, predicate, object].hash
    end
    
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
      when nil
        subject
      when /^\w+:\/\/\S+/ # does it smell like a URI?
        URIRef.new subject
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
      when nil
        predicate
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
      when nil, regexp
        object
      else
        raise InvalidObject, "#{object.class}: #{object.inspect} is not a valid object"
      end
    end
  end
end
