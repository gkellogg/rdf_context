module RdfContext
  # Abstract storage module, superclass of other storage classes
  class AbstractStore
    attr_reader :nsbinding, :uri_binding, :identifier
    
    def initialize(identifier = nil, configuration = {})
      @nsbinding = {}
      # Reverse namespace binding
      @uri_binding = {}
      
      @identifier = identifier || BNode.new
    end
    
    def context_aware?; false; end
    def formula_aware?; false; end
    def transaction_aware?; false; end

    # Interfaces that must be implemented
    def triples(triple, context = nil)  # :yields: triple, context
      raise StoreException, "not implemented"
    end
    def add(triple, context = nil, quoted = false); raise StoreException, "not implemented"; end
    def remove(triple, context = nil); raise StoreException, "not implemented"; end
    
    # Default (sub-optimal) implemenations of interfaces
    def inspect
      "#{self.class}[identifier=#{identifier.inspect}]"
    end
    
    def destroy(configuration = {}); end
    def open(configuration = {}); end
    def commit; end
    def rollback; end

    # Bind namespace to store, returns bound namespace
    def bind(namespace)
      # Over-write an empty prefix
      uri = namespace.uri.to_s
      @uri_binding[uri] = namespace unless namespace.prefix.to_s.empty?
      @uri_binding[uri] ||= namespace
      @nsbinding[namespace.prefix.to_s] = namespace
    end

    # Namespace for prefix
    def namespace(prefix)
      @nsbinding[prefix.to_s]
    end
    
    # Prefix for namespace
    def prefix(namespace)
      namespace.is_a?(Namespace) ? @uri_binding[namespace.uri.to_s].prefix : @uri_binding[namespace].prefix
    end
    
    # Get all BNodes with usage count used within graph
    def bnodes(context = nil)
      bn = {}
      triples(Triple.new(nil, nil, nil), context) do |t, ctx|
        if t.subject.is_a?(BNode)
          bn[t.subject] ||= 0
          bn[t.subject] += 1
        end
        if t.predicate.is_a?(BNode)
          bn[t.predicate] ||= 0
          bn[t.predicate] += 1
        end
        if t.object.is_a?(BNode)
          bn[t.object] ||= 0
          bn[t.object] += 1
        end
      end
      bn
    end

    def size(context = nil); triples(Triple.new(nil, nil, nil), context).size; end
    def subjects(context = nil); triples(Triple.new(nil, nil, nil), context).map {|t| t.subject}.uniq; end
    def predicates(context = nil); triples(Triple.new(nil, nil, nil), context).map {|t| t.predicate}.uniq; end
    def objects(context = nil); triples(Triple.new(nil, nil, nil), context).map {|t| t.object}.uniq; end
    def item(item, context = nil) triples(Triple.new(nil, nil, nil), context)[item]; end
  end
end