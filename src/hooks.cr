class Let::Parser
  def hook_unexpected_char
    "Unexpected character '%{got}', expected '%{expected}'"
  end

  def hook_unexpected_token
    "Unexpected token '%{got}', expected '%{expected}'"
  end

  def hook_could_not_parse_string
    "Unexpected character '%{got}', expected matching with \"%{expected}\""
  end

  def hook_could_not_parse_regex
    "Unexpected character '%{got}', expected matching the patern /%{expected}/"
  end

  def hook_could_not_parse_syntax
    "Could not parse syntax '%{expected}'"
  end
end

class Let::CharReader
  def hook_skip_char?(char : Char)
    false
  end
end
