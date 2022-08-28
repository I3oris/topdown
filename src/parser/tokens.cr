abstract class TopDown::Parser < TopDown::CharReader
  # A type that can be returned when using [`Parser.tokens`](../Parser.html#tokens(&block)-macro).
  #
  # It's composed from a generic `type` (usually a `Symbol` or an `Enum`), and a `value`.
  # ```
  # tokens do
  #   parse('+') { Token.new(:"+") }
  #   parse(/\w+/) { Token.new(:name, $0) }
  #   parse('*') { Token(MyTokenTypeEnum).new(:STAR) }
  # end
  # ```
  #
  # NOTE: Currently only a `String` `value` is supported, this may change in the future.
  record Token(TokenType), type : TokenType, value = "" do
    # Returns true if *type* is equal to this token `type`.
    #
    # A similar method should be implemented on any class used for [`Parser.tokens`](../Parser.html#tokens(&block)-macro).
    def is?(type : TokenType)
      @type == type
    end

    # Display the token.
    #
    # ```
    # Token.new(:"+").to_s         # => "[+]"
    # Token.new(:name, "foo").to_s # => "[name:foo]"
    # ```
    def to_s(io)
      value = ":#{@value}".dump_unquoted unless value.empty?
      io << "[#{type.to_s.dump_unquoted}#{value}]"
    end

    # Same as `to_s`.
    def inspect(io)
      to_s(io)
    end
  end

  private def next_token?
    {% raise "No tokens definition found, use 'TopDown::Parser.tokens' macro to define tokens" %}
  end

  # This macro allows to define how token are parsed.
  #
  # Members of the *block* works similarity to an `union`, on which each member would correspond a token.
  #
  # ```
  # tokens do
  #   parse('+') { Token.new(:"+") }
  #   parse('-') { Token.new(:"-") }
  #   parse("**") { Token.new(:"**") }
  #   parse('*') { Token.new(:"*") }
  #   parse('/') { Token.new(:"/") }
  #   parse('\n') { Token.new(:new_line) }
  # end
  # ```
  # Hence, the order of token matter, if `'*'` is moved before `"**"`, two token `:"*"` would be parsed and `:"**"` would never.
  #
  # The returned result should an object that implements a method `is?(type)`,
  # which will allow `parse([<token_type>])` to know if the object is of type `<token_type>`.
  #
  #
  # Member can be any usual `parse`, meaning a `syntax` can be used:
  #
  # ```
  # tokens do
  #   ...
  #   parse(:tk_string) { |str| Token.new(:string, str) }
  # end
  #
  # syntax(:tk_string, '"') do
  #   partial_capture do |io|
  #     io << repeat { parse(not('"')) }
  #     parse!('"')
  #   end
  # end
  # ```
  #
  # Moreover, characters are never skipped while parsing tokens (and all inner syntax calls), see `no_skip`.
  macro tokens(&block)
    private def next_token?
      _precedence_ = 0
      %result = handle_fail do
        no_skip do
          _union_ do
            {{ yield }}
            parse('\0') { nil }
          end
        end
      end
      if %result.is_a? Fail
        raise_syntax_error error_message(->hook_could_not_parse_token(Char, Nil), got: peek_char, expected: nil)
      end
      %result
    end
  end

  private macro consume_token(token_type)
    skip_chars
    %token = next_token?
    if %token && %token.is?({{token_type}})
      %token.value
    else
      break Fail.new
    end
  end

  private macro consume_token!(token_type, error = nil, at = nil)
    skip_chars
    %begin_location = self.location
    %token = next_token?
    if %token && %token.is?({{token_type}})
      %token.value
    else
      raise_syntax_error error_message({{error}} || ->hook_unexpected_token(typeof(%token), typeof({{token_type}})), got: %token, expected: {{token_type}}), at: ({{at}}) || (%begin_location..)
    end
  end

  private macro consume_not_token(token_type)
    skip_chars
    %token = next_token?
    if %token.nil? || %token.is?({{token_type}})
      break Fail.new
    else
      %token.value
    end
  end

  private macro consume_any_token
    %token = next_token?
    if %token.nil?
      break Fail.new
    else
      %token.value
    end
  end

  # Yields successively parsed tokens.
  #
  # Stops when EOF is hit, or raises if a token fail to parse.
  #
  # The token type *eof* can be given to stop at that type.
  # Can be useful if a EOF token have been defined.
  def each_token(eof = nil, &) : Nil
    begin_location = self.location

    skip_chars
    while token = next_token?
      break if eof && token.is?(eof)

      yield token
      skip_chars
    end
    self.location = begin_location
  end

  # Returns the array of parsed tokens.
  #
  # Stops when EOF is hit, or raises if a token fail to parse.
  #
  # The token type *eof* can be given to stop at that type.
  # Can be useful if a EOF token have been defined.
  def tokens(eof = nil)
    tokens = [] of typeof(next_token?.not_nil!)

    each_token(eof) do |token|
      tokens << token
    end
    tokens
  end
end
