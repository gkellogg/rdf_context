module Rena
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
      self.check_subject(subject)
      self.check_predicate(predicate)
      self.check_object(object)
    end

    def to_ntriples
      @subject.to_ntriples + " " + @predicate.to_ntriples + " " + @object.to_ntriples + " ."
    end
  
    protected
    def check_subject(subject)
      if subject.class == BNode || subject.class == URIRef
        @subject = subject
      elsif subject.class == String
        if subject =~ /\S+\/\/\S+/ # does it smell like a URI?
          @subject = URIRef.new(subject)
        else
          @subject = BNode.new(subject)
        end
      else
        raise "Subject is not of a known class"
      end
    end

    protected
    def check_predicate(predicate)
      if predicate.class == URIRef
        @predicate = predicate
      elsif predicate.class == BNode
        raise "BNode is not allowed as a predicate"
      elsif predicate.class == String
        if predicate =~ /\S+\/\/\S+/ # URI smell check again
          @predicate = URIRef.new(predicate)
        else
          raise "String literals are not acceptable as predicates"
        end
      else
        raise "Predicate should be a uriref"
      end
    end

    protected
    def check_object(object)
      if [String, Integer, Fixnum, Float].include? object.class
        @object = Literal.new(object.to_s)
      elsif [URIRef, BNode, Literal, TypedLiteral].include? object.class
        @object = object
      else
        raise "Object expects valid class"
      end
    end
  end
end