module Reddy
  # Abstract storage module, superclass of other storage classes
  class AbstractStore
    
    # Does store support contexts?
    def self.context_aware?; false; end
    
    # Does store support formulae?
    def self.formula_aware?; false; end
    
    # Silently eat unimplemented methods
    def method_missing meth, *args
    end
  end
end