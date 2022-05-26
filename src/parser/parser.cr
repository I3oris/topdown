require "../char_reader"

abstract class Let::Parser < Let::CharReader
  def parse
    result = parse_root
    if result.is_a? Fail
      raise_syntax_error hook_could_not_parse_syntax % {got: char_to_s(peek_char), expected: "root"}
    end

    consume_char!('\0')
    result
  end

  private def parse_root
    {% raise "Root syntax is not definied, use 'Let::Parser.root' macro to define the root" %}
  end

  macro root(parselet)
    private def parse_root
      parse!({{parselet}}, with_precedence: 0)
    end
  end

  struct Fail
  end

  private def fail_zone(*args)
    yield *args
  end

  macro capture
    %pos = self.location.pos
    {{ yield }}
    self.string[%pos...self.location.pos]
  end

  macro partial_capture(&block)
    {% raise "partial_capture should have one block argument" unless block.args[0] %}
    {{block.args[0].id}} = String::Builder.new
    {{ yield }}
    {{block.args[0].id}}.to_s
  end

  private macro consume_char(char)
    if peek_char != {{char}}
      break Fail.new
    else
      next_char
    end
  end

  private macro consume_char!(char, error = nil)
    if peek_char != {{char}}
      raise_syntax_error ({{error}} || hook_unexpected_char) % {got: char_to_s(peek_char), expected: char_to_s({{char}}) }
    else
      next_char
    end
  end

  private macro consume_not_char(char)
    if peek_char == {{char}} || peek_char == '\0'
      break Fail.new
    else
      next_char
    end
  end

  private macro consume_string(string)
    capture do
      {% for c in string.chars %}
        consume_char({{c}})
      {% end %}
    end
  end

  private macro consume_string!(string, error = nil)
    %result = fail_zone do
      capture do
        {% for c in string.chars %}
          consume_char({{c}})
        {% end %}
      end
    end
    if %result.is_a? Fail
      raise_syntax_error ({{error}} || hook_unexpected_string) % {got: char_to_s(peek_char), expected: {{string}}.dump_unquoted }
    end
    %result
  end

  private macro consume_regex(regex)
    peek_char # skip char if any
    if regex_match_start({{regex}}) =~ self.string[self.location.pos..]
      @char_reader.pos += $0.size
      $0.each_char { |ch| increment_location(ch) }
      $0
    else
      break Fail.new
    end
  end

  private macro consume_regex!(regex, error = nil)
    peek_char # skip char if any
    if regex_at_start({{regex}}) =~ self.string[self.location.pos..]
      @char_reader.pos += $0.size
      $0.each_char { |ch| increment_location(ch) }
      $0
    else
      raise_syntax_error ({{error}} || hook_could_not_parse_regex) % {got: char_to_s(peek_char), expected: {{regex}}.source }
    end
  end

  private macro consume_syntax(syntax_name, with_precedence = nil)
    peek_char # skip char if any
    %result = parse_{{syntax_name.id}}({{with_precedence || "_precedence_".id}})
    if %result.is_a? Fail
      break Fail.new
    else
      %result
    end
  end

  private macro consume_syntax!(syntax_name, error = nil, with_precedence = nil)
    peek_char # skip char if any
    %result = parse_{{syntax_name.id}}({{with_precedence || "_precedence_".id}})
    if %result.is_a? Fail
      raise_syntax_error ({{error}} || hook_could_not_parse_syntax) % {got: char_to_s(peek_char), expected: {{syntax_name}} }
    else
      %result
    end
  end

  private macro consume_token(type)
    %token = next_token
    if %token.type != {{type}}
      break Fail.new
    else
      %token.value
    end
  end

  private macro consume_token!(token_type, error = nil)
    %token = next_token
    if %token.type != {{token_type}}
      raise_syntax_error ({{error}} || hook_unexpected_token) % {got: %token.type, expected: {{token_type}} }
    else
      %token.value
    end
  end

  macro parse(parselet, with_precedence = nil, &block)
    {% parselet = parselet.expressions[0] if parselet.is_a?(Expressions) && parselet.expressions.size == 1 %}

    {% if parselet.is_a? CharLiteral %}
      %result = consume_char({{parselet}})

    {% elsif parselet.is_a? StringLiteral %}
      %result = consume_string({{parselet}})

    {% elsif parselet.is_a? RegexLiteral %}
      %result = consume_regex({{parselet}})

    {% elsif parselet.is_a? SymbolLiteral %}
      %result = consume_syntax({{parselet}}, with_precedence: {{with_precedence}})

    {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 %}
      %result = consume_token({{parselet[0]}})

    {% elsif parselet.is_a? Call && parselet.name == "|" %}
      %result = simple_union([parse({{parselet.receiver}}), parse({{parselet.args[0]}})], with_precedence: {{with_precedence || "_precedence_".id}}) # || 0 ?

    {% else %}
      {% raise "Unsuported ASTNode #{parselet.class_name} : #{parselet}" %}
    {% end %}

    {% if block %}
      fail_zone(%result) {{ block }}
    {% end %}
  end

  macro parse!(parselet, error = nil, with_precedence = nil, &block)
    {% if parselet.is_a? CharLiteral %}
      %result = consume_char!({{parselet}}, error: {{error}})

    {% elsif parselet.is_a? StringLiteral %}
      %result = consume_string!({{parselet}}, error: {{error}})

    {% elsif parselet.is_a? RegexLiteral %}
      %result = consume_regex!({{parselet}}, error: {{error}})

    {% elsif parselet.is_a? SymbolLiteral %}
      %result = consume_syntax!({{parselet}}, error: {{error}}, with_precedence: {{with_precedence}})

    {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 %}
      %result = consume_token!({{parselet[0]}}, error: {{error}})

    {% elsif parselet.is_a? Call && parselet.name == "|" %}
      %result = simple_union([parse({{parselet.receiver}}), parse({{parselet.args[0]}})], with_precedence: {{with_precedence}})

    {% else %}
      {% raise "Unsuported ASTNode #{parselet.class_name} : #{parselet}" %}
    {% end %}

    {% if block %}
      fail_zone(%result) {{ block }}
    {% end %}
  end

  private macro infix(precedence, parselet, associativity = "right")
    {% if parselet.is_a? SymbolLiteral %}
      if _precedence_ < {{precedence}}
        {% precedence -= 1 if associativity.id == "right".id %}
        _left_ = forward_fail(infix_parse_{{parselet.id}}(_left_, _precedence_: {{precedence}}))
      else
        break Fail.new
      end
    {% else %}
      {% raise "parselet for infix should be 'SymbolLiteral', not '#{parselet.class_name.id}'" %}
    {% end %}
  end

  macro syntax(syntax_name, *prefixs, &block)
    private def parse_{{syntax_name.id}}(_precedence_)
      fail_zone do
        sequence(name: {{syntax_name}}) do
          prefixs = Tuple.new({% for p in prefixs %} parse({{p}}), {% end %})

          fail_zone(*prefixs) {{block}}
        end
      end
    end
  end

  macro infix_syntax(syntax_name, *infixs, &block)
    private def infix_parse_{{syntax_name.id}}(_left_, _precedence_)
      fail_zone do
        sequence(name: {{syntax_name}}) do
          infixs = Tuple.new({% for i in infixs %} parse({{i}}), {% end %})

          fail_zone(_left_, *infixs) {{ block }}
        end
      end
    end
  end

  private def next_token
    {% raise "No tokens definition found, use 'Let::Parser.tokens' macro to define tokens" %}
  end

  macro tokens(&block)
    private def next_token
      _precedence_ = 0
      %result = fail_zone do
        \{% begin %}
        \{{"union".id}} do
          {{ yield }}
          parse('\0') { Token.new(:EOF) }
        end
        \{% end %}
      end
      if %result.is_a? Fail
        raise_syntax_error hook_unexpected_char % {got: char_to_s(peek_char), expected: nil }
      end
      %result
    end
  end

  private macro simple_union(members, with_precedence)
    forward_fail(
      fail_zone(self.location, {{with_precedence}}) do |old_location, _precedence_|

        {% for union_member in members %}
          self.location = old_location # not here?
          %result = fail_zone do
            {{ union_member }}
          end

          break %result if !%result.is_a? Fail
        {% end %}

        self.location = old_location
        Fail.new
      end
    )
  end

  macro union(&members)
    {% members = members.body.is_a?(Expressions) ? members.body.expressions : [members.body] %}
    {% prefix_members = members.reject do |m|
         m.is_a?(Call) && m.name == "infix"
       end %}

    {% infixs_members = members.select do |m|
         m.is_a?(Call) && m.name == "infix"
       end %}

    begin
      _left_ = simple_union({{prefix_members}}, with_precedence: 0) # _precedence = 0 because prefix are not subject to precedende

      {% unless infixs_members.empty? %}
        loop do
          simple_union({{infixs_members}}, with_precedence: _precedence_)
        end
      {% end %}
      _left_
    end
  end

  macro maybe(&)
    %old_location = self.location
    begin
      %result = fail_zone do
        {{ yield }}
      end
      if %result.is_a? Fail
        self.location = %old_location
        nil
      else
        %result
      end
    end
  end

  macro repeat(&)
    %old_location = self.location
    loop do
      %old_location = self.location
      {{ yield }}
    end
    self.location = %old_location
  end

  macro repeat(separator, &)
    maybe do
      {{ yield }}
      repeat do
        parse({{separator}})
        {{ yield }}
      end
    end
  end

  macro repeat_union(&)
    repeat do
      \{% begin %}
      \{{"union".id}} do
        {{ yield }}
      end
      \{% end %}
    end
  end

  @sequence_name = :main

  macro sequence(name, &)
    %prev_name = @sequence_name
    begin
      @sequence_name = {{name.id.symbolize}}
      {{ yield }}
    ensure
      @sequence_name = %prev_name
    end
  end

  macro sequence(&)
    {{ yield }}
  end

  def in_sequence?(*names)
    @sequence_name.in? names
  end

  macro forward_fail(result)
    %result = {{result}}
    if %result.is_a? Fail
      break Fail.new
    else
      %result
    end
  end

  class SyntaxError < Exception
    def initialize(@message : String, @location : Location, @string : String)
    end

    def show_location(io)
      line_number, line_pos = @location.line_number, @location.line_pos
      io << "at [#{line_number}:#{line_pos}]\n"

      lines = @string.split('\n')
      start = {0, line_number - 2}.max
      end_ = {line_number + 2, lines.size}.min
      return if start > end_

      lines[start..end_].each_with_index do |l, i|
        io << l << '\n'
        if start + i == line_number
          line_pos.times { io << ' ' }
          io << "^\n"
        end
      end
    end

    def inspect_with_backtrace(io)
      io << message << " (" << self.class << ")\n"

      show_location(io)

      backtrace?.try &.each do |frame|
        io.print "  from "
        io.puts frame
      end

      if cause = @cause
        io << "Caused by: "
        cause.inspect_with_backtrace(io)
      end

      io.flush
    end
  end

  private def char_to_s(char)
    char == '\0' ? "EOF" : char.to_s.dump_unquoted
  end

  # Appends a '\A' to begin of *regex* (forcing the regex to match at start)
  # Equivalent to `/\A#{regex}/` but done at compile time
  private macro regex_match_start(regex)
    {%
      str = "(?"
      str += 'i' if regex.options.includes?(:i)
      str += "ms" if regex.options.includes?(:m)
      str += 'x' if regex.options.includes?(:x)
      str += '-'
      str += 'i' unless regex.options.includes?(:i)
      str += "ms" unless regex.options.includes?(:m)
      str += 'x' unless regex.options.includes?(:x)
      str += ':'
      str += regex.source
      str += ')'
    %}
    %r(\A{{str.id}})
  end

  def raise_syntax_error(message, location = self.location, string = self.string)
    raise SyntaxError.new message, location, string
  end

  def hook_unexpected_char
    "Unexpected character '%{got}', expected '%{expected}'"
  end

  def hook_unexpected_string
    "Unexpected character '%{got}', expected matching with \"%{expected}\""
  end

  def hook_unexpected_token
    "Unexpected token '%{got}', expected '%{expected}'"
  end

  def hook_could_not_parse_regex
    "Unexpected character '%{got}', expected matching the patern /%{expected}/"
  end

  def hook_could_not_parse_syntax
    "Could not parse syntax '%{expected}'"
  end
end
