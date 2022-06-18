require "./spec_helper"

module TopDown::Spec
  extend self

  class BaseTokenParser < TopDown::Parser
    syntax(:int) do
      capture do
        parse('1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9')
        repeat do
          parse('0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9')
        end
      end
    end

    def spec_next_token
      self.skip_chars
      self.next_token?
    end

    macro def_parse_wrapper(parselet, def_name, error)
      def spec_parse_{{def_name.id}}
        fail_zone { parse({{parselet}}) }
      end

      def spec_parse_{{def_name.id}}_with_error!
        fail_zone { parse!({{parselet}}, error: {{error}}) }
      end
    end
  end

  class TokenParser < BaseTokenParser
    tokens do
      parse('+') { Token.new(:"+") }
      parse('*') { Token.new(:"*") }
      parse('=') { Token.new(:"=") }
      parse(:int) { |v| Token.new(:int, v) }
      parse(/\w+/) { Token.new(:name, $0) }
    end

    def_parse_wrapper([:"+"], :plus, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([:"*"], :star, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([:"="], :eq, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([:int], :int, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([:name], :name, "Custom Error: got:%{got}, expected:%{expected}")
  end

  class TokenParserWithSkip < TokenParser
    skip do
      parse(' ' | '\t' | '\n')
    end
  end

  class TokenParserWithEOF < TokenParser
    tokens do
      parse('+') { Token.new(:"+") }
      parse('*') { Token.new(:"*") }
      parse('=') { Token.new(:"=") }
      parse(:int) { |v| Token.new(:int, v) }
      parse(/\w+/) { Token.new(:name, $0) }
      parse('\0') { Token.new(:EOF) }
    end

    def_parse_wrapper([:EOF], :eof, "Custom Error: got:%{got}, expected:%{expected}")
  end

  enum CustomTokenType
    PLUS
    STAR
    EQ
    INT
    NAME
  end

  struct CustomToken
    getter value

    def initialize(@type : CustomTokenType, @value : Int32 | String? = nil)
    end

    def is?(type : CustomTokenType)
      @type == type
    end
  end

  class CustomTokenParser < BaseTokenParser
    tokens do
      parse('+') { CustomToken.new(:PLUS) }
      parse('*') { CustomToken.new(:STAR) }
      parse('=') { CustomToken.new(:EQ) }
      parse(:int) { |v| CustomToken.new(:INT, v.to_i) }
      parse(/\w+/) { CustomToken.new(:NAME, $0) }
    end

    skip do
      parse(' ' | '\t' | '\n')
    end

    def_parse_wrapper([:PLUS], :plus, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([:STAR], :star, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([:EQ], :eq, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([:INT], :int, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([:NAME], :name, "Custom Error: got:%{got}, expected:%{expected}")
    # def_parse_wrapper([:NAME], :eof, "Custom Error: got:%{got}, expected:%{expected}")
  end

  class_getter token_parser = TokenParser.new("")
  class_getter token_parser_with_skip = TokenParserWithSkip.new("")
  class_getter token_parser_with_eof = TokenParserWithEOF.new("")
  class_getter custom_token_parser = CustomTokenParser.new("")
end
