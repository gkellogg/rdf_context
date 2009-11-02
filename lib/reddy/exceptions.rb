module Reddy
  class RdfException < RuntimeError; end
  class ParserException < RdfException; end
  class GraphException < RdfException; end
  class TypeError < RdfException; end
  class AboutEachException < ParserException; end
  class UriRelativeException < RdfException; end
  class InvalidPredicate < RdfException; end
  class InvalidSubject < RdfException; end
  class InvalidObject < RdfException; end
end