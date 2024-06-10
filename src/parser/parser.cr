require "./syntax_error"
require "./parselets"
require "./tokens"

# `TopDown::Parser` is the main class to derive for building a parser.
#
# ### Basis
#
# A minimal parser could be:
# ```
# class Parser < TopDown::Parser
#   root :expression
#
#   syntax :expression do
#   end
# end
# ```
# which will parse anything but EOF.
#
# `root` indicate the starting point of parsing, the rest is to do inside `syntax`.
#
# Syntax are like functions, in which, any code can be added.
# Inside it, `parse` & `parse!` can be used to define what to parse.
#
# ```
# syntax :expression do
#   a = parse('a')
#   parse(/( )+/)
#   foo = parse!("foo")
#
#   {a, foo}
# end
# ```
#
# ```
# "a   foo" # ~> {'a', "foo"}
# "a   bar" # ~> Unexpected character 'b', expected 'foo'
# "ab"      # ~> Unexpected character 'b', expected expression
# ```
# NOTE:
# In this documentation, `"foo" # ~> result` is used as a shortcut for
# `Parser.new("foo").parse # => result`
#
#
# In the above, if `parse!("foo")` fail to parse, it raises an error.
# But `parse('a')` don't raises, instead it use a `break` (`break Fail.new`) to stop the current sequence to be parsed.
# This failure is caught by the `root :expression`, that why it next raises an exception.
#
# This difference is important because is on what is based `TopDown`, using `parse` let a change to the surrounding context to handle the failure, whereas
# `parse!` permit the raise directly, leading to better errors.
#
# For example, using `parse!` above:
# ```
# syntax :expression do
#   a = parse!('a')
#   parse!(/( )+/)
#   foo = parse!("foo")
#
#   {a, foo}
# end
# ```
#
# ```
# "ab" # ~> Unexpected character 'b', expected pattern /( )+/
# ```
# Gives a more precise error.
#
# ### Repeat, union, maybe
#
# `repeat`, `union`, `maybe` allow interesting things to be parsed. They take both a block, in which parse failure can occur.
#
# ```
# syntax :expression do
#   repeat do
#     parse('a')
#     parse!('b')
#   end
#   maybe { parse('c') }
#   parse!('d')
#
#   union do
#     parse('e')
#     parse('é')
#     parse('è')
#   end
#   "ok"
# end
# ```
#
# This is equivalent to parse `/(ab)*c?d[eéè]/`, in a bit more verbose. However, doing so allow to insert code between and retrieve
# only needed result, storing in array, or to insert some logic.
#
# For example:
# ```
# syntax :expression do
#   array = [] of {Char, Char}
#   repeat do
#     array << {parse('a'), parse!('b')}
#   end
#   have_c = maybe { parse('c') }
#   parse!('d')
#
#   if have_c
#     e = union do
#       parse('e')
#       parse('é')
#       parse('è')
#     end
#   end
#   {array, e}
# end
# ```
# Here, we store each `ab` in an array and accept the union `'e'|'é'|'è'` only if the optional `'c'` have been parsed.
# ```
# "ababd" # ~> {[{'a', 'b'}, {'a', 'b'}], nil}
# "cde"   # ~> {[], 'e'}
# "dé"    # ~> Unexpected character 'é', expected 'EOF'
# "abac"  # # Unexpected character 'c', expected 'b'
# ```
#
# NOTE:
# When using `repeat`, `union`, and `maybe`, we always use `parse` at first (without exclamation), because they `break` on failure,
# which is caught by the `repeat`/`maybe`/`union`. They know so they should continue parsing without a failure.
#
# ### Infix
#
# `infix` can be used inside a union. It permits to parse operators with precedence easily.
# ```
# syntax :expression do
#   union do
#     parse(/\d+/).to_i
#     infix 30 "**" { left() ** parse!(:expression) }
#     infix 20 '*' { left() * parse!(:expression) }
#     infix 20 '/' { left() / parse!(:expression) }
#     infix 10 '+' { left() + parse!(:expression) }
#     infix 10 '-' { left() - parse!(:expression) }
#   end
# end
# ```
#
# Infix are treated specially by the `union`. They are parsed after any other member of the union, the `left()` result is updated each time.
# They are parsed in function of their precedence (first argument), higher precedence mean grouped first.
#
# ```
# "3*6+6*4" # ~> 42
# ```
#
# ### Precedence:
#
# `current_precedence()` is initially zero, it changes when entering in `infix`. This is this value that guide the recursion for parsing operators.
# Its value can be changed at specific places, so parsing order can be entirely controlled.
#
# For example, assuming we want to parse a ternary if `_ ? _ : _` that have a higher precedence that classical operators (e.g. `"1+1?2:3+3"` gets parsed as (`1` + (`1?2:3`)) + `3`.
#
# We can do the following:
# ```
# syntax(:expression) do
#   union do
#     parse(/\d+/).to_i
#     infix 10, :plus
#     infix 90, :ternary_if
#   end
# end
#
# syntax :plus, '+' do
#   left() + parse!(:expression)
# end
#
# syntax :ternary_if, '?' do
#   cond = left()
#   then_arm = parse!(:expression)
#   parse!(':')
#   else_arm = parse!(:expression)
#
#   cond != 0 ? then_arm : else_arm
# end
# ```
#
# ```
# "1+1?2:3+3" # ~> 6
# ```
#
# However the following is not what we except:
# ```
# "1+1?2+2:3+3" # => Unexpected character '+', expected ':'
# ```
#
# This happens because the `+` inside the `then_arm` have lower precedence, it wants so
# let its left with higher precedence finish before parsing itself. So the `then_arm` finish
# but we except a `:` right after, so it fails (got '+', expected ':').
#
# To fix that, we can set the `current_precedence()` for the `then arm` to 0:
# ```
# then_arm = parse!(:expression, with_precedence: 0)
# ```
# ```
# "1+1?2+2:3+3" # ~> 8
# ```
#
abstract class TopDown::Parser < TopDown::CharReader
  # Parses the source contained in this parser.
  #
  # Returns the result of the root syntax.
  # Expects `eof` after parsing root syntax.
  # Raises `SyntaxError` if fail to parse.
  def parse
    result = parse_root
    if result.is_a? Fail
      raise_syntax_error error_message(->hook_expected_syntax(Char, Symbol), got: peek_char, expected: :root)
    end

    parse!('\0')
    result
  end

  private def parse_root
    {% raise "Root syntax is not defined, use 'TopDown::Parser.root' macro to define the root" %}
  end

  # Defines the main syntax to parse.
  #
  # *parselet* (`ParseletLiteral`): the syntax name or parselet to be the root.
  macro root(parselet)
    private def parse_root
      parse!({{parselet}}, with_precedence: 0)
    end
  end

  # Defines a syntax that can be called with `parse(SymbolLiteral)`.
  #
  # _syntax_name_ (`SymbolLiteral`): The identifier of the syntax.
  #
  # _*prefix_ (`ParseletLiteral`): A list of parselet, to parse at the beginning of the syntax, results are yielded in the given block.
  #
  # _block_: The body of the syntax, work like a usual body function.
  #
  # ```
  # class Parser < TopDown::Parser
  #   syntax :expression do
  #     a = parse('a')
  #     parse(/( )+/)
  #     foo = parse!("foo")
  #
  #     {a, foo}
  #   end
  # end
  # ```
  macro syntax(syntax_name, *prefixs, end! = nil, &block)
    @[AlwaysInline]
    private def parse_{{syntax_name.id}}(_left_, _precedence_)
      _begin_location_ = self.location

      handle_fail do
        prefixs = Tuple.new({% for p in prefixs %} parse({{p}}), {% end %})

        {% if block %}
          handle_fail(*prefixs) {{block}}
        {% elsif prefixs.size == 1 %}
          prefixs.first
        {% end %}
        {% if end! %}
          .tap { parse!({{end!}}) }
        {% end %}
      end
    end
  end

  # Parses the given *parselet* (`ParseletLiteral`), and yield/return the according result.
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
    parselet({{parselet}}, with_precedence: {{with_precedence}}) {{ block }}
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
  # Because it raises, this shouldn't be used as first *parselet* inside a `union`, `maybe`, `repeat` and `syntax`.
  # This would raises before the surrounding context could try an other solution.
  #
  # However, this should generally be used everywhere else, to allow more localized errors.
  macro parse!(parselet, error = nil, at = nil, with_precedence = nil, &block)
    parselet({{parselet}}, true, {{error}}, {{at}}, {{with_precedence}}) {{ block }}
  end

  # Equivalent to `parse(parselet, with_precedence: precedence)`
  macro prefix(precedence, parselet, &block)
    parselet({{parselet}}, with_precedence: {{precedence}}) {{ block }}
  end

  # TODO: docs
  macro infix(precedence, parselet, associativity = "right", &block)
    if _precedence_ < {{precedence}}
      {% precedence -= 0.0001 if associativity.id == "right".id %}
      _begin_location_ = self.location
      _left_ = parselet({{parselet}}, with_precedence: {{precedence}}, left: _left_) {{block}}
    else
      break Fail.new
    end
  end

  # TODO: docs
  # parse parselet
  # if succeed, don't move the cursor and return parselet result
  # else, don't move the cursor and break a failure
  macro peek(parselet, with_precedence = nil, &block)
    %location = self.location
    handle_fail do
      parselet({{parselet}}, with_precedence: {{with_precedence}}) {{ block }}
    ensure
      self.location = %location
    end.tap do |result|
      break result if result.is_a? Fail
    end
  end

  # In the context of an `infix` member, returns the `left` result of the current `union`.
  #
  # Returns `nil` in a context other than inside an `infix`.
  #
  # Each time a `union` member is successfully parsed, `left` value is updated.
  #
  # As a `union` continue parsing `infix` until possible,
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

  private macro _union_(raises? = false, error = nil, at = nil, &members)
    {% members = members.body.is_a?(Expressions) ? members.body.expressions : [members.body] %}
    {% prefix_members = members.reject do |m|
         m.is_a?(Call) && m.name == "infix"
       end %}

    {% infixs_members = members.select do |m|
         m.is_a?(Call) && m.name == "infix"
       end %}

    _left_ = forward_fail(handle_fail(0) do |_precedence_| # precedence = 0 because prefix are not subject to precedence
      parselet_union({{prefix_members}} of MacroId, {{raises?}}, {{error}}, {{at}})
    end)

    {% unless infixs_members.empty? %}
      loop do
        parselet_union({{infixs_members}})
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
  # `infix` members could be added to a union.
  #
  # `infix` members are always treated after each normal members, in the order there are defined.
  # A union act as follow:
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

  # Similar to `Parser.union`, but raises `SyntaxError` if the parsing fail.
  macro union!(error = nil, at = nil, &members)
    _union_(true, {{error}}, {{at}}) {{members}}
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
  macro maybe(parselet = nil, &)
    %begin_location = self.location
    %result = handle_fail do
      {% if parselet %}
        parse({{parselet}})
      {% end %}
      {{ yield }}
    end
    if %result.is_a? Fail
      self.location = %begin_location
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
  macro repeat(parselet = nil, &)
    %old_location = self.location
    loop do

      %old_location = self.location
      {% if parselet %}
        parse({{parselet}})
      {% end %}
      {{ yield }}
    end
    self.location = %old_location
    nil
  end

  macro repeat_n(count, parselet = nil, &block)
    {% if count.is_a? RangeLiteral && (count.begin.nil? || count.begin.is_a? NumberLiteral) && (count.end.nil? || count.end.is_a? NumberLiteral) %}
      {{max = count.end || Int32::MAX - 1}}
      repeat_min_max({{count.begin || 0}}, {{max}}, {{parselet}}) {{block}}
    {% elsif count.is_a? NumberLiteral %}
      repeat_min_max({{count}}, {{count}}, {{parselet}}) {{block}}
    {% else %}
      {% raise "'count' should be 'RangeLiteral', or 'NumberLiteral' not #{count.class_name}: #{count}" %}
    {% end %}
  end

  private macro repeat_min_max(min, max, parselet = nil, &)
    forward_fail({{min}}.times do
      {% if parselet %}
        parse({{parselet}})
      {% end %}
      {{ yield }}
    end)

    %old_location = self.location
    {{max + 1 - min}}.times do
      %old_location = self.location
      {% if parselet %}
        parse({{parselet}})
      {% end %}
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
  macro repeat(parselet = nil, *, separator, &)
    maybe do
      {% if parselet %}
        parse({{parselet}})
      {% end %}
      {{ yield }}
      repeat do
        parse({{separator}})
        {% if parselet %}
          parse!({{parselet}})
        {% end %}
        {{ yield }}
      end
    end
  end

  # TODO: docs
  macro repeat_to_h(type, *, separator = nil, &)
    hash = {{type}}.new
    repeat({{{separator: separator}.double_splat if separator}}) do
      key, value = {{yield}}
      hash[key] = value
    end
    hash
  end

  # TODO: docs
  macro repeat_to_a(type, *, separator = nil, &)
    array = {{type}}.new
    repeat({{{separator: separator}.double_splat if separator}}) do
      array << {{yield}}
    end
    array
  end

  # TODO: docs
  macro repeat_to_s(*, separator = nil, &block)
    skip_chars
    capture do
      repeat({{{separator: separator}.double_splat if separator}}) {{block}}
    end
  end

  # TODO: docs
  macro repeat_count(*, separator = nil)
    count = 0
    repeat({{{separator: separator}.double_splat if separator}}) do
      {{yield}}
      count += 1
    end
    count
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

  # Defines what is ignored during the parsing.
  #
  # It is triggered every time prior a parselet is parsed.
  #
  # It works similarly to the members of a `Parser.union`, in which each members are consumed while possible.
  #
  # ```
  # class Parser < TopDown::Parser
  #   skip do
  #     # Skips spaces:
  #     parse ' '
  #     parse '\n'
  #     parse '\t'
  #     parse '\r'
  #
  #     # Line comments:
  #     parse "//" { repeat { parse not('\n') } }
  #
  #     # Block comments:
  #     parse "/*" do
  #       repeat { parse not("*/") }
  #       parse "*/"
  #     end
  #   end
  # end
  # ```
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

  # Prevents the `skip` rules to be triggered inside the given block.
  macro no_skip(&)
    @no_skip_nest += 1
    ({{ yield }}) ensure @no_skip_nest -= 1
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

  private def handle_fail(*args, &)
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
    {% raise "partial_capture should have one block argument" if !block || block.args.size != 1 %}
    {{block.args[0].id}} = String::Builder.new
    {{ yield }}
    {{block.args[0].id}}.to_s
  end

  # Allows to group a sequence of parsing (inside a union for example).
  #
  # ```
  # union do
  #   sequence do
  #     parse("a")
  #     parse!("b")
  #   end
  #   parse("2")
  # ```
  macro sequence(&)
    %begin_location = self.location
    %result = handle_fail do
      {{ yield }}
    end
    if %result.is_a? Fail
      self.location = %begin_location
      break Fail.new
    else
      %result
    end
  end

  # Allows to match a word only if a non-alphanumeric follows
  #
  # ```
  # parse("foo") { end_word }
  #
  # Equivalent to: (but faster)
  # parse(/foo\b/) { nil }
  # ```
  # ```
  # "foo bar" # ~> "foo"
  # "foobar"  # ~> Unexpected character 'b', expected 'EOF'
  # ```
  #
  # NOTE: end_word returns `nil`.
  macro end_word
    break Fail.new if peek_char.alphanumeric?
    nil
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
