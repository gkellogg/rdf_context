module Matchers
  class BeEquivalentGraph
    def initialize(expected, info)
      @expected = case expected
      when Graph then expected
      when Array then N3Parser.new(expected.join("\n"), info.about).graph
      when String then N3Parser.new(expected, info.about).graph
      when N3Parser then expected.graph
      else nil
      end
      @info = info
    end
    def matches?(actual)
      @actual = case actual
      when Graph then actual
      when Array then N3Parser.new(actual.join("\n"), @info.about).graph
      when String then N3Parser.new(actual, @info.about).graph
      when N3Parser then actual.graph
      else nil
      end
      @last_line = 0
      @sorted_actual = @actual.triples.sort_by{|t| t.to_ntriples}
      @sorted_expected = @expected.triples.sort_by{|t| t.to_ntriples}
      0.upto(@sorted_actual.length) do |i|
        @last_line = i
        a = @sorted_actual[i]
        b = @sorted_expected[i]
        return false unless a == b
      end
      @sorted_actual.length == @sorted_expected.length
    end
    def failure_message_for_should
      info = @info.respond_to?(:information) ? @info.information : ""
      if @last_line < @sorted_actual.length && @sorted_expected[@last_line]
        "Graph differs at entry #{@last_line}:\nexpected: #{@sorted_expected[@last_line].to_ntriples}\nactual:   #{@sorted_actual[@last_line].to_ntriples}"
      elsif @last_line < @actual.triples.length
        "Graph differs at entry #{@last_line}:\nunexpected: #{@sorted_actual[@last_line].to_ntriples}"
      else
        "Graph entry count differs:\nexpected: #{@sorted_expected.length}\nactual:   #{@sorted_actual.length}"
      end +
      "\n\n#{info + "\n" unless info.empty?}" +
      "Unsorted Expected:\n#{@expected.to_ntriples}" +
      "Unsorted Results:\n#{@actual.to_ntriples}" +
      "\nDebug:\n#{@info.trace}"
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
