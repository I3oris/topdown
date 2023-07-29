abstract class TopDown::Parser < TopDown::CharReader
  # Override this method to modify the default error message when `parse('a')` fail.
  def hook_unexpected_char(got : Char, expected : Char)
    "Unexpected character '#{dump_in_error(got)}', expected '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when `parse('a'..'z')` fail.
  def hook_unexpected_range_char(got : Char, expected : Range(Char, Char))
    "Unexpected character '#{dump_in_error(got)}', expected any in '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when `parse(["TOKEN"])` fail.
  def hook_unexpected_token(got : Token?, expected : String) forall Token
    "Unexpected token '#{dump_in_error(got)}', expected '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when any token can be parsed.
  def hook_could_not_parse_token(got : Char, expected : Nil)
    "Unexpected character '#{dump_in_error(got)}'"
  end

  # Override this method to modify the default error message when `parse("string")` fail.
  def hook_could_not_parse_string(got : Char, expected : String)
    "Unexpected character '#{dump_in_error(got)}', expected '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when `parse(/regex/)` fail.
  def hook_could_not_parse_regex(got : Char, expected : Regex)
    "Unexpected character '#{dump_in_error(got)}', expected pattern #{dump_in_error(expected)}"
  end

  # Override this method to modify the default error message when `parse(:syntax)` fail.
  def hook_could_not_parse_syntax(got : Char, expected : Symbol)
    "Unexpected character '#{dump_in_error(got)}', expected #{dump_in_error(expected)}"
  end
end
