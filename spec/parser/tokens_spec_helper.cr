require "../spec_helper"

module TopDown::Spec
  extend self

  class BaseTokenParser < TopDown::Parser
    syntax(:int) do
      capture do
        parse('1'..'9')
        repeat do
          parse('0'..'9')
        end
      end
    end

    def spec_next_token
      self.skip_chars
      self.next_token?
    end

    macro def_parse_wrapper(parselet, def_name, error)
      def spec_parse_{{def_name.id}}(_precedence_ = 0)
        handle_fail { parse({{parselet}}) }
      end

      def spec_parse_{{def_name.id}}_with_error!(_precedence_ = 0)
        handle_fail { parse!({{parselet}}, error: {{error}}) }
      end
    end
  end

  class TokenParser < BaseTokenParser
    tokens do
      token("+")
      token("*")
      token("=")
      token("int", :int, &.to_i)
      token("name", /\w+/) { $0 }
    end

    def_parse_wrapper(["+"], :plus, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper(["*"], :star, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper(["="], :eq, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper(["int"], :int, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper(["name"], :name, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper(not(["name"]), :not_name, "Custom Error: got:%{got}, expected:%{expected}")
    def_parse_wrapper([any], :any, "Custom Error: got:%{got}, expected:%{expected}")
  end

  class TokenParserWithSkip < TokenParser
    skip do
      parse(' ' | '\t' | '\n')
    end
  end

  class TokenParserWithEOF < TokenParser
    tokens do
      token("+")
      token("*")
      token("=")
      token("int", :int, &.to_i)
      token("name", /\w+/) { $0 }
      token("EOF", '\0')
    end

    def_parse_wrapper(["EOF"], :eof, "Custom Error: got:%{got}, expected:%{expected}")
  end

  class DocsTokenParser < TokenParser
    tokens do
      token("+")
      token("-")
      token("**")
      token("*")
      token("/")
      token("hey")
      token("new_line", '\n')
      token("int", /\d+/, &.to_i)
      token("string", :tk_string, &.itself)
    end

    skip { parse(' ') }

    syntax(:tk_string, '"') do
      partial_capture do |io|
        repeat { io << parse(not('"')) }
        parse!('"')
      end
    end
  end

  class_getter token_parser = TokenParser.new("")
  class_getter token_parser_with_skip = TokenParserWithSkip.new("")
  class_getter token_parser_with_eof = TokenParserWithEOF.new("")
  class_getter docs_token_parser = DocsTokenParser.new("")
end
