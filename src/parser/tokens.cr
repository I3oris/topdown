abstract class TopDown::Parser < TopDown::CharReader
  # TODO: docs
  record Token(TokenType), type : TokenType, value = "" do
    def is?(type : TokenType)
      @type == type
    end

    def to_s(io)
      value = ":#{@value}".dump_unquoted unless value.empty?
      io << "[#{type.to_s.dump_unquoted}#{value}]"
    end

    def inspect(io)
      to_s(io)
    end
  end

  private def next_token?
    {% raise "No tokens definition found, use 'TopDown::Parser.tokens' macro to define tokens" %}
  end

  # TODO: docs
  macro tokens(&block)
    private def next_token?
      _precedence_ = 0
      %result = fail_zone do
        no_skip do
          _union_ do
            {{ yield }}
            parse('\0') { nil }
          end
        end
      end
      if %result.is_a? Fail
        raise_syntax_error hook_unexpected_char % {got: char_to_s(peek_char), expected: nil} # TODO: change this
      end
      %result
    end
  end

  private macro consume_token(type)
    skip_chars
    %token = next_token?
    if %token && %token.is?({{type}})
      %token.value
    else
      break Fail.new
    end
  end

  private macro consume_token!(token_type, error = nil)
    skip_chars
    %begin_location = self.location
    %token = next_token?
    if %token && %token.is?({{token_type}})
      %token.value
    else
      raise_syntax_error ({{error}} || hook_unexpected_token) % {got: %token.try &.type, expected: {{token_type}}}, begin_location: %begin_location
    end
  end

  # TODO: docs
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

  # TODO: docs
  def tokens(eof = nil)
    tokens = [] of typeof(next_token?.not_nil!)

    each_token(eof) do |token|
      tokens << token
    end
    tokens
  end
end
