require "../spec_helper"

module TopDown::Spec
  extend self

  class ParserBase < TopDown::Parser
    macro def_parse_wrapper(name, &)
      def spec_parse_{{name.id}}(_precedence_ = 0)
        fail_zone { {{ yield }} }
      end
    end
  end

  class CharParser < ParserBase
    def_parse_wrapper :ch_a { parse('a') }
    def_parse_wrapper :ch_b! { parse!('b') }
    def_parse_wrapper :ch_c_with_error! { parse!('c', error: "Custom Error: got:%{got}, expected:%{expected}") }
    def_parse_wrapper :ch_d_with_error_proc! do
      parse!('d', error: ->(got : Char, expected : Char) { "Custom Error Proc: got:#{got}, expected:#{expected}" })
    end
    def_parse_wrapper :ch_e_with_block { parse('e') { |ch| {"Custom return", ch} } }
    def_parse_wrapper :ch_f_with_block! { parse!('f') { |ch| {"Custom return", ch} } }
  end

  class StringParser < ParserBase
    def_parse_wrapper :str_abc { parse("abc") }
    def_parse_wrapper :str_def! { parse!("def") }
    def_parse_wrapper :str_ghi_with_error! { parse!("ghi", error: "Custom Error: got:%{got}, expected:%{expected}") }
    def_parse_wrapper :str_jkl_with_error_proc! do
      parse!("jkl", error: ->(got : Char, expected : String) { "Custom Error Proc: got:#{got}, expected:#{expected}" })
    end
    def_parse_wrapper :str_mno_with_block { parse("mno") { |str| {"Custom return", str} } }
    def_parse_wrapper :str_pqr_with_block! { parse!("pqr") { |str| {"Custom return", str} } }
    def_parse_wrapper :str_empty { parse("") }
  end

  class RegexParser < ParserBase
    def_parse_wrapper :rgx_a { parse(/a+/) }
    def_parse_wrapper :rgx_b! { parse!(/b+/) }
    def_parse_wrapper :rgx_c_with_error! { parse!(/c+/, error: "Custom Error: got:%{got}, expected:%{expected}") }
    def_parse_wrapper :rgx_d_with_error_proc! do
      parse!(/d+/, error: ->(got : Char, expected : Regex) { "Custom Error Proc: got:#{got}, expected:#{expected}" })
    end
    def_parse_wrapper :rgx_e_with_block { parse(/(e)+/) { |match| {"Custom return", match, $0, $1} } }
    def_parse_wrapper :rgx_f_with_block! { parse!(/(f)+/) { |match| {"Custom return", match, $0, $1} } }
    def_parse_wrapper :rgx_empty { parse(//) }
    def_parse_wrapper :rgx_empty_match { parse(/x*/) }
    def_parse_wrapper :rgx_i! { parse!(/a+/i) }
    def_parse_wrapper :rgx_m! { parse!(/b+\nc+/m) }
    # def_parse_wrapper :rgx_x! { parse!(/  d+ #comment/x) } # PENDING
  end

  class SyntaxParser < ParserBase
    def_parse_wrapper :syn { parse(:syntax) }
    def_parse_wrapper :syn! { parse!(:syntax) }
    def_parse_wrapper :syn_with_error! { parse!(:syntax, error: "Custom Error: got:%{got}, expected:%{expected}") }
    def_parse_wrapper :syn_with_error_proc! do
      parse!(:syntax, error: ->(got : Char, expected : Symbol) { "Custom Error Proc: got:#{got}, expected:#{expected}" })
    end
    def_parse_wrapper :syn_with_block { parse(:syntax) { |v| {"Custom return", v} } }
    def_parse_wrapper :syn_with_block! { parse!(:syntax) { |v| {"Custom return", v} } }

    def_parse_wrapper :syn_empty { parse(:empty_syntax) }
    def_parse_wrapper :syn_with_prefix { parse(:syntax_with_prefix) }
    def_parse_wrapper :syn_blockless { parse(:blockless_syntax) }

    syntax(:syntax) do
      a = parse('a')
      b = parse("bb")
      c = parse(/c+/)
      parse!(';')
      {a: a, b: b, c: c}
    end

    syntax(:empty_syntax) { }
    syntax(:syntax_with_prefix, 'a', "bb", /c+/) do |a, b, c|
      parse!(';')
      {a: a, b: b, c: c}
    end

    syntax(:blockless_syntax, 'a', "bb", /c+/, ';') { |a, b, c, d| {a, b, c, d} } # TODO: make it really block less!
  end

  class_getter char_parser = CharParser.new("")
  class_getter string_parser = StringParser.new("")
  class_getter regex_parser = RegexParser.new("")
  class_getter syntax_parser = SyntaxParser.new("")
end
