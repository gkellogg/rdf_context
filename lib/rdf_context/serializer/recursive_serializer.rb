require File.join(File.dirname(__FILE__), 'abstract_serializer')
require File.join(File.dirname(__FILE__), '..', 'bnode')
require File.join(File.dirname(__FILE__), '..', 'literal')

module RdfContext
  # Recursive serializer
  class RecursiveSerializer < AbstractSerializer
    MAX_DEPTH = 10
    INDENT_STRING = " "
    
    def initialize(graph)
      super(graph)
      @stream = nil
      self.reset
    end

    def top_classes; [RDFS_NS.Class]; end
    def predicate_order; [RDF_TYPE, RDFS_NS.label]; end
    
    def add_namespace(ns)
      @namespaces[ns.prefix] = ns
    end

    # Check to see if the subject should be serialized yet 
    def check_subject(subject)
      is_done(subject) ||
      !@subjects.include(subject) ||
      (@top_levels.include(subject) && @depth > 1) ||
      (subject.is_a?(URIRef) && @depth > MAX_DEPTH)
    end
    
    def is_done(subject)
      @serialized.include?(subject)
    end
    
    def order_subjects
      seen = {}
      subjects = []
      
      top_classes.each do |class_uri|
        graph.triples(Triple.new(nil, RDF_TYPE, class_uri)).map {|t| t.subject}.sort.uniq.each do |subject|
          #puts "order_subjects: #{subject.inspect}"
          subjects << subject
          seen[subject] = @top_levels[subject] = true
        end
      end
      
      # Sort subjects by resources over bnodes, ref_counts and the subject URI itself
      recursable = @subjects.keys.
        select {|s| !seen.include?(s)}.
        map {|r| [r.is_a?(BNode) ? 1 : 0, ref_count(r), r]}.
        sort
      
      subjects += recursable.map{|r| r.last}
    end
    
    def preprocess
      @graph.triples.each {|t| preprocess_triple(t)}
    end
    
    def preprocess_triple(triple)
      #puts "preprocess: #{triple.inspect}"
      references = ref_count(triple.object) + 1
      @references[triple.object] = references
      @subjects[triple.subject] = true
    end
    
    # Return the number of times this node has been referenced in the object position
    def ref_count(node)
      @references.fetch(node, 0)
    end

    def reset
      @depth = 0
      @lists = {}
      @namespaces = {}
      @references = {}
      @serialized = {}
      @subjects = {}
      @top_levels = {}
    end

    # Take a hash from predicate uris to lists of values.
    # Sort the lists of values.  Return a sorted list of properties.
    def sort_properties(properties)
      properties.keys.each do |k|
        properties[k] = properties[k].sort
      end
      
      # Make sorted list of properties
      prop_list = []
      seen = {}
      
      predicate_order.each do |prop|
        next if seen.has_key?(prop) || !properties.has_key?(prop)
        prop_list << prop
        seen[prop] = true
      end
      
      properties.keys.sort.each do |prop|
        next if seen.has_key?(prop)
        prop_list << prop
        seen[prop] = true
      end
    end

    # Mark a subject as done.
    def subject_done(subject)
      @serialized[subject] = true
    end
    
    # Returns indent string multiplied by the depth
    def indent(modifier = 0)
      INDENT_STRING * (@depth + modifier)
    end
    
    # Write text
    def write(text)
      @stream.write(text)
    end
  end
end