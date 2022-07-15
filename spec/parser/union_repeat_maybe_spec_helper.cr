require "./parser_spec_helper"

module TopDown::Spec
  class UnionParser < ParserBase
    def_parse_wrapper :union_a { parse('a' | "A" | /α/) }
    def_parse_wrapper :union_b! { parse!('b' | "B" | /β/) }
    def_parse_wrapper :union_c_with_error! { parse!('c' | "C" | /γ/, error: "Custom Error: got:%{got}, expected:%{expected}") }
    def_parse_wrapper :union_d_with_error_proc! do
      parse!('d' | "D" | /Δ/, error: ->(got : Char, expected : Array(Char)) { "Custom Error Proc: got:#{got}, expected:#{expected}" })
    end
    def_parse_wrapper :union_e_with_block { parse('e' | "E" | /ε/) { |v| {"Custom return", v} } }
    def_parse_wrapper :union_f_with_block! { parse!('f' | "F" | /λ/) { |v| {"Custom return", v} } }

    # TODO:
    # def_parse_wrapper :union_empty { union {} }

    def_parse_wrapper :union_expanded do
      union do
        parse('a')
        parse("A")
        parse(/α/)
      end
    end

    # TODO:
    # def_parse_wrapper :union_expanded! do
    #   union! do
    #     parse('a')
    #     parse("A")
    #     parse(/α/)
    #   end
    # end

    # TODO:
    # def_parse_wrapper :union_expanded_with_error! do
    #   union!(error: "TODO") do
    #     parse('a')
    #     parse("A")
    #     parse(/α/)
    #   end
    # end

    # TODO:
    # def_parse_wrapper :union_expanded_with_error_proc! do
    #   union!(error: ->{"TODO"}) do
    #     parse('a')
    #     parse("A")
    #     parse(/α/)
    #   end
    # end

    def_parse_wrapper :union_expanded_with_sequence do
      union do
        parse('1')
        parse('2')
        sequence do
          parse('a')
          parse('b')
          parse!('c')
        end
        parse('a')
      end
    end

    syntax(:syntax) do
      a = parse('a')
      b = parse("bb")
      c = parse(/c+/)
      {a: a, b: b, c: c}
    end

    def_parse_wrapper :union_complex do
      union do
        parse(:syntax) { |r| {syntax: r} }
        sequence do
          r1 = parse("ab" | 'a')
          r2 = parse('c')
          {sequence: {r1, r2}}
        end
        parse(/ab+/) { |r| {regex: r} }
        parse('a') { |r| {char: r} }
      end
    end
  end

  class_getter union_parser = UnionParser.new("")
end
