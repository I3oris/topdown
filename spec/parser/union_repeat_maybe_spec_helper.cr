require "./parser_spec_helper"

module TopDown::Spec
  class UnionParser < ParserBase
    def_parse_wrapper :union_a { parse('a' | "A" | /α/) }
    def_parse_wrapper :union_b! { parse!('b' | "B" | /β/) }
    def_parse_wrapper :union_c_with_error! { parse!('c' | "C" | /γ/, error: "Custom Error: got:%{got}, expected:%{expected}") }
    def_parse_wrapper :union_d_with_error_proc! do
      parse!('d' | "D" | /Δ/, error: ->(got : Char, _expected : Nil) { "Custom Error Proc: got:#{got}" })
    end
    def_parse_wrapper :union_e_with_block { parse('e' | "E" | /ε/) { |v| {"Custom return", v} } }
    def_parse_wrapper :union_f_with_block! { parse!('f' | "F" | /λ/) { |v| {"Custom return", v} } }

    # TODO:
    def_parse_wrapper :union_empty { union { } }

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
    #   union!(error: "Custom Error: got:%{got}, expected 'a', 'A' or 'α'") do
    #     parse('a')
    #     parse("A")
    #     parse(/α/)
    #   end
    # end

    # TODO:
    # def_parse_wrapper :union_expanded_with_error_proc! do
    #   union!(error: ->(got : Char, _expected : Nil) { "Custom Error: got:#{got}, expected 'a', 'A' or 'α'" } ) do
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

  class MaybeParser < ParserBase
    def_parse_wrapper :maybe_char { maybe { parse('a') } }
    def_parse_wrapper :maybe_string { maybe { parse("bbb") } }
    def_parse_wrapper :maybe_regex { maybe { parse(/c+/) } }
    def_parse_wrapper :maybe_parselet_union { maybe { parse('a' | "bbb" | /c+/) } }

    def_parse_wrapper :maybe_union do
      maybe_union do
        parse('a')
        parse("bbb")
        parse(/c+/)
      end
    end
  end

  class RepeatParser < ParserBase
    def_parse_wrapper :rep_char { capture { repeat { parse('a') } } }
    def_parse_wrapper :rep_string { capture { repeat { parse("bbb") } } }
    def_parse_wrapper :rep_regex { capture { repeat { parse(/c+;/) } } }
    def_parse_wrapper :rep_parselet_union { capture { repeat { parse('a' | "bbb" | /c+/) } } }

    def_parse_wrapper :rep_union do
      capture do
        repeat_union do
          parse('a')
          parse("bbb")
          parse(/c+/)
        end
      end
    end

    def_parse_wrapper :rep_with_sep { capture { repeat(separator: ',') { parse(/\w+/) } } }
  end

  class_getter union_parser = UnionParser.new("")
  class_getter maybe_parser = MaybeParser.new("")
  class_getter repeat_parser = RepeatParser.new("")
end
