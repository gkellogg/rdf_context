class Array
  # http://wiki.rubygarden.org/Ruby/page/show/ArrayPermute
  # Permute an array, and call a block for each permutation
  # Author: Paul Battley
  def permute(prefixed=[])
    if (length < 2)
      # there are no elements left to permute
      yield(prefixed + self)
    else
      # recursively permute the remaining elements
      each_with_index do |e, i|
        (self[0,i]+self[(i+1)..-1]).permute(prefixed+[e]) { |a| yield a }
      end
    end
  end
  
  # Converts the array to a comma-separated sentence where the last element is joined by the connector word. Options:
  # @option [String] :words_connector (", ") The sign or word used to join the elements in arrays with two or more elements
  # @option [String] :two_words_connector (" and ") The sign or word used to join the elements in arrays with two elements
  # @option [String] :last_word_connector (", ") The sign or word used to join the elements in arrays with two or more elements
  def to_sentence(options = {})
    default_words_connector     = ", "
    default_two_words_connector = " and "
    default_last_word_connector = ", and "

    # Try to emulate to_senteces previous to 2.3
    if options.has_key?(:connector) || options.has_key?(:skip_last_comma)
      ::ActiveSupport::Deprecation.warn(":connector has been deprecated. Use :words_connector instead", caller) if options.has_key? :connector
      ::ActiveSupport::Deprecation.warn(":skip_last_comma has been deprecated. Use :last_word_connector instead", caller) if options.has_key? :skip_last_comma

      skip_last_comma = options.delete :skip_last_comma
      if connector = options.delete(:connector)
        options[:last_word_connector] ||= skip_last_comma ? connector : ", #{connector}"
      else
        options[:last_word_connector] ||= skip_last_comma ? default_two_words_connector : default_last_word_connector
      end
    end

#    options.assert_valid_keys(:words_connector, :two_words_connector, :last_word_connector, :locale)
    options = {:words_connector => default_words_connector, :two_words_connector => default_two_words_connector, :last_word_connector => default_last_word_connector}.merge(options)

    case length
      when 0
        ""
      when 1
        self[0].to_s
      when 2
        "#{self[0]}#{options[:two_words_connector]}#{self[1]}"
      else
        "#{self[0...-1].join(options[:words_connector])}#{options[:last_word_connector]}#{self[-1]}"
    end
  end
end
