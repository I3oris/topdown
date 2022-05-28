abstract class Let::Parser < Let::CharReader
  # TODO: docs
  record Token, type : Symbol, value = "" do
    def is?(type : Symbol)
      @type == type
    end

    def to_s(io)
      value = ":#{@value}".dump_unquoted unless value.empty?
      io << "Token[#{type.to_s.dump_unquoted}#{value}]"
    end
  end

  private def next_token
    {% raise "No tokens definition found, use 'Let::Parser.tokens' macro to define tokens" %}
  end

  # TODO: docs
  macro tokens(&block)
    private def next_token
      _precedence_ = 0
      %result = fail_zone do
        _union_ do
          {{ yield }}
          parse('\0') { Token.new(:EOF) }
        end
      end
      if %result.is_a? Fail
        raise_syntax_error hook_unexpected_char % {got: char_to_s(peek_char), expected: nil} # TODO: change this
      end
      %result
    end
  end

  private macro consume_token(type)
    %token = next_token
    if %token.is?({{type}})
      %token.value
    else
      break Fail.new
    end
  end

  private macro consume_token!(token_type, error = nil)
    %token = next_token
    if %token.is?({{token_type}})
      %token.value
    else
      raise_syntax_error ({{error}} || hook_unexpected_token) % {got: %token.type, expected: {{token_type}}}
    end
  end

  # TODO: docs
  def each_token
    until (token = next_token).is?(:EOF)
      yield token
    end
  end
end
