require 'lib/namespace'
require 'lib/bnode'
require 'lib/uriref'
require 'lib/literal'
require 'lib/triple'
class Graph
  attr_accessor :triples
  
  def initialize
    @triples = []
    @nsbinding = []
  end
  
  def size
    @triples.size
  end
  
  def add_triple(s, p, o)
    @triples += [ Triple.new(s, p, o) ]
  end
  
  def << (triple)
#    self.add_triple(s, p, o)
    @triples += [ triple ]
  end
  
  def to_ntriples
    str = ""
    @triples.each do |t|
      str << t.to_ntriples + "\n"
    end
    return str
  end
  
  def namespace(uri, short)
    @nsbinding =+ Namespace.new(uri, short)
  end
  
  def bind(namespace)
    if namespace.class == Namespace
      @nsbinding =+ namespace
    else
      raise
    end
  end
  
  def has_bnode_identifier?(bnodeid)
    temp_bnode = BNode.new(bnodeid)
    returnval = false
    @triples.each { |triple|
      if triple.subject.eql?(temp_bnode)
        returnval = true
        break
      end
      if triple.object.eql?(temp_bnode)
        returnval = true
        break
      end
    }
    return returnval
  end
  
  def get_bnode_by_identifier(bnodeid)
    temp_bnode = BNode.new(bnodeid)
    returnval = false
    @triples.each { |triple|
      if triple.subject.eql?(temp_bnode)
        returnval = triple.subject
        break
      end
      if triple.object.eql?(temp_bnode)
        returnval = triple.object
        break
      end
    }
    return returnval
  end
#  alias :add, :add_triple
#  alias (=+, add_triple)
end