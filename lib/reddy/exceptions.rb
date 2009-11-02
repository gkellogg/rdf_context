module Reddy
  class ParserException < RuntimeError; end
  class AboutEachException < ParserException; end
  class UriRelativeException < RuntimeError; end
end