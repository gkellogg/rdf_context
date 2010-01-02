require 'rdf/redland'

module Matchers
  class BeEquivalentGraph
    def normalize(graph)
      case graph
      when Graph then graph
      when Parser then graph.graph
      else
        triples = [graph].flatten.join("\n")
        N3Parser.parse(graph.to_s, @info.about, :strict => true)
      end
    end
    
    def initialize(expected, info)
      @info = info
      @expected = normalize(expected)
    end

    def matches?(actual)
      @actual = normalize(actual)
      @actual == @expected
    end

    def failure_message_for_should
      info = @info.respond_to?(:information) ? @info.information : ""
      if @actual.size != @expected.size
        "Graph entry count differs:\nexpected: #{@expected.size}\nactual:   #{@actual.size}"
      elsif @actual.identifier != @expected.identifier
        "Graph identifiers differ:\nexpected: #{@expected.identifier}\nactual:   #{@actual.identifier}"
      else
        "Graph differs\n"
      end +
      "\n\n#{info + "\n" unless info.empty?}" +
      "Unsorted Expected:\n#{@expected.to_ntriples}" +
      "Unsorted Results:\n#{@actual.to_ntriples}" +
      (@info.respond_to?(:trace) ? "\nDebug:\n#{@info.trace}" : "")
    end
    def negative_failure_message
      "Graphs do not differ\n"
    end
  end
  
  def be_equivalent_graph(expected, info = "")
    BeEquivalentGraph.new(expected, info)
  end

  # Run expected SPARQL query against actual
  class PassQuery
    def initialize(expected, info)
      @expected = expected
      @query = Redland::Query.new(expected)
      @info = info
    end
    def matches?(actual)
      @actual = actual
      @expected_results = @info.respond_to?(:expectedResults) ? @info.expectedResults : true
      model = Redland::Model.new
      ntriples_parser = Redland::Parser.ntriples
      ntriples_parser.parse_string_into_model(model, actual.to_ntriples, "http://www.w3.org/2006/07/SWD/RDFa/testsuite/xhtml1-testcases/")

      @results = @query.execute(model)
      if @expected_results
        @results.is_boolean? && @results.get_boolean?
      else
        @results.nil? || @results.is_boolean? && !@results.get_boolean?
      end
    end
    def failure_message_for_should
      info = @info.respond_to?(:information) ? @info.information : ""
      "#{info + "\n" unless info.empty?}" +
      if @results.nil?
        "Query failed to return results"
      elsif !@results.is_boolean?
        "Query returned non-boolean results"
      elsif @expected_results
        "Query returned false"
      else
        "Query returned true (expected false)"
      end +
      "\n#{@expected}" +
      "\n#{@info.input}" +
      "\nResults:\n#{@actual.to_ntriples}" +
      "\nDebug:\n#{@info.trace}"
    end
  end

  def pass_query(expected, info = "")
    PassQuery.new(expected, info)
  end

  class BeValidXML
    def initialize(info)
      @info = info
    end
    def matches?(actual)
      @actual = actual
      @doc = Nokogiri::XML.parse(actual)
      @results = @doc.validate
      @results.nil?
    rescue
      false
    end
    def failure_message_for_should
      "#{@info + "\n" unless @info.empty?}" +
      if @doc.nil?
        "did not parse"
      else
        "\n#{@results}" +
        "\nParsed:\n#{@doc}"
      end   +
        "\nActual:\n#{@actual}"
    end
  end
  
  def be_valid_xml(info = "")
    BeValidXML.new(info)
  end

  class BeEquivalentXML
    def initialize(expected, info)
      @expected = expected
      @info = info
    end
    
    def matches?(actual)
      @actual = actual

      a = "<foo>#{@actual}</foo>" unless @actual.index("<") == 0
      e = "<foo>#{@expected}</foo>" unless @actual.index("<") == 0
      a_hash = ActiveSupport::XmlMini.parse(a)
      e_hash = ActiveSupport::XmlMini.parse(e)
      a_hash == e_hash
    rescue
      @fault = $!.message
      false
    end

    def failure_message_for_should
      "#{@info + "\n" unless @info.empty?}" +
      "#{@fault + "\n" unless @fault.nil?}" +
      "Expected:\n#{@expected}\n" +
      "Actual:#{@actual}"
    end
  end
  
  def be_equivalent_xml(expected, info = "")
    BeEquivalentXML.new(expected, info)
  end
end
