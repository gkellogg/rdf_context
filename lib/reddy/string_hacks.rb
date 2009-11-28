require 'iconv'

class String
  #private
  # "Borrowed" from JSON utf8_to_json
  RDF_MAP = {
    "\x0" => '\u0000',
    "\x1" => '\u0001',
    "\x2" => '\u0002',
    "\x3" => '\u0003',
    "\x4" => '\u0004',
    "\x5" => '\u0005',
    "\x6" => '\u0006',
    "\x7" => '\u0007',
    "\b"  =>  '\b',
    "\t"  =>  '\t',
    "\n"  =>  '\n',
    "\xb" => '\u000B',
    "\f"  =>  '\f',
    "\r"  =>  '\r',
    "\xe" => '\u000E',
    "\xf" => '\u000F',
    "\x10" => '\u0010',
    "\x11" => '\u0011',
    "\x12" => '\u0012',
    "\x13" => '\u0013',
    "\x14" => '\u0014',
    "\x15" => '\u0015',
    "\x16" => '\u0016',
    "\x17" => '\u0017',
    "\x18" => '\u0018',
    "\x19" => '\u0019',
    "\x1a" => '\u001A',
    "\x1b" => '\u001B',
    "\x1c" => '\u001C',
    "\x1d" => '\u001D',
    "\x1e" => '\u001E',
    "\x1f" => '\u001F',
    '"'   =>  '\"',
    '\\'  =>  '\\\\',
    '/'   =>  '/',
  } # :nodoc:

  # Convert a UTF8 encoded Ruby string _string_ to an escaped string, encoded with
  # UTF16 big endian characters as \U????, and return it.
  #
  # \\:: Backslash
  # \':: Single quote
  # \":: Double quot
  # \n:: ASCII Linefeed
  # \r:: ASCII Carriage Return
  # \t:: ASCCII Horizontal Tab
  # \uhhhh:: character in BMP with Unicode value U+hhhh
  # \U00hhhhhh:: character in plane 1-16 with Unicode value U+hhhhhh
  def rdf_escape
    string = self + '' # XXX workaround: avoid buffer sharing
    string.force_encoding(Encoding::ASCII_8BIT) if String.method_defined?(:force_encoding)
    string.gsub!(/["\\\/\x0-\x1f]/) { RDF_MAP[$&] }
    string.gsub!(/(
                    (?:
                      [\xc2-\xdf][\x80-\xbf]    |
                      [\xe0-\xef][\x80-\xbf]{2} |
                      [\xf0-\xf4][\x80-\xbf]{3}
                    )+ |
                    [\x80-\xc1\xf5-\xff]       # invalid
                  )/nx) { |c|
                    c.size == 1 and raise TypeError, "invalid utf8 byte: '#{c}'"
                    s = Iconv.new('utf-16be', 'utf-8').iconv(c).unpack('H*')[0].upcase
                    s.gsub!(/.{4}/n, '\\\\u\&')
                  }
    string.force_encoding(Encoding::UTF_8) if String.method_defined?(:force_encoding)
    string
  end
  
  # Unescape characters in strings.
  RDF_UNESCAPE_MAP = Hash.new { |h, k| h[k] = k.chr }
  RDF_UNESCAPE_MAP.update({
    ?"  => '"',
    ?\\ => '\\',
    ?/  => '/',
    ?b  => "\b",
    ?f  => "\f",
    ?n  => "\n",
    ?r  => "\r",
    ?t  => "\t",
    ?u  => nil, 
  })

  # Reverse operation of escape
  # From JSON parser
  def rdf_unescape
    return '' if self.empty?
    string = self.gsub(%r((?:\\[\\bfnrt"/]|(?:\\u(?:[A-Fa-f\d]{4}))+|\\[\x20-\xff]))n) do |c|
      if u = RDF_UNESCAPE_MAP[$&[1]]
        u
      else # \uXXXX
        bytes = [c[2, 2].to_i(16), c[4, 2].to_i(16)]
        Iconv.new('utf-8', 'utf-16').iconv(bytes.pack("C*"))
      end
    end
    if string.respond_to?(:force_encoding)
      string.force_encoding(Encoding::UTF_8)
    end
    string
  rescue Iconv::Failure => e
    raise RdfException, "Caught #{e.class}: #{e}"
  end
end