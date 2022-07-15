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

    # PENDING
    # parser.source = ""
    # parser.spec_parse_union_empty.should be_nil

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
    # parser.location.should eq zero # PENDING

    # PENDING
    # parser.source = "§"
    # expect_raises(TopDown::Parser::SyntaxError, "TODO") do
    #   parser.spec_parse_union_b!
    # end
    # parser.location.should eq zero # PENDING

    # PENDING
    # parser.source = "§"
    # expect_raises(TopDown::Parser::SyntaxError, "TODO") do
    #   parser.spec_parse_union_c_with_error!
    # end
    # parser.location.should eq zero # PENDING

    # PENDING
    # parser.source = "§"
    # expect_raises(TopDown::Parser::SyntaxError, "TODO") do
    #   parser.spec_parse_union_d_with_error_proc!
    # end
    # parser.location.should eq zero # PENDING

    parser.source = "§"
    parser.spec_parse_union_e_with_block.should be_a TopDown::Parser::Fail
    # parser.location.should eq zero # PENDING

    # PENDING
    # parser.source = "§"
    # expect_raises(TopDown::Parser::SyntaxError, "TODO") do
    #   parser.spec_parse_union_f_with_block!
    # end
    # parser.location.should eq zero # PENDING

    # PENDING
    # parser.source = "§"
    # parser.spec_parse_union_empty.should be_nil
    # parser.location.should eq zero # PENDING

    parser.source = "§"
    parser.spec_parse_union_expanded.should be_a TopDown::Parser::Fail
    # parser.location.should eq zero # PENDING

    parser.source = "§"
    parser.spec_parse_union_expanded_with_sequence.should be_a TopDown::Parser::Fail

    parser.source = "ab§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected 'c'") do
      parser.spec_parse_union_expanded_with_sequence
    end
    # parser.location.should eq zero # PENDING

    parser.source = "§"
    parser.spec_parse_union_complex.should be_a TopDown::Parser::Fail

    parser.source = "bbc"
    parser.spec_parse_union_complex.should be_a TopDown::Parser::Fail
  end
end
