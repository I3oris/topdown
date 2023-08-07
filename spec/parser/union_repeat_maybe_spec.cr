require "./union_repeat_maybe_spec_helper"

zero = TopDown::Location.new(0, 0, 0)

describe TopDown::Parser do
  it "parses union" do
    parser = TopDown::Spec.union_parser

    parser.source = "a"
    parser.spec_parse_union_a.should eq('a')

    parser.source = "B"
    parser.spec_parse_union_b!.should eq("B")

    parser.source = "γ"
    parser.spec_parse_union_c_with_error!.should eq("γ")

    parser.source = "d"
    parser.spec_parse_union_d_with_error_proc!.should eq('d')

    parser.source = "E"
    parser.spec_parse_union_e_with_block.should eq({"Custom return", "E"})

    parser.source = "λ"
    parser.spec_parse_union_f_with_block!.should eq({"Custom return", "λ"})

    parser.source = "a"
    parser.spec_parse_union_expanded.should eq('a')
    parser.source = "A"
    parser.spec_parse_union_expanded.should eq("A")
    parser.source = "α"
    parser.spec_parse_union_expanded.should eq("α")

    parser.source = "1"
    parser.spec_parse_union_expanded_with_sequence.should eq('1')
    parser.source = "abc"
    parser.spec_parse_union_expanded_with_sequence.should eq('c')
    parser.source = "a"
    parser.spec_parse_union_expanded_with_sequence.should eq('a')

    parser.source = "abbc"
    parser.spec_parse_union_complex.should eq({syntax: {a: 'a', b: "bb", c: "c"}})
    parser.source = "abbccc"
    parser.spec_parse_union_complex.should eq({syntax: {a: 'a', b: "bb", c: "ccc"}})
    parser.source = "ac"
    parser.spec_parse_union_complex.should eq({sequence: {'a', 'c'}})
    parser.source = "abc"
    parser.spec_parse_union_complex.should eq({sequence: {"ab", 'c'}})
    parser.source = "abb"
    parser.spec_parse_union_complex.should eq({regex: "abb"})
    parser.source = "abbbb"
    parser.spec_parse_union_complex.should eq({regex: "abbbb"})
    parser.source = "a"
    parser.spec_parse_union_complex.should eq({char: 'a'})
  end

  it "fails parsing union" do
    parser = TopDown::Spec.union_parser

    parser.source = "§"
    parser.spec_parse_union_a.should be_a TopDown::Parser::Fail
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§'") do
      parser.spec_parse_union_b!
    end
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:§, expected:EOF") do
      parser.spec_parse_union_c_with_error!
    end
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error Proc: got:§") do
      parser.spec_parse_union_d_with_error_proc!
    end
    parser.location.should eq zero

    parser.source = "§"
    parser.spec_parse_union_e_with_block.should be_a TopDown::Parser::Fail
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§'") do
      parser.spec_parse_union_f_with_block!
    end
    parser.location.should eq zero

    parser.source = "§"
    parser.spec_parse_union_empty.should be_a TopDown::Parser::Fail
    parser.location.should eq zero

    parser.source = "§"
    parser.spec_parse_union_expanded.should be_a TopDown::Parser::Fail
    parser.location.should eq zero

    parser.source = "§"
    parser.spec_parse_union_expanded_with_sequence.should be_a TopDown::Parser::Fail

    parser.source = "ab§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected character 'c'") do
      parser.spec_parse_union_expanded_with_sequence
    end
    # parser.location.should eq zero # PENDING

    parser.source = "§"
    parser.spec_parse_union_complex.should be_a TopDown::Parser::Fail

    parser.source = "bbc"
    parser.spec_parse_union_complex.should be_a TopDown::Parser::Fail
  end

  it "parses maybe" do
    parser = TopDown::Spec.maybe_parser

    parser.source = "a"
    parser.spec_parse_maybe_char.should eq 'a'
    parser.source = "§"
    parser.spec_parse_maybe_char.should be_nil
    parser.location.should eq zero

    parser.source = "bbb"
    parser.spec_parse_maybe_string.should eq "bbb"
    parser.source = "bb§"
    parser.spec_parse_maybe_string.should be_nil
    parser.location.should eq zero

    parser.source = "cc"
    parser.spec_parse_maybe_regex.should eq "cc"
    parser.source = "§"
    parser.spec_parse_maybe_regex.should be_nil
    parser.location.should eq zero

    parser.source = "bbb"
    parser.spec_parse_maybe_parselet_union.should eq "bbb"
    parser.source = "§"
    parser.spec_parse_maybe_parselet_union.should be_nil
    parser.location.should eq zero

    parser.source = "cc"
    parser.spec_parse_maybe_union.should eq "cc"
    parser.source = "§"
    parser.spec_parse_maybe_union.should be_nil
    parser.location.should eq zero
  end

  it "parses repeat" do
    parser = TopDown::Spec.repeat_parser

    parser.source = "aaa"
    parser.spec_parse_rep_char.should eq "aaa"
    parser.source = "a"
    parser.spec_parse_rep_char.should eq "a"
    parser.source = "§"
    parser.spec_parse_rep_char.should eq ""

    parser.source = "bbbbbb"
    parser.spec_parse_rep_string.should eq "bbbbbb"
    parser.source = "bbbb§"
    parser.spec_parse_rep_string.should eq "bbb"
    parser.source = "§"
    parser.spec_parse_rep_string.should eq ""

    parser.source = "cc;c;cccc;"
    parser.spec_parse_rep_regex.should eq "cc;c;cccc;"
    parser.source = "cc;c§"
    parser.spec_parse_rep_regex.should eq "cc;"
    parser.source = "§"
    parser.spec_parse_rep_regex.should eq ""

    parser.source = "bbbaaccc"
    parser.spec_parse_rep_parselet_union.should eq "bbbaaccc"
    parser.source = "abb§"
    parser.spec_parse_rep_parselet_union.should eq "a"
    parser.source = "§"
    parser.spec_parse_rep_parselet_union.should eq ""

    parser.source = "abbbac"
    parser.spec_parse_rep_union.should eq "abbbac"

    parser.source = "ab,bb,ac"
    parser.spec_parse_rep_with_sep.should eq "ab,bb,ac"
  end
end
