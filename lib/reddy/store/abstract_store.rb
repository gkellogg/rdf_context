module Reddy
  # Abstract storage module, superclass of other storage classes
  class AbstractStore
    
    # Silently eat unimplemented methods
    def method_missing meth, *args
    end
  end
end