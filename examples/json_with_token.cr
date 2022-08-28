require "../src/topdown"

# Same parser as `json.cr` but using tokens.
class JSONParserWithToken < TopDown::Parser
  root :object

  alias Value = String | Float64 | Int32 | Bool | Nil | Hash(String, Value) | Array(Value)

  # # Tokens ##

  tokens do
    parse('{') { Token.new(:"{") }
    parse('}') { Token.new(:"}") }
    parse(':') { Token.new(:":") }
    parse('[') { Token.new(:"[") }
    parse(']') { Token.new(:"]") }
    parse(',') { Token.new(:",") }
    parse("true") { Token.new(:true) }
    parse("false") { Token.new(:false) }
    parse("null") { Token.new(:null) }
    parse(:tk_string) { |v| Token.new(:string, v) }
    parse(:tk_number) { |v| Token.new(:number, v) }
  end

  syntax :digit1_9, '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' { }
  syntax :digit, '0' | :digit1_9 { }
  syntax :hexdigit, :digit | 'a' | 'b' | 'c' | 'd' | 'e' | 'f' | 'A' | 'B' | 'C' | 'D' | 'E' | 'F' { }

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

  syntax :object, [:"{"] do
    obj = {} of String => Value

    repeat separator: [:","] do
      key, value = parse(:key_value)
      obj[key] = value
    end

    parse! [:"}"]
    obj
  end

  syntax :key_value do
    key = parse [:string]
    parse! [:":"]
    value = parse! :value

    {key, value}
  end

  syntax :value do
    union do
      parse [:string]
      parse [:number] { |v| v.to_i? || v.to_f }
      parse :object
      parse :array
      parse [:true] { true }
      parse [:false] { false }
      parse [:null] { nil }
    end
  end

  syntax :array, [:"["] do
    values = [] of Value

    repeat separator: [:","] do
      values << parse :value
    end
    parse! [:"]"]

    values
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
