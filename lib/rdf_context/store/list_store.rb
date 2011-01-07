module RdfContext
  autoload :AbstractStore, File.join(File.dirname(__FILE__), 'abstract_store')

  # List storage, most efficient, but slow storage model. Works well for basic parse and serialize.
  class ListStore < AbstractStore
    def initialize(identifier = nil, configuration = {})
      super
      @triples = []
    end
    
    # Create a new ListStore Store, should be subclassed
    # @param [Resource] identifier
    # @param[Hash] configuration Specific to type of storage
    # @return [ListStore]
    def inspect
      "ListStore[id=#{identifier}, size=#{@triples.length}]"
    end
    
    # Destroy the store, as it can contain only one context
    def destroy(configuration = {})
      @triples = []
    end
    
    # Add triple to store
    # @param [Triple] triple
    # @param [Graph] context (nil) ignored
    # @param [Boolean] quoted (false) ignored
    # @return [Triple]
    def add(triple, context, quoted = false)
      @triples << triple unless contains?(triple, context)
    end
    
    # Remove a triple from the store
    #
    # If the triple does not provide a context attribute, removes the triple
    # from all contexts.
    # @param [Triple] triple
    # @param [Graph] context (nil) ignored
    # @param [Boolean] quoted (false) ignored
    # @return [void]
    def remove(triple, context, quoted = false)
      @triples.delete(triple)
    end

    # Check to see if this store contains the specified triple
    # @param [Triple] triple
    # @param [Graph] context (nil) ignored
    # @return [Boolean]
    def contains?(triple, context = nil)
      @triples.any? {|t| t == triple}
    end

    # Triples from graph, optionally matching subject, predicate, or object.
    # Delegated from Graph. See Graph#triples for details.
    #
    # @param [Triple] triple
    # @param [Graph] context (nil)
    # @return [Array<Triplle>]
    # @yield [triple, context]
    # @yieldparam [Triple] triple
    # @yieldparam [Graph] context
    def triples(triple, context = nil)
      subject = triple.subject
      predicate = triple.predicate
      object = triple.object
      
      if subject || predicate || object
        @triples.select do |t|
          next unless t == triple # Includes matching
          
          if block_given?
            yield t
          end
          t
        end.compact
      elsif block_given?
        @triples.each {|triple| yield triple}
      else
        @triples
      end
    end
  end
end