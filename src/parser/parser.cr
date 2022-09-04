require "./syntax_error"
require "./tokens"

# # Parser:
# TODO: docs
# NOTE:
# In this documentation, `"foo" # ~> result` is used as a shortcut for
# `Parser.new("foo").parse # => result`
#
# ### Precedence:
# Example of a `:ternary_if`:
# ```
# syntax(:expression) do
#   union do
#     parse(/\d+/, &.to_i)
#     infix 1, :plus
#     infix 9, :ternary_if
#   end
# end
#
# infix_syntax(:plus, '+') do |left|
#   GenericAST.new(left, parse!(:expression))
# end
#
# infix_syntax(:ternary_if, '?') do |cond|
#   then_arm = parse!(:expression)
#   parse!(':')
#   else_arm = parse!(:expression)
#   GenericAST.new(cond, then_arm, else_arm)
# end
# ```
# Here the `:ternary_if` have been defined with a higher precedence, so `"1+1?2:3+3"` will be parsed as (`1` + (`1?2:3`)) + `3`.
#
# However the above example doesn't parse `"1+1?2+2:3+3"`
# => raises `"Unexpected character '+', expected ':'"`.
#
# This happen because when parsing the `then_arm`, it hit a '+', that have smaller precedence,
# so the parsing of `:expression` finish, to let the '+' catch it as a left.
# however, after `then_arm` we expects a ':', so it fails.
#
# To solve that without change the precedence of the hole `:ternary_if`, precedence can be set only for the `then_arm`:
# ```
# then_arm = parse(:expression, with_precedence: 0)
# ```
#
# `with_precedence: 0` means: 'inside the then arm, act as if the `:ternary_if` have a precedence 0'.
abstract class TopDown::Parser < TopDown::CharReader
  # Parses the source contained in this parser.
  #
  # Returns the result of the root syntax.
  # Expects `eof` after parsing root syntax.
  # Raises `SyntaxError` if fail to parse.
  def parse
    result = parse_root
    if result.is_a? Fail
      raise_syntax_error error_message(->hook_could_not_parse_syntax(Char, Symbol), got: peek_char, expected: :root)
    end

    consume_char!('\0')
    result
  end

  private def parse_root
    {% raise "Root syntax is not defined, use 'TopDown::Parser.root' macro to define the root" %}
  end

  # Defines the main syntax to parse.
  #
  # *parselet*: the syntax name or the parselet to be the root.
  # Could be `StringLiteral`|`CharLiteral`|`RegexLiteral`|`SymbolLiteral`|`ArrayLiteral`|`Call`,
  # see [`Parser.parse`](#parse(parselet,with_precedence=nil,&block)-macro)
  macro root(parselet)
    private def parse_root
      parse!({{parselet}}, with_precedence: 0)
    end
  end

  # Defines a syntax that can be called with `parse(SymbolLiteral)`.
  #
  # TODO: docs
  macro syntax(syntax_name, *prefixs, &block)
    @[AlwaysInline]
    private def parse_{{syntax_name.id}}(_left_, _precedence_)
      _begin_location_ = self.location

      handle_fail do
        prefixs = Tuple.new({% for p in prefixs %} parse({{p}}), {% end %})

        handle_fail(*prefixs) {{block}}
      end
    end
  end

  private macro consume_char(char)
    skip_chars
    if peek_char != {{char}}
      break Fail.new
    else
      next_char
    end
  end

  private macro consume_char!(char, error = nil, at = nil)
    skip_chars
    if peek_char != {{char}}
      raise_syntax_error error_message({{error}} || ->hook_unexpected_char(Char, Char), got: peek_char, expected: {{char}}), at: ({{at || "self.location".id}})
    else
      next_char
    end
  end

  private macro consume_not_char(char)
    skip_chars
    if peek_char == {{char}} || peek_char == '\0'
      break Fail.new
    else
      next_char
    end
  end

  private macro consume_any_char
    if peek_char == '\0'
      break Fail.new
    else
      next_char
    end
  end

  private macro consume_range(range)
    if peek_char.in? {{range}}
      next_char
    else
      break Fail.new
    end
  end

  private macro consume_range!(range, error = nil, at = nil)
    if peek_char.in? {{range}}
      next_char
    else
      raise_syntax_error error_message({{error}} || ->hook_unexpected_range_char(Char, Range(Char, Char)), got: peek_char, expected: {{range}}), at: ({{at || "self.location".id}})
    end
  end

  private macro consume_string(string)
    skip_chars
    capture do
      no_skip do
        {% for c in string.chars %}
          consume_char({{c}})
        {% end %}
      end
    end
  end

  private macro consume_string!(string, error = nil, at = nil)
    skip_chars
    %result = handle_fail do
      capture do
        no_skip do
          {% for c in string.chars %}
            consume_char({{c}})
          {% end %}
        end
      end
    end
    if %result.is_a? Fail
      raise_syntax_error error_message({{error}} || ->hook_could_not_parse_string(Char, String), got: peek_char, expected: {{string}}), at: ({{at || "self.location".id}})
    end
    %result
  end

  private macro consume_not_string(string)
    %old_location = self.location
    %result = handle_fail do
      consume_string({{string}})
    end
    if %result.is_a? Fail
      self.location = %old_location
      break Fail.new if peek_char == '\0'
      next_char
      nil
    else
      break Fail.new
    end
  end

  private macro consume_regex(regex)
    skip_chars
    if regex_match_start({{regex}}) =~ String.new(self.source.to_slice[self.location.pos..])
      @char_reader.pos += $0.bytesize
      $0.each_char { |ch| increment_location(ch) }
      $0
    else
      break Fail.new
    end
  end

  private macro consume_regex!(regex, error = nil, at = nil)
    skip_chars
    if regex_match_start({{regex}}) =~ String.new(self.source.to_slice[self.location.pos..])
      @char_reader.pos += $0.bytesize
      $0.each_char { |ch| increment_location(ch) }
      $0
    else
      raise_syntax_error error_message({{error}} || ->hook_could_not_parse_regex(Char, Regex), got: peek_char, expected: {{regex}}), at: ({{at || "self.location".id}})
    end
  end

  private macro consume_syntax(syntax_name, with_precedence = nil)
    skip_chars
    %result = parse_{{syntax_name.id}}(nil, {{with_precedence || "_precedence_".id}})
    if %result.is_a? Fail
      break Fail.new
    else
      %result
    end
  end

  private macro consume_syntax!(syntax_name, error = nil, at = nil, with_precedence = nil)
    skip_chars
    %result = parse_{{syntax_name.id}}(nil, {{with_precedence || "_precedence_".id}})
    if %result.is_a? Fail
      raise_syntax_error error_message({{error}} || ->hook_could_not_parse_syntax(Char, Symbol), got: peek_char, expected: {{syntax_name}}), at: ({{at || "self.location".id}})
    else
      %result
    end
  end

  private macro consume_not(parselet)
    {% if parselet.is_a? CharLiteral %}
      consume_not_char({{parselet}})
    {% elsif parselet.is_a? StringLiteral %}
      consume_not_string({{parselet}})
    {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 %}
      consume_not_token({{parselet[0]}})
    {% else %}
      {% raise "'not' arguments should be 'CharLiteral', 'StringLiteral' or 'ArrayLiteral' not #{parselet.class_name}: #{parselet}" %}
    {% end %}
  end

  # Parse the given *parselet*.
  #
  # #### parselet:
  # *parselet* could be one of the following:
  # * a `CharLiteral`, to parse exactly one `Char`
  # * a `StringLiteral`, to parse an exact `String`
  # * a `RegexLiteral`, to parse the given pattern, returns the matched `String`. ($~, $0, $1, ... could be used after)
  # * a `RangeLiteral(Char, Char)`, to parse any `Char` between the range
  # * a `SymbolLiteral`, to parse an entire `syntax`, returns the result of the syntax.
  # * an one-value `ArrayLiteral`, to parse a `Token`, returns the value of matched token.
  #  NOTE: the type of token should correspond to the type of tokens defined with `Parser.tokens`.
  # * a `Call`:
  #   * `|`: to parse an union, see `Parser.union`.
  #   * `any`, to parse any `Char` except EOF.
  #   * `[any]`, to parse any token except EOF.
  #   * `not(parselet)`, to parse any char, except if *parselet* matches.
  #  ```
  # parse('💎')   # => '💎'
  # parse("foo") # => "foo"
  # parse(/\d+/, &.to_i)
  # parse(/"(([^"\\]|\\.)*)"/) { $1 }
  # parse(:expression)
  # parse([:"+="])           # => "+="
  # parse([TokenType::PLUS]) # => "+"
  #
  # parse("foo" | :value | '💎')
  # # equivalent to:
  # union do
  #   parse("foo")
  #   parse(:value)
  #   parse('💎')
  # end
  #
  # parse(any)         # any char except '\0'
  # parse([any])       # any token except EOF
  # parse(not('\n'))   # any char except '\n' & EOF
  # parse(not([:"+"])) # any token except :"+" & EOF
  # parse(not("foo"))  # any char or fail on "foo".
  #  ```
  #
  # #### failure:
  # If the given *parselet* fails to parse, it `break` the current sequence with a `Fail`. Failure is catch by the surrounding context.
  # * inside an `union`, tell the union that member have fail. The union tries to parse the next member.
  # * inside a `maybe`, the maybe will return `nil`.
  # * inside a `repeat`, make the repeat to stop.
  # * inside a `syntax`, the syntax is considered to fail, it will in turn `break` or raises.
  #
  # #### block:
  # A *block* could be given to let return the value of the block.
  #
  # #### precedence:
  # *with_precedence* (`NumberLiteral`) changes the `current_precedence`, the given *parselet* will be parsed as if the contained syntax have this precedence.
  # Allow to handle multi-precedence for ternary-or-more operator.
  #
  macro parse(parselet, with_precedence = nil, &block)
    {% parselet = parselet.expressions[0] if parselet.is_a?(Expressions) && parselet.expressions.size == 1 %}

    {% if parselet.is_a? CharLiteral %}
      %result = consume_char({{parselet}})

    {% elsif parselet.is_a? RangeLiteral %}
      %result = consume_range({{parselet}})

    {% elsif parselet.is_a? StringLiteral %}
      %result = consume_string({{parselet}})

    {% elsif parselet.is_a? RegexLiteral %}
      %result = consume_regex({{parselet}})

    {% elsif parselet.is_a? SymbolLiteral %}
      %result = consume_syntax({{parselet}}, with_precedence: {{with_precedence}})

    {% elsif parselet.is_a? Call && parselet.name == "|" %}
      %result = simple_union([parse({{parselet.receiver}}), parse({{parselet.args[0]}})], with_precedence: {{with_precedence || "_precedence_".id}}) # || 0 ?

    {% elsif parselet.is_a? Call && parselet.name == "not" %}
      %result = consume_not({{parselet.args[0]}})

    {% elsif parselet.is_a? Call && parselet.name == "any" %}
      %result = consume_any_char

    {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 && parselet[0].is_a? Call && parselet[0].name == "any" %}
      %result = consume_any_token

    {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 %}
      %result = consume_token({{parselet[0]}})

    {% else %}
      {% raise "Unsupported ASTNode #{parselet.class_name} : #{parselet}" %}
    {% end %}

    {% if block %}
      handle_fail(%result) {{ block }}
    {% end %}
  end

  # Similar to [`Parser.parse`](#parse(parselet,with_precedence=nil,&block)-macro), but raises `SyntaxError` if the parsing fail.
  #
  # *error*: allows to customize error message, it can be:
  # * a `StringLiteral`:
  #   Following percent interpolations are available:
  #   * `%{got}`: The character or token causing the failure.
  #   * `%{expected}`: The expected `Char`, `String`, `Regex`, `Token` or syntax name (`Symbol`).
  # * a `ProcLiteral` taking two arguments: 'got' and 'expected', with types explained above.
  #
  # *at*: indicates where the error is raised, it can be a `Location`, `Range(Location, Location)` or `Range(Location, Nil)`.
  #
  # #### failure:
  # Because it raises, this shouldn't be used as first *parselet* inside an `union`, `maybe`, `repeat` and `syntax`.
  # This would raises before the surrounding context could try an other solution.
  #
  # However, this should generally be used everywhere else, to allow more localized errors.
  macro parse!(parselet, error = nil, at = nil, with_precedence = nil, &block)
    {% if parselet.is_a? CharLiteral %}
      %result = consume_char!({{parselet}}, error: {{error}}, at: {{at}})

    {% elsif parselet.is_a? RangeLiteral %}
      %result = consume_range!({{parselet}}, error: {{error}}, at: {{at}})

    {% elsif parselet.is_a? StringLiteral %}
      %result = consume_string!({{parselet}}, error: {{error}}, at: {{at}})

    {% elsif parselet.is_a? RegexLiteral %}
      %result = consume_regex!({{parselet}}, error: {{error}}, at: {{at}})

    {% elsif parselet.is_a? SymbolLiteral %}
      %result = consume_syntax!({{parselet}}, error: {{error}}, at: {{at}}, with_precedence: {{with_precedence}})

    {% elsif parselet.is_a? ArrayLiteral && parselet.size == 1 %}
      %result = consume_token!({{parselet[0]}}, error: {{error}}, at: {{at}})

    {% elsif parselet.is_a? Call && parselet.name == "|" %}
      %result = simple_union([parse({{parselet.receiver}}), parse({{parselet.args[0]}})], with_precedence: {{with_precedence || "_precedence_".id}})

    {% else %}
      {% raise "Unsupported ASTNode #{parselet.class_name} : #{parselet}" %}
    {% end %}

    {% if block %}
      handle_fail(%result) {{ block }}
    {% end %}
  end

  # TODO: docs
  macro infix(precedence, parselet, associativity = "right")
    {% if parselet.is_a? SymbolLiteral %}
      if _precedence_ < {{precedence}}
        {% precedence -= 1 if associativity.id == "right".id %}
        skip_chars
        _left_ = forward_fail(parse_{{parselet.id}}(_left_, _precedence_: {{precedence}}))
      else
        break Fail.new
      end
    {% else %}
      {% raise "parselet for infix should be 'SymbolLiteral', not '#{parselet.class_name.id}'" %}
    {% end %}
  end

  # In the context of an `infix` member, returns the `left` result of the current `union`.
  #
  # Returns `nil` in a context other than inside an `infix`.
  #
  # Each time a `union` member is successfully parsed, `left` value is updated.
  #
  # As an `union` continue parsing `infix` until possible,
  # `left` allows to retrieve the subsequent results.
  #
  # ```
  # syntax(:exp) do
  #   union do
  #     parse('a')
  #     infix(1, :comma)
  #   end
  # end
  # ```
  # ```
  # syntax(:comma) do
  #   l = left() # left returns either
  #   r = parse(:exp)
  #   "#{l}, #{r}"
  # end
  # ```
  macro left
    _left_
  end

  # Returns the current precedence.
  #
  # Initially zero.
  # Changes inside an `infix` or when `with_precedence` is used.
  macro current_precedence
    _precedence_
  end

  # Returns the `Location` at the beginning of the `syntax`.
  #
  # The given location is after skipping characters.
  macro begin_location
    _begin_location_
  end

  private macro simple_union(members, with_precedence)
    forward_fail(
      handle_fail(self.location, {{with_precedence}}) do |old_location, _precedence_|

        {% for union_member in members %}
          self.location = old_location
          %result = handle_fail do
            {{ union_member }}
          end

          break %result if !%result.is_a? Fail
        {% end %}

        self.location = old_location
        Fail.new
      end
    )
  end

  private macro _union_(&members)
    {% members = members.body.is_a?(Expressions) ? members.body.expressions : [members.body] %}
    {% prefix_members = members.reject do |m|
         m.is_a?(Call) && m.name == "infix"
       end %}

    {% infixs_members = members.select do |m|
         m.is_a?(Call) && m.name == "infix"
       end %}

    _left_ = simple_union({{prefix_members}}, with_precedence: 0) # precedence = 0 because prefix are not subject to precedence

    {% unless infixs_members.empty? %}
      loop do
        simple_union({{infixs_members}}, with_precedence: _precedence_)
      end
    {% end %}
    _left_
  end

  # Tries to parse each member of the union, returns the result of the first that succeed.
  #
  # ```
  # union do
  #   parse('1')
  #   parse('2')
  #   sequence do
  #     parse('a')
  #     parse('b')
  #     parse!('c')
  #   end
  #   parse('a')
  # end
  # ```
  # ```
  # "1"   # ~> '1'
  # "abc" # ~> 'c'
  # "ab*" # ~> "Unexpected character '*', expected 'c'"
  # "a"   # ~> 'a'
  # "*"   # ~> "Could not parse syntax ':main'
  # ```
  #
  # #### members:
  # Members are delimited by each expression in the `Expressions` of the given block.
  # NOTE: a block `begin`/`end` doesn't group a member since it is inlined by the crystal parser. Use `sequence` instead.
  #
  # #### failure:
  # If all members of the union fail, the union is considered to fail, and will `break` the current sequence
  #
  # #### infix:
  # `infix` members could be added to an union.
  #
  # `infix` members are always treated after each normal members, in the order there are defined.
  # An union act as follow:
  # 1) Tries to parse each normal member.
  # 2) When one succeed, store the result. `left` allows to retrieve this result.
  # 3) Tries to parse `infix` members whose precedence is greater than current precedence (initial is zero).
  # 4) Inner of `infix` is executed, it potentially triggers parsing of this union recursively, but current precedence is sets to the `infix` precedence.
  # 5) When one fully succeed, store the result. `left` is updated.
  # 6) Repeats step 3-5) until there no more infix.
  # 7) Returns last result.
  #
  # This is mainly the top-down operator precedence algorithm, also known as precedence climbing.
  macro union(&members)
    _union_ {{members}}
  end

  # Parses the sequence inside the block, returns `nil` if it fails.
  #
  # ```
  # x = parse('1').to_i
  # y =
  #   maybe do
  #     parse('+')
  #     parse!('1').to_i
  #   end
  # parse!(';')
  # x + (y || 0)
  # ```
  # ```
  # "1;"   # ~> 1
  # "1+1;" # ~> 2
  # "1+*;" # ~> "Unexpected character '*', expected '1'"
  # "1*;"  # ~> "Unexpected character '*', expected ';'"
  # ```
  macro maybe(&)
    %old_location = self.location
    %result = handle_fail do
      {{ yield }}
    end
    if %result.is_a? Fail
      self.location = %old_location
      nil
    else
      %result
    end
  end

  # Repeatedly parses the sequence inside the block until it fails.
  #
  # Returns `nil`. Results should be either collected by `capture` or stored inside a variable or array.
  # ```
  # x = parse('1').to_i
  # repeat do
  #   parse('+')
  #   x += parse!('1').to_i
  # end
  # parse!(';')
  # x
  # ```
  # ```
  # "1;"         # ~> 1
  # "1+1+1+1+1;" # ~> 5
  # "1+1+1+*;"   # ~> "Unexpected character '*', expected '1'"
  # "1*;"        # ~> "Unexpected character '*', expected ';'"
  # ```
  macro repeat(&)
    %old_location = self.location
    loop do
      %old_location = self.location
      {{ yield }}
    end
    self.location = %old_location
    nil
  end

  # Repeatedly parses the sequence inside the block until it fails, with a *separator* parselet between each iteration.
  #
  # Returns `nil`. Results should be either collected by `capture` or stored inside a variable or array.
  # ```
  # x = 0
  # parse('(')
  # repeat(',') do
  #   x += parse('1').to_i
  # end
  # parse!(')')
  # x
  # ```
  # ```
  # "()"          # ~> 0
  # "(1,1,1,1,1)" # ~> 5
  # "(1,1,)"      # ~> "Unexpected character ',', expected ')'"
  # "(11)"        # ~> "Unexpected character '1', expected ')'"
  # ```
  macro repeat(separator, &)
    maybe do
      {{ yield }}
      repeat do
        parse({{separator}})
        {{ yield }}
      end
    end
  end

  # Equivalent to `repeat { union { ... } }`
  macro repeat_union(&block)
    repeat do
      _union_ do
        {{block.body}}
      end
    end
  end

  # Equivalent to `maybe { union { ... } }`
  macro maybe_union(&block)
    maybe do
      _union_ do
        {{block.body}}
      end
    end
  end

  private def skip_chars
  end

  # TODO: docs
  macro skip(&members)
    private def skip_chars
      if @no_skip_nest == 0
        no_skip do
          loop do
            _union_ do
              {{ yield }}
            end
          end
        end
      end
    end
  end

  @no_skip_nest = 0

  # TODO: docs
  macro no_skip(&)
    begin
      @no_skip_nest += 1
      %ret = ({{ yield }})
    ensure
      @no_skip_nest -= 1
    end
    %ret
  end

  # Empty struct representing a parse failure.
  #
  # When [`Parser.parse`](#parse(parselet,with_precedence=nil,&block)-macro) is used,
  # if it fails, it `break` the current sequence with a `Fail`.
  #
  # However when the method is surrounded by a block, the `Fail` get returned.
  # In this case it recommended to use `Parser.forward_fail` to `break` again.
  #
  # ```
  # result = Array.new(3) do
  #   parse("a")
  # end
  #
  # typeof(result) # => Array(String) | TopDown::Parser::Fail
  #
  # result = forward_fail(result)
  # typeof(result) # => Array(String)
  # ```
  struct Fail
  end

  private def handle_fail(*args)
    yield *args
  end

  # Returns the given *result*, or `break` the current sequence if *result* is a `Fail`.
  #
  # This macro is the recommended ways to handle `Fail`.
  #
  # ```
  # result = Array.new(3) do
  #   parse("a")
  # end
  #
  # typeof(result) # => Array(String) | TopDown::Parser::Fail
  #
  # result = forward_fail(result)
  # typeof(result) # => Array(String)
  # ```
  macro forward_fail(result)
    %result = {{result}}
    if %result.is_a? Fail
      break Fail.new
    else
      %result
    end
  end

  # Captures all characters parsed inside the *block*.
  #
  # Returns a `String`
  # NOTE: `skip` characters are still captured, use `partial_capture` instead.
  #
  # ```
  # capture do
  #   repeat(/ +/) do
  #     parse(/\w+/)
  #   end
  # end
  # ```
  # ```
  # "a   bc d e"  # ~> "a   bc d e"
  # "Hello World" # ~> "Hello World"
  # ```
  macro capture(&)
    %pos = self.location.pos
    {{ yield }}
    String.new(self.source.to_slice[%pos...self.location.pos])
  end

  # Captures chosen characters parsed inside the *block*.
  #
  # Yields a `String::Builder` in which characters to capture can be added.
  #
  # Returns a `String`.
  #
  # ```
  # partial_capture do |io|
  #   repeat(/ +/) do
  #     io << parse(/\w+/)
  #   end
  # end
  # ```
  # ```
  # "a   bc d e"  # ~> "abcde"
  # "Hello World" # ~> "HelloWorld"
  # ```
  macro partial_capture(&block)
    {% raise "partial_capture should have one block argument" unless block.args[0] %}
    {{block.args[0].id}} = String::Builder.new
    {{ yield }}
    {{block.args[0].id}}.to_s
  end

  # TODO: docs
  macro sequence(&)
    {{ yield }}
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
end
