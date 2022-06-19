abstract class TopDown::Parser < TopDown::CharReader
  # TODO: docs
  def hook_unexpected_char(got : Char, expected : Char)
    "Unexpected character '#{dump_in_error(got)}', expected '#{dump_in_error(expected)}'"
  end

  # TODO: docs
  def hook_unexpected_token(got : Token?, expected : TokenType) forall Token, TokenType
    "Unexpected token '#{dump_in_error(got)}', expected '#{dump_in_error(expected)}'"
  end

  # TODO: docs
  def hook_could_not_parse_token(got : Char, expected : Nil)
    "Unexpected character '#{dump_in_error(got)}'"
  end

  # TODO: docs
  def hook_could_not_parse_string(got : Char, expected : String)
    "Unexpected character '#{dump_in_error(got)}', expected '#{dump_in_error(expected)}'"
  end

  # TODO: docs
  def hook_could_not_parse_regex(got : Char, expected : Regex)
    "Unexpected character '#{dump_in_error(got)}', expected patern #{dump_in_error(expected)}"
  end

  # TODO: docs
  def hook_could_not_parse_syntax(got : Char, expected : Symbol)
    "Unexpected character '#{dump_in_error(got)}', expected #{dump_in_error(expected)}"
  end
end
