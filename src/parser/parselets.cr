abstract class TopDown::Parser < TopDown::CharReader
  # This type is used for documentation purpose only. It represents an element to parse inside macro.
  #
  # Could be one of the following:
  # * a `CharLiteral`, to parse exactly one `Char`
  # * a `StringLiteral`, to parse an exact `String`
  # * a `RegexLiteral`, to parse the given pattern, returns the matched `String`. ($~, $0, $1, ... could be used after)
  # * a `RangeLiteral(Char, Char)`, to parse any `Char` between the range
  # * a `SymbolLiteral`, to parse an entire syntax, returns the result of the syntax, see `Parser.syntax`
  # * an one-value `ArrayLiteral`, to parse a token, returns the value of matched token
  # * a `Call`:
  #   * `|`: to parse a union, see `Parser.union`.
  #   * `any`, to parse any `Char` except EOF.
  #   * `[any]`, to parse any token except EOF.
  #   * `not(parselet)`, to parse any char, except if *parselet* matches.
  #  ```
  # parse('💎')
  # parse("foo")
  # parse(/\d+/, &.to_i)
  # parse(/"(([^"\\]|\\.)*)"/) { $1 }
  # parse(:expression)
  # parse(["+="])
  #
  # parse("foo" | :value | '💎')
  # # equivalent to:
  # union do
  #   parse("foo")
  #   parse(:value)
  #   parse('💎')
  # end
  #
  # parse(any)        # any char except '\0'
  # parse([any])      # any token except EOF
  # parse(not('\n'))  # any char except '\n' & EOF
  # parse(not(["+"])) # any token except "+" & EOF
  # parse(not("foo")) # any char or fail on "foo".
  #  ```
  # See [`Parser.parse`](#parse(parselet,with_precedence=nil,&block)-macro).
  class ParseletLiteral
  end

  private macro consume_char(char)
    skip_chars
    if peek_char != {{char}}
      break Fail.new
    else
      next_char
    end
  end

  private macro consume_char!(char, error = nil, at = nil)
    skip_chars
    if peek_char != {{char}}
      raise_syntax_error error_message({{error}} || ->hook_unexpected_char(Char, Char), got: peek_char, expected: {{char}}), at: ({{at || "self.location".id}})
    else
      next_char
    end
  end

  private macro consume_not_char(char)
    skip_chars
    if peek_char == {{char}} || peek_char == '\0'
      break Fail.new
    else
      next_char
    end
  end

  private macro consume_any_char
    if peek_char == '\0'
      break Fail.new
    else
      next_char
    end
  end

  private macro consume_range(range)
    if peek_char.in? {{range}}
      next_char
    else
      break Fail.new
    end
  end

  private macro consume_range!(range, error = nil, at = nil)
    if peek_char.in? {{range}}
      next_char
    else
      raise_syntax_error error_message({{error}} || ->hook_unexpected_range_char(Char, Range(Char, Char)), got: peek_char, expected: {{range}}), at: ({{at || "self.location".id}})
    end
  end

  private macro consume_string(string)
    skip_chars
    capture do
      no_skip do
        {% for c in string.chars %}
          consume_char({{c}})
        {% end %}
      end
    end
  end

  private macro consume_string!(string, error = nil, at = nil)
    skip_chars
    %result = handle_fail do
      capture do
        no_skip do
          {% for c in string.chars %}
            consume_char({{c}})
          {% end %}
        end
      end
    end
    if %result.is_a? Fail
      raise_syntax_error error_message({{error}} || ->hook_could_not_parse_string(Char, String), got: peek_char, expected: {{string}}), at: ({{at || "self.location".id}})
    end
    %result
  end

  private macro consume_not_string(string)
    %old_location = self.location
    %result = handle_fail do
      consume_string({{string}})
    end
    if %result.is_a? Fail
      self.location = %old_location
      break Fail.new if peek_char == '\0'
      next_char
      nil
    else
      break Fail.new
    end
  end

  private macro consume_regex(regex)
    skip_chars
    if regex_match_start({{regex}}) =~ String.new(self.source.to_slice[self.location.pos..])
      @char_reader.pos += $0.bytesize
      $0.each_char { |ch| increment_location(ch) }
      $0
    else
      break Fail.new
    end
  end

  private macro consume_regex!(regex, error = nil, at = nil)
    skip_chars
    if regex_match_start({{regex}}) =~ String.new(self.source.to_slice[self.location.pos..])
      @char_reader.pos += $0.bytesize
      $0.each_char { |ch| increment_location(ch) }
      $0
    else
      raise_syntax_error error_message({{error}} || ->hook_could_not_parse_regex(Char, Regex), got: peek_char, expected: {{regex}}), at: ({{at || "self.location".id}})
    end
  end

  private macro consume_syntax(syntax_name, with_precedence = nil)
    skip_chars
    %result = parse_{{syntax_name.id}}(nil, {{with_precedence || "_precedence_".id}})
    if %result.is_a? Fail
      break Fail.new
    else
      %result
    end
  end

  private macro consume_syntax!(syntax_name, error = nil, at = nil, with_precedence = nil)
    skip_chars
    %result = parse_{{syntax_name.id}}(nil, {{with_precedence || "_precedence_".id}})
    if %result.is_a? Fail
      raise_syntax_error error_message({{error}} || ->hook_could_not_parse_syntax(Char, Symbol), got: peek_char, expected: {{syntax_name}}), at: ({{at || "self.location".id}})
    else
      %result
    end
  end

  private macro consume_not(parselet)
    {% if parselet.is_a? CharLiteral %}
      consume_not_char({{parselet}})
    {% elsif parselet.is_a? StringLiteral %}
      consume_not_string({{parselet}})
    {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 %}
      consume_not_token({{parselet[0]}})
    {% else %}
      {% raise "'not' arguments should be 'CharLiteral', 'StringLiteral' or 'ArrayLiteral' not #{parselet.class_name}: #{parselet}" %}
    {% end %}
  end
end
