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

  private macro parselet(parselet, raises? = false, error = nil, at = nil, with_precedence = nil, left = nil, &block)
    {% parselet = parselet.expressions[0] if parselet.is_a?(Expressions) && parselet.expressions.size == 1 %}

    skip_chars
    %result =
      {% if parselet.is_a? CharLiteral %}
        parselet_char({{parselet}}, {{raises?}}, {{error}}, {{at}})

      {% elsif parselet.is_a? RangeLiteral %}
        parselet_range({{parselet}}, {{raises?}}, {{error}}, {{at}})

      {% elsif parselet.is_a? StringLiteral %}
        parselet_string({{parselet}}, {{raises?}}, {{error}}, {{at}})

      {% elsif parselet.is_a? RegexLiteral %}
        parselet_regex({{parselet}}, {{raises?}}, {{error}}, {{at}})

      {% elsif parselet.is_a? SymbolLiteral %}
        parselet_syntax({{parselet}}, {{raises?}}, {{error}}, {{at}}, {{with_precedence}}, {{left}})

      {% elsif parselet.is_a? Call && parselet.name == "|" %}
        simple_union([parse({{parselet.receiver}}), parse({{parselet.args[0]}})], with_precedence: {{with_precedence || "_precedence_".id}}) # || 0 ?

      {% elsif parselet.is_a? Call && parselet.name == "not" %}
        parselet_not({{parselet.args[0]}}, {{raises?}}, {{error}}, {{at}})

      {% elsif parselet.is_a? Call && parselet.name == "any" %}
        parselet_any_char({{raises?}}, {{error}}, {{at}})

      {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 && parselet[0].is_a? Call && parselet[0].name == "any" %}
        parselet_any_token({{raises?}}, {{error}}, {{at}})

      {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 %}
        parselet_token({{parselet[0]}}, {{raises?}}, {{error}}, {{at}})

      {% else %}
        {% raise "Unsupported ASTNode #{parselet.class_name} : #{parselet}" %}
      {% end %}

    {% if block %}
      {% if with_precedence %} handle_fail({{with_precedence}}) do |_precedence_| {% end %}

        handle_fail(%result) {{ block }}

      {% if with_precedence %} end {% end %}
    {% end %}
  end

  private macro fail(raises?, error_message, at)
    {% if raises? %}
      raise_syntax_error({{error_message}}, at: {{at}})
    {% else %}
      break Fail.new
    {% end %}
  end

  private macro parselet_char(char, raises? = false, error = nil, at = nil)
    if peek_char != {{char}}
      fail {{raises?}}, error_message({{error}} || ->hook_expected_character(Char, Char), got: peek_char, expected: {{char}}), at: ({{at || "self.location".id}})
    else
      next_char
    end
  end

  private macro parselet_not_char(char, raises? = false, error = nil, at = nil)
    if peek_char == {{char}} || peek_char == '\0'
      fail {{raises?}}, error_message({{error}} || ->hook_expected_any_character_but(Char, Char), got: peek_char, expected: {{char}}), at: ({{at || "self.location".id}})
    else
      next_char
    end
  end

  private macro parselet_any_char(raises? = false, error = nil, at = nil)
    if peek_char == '\0'
      fail {{raises?}}, error_message({{error}} || ->hook_expected_any_character_but(Char, Char), got: '\0', expected: '\0'), at: ({{at || "self.location".id}})
    else
      next_char
    end
  end

  private macro parselet_range(range, raises? = false, error = nil, at = nil)
    if peek_char.in? {{range}}
      next_char
    else
      fail {{raises?}}, error_message({{error}} || ->hook_expected_any_in_range(Char, Range(Char, Char)), got: peek_char, expected: {{range}}), at: ({{at || "self.location".id}})
    end
  end

  private macro parselet_string(string, raises? = false, error = nil, at = nil)
    capture do
      {% for c in string.chars %}
        if peek_char != {{c}}
          fail {{raises?}}, error_message({{error}} || ->hook_expected_word(Char, String), got: peek_char, expected: {{string}}), at: ({{at || "self.location".id}})
        else
          next_char
        end
      {% end %}
    end
  end

  private macro parselet_not_string(string)
    %old_location = self.location
    %result = handle_fail do
      parselet_string({{string}})
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

  private macro parselet_regex(regex, raises? = false, error = nil, at = nil)
    if regex_match_start({{regex}}) =~ String.new(self.source.to_slice[self.location.pos..])
      @char_reader.pos += $0.bytesize
      $0.each_char { |ch| increment_location(ch) }
      $0
    else
      fail {{raises?}}, error_message({{error}} || ->hook_expected_pattern(Char, Regex), got: peek_char, expected: {{regex}}), at: ({{at || "self.location".id}})
    end
  end

  private macro parselet_syntax(syntax_name, raises? = false, error = nil, at = nil, with_precedence = nil, left = nil)
    %result = parse_{{syntax_name.id}}({{left}}, {{with_precedence || "_precedence_".id}})
    if %result.is_a? Fail
      fail {{raises?}}, error_message({{error}} || ->hook_expected_syntax(Char, Symbol), got: peek_char, expected: {{syntax_name}}), at: ({{at || "self.location".id}})
    else
      %result
    end
  end

  private macro parselet_not(parselet, raises? = false, error = nil, at = nil)
    {% if parselet.is_a? CharLiteral %}
      parselet_not_char({{parselet}}, {{raises?}}, {{error}}, {{at}})
    {% elsif parselet.is_a? StringLiteral %}
      parselet_not_string({{parselet}}) # TODO: raise version
    {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 %}
      parselet_not_token({{parselet[0]}}, {{raises?}}, {{error}}, {{at}})
    {% else %}
      {% raise "'not' arguments should be 'CharLiteral', 'StringLiteral' or 'ArrayLiteral' not #{parselet.class_name}: #{parselet}" %}
    {% end %}
  end
end
