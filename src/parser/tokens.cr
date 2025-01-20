abstract class TopDown::Parser < TopDown::CharReader
  record Token(ValueType), name : Symbol, value : ValueType, end_location : Location do
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

  @tokens = Array(Void*).new initial_capacity: 256
  @token_pos = 0

  # :inherit:
  def source=(source : String)
    super
    @tokens.clear
    @token_pos = 0
  end

  # :inherit:
  def location : Location
    Location.new(@char_reader.pos, @line_number, @line_pos, @token_pos)
  end

  # :inherit:
  def location=(location : Location)
    super
    @token_pos = location.token_pos
  end

  private def load_tokens
  end

  private def parse_token?
    {% raise "No tokens definition found, use 'TopDown::Parser.tokens' macro to define tokens" %}
  end

  private def peek_token?
    if token = @tokens[@token_pos]?
      Box(typeof(parse_token?)).unbox token
    end
  end

  private def consume_token(token)
    self.location = token.end_location
  end

  private def create_token(token_name : Symbol, value : Token)
    value.copy_with(end_location: self.location)
  end

  private def create_token(token_name : Symbol, value)
    Token.new(token_name, value, self.location)
  end

  # This macro allows to define how tokens are parsed.
  #
  # Each line of the *block* correspond a token.
  #
  # ```
  # class Parser < TopDown::Parser
  #   tokens do
  #     token("+")
  #     token("-")
  #     token("**")
  #     token("*")
  #     token("/")
  #     token("new_line", '\n')
  #   end
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
    private def parse_token?
      token = handle_fail do
        _union_ do
          {{ yield }}
          parse('\0') { nil }
        end
      end
      if token.is_a? Fail
        raise_syntax_error error_message(->hook_could_not_parse_any_token(Char, Nil), got: peek_char, expected: nil)
      end

      token
    end

    {% macro_tokens_map = {} of MacroId => StringLiteral %}
    {% for node in block.body.expressions %}
      {% if (call = node) && call.is_a? Call && call.name.starts_with? "token"
           macro_tokens_map[call.args[0]] = "typeof(#{call})".id
         else
           raise "Only the macro call 'token(token_name, parselet = nil, &block)' is accepted inside the macro 'Parser.tokens'"
         end %}
    {% end %}

    private MACRO_TOKENS_MAP = {{ macro_tokens_map }}

    private def load_tokens
      begin_location = self.location

      skip_chars!
      while token = parse_token?
        @tokens << Box.box token
        skip_chars!
      end

      self.location = begin_location
    end

    private def skip_chars
    end
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
  # class Parser < TopDown::Parser
  #   tokens do
  #     token("+")                            # Parses '+', produces Token[+]
  #     token("hey")                          # Parses "hey", produces Token[hey]
  #     token("new_line", '\n')               # Parses '\n', produces Token[new_line]
  #     token("int", /\d+/) { |v| v.to_i }    # Parses /\d+/, produces Token[int:<int_value>]
  #     token("string", :tk_string, &.itself) # Parses syntax :tk_string, produces Token[string:<string_value>]
  #   end
  # end
  # ```
  macro token(token_name, parselet = nil, context = nil, &block)
    {% if context %}
      break Fail.new unless {{context}}
    {% end %}

    {% parselet ||= token_name %}
    {% block ||= "{ nil }".id %}
    %result = parse({{parselet}}) {{block}}
    break Fail.new if %result.is_a? Fail

    @token_pos += 1
    create_token({{token_name.id.symbolize}}, %result)
  end

  private macro parselet_token(token_name, token_value = nil, raises? = false, error = nil, at = nil)
    {% type = MACRO_TOKENS_MAP[token_name] %}
    {% raise "The token [#{token_name}] is not defined. Add 'token(#{token_name})' inside the macro 'Parser.tokens' to define it" unless type %}

    %token = peek_token?
    if %token && %token.name == {{token_name.id.symbolize}} && ({{token_value.nil?}} || %token.value == {{token_value}})
      consume_token(%token)
      %token.as({{type}}).value
    else
      fail {{raises?}}, error_message({{error}} || ->hook_expected_token(typeof(%token), String), got: %token, expected: {{token_name}}), at: ({{at}}) || (self.location..(%token.try &.end_location || self.location))
    end
  end

  private macro parselet_not_token(token_name, raises? = false, error = nil, at = nil)
    {% type = MACRO_TOKENS_MAP[token_name] %}
    {% raise "The token [#{token_name}] is not defined. Add 'token(#{token_name})' inside the macro 'Parser.tokens' to define it" unless type %}

    %token = peek_token?
    if %token.nil? || %token.name == {{token_name.id.symbolize}}
      fail {{raises?}}, error_message({{error}} || ->hook_expected_any_token_but(typeof(%token), String), got: %token, expected: {{token_name}}), at: ({{at}}) || (self.location..(%token.try &.end_location || self.location))
    else
      consume_token(%token)
      %token.value
    end
  end

  private macro parselet_any_token(raises? = false, error = nil, at = nil)
    %token = peek_token?
    if %token.nil?
      fail {{raises?}}, error_message({{error}} || ->hook_expected_any_token_but(typeof(%token), String), got: %token, expected: "EOF"), at: ({{at}} || self.location)
    else
      consume_token(%token)
      %token.value
    end
  end

  # Yields successively parsed tokens.
  def each_token(&) : Nil
    load_tokens if @tokens.empty?

    @tokens.each do |token|
      yield Box(typeof(parse_token?.not_nil!)).unbox token # ameba:disable Lint/NotNil
    end
  end

  # Returns the array of parsed tokens.
  def tokens
    tokens = [] of typeof(parse_token?.not_nil!) # ameba:disable Lint/NotNil

    each_token do |token|
      tokens << token
    end
    tokens
  end

  # :nodoc:
  def each_token_unloaded(&) : Nil
    begin_location = self.location

    skip_chars!
    while token = parse_token?
      yield token
      skip_chars!
    end

    self.location = begin_location
  end

  # TODO docs
  macro contexts(*contexts)
    @token_contexts = [{{contexts[0]}}]

    {% for ctx in contexts %}
      def {{ctx.id}}?
        @token_contexts.last == {{ctx}}
      end
    {% end %}

    macro context_push(context)
      \{% if !({{contexts}}).includes?(context) %}
        \{% raise "Undefined context: #{context.id}" %}
      \{% end %}
      # puts "push \{{context.id}}"
      @token_contexts.push(\{{context}})
      nil
    end

    def context_pop
      @token_contexts.pop?
    end
  end
end
