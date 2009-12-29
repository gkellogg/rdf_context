module Reddy
  # An integer-key-optimized-context-aware-in-memory store.
  #
  # Uses nested dictionaries to store triples and context. Each triple
  # is stored in six such indices as follows cspo[c][s][p][o] = 1
  # and cpos[c][p][o][s] = 1 and cosp[c][o][s][p] = 1 as well as
  # spo[s][p][o] = [c] and pos[p][o][s] = [c] and pos[o][s][p] = [c]
  #
  # Context information is used to track the 'source' of the triple
  # data for merging, unmerging, remerging purposes.  context aware
  # store stores consume more memory size than non context stores.
  #
  # Querying or removing triples using the store identifier (or nil) as context operate
  # across all contexts within the store; otherwise, operations are specifiec to the
  # specified context.
  # 
  # Based on Python RdfLib IOMemory
  class MemoryStore < AbstractStore
    attr_accessor :default_context
    
    # Supports contexts
    def context_aware?; true; end
    
    # Supports formulae
    def formula_aware?; true; end
    
    def initialize(identifier = nil, configuration = {})
      super
      # indexed by [context][subject][predicate][object] = 1
      @cspo = {}
      # indexed by [context][predicate][object][subject] = 1
      @cpos = {}
      # indexed by [context][object][subject][predicate] = 1
      @cosp = {}
      # indexed by [subject][predicate][object] = [context]
      @spo = {}
      # indexed by [predicate][object][subject] = [context]
      @pos = {}
      # indexed by [object][subject][predicate] = [context]
      @osp = {}
      # indexes integer keys to identifiers
      @forward = {}
      # reverse index of forward
      @reverse = {}
    end
  end
  
  def dump
    puts "MemoryStore: #{identifier}\n" +
      "  cspo: #{@cspo.inspect}\n" +
      "  cpos: #{@cpos.inspect}\n" +
      "  cosp: #{@cosp.inspect}\n" +
      "  spo: #{@spo.inspect}\n" +
      "  pos: #{@pos.inspect}\n" +
      "  osp: #{@osp.inspect}\n" +
      "  forward: #{@forward.inspect}\n" +
      "  reverse: #{@reverse.inspect}\n"
  end
  
  # Add a triple to the store
  # Add to default context, if context is nil
  def add(triple, context, quoted = false)
    context = context.identifier if context.respond_to?(:identifier)
    context ||= @identifier
    return unless triples(triple, context).empty?
    
    # Assign keys for new identifiers
    si = resource_to_int(triple.subject) || gen_key(triple.subject)
    pi = resource_to_int(triple.predicate) || gen_key(triple.predicate)
    oi = resource_to_int(triple.object) || gen_key(triple.object)
    ci = resource_to_int(context) || gen_key(context)
    
    #puts "add: #{si}, #{pi}, #{oi}, #{ci}" if $DEBUG
    set_nested_index(@cspo, ci, si, pi, oi)
    set_nested_index(@cpos, ci, pi, oi, si)
    set_nested_index(@cosp, ci, oi, si, pi)
    
    unless quoted
      set_nested_index(@spo, si, pi, oi, ci)
      set_nested_index(@pos, pi, oi, si, ci)
      set_nested_index(@osp, oi, si, pi, ci)
    end
    #dump if $DEBUG
  end
  
  # Remove a triple from the context and store
  def remove(triple, context = nil)
    context = context.identifier if context.respond_to?(:identifier)
    context = nil if context == @identifier
    
    # Iterate over all matching triples and contexts
    triples(triple, context) do |t, cg|
      si, pi, oi = triple_to_int(t)
      ci = resource_to_int(cg)
      #puts "remove: si=#{si}, pi=#{pi}, oi=#{oi}, ci=#{ci}"
      
      # Remove triple from context
      remove_nested_index(@cspo, ci, si, pi, oi)
      remove_nested_index(@cpos, ci, pi, oi, si)
      remove_nested_index(@cosp, ci, oi, si, pi)

      # Remove context from triple
      remove_nested_index(@spo, si, pi, oi, ci)
      remove_nested_index(@pos, pi, oi, si, ci)
      remove_nested_index(@osp, oi, si, pi, ci)
    end
  end
  
  # A generator over all matching triples
  def triples(triple, context = nil, &block)
    context = context.identifier if context.respond_to?(:identifier)
    context = nil if context == @identifier
    
    if context.nil?
      spo = @spo
      pos = @pos
      osp = @osp
    else
      ci = resource_to_int(context)
      return [] unless ci
      spo = @cspo[ci]
      pos = @cpos[ci]
      osp = @cosp[ci]
      return [] unless spo && pos && osp
    end

    #self.dump
    
    results = []
    si, pi, oi = triple_to_int(triple)
    puts "triples: si=#{si}, pi=#{pi}, oi=#{oi}, ci=#{ci}" if $DEBUG

    def result(v, si, pi, oi, ctx)
      t = int_to_triple(si, pi, oi)
      if block_given?
        if v.is_a?(Hash)
          # keys are contexts
          v.keys.each do |ci|
            yield t, int_to_resource(ci)
          end
        else
          #puts "ctx: #{ctx}"
          yield t, ctx
        end
      end
      t
    end
    
    if si # subject is given
      if spo.has_key?(si)
        #puts "spo[#{si}] = #{spo[si].inspect}" if $DEBUG
        if pi # subject+predicate is given
          if spo[si].has_key?(pi)
            if oi # subject+predicate+object is given
              #puts "spo[#{si}][#{pi}][#{oi}] = #{spo[si][pi][oi].inspect}"
              results << result(spo[si][pi][oi], si, pi, oi, context, &block) if spo[si][pi].has_key?(oi)
            elsif triple.object.nil? # subject+predicate is given, object unbound
              spo[si][pi].each_pair do |oi, value|
                results << result(value, si, pi, oi, context, &block)
              end
              oi = nil
            end
          end
        elsif triple.predicate.nil? # subject given, predicate unbound
          spo[si].keys.each do |pi|
            #puts "spo[#{si}][#{pi}] = #{spo[si][pi].inspect}" if $DEBUG
            if oi # object is given
              results << result(spo[si][pi][oi], si, pi, oi, context, &block) if spo[si][pi].has_key?(oi)
            else # object unbound
              #puts "spo[#{si}][#{pi}] = #{spo[si][pi].inspect}"
              spo[si][pi].each_pair do |oi, value|
                #puts "spo[#{si}][#{pi}][#{oi}] = #{spo[si][pi][oi].inspect}" if $DEBUG
                results << result(value, si, pi, oi, context, &block)
              end
              oi = nil
            end
          end
        end
      end
    elsif !triple.subject.nil?
      # Subject specified, but not found, skip
    elsif pi # subject unbound, predicate given
      if pos.has_key?(pi)
        if oi # subject unbound, predicate+object given
          if pos[pi].has_key?(oi)
            pos[pi][oi].each_pair do |si, value|
              results << result(value, si, pi, oi, context, &block)
            end
          end
        elsif triple.object.nil? # subject unbound, predicate given, object unbound
          pos[pi].keys.each do |oi|
            pos[pi][oi].each_pair do |si, value|
              results << result(value, si, pi, oi, context, &block)
            end
          end
          oi = nil
        end
      end
    elsif !triple.predicate.nil?
      # Subject unspecified, predicate specified but not found, skip
    elsif oi # subject+predicate unbound, object given
      if osp.has_key?(oi)
        osp[oi].keys.each do |si|
          osp[oi][si].each_pair do |pi, value|
            results << result(value, si, pi, oi, context, &block)
          end
        end
      end
    elsif !triple.object.nil?
      # Subject+predicate unspecified, object specified but not found, skip
    else # subject+predicate+object unbound
      puts "spo = #{spo.inspect}" if $DEBUG
      spo.keys.each do |si|
        puts "spo[#{si}] = #{spo[si].inspect}" if $DEBUG
        spo[si].keys.each do |pi|
          puts "spo[#{si}][#{pi}] = #{spo[si][pi].inspect}" if $DEBUG
          spo[si][pi].each_pair do |oi, value|
            puts "spo[#{si}][#{pi}][#{oi}] = #{spo[si][pi][oi].inspect}" if $DEBUG
            results << result(value, si, pi, oi, context, &block)
          end
        end
      end
    end
    results
  end
  
  # Check to see if this store contains the specified triple
  #
  # Note, if triple contains a Literal object, need to wild-card
  # and check each result individually due to variation in literal
  # comparisons
  def contains?(triple, context = nil)
    #puts "contains? #{triple}"
    object = triple.object
    if object.is_a?(Literal)
      triple = Triple.new(triple.subject, triple.predicate, nil)
      triples(triple, context) do |t, cg|
        return true if t.object == object
      end
      false
    else
      !triples(triple, context).empty?
    end
  end

  def size(context = nil)
    context = context.identifier if context.respond_to?(:identifier)
    context = nil if context == @identifier
    
    if context.nil?
      spo = @spo
    else
      ci = resource_to_int(context)
      return 0 unless ci
      spo = @cspo[ci]
      return 0 unless spo.is_a?(Hash)
    end
    
    count = 0
    spo.values.each do |po|
       count += po.length
    end
    count
  end
  
  # Contexts containing the triple (no matching), or total number of contexts in store
  def contexts(triple = nil)
    if triple
      si, pi, oi = triple_to_int(triple)
      value = @spo[si][pi][oi]
      (value && value.keys.map {|ci| int_to_resource(ci)}) || []
    else
      @cspo.keys.map {|ci| int_to_resource(ci)}
    end
  end
  
  private
  
  # Generate a random key and associate with resource
  def gen_key(resource)
    begin i = rand((@forward.size + 1) * 4) end while @forward.has_key?(i)
    @forward[i] = resource
    @reverse[resource.hash] = i
  end
  
  def set_nested_index(index, *keys)
    ndx = index
    keys.each_index do |i|
      key = keys[i]
      ndx[key] ||= i == (keys.length - 1) ? 1 : {}
      ndx = ndx[key]
    end
    
    #puts("set_nested_index: #{index.inspect}, keys: #{keys.inspect}") if $DEBUG
  end
  
  # Remove context from the list of contexts in a nested index.
  #
  # Afterwards, recursively remove nested indexes when they became empty.
  def remove_nested_index(index, *keys)
    ndx = index
    parents = []
    keys.each do |key|
      parents << ndx
      ndx = ndx[key]
    end
    #puts "parents: #{parents.inspect}"
    #puts "keys: #{keys.inspect}"
    
    (keys.length-1).downto(0) do |i|
      ndx = parents[i]
      key = keys[i]
      #puts "i=#{i}, key=#{key}, index: #{ndx.inspect}"
      ndx.delete(key) if !ndx[key].is_a?(Hash) || ndx[key].empty?
    end
    #puts "end: index=#{index.inspect}", ""
  end
  
  # Translate integer versions of subject, predicate and object into a Triple
  def int_to_triple(si, pi, oi)
    Triple.new(@forward[si], @forward[pi], @forward[oi])
  end
  
  def int_to_resource(i); @forward[i]; end
  
  # Translate a triple into integer subject, predicate and object
  def triple_to_int(triple)
    [@reverse[triple.subject.hash], @reverse[triple.predicate.hash], @reverse[triple.object.hash]]
  end
  def resource_to_int(resource); @reverse[resource.hash]; end
  
  def unique_subjects(context=nil)
    context = context.identifier if context.respond_to?(:identifier)
    index = context ? @cspo[context] : @spo
    index.keys.each {|i| yield @forward[i]}
  end
  
  def unique_predicates(context=nil)
    context = context.identifier if context.respond_to?(:identifier)
    index = context ? @cpos[context] : @pos
    index.keys.each {|i| yield @forward[i]}
  end
  
  def unique_objects(context=nil)
    context = context.identifier if context.respond_to?(:identifier)
    index = context ? @cosp[context] : @osp
    index.keys.each {|i| yield @forward[i]}
  end
end