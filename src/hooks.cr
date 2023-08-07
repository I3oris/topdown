abstract class TopDown::Parser < TopDown::CharReader
  # Override this method to modify the default error message when `parse!('a')` fail.
  def hook_expected_character(got : Char, expected : Char)
    "Unexpected character '#{dump_in_error(got)}', expected character '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when `parse!('a'..'z')` fail.
  def hook_expected_any_in_range(got : Char, expected : Range(Char, Char))
    "Unexpected character '#{dump_in_error(got)}', expected any in range '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when `parse!(["TOKEN"])` fail.
  def hook_expected_token(got : Token?, expected : String)
    "Unexpected token '#{dump_in_error(got)}', expected token '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when any token can be parsed.
  def hook_could_not_parse_any_token(got : Char, expected : Nil)
    "Unexpected character '#{dump_in_error(got)}', could not parse any token"
  end

  # Override this method to modify the default error message when `parse!("string")` fail.
  def hook_expected_word(got : Char, expected : String)
    "Unexpected character '#{dump_in_error(got)}', expected word '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when `parse!(/regex/)` fail.
  def hook_expected_pattern(got : Char, expected : Regex)
    "Unexpected character '#{dump_in_error(got)}', expected pattern #{dump_in_error(expected)}"
  end

  # Override this method to modify the default error message when `parse!(:syntax)` fail.
  def hook_expected_syntax(got : Char, expected : Symbol)
    "Unexpected character '#{dump_in_error(got)}', expected syntax #{dump_in_error(expected)}"
  end

  def hook_union_failed(got : Char, expected : Nil)
    "Unexpected character '#{dump_in_error(got)}'"
  end

  # Override this method to modify the default error message when `parse!(not('a'))` fail.
  def hook_expected_any_character_but(got : Char, expected : Char)
    "Unexpected character, expected any character but '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when `parse!(not('a'..'z'))` fail.
  def hook_expected_any_character_but_range(got : Char, expected : Range(Char, Char))
    "Unexpected character, expected any character but range '#{dump_in_error(expected)}'"
  end

  # Override this method to modify the default error message when `parse!(not(["TOKEN"]))` fail.
  def hook_expected_any_token_but(got : Token?, expected : String)
    "Unexpected token, expected any token but '#{dump_in_error(expected)}'"
  end
end
