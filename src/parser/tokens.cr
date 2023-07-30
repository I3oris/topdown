abstract class TopDown::Parser < TopDown::CharReader
  record Token(ValueType), name : Symbol, value : ValueType do
    # Display the token.
    #
    # ```
    # Token.new(:"+").to_s         # => "[+]"
    # Token.new(:name, "foo").to_s # => "[name:foo]"
    # ```
    def to_s(io)
      value = ":#{@value}".dump_unquoted if @value
      io << "[#{name.to_s.dump_unquoted}#{value}]"
    end

    # Same as `to_s`.
    def inspect(io)
      to_s(io)
    end
  end

  private def next_token?
    {% raise "No tokens definition found, use 'TopDown::Parser.tokens' macro to define tokens" %}
  end

  # This macro allows to define how tokens are parsed.
  #
  # Each line of the *block* correspond a token.
  #
  # ```
  # tokens do
  #   token("+")
  #   token("-")
  #   token("**")
  #   token("*")
  #   token("/")
  #   token("new_line", '\n')
  # end
  # ```
  #
  # Use `Parser.token` to define how a token is parsed
  #
  # The order of token matter, because there are parsed in this order.
  # Hence, if `*` is moved before `**`, the result will be two token `*` parsed instead of one `**`.
  #
  #
  # In addition, characters are never skipped while parsing tokens (and all inner syntax calls), see `no_skip`.
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

    {% macro_tokens_map = {} of MacroId => StringLiteral %}
    {% for node in block.body.expressions %}
      {% if (call = node) && call.is_a? Call && call.name == "token"
           macro_tokens_map[call.args[0]] = "typeof(#{call})".id
         else
           raise "Only the macro call 'token(token_name, parselet = nil, &block)' is accepted inside the macro 'Parser.tokens'"
         end %}
    {% end %}

    private MACRO_TOKENS_MAP = {{ macro_tokens_map }}
  end

  # Defines a token to parse. Can be used only inside [`Parser.tokens`](#tokens(&block)-macro).
  #
  # Each token have a *token_name* (`StringLiteral`), and is parsed according to *parselet*.
  # The *block* indicate the value of the resulting `Token`.
  #
  # * If no *parselet* provided, it deduced from *token_name*.
  # * If no *block* provided, token *value* is nil. (use `&.itself` to actually keep the parsed string)
  #
  # Example:
  #
  # ```
  # tokens do
  #   token("+")                            # Parses '+', produces Token[+]
  #   token("hey")                          # Parses "hey", produces Token[hey]
  #   token("new_line", '\n')               # Parses '\n', produces Token[new_line]
  #   token("int", /\d+/) { |v| v.to_i }    # Parses /\d+/, produces Token[int:<int_value>]
  #   token("string", :tk_string, &.itself) # Parses syntax :tk_string, produces Token[string:<string_value>]
  # end
  # ```
  macro token(token_name, parselet = nil, &block)
    {% parselet ||= token_name %}
    {% block ||= "{ nil }".id %}
    %result = parse({{parselet}}) {{block}}
    break Fail.new if %result.is_a? Fail

    Token.new({{token_name.id.symbolize}}, %result)
  end

  private macro consume_token(token_name)
    {% type = MACRO_TOKENS_MAP[token_name] %}
    {% raise "The token [#{token_name}] is not defined. Add 'token(#{token_name})' inside the macro 'Parser.tokens' to define it" unless type %}

    skip_chars
    %token = next_token?.as?({{type}})
    if %token && %token.name == {{token_name.id.symbolize}}
      %token.value
    else
      break Fail.new
    end
  end

  private macro consume_token!(token_name, error = nil, at = nil)
    {% type = MACRO_TOKENS_MAP[token_name] %}
    {% raise "The token [#{token_name}] is not defined. Add 'token(#{token_name})' inside the macro 'Parser.tokens' to define it" unless type %}

    skip_chars
    %begin_location = self.location
    %token = next_token?
    if %token && %token.name == {{token_name.id.symbolize}}
      %token.as({{type}}).value
    else
      raise_syntax_error error_message({{error}} || ->hook_unexpected_token(typeof(%token), String), got: %token, expected: {{token_name}}), at: ({{at}}) || (%begin_location..)
    end
  end

  private macro consume_not_token(token_name)
    {% type = MACRO_TOKENS_MAP[token_name] %}
    {% raise "The token [#{token_name}] is not defined. Add 'token(#{token_name})' inside the macro 'Parser.tokens' to define it" unless type %}

    skip_chars
    %token = next_token?
    if %token.nil? || %token.name == {{token_name.id.symbolize}}
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
  # The token name *eof* can be given to stop at that name.
  # Can be useful if a EOF token have been defined.
  def each_token(eof = nil, &) : Nil
    begin_location = self.location

    skip_chars
    while token = next_token?
      break if eof && token.name == eof

      yield token
      skip_chars
    end
    self.location = begin_location
  end

  # Returns the array of parsed tokens.
  #
  # Stops when EOF is hit, or raises if a token fail to parse.
  #
  # The token name *eof* can be given to stop at that name.
  # Can be useful if a EOF token have been defined.
  def tokens(eof = nil)
    tokens = [] of typeof(next_token?.not_nil!) # ameba:disable Lint/NotNil

    each_token(eof) do |token|
      tokens << token
    end
    tokens
  end
end
