require "../src/topdown"

# Same parser as `json.cr` but using tokens.
class JSONParserWithToken < TopDown::Parser
  root :object

  alias Value = String | Float64 | Int32 | Bool | Nil | Hash(String, Value) | Array(Value)

  # # Tokens ##

  tokens do
    token("{")
    token("}")
    token(":")
    token("[")
    token("]")
    token(",")
    token("true") { true }
    token("false") { false }
    token("null") { nil }
    token("string", :tk_string) { |v| v }
    token("number", :tk_number) { |v| v.to_i? || v.to_f }
  end

  syntax :digit1_9, '1'..'9'
  syntax :digit, '0'..'9'
  syntax :hexdigit, :digit | ('a'..'f') | ('A'..'F')

  syntax :int do
    capture do
      # Sign:
      maybe { parse('-') }

      # Entire part:
      union do
        parse('0')
        parse(:digit1_9) do
          repeat { parse(:digit) }
        end
      end
    end
  end

  syntax :tk_number do
    no_skip do # Don't skip spaces inside number
      capture do
        int = parse(:int)

        return int unless peek_char == '.'

        # Decimal part:
        parse!('.')
        parse!(:digit)
        repeat { parse :digit }

        # Exponent:
        maybe do
          parse('e' | 'E')
          parse!('-' | '+')
          parse!(:digit)
          repeat { parse(:digit) }
        end
      end
    end
  end

  syntax :tk_string, '"' do
    partial_capture do |io|
      repeat_union do
        parse '\\' do
          io << parse(:escape_sequence)
        end
        io << parse not('"')
      end
      parse! '"'
    end
  end

  # Returns escaped character.
  syntax :escape_sequence do
    union do
      parse '"' | '\\' | '/'
      parse 'b' { '\b' }
      parse 'f' { '\f' }
      parse 'n' { '\n' }
      parse 'r' { '\r' }
      parse 't' { '\t' }
      parse 'u' do
        code = capture do
          4.times { parse! :hexdigit }
        end
        code.to_i(16).chr
      end
      raise_syntax_error "Invalid escape sequence: '\\#{peek_char}'"
    end
  end

  # # Syntax ##

  syntax :object, ["{"], end!: ["}"] do
    repeat_to_h(Hash(String, Value), separator: [","]) do
      parse(:key_value)
    end
  end

  syntax :key_value do
    key = parse ["string"]
    parse! [":"]
    value = parse!(:value)

    {key, value}
  end

  syntax :value do
    union do
      parse ["string"]
      parse ["number"]
      parse :object
      parse :array
      parse ["true"]
      parse ["false"]
      parse ["null"]
    end
  end

  syntax :array, ["["], end!: ["]"] do
    repeat_to_a Array(Value), separator: [","] do
      parse(:value)
    end
  end

  # # Skip ##

  skip do
    parse ' '
    parse '\n'
    parse '\t'
    parse '\r'
    # # Line comments:
    # parse "//" { repeat { parse not('\n') } }

    # # Block comments:
    # parse "/*" do
    #   repeat { parse not("*/") }
    #   parse "*/"
    # end
  end
end

json = %q(
  {
    "string": "Hello World",
    "int": -42,
    "float": 3.14,
    "bool": true,
    "null": null,
    "exponent": 2.99792458e+8,
    "object": {"a": 1, "b": 2, "c": []},
    "array": [1, "2", false],
    "escapes": "\b\t \" \u2665"
  }
)

pp JSONParserWithToken.new(json).parse
