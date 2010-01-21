# An XSD duration
module RdfContext
  class Duration
    attr_accessor :ne, :yr, :mo, :da, :hr, :mi, :se
  
    # * Given an integer, assumes that it is milliseconds
    # * Given a time, extract second
    # * Given a Flaat, use value direcly
    # * Given a String, parse as xsd:duration
    def initialize(value)
      case value
      when Hash
        @ne = value[:ne] || 1
        @yr = value[:yr] || value[:years] || 0
        @mo = value[:mo] || value[:months] || 0
        @da = value[:da] || value[:days] || 0
        @hr = value[:hr] || value[:hours] || 0
        @mi = value[:mi] || value[:minutes] || 0
        @se = value[:se] || value[:seconds] || 0
      when Duration
        @se = value.to_f
      when Numeric
        @se = value
      else
        @se = value.to_i
      end
      
      self.normalize
    end
  
    def self.parse(value)
      # Reverse convert from XSD version of duration
      # XSD allows -P1111Y22M33DT44H55M66.666S with any combination in regular order
      # We assume 1M == 30D, but are out of spec in this regard
      # We only output up to hours
      if value.to_s.match(/^(-?)P(\d+Y)?(\d+M)?(\d+D)?T?(\d+H)?(\d+M)?([\d\.]+S)?$/)
        hash = {}
        hash[:ne] = $1 == "-" ? -1 : 1
        hash[:yr] = $2.to_i
        hash[:mo] = $3.to_i
        hash[:da] = $4.to_i
        hash[:hr] = $5.to_i
        hash[:mi] = $6.to_i
        hash[:se] = $7.to_f
        value = hash
      end

      self.new(value)
    end
    
    def to_f
      (((((@yr.to_i * 12 + @mo.to_i) * 30 + @da.to_i) * 24 + @hr.to_i) * 60 + @mi.to_i) * 60 + @se.to_f) * (@ne || 1)
    end
    
    def to_i; Integer(self.to_f); end
    def eql?(something)
      case something
      when Duration
        self.to_f == something.to_f
      when String
        self.to_s(:xml) == something
      when Numeric
        self.to_f == something
      else
        false
      end
    end
    alias_method :==, :eql?
   
    def to_s(format = nil)
      usec = (@se * 1000).to_i % 1000
      sec_str = usec > 0 ? "%2.3f" % @se : @se.to_i.to_s
      
      if format == :xml
        str = @ne < 0 ? "-P" : "P"
        str << "%dY" % @yr if @yr > 0
        str << "%dM" % @mo if @mo > 0
        str << "%dD" % @da if @da > 0
        str << "T" if @hr + @mi + @se > 0
        str << "%dH" % @hr if @hr > 0
        str << "%dM" % @mi if @mi > 0
        str << "#{sec_str}S" if @se > 0
      else
        ar = []
        ar << "%d years"    % @yr     if @yr > 0
        ar << "%d months"   % @mo     if @mo > 0
        ar << "%d days"     % @da     if @da > 0
        ar << "%d hours"    % @hr     if @hr > 0
        ar << "%d minutes"  % @mi     if @mi > 0
        ar << "%s seconds"  % sec_str if @se > 0
        last = ar.pop
        first = ar.join(", ")
        res = first.empty? ? last : "#{first} and #{last}"
        ne < 0 ? "#{res} ago" : res
      end
    end
    
    protected
    
      # Normalize representation by adding everything up and then breaking it back down again
      def normalize
        s = self.to_f
        
        @ne = s < 0 ? -1 : 1
        s = s * @ne
        _mi, @se = s.divmod(60)
        _hr, @mi = _mi.to_i.divmod(60)
        _da, @hr = _hr.divmod(24)
        _mo, @da = _da.divmod(30)
        @yr, @mo = _mo.divmod(12)
      end
  end
end