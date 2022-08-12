require "./parser_spec_helper"

zero = TopDown::Location.new(0, 0, 0)

describe TopDown::Parser do
  it "parses char" do
    parser = TopDown::Spec.char_parser
    parser.source = "abcdef"
    parser.spec_parse_ch_a.should eq 'a'
    parser.spec_parse_ch_b!.should eq 'b'
    parser.spec_parse_ch_c_with_error!.should eq 'c'
    parser.spec_parse_ch_d_with_error_proc!.should eq 'd'
    parser.spec_parse_ch_e_with_block.should eq({"Custom return", 'e'})
    parser.spec_parse_ch_f_with_block!.should eq({"Custom return", 'f'})
  end

  it "fails parsing char" do
    parser = TopDown::Spec.char_parser
    parser.source = "§"
    parser.spec_parse_ch_a.should be_a TopDown::Parser::Fail
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected 'b'") do
      parser.spec_parse_ch_b!
    end
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:§, expected:c") do
      parser.spec_parse_ch_c_with_error!
    end
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error Proc: got:§, expected:d") do
      parser.spec_parse_ch_d_with_error_proc!
    end
    parser.location.should eq zero

    parser.source = "§"
    parser.spec_parse_ch_e_with_block.should be_a TopDown::Parser::Fail
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected 'f'") do
      parser.spec_parse_ch_f_with_block!
    end
    parser.location.should eq zero
  end

  it "parses string" do
    parser = TopDown::Spec.string_parser
    parser.source = "abcdefghijklmnopqr"
    parser.spec_parse_str_abc.should eq "abc"
    parser.spec_parse_str_def!.should eq "def"
    parser.spec_parse_str_empty.should eq ""
    parser.spec_parse_str_ghi_with_error!.should eq "ghi"
    parser.spec_parse_str_jkl_with_error_proc!.should eq "jkl"
    parser.spec_parse_str_mno_with_block.should eq({"Custom return", "mno"})
    parser.spec_parse_str_pqr_with_block!.should eq({"Custom return", "pqr"})
  end

  it "fails parsing string" do
    parser = TopDown::Spec.string_parser
    parser.source = "ab§"
    parser.spec_parse_str_abc.should be_a TopDown::Parser::Fail
    # parser.location.should eq zero # PENDING

    parser.source = "de§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected 'def'") do
      parser.spec_parse_str_def!
    end
    # parser.location.should eq zero # PENDING

    parser.source = "§"
    parser.spec_parse_str_empty.should eq ""
    parser.location.should eq zero

    parser.source = "gh§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:§, expected:ghi") do
      parser.spec_parse_str_ghi_with_error!
    end
    # parser.location.should eq zero # PENDING

    parser.source = "jk§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error Proc: got:§, expected:jkl") do
      parser.spec_parse_str_jkl_with_error_proc!
    end
    # parser.location.should eq zero # PENDING

    parser.source = "mn§"
    parser.spec_parse_str_mno_with_block.should be_a TopDown::Parser::Fail
    # parser.location.should eq zero # PENDING

    parser.source = "pq§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected 'pqr'") do
      parser.spec_parse_str_pqr_with_block!
    end
    # parser.location.should eq zero # PENDING
  end

  it "parses regex" do
    parser = TopDown::Spec.regex_parser
    parser.source = "abbcccdeeeeefaAAabbb\nccd"
    parser.spec_parse_rgx_a.should eq "a"
    parser.spec_parse_rgx_b!.should eq "bb"
    parser.spec_parse_rgx_c_with_error!.should eq "ccc"
    parser.spec_parse_rgx_d_with_error_proc!.should eq "d"
    parser.spec_parse_rgx_e_with_block.should eq({"Custom return", "eeeee", "eeeee", "e"})
    parser.spec_parse_rgx_f_with_block!.should eq({"Custom return", "f", "f", "f"})
    parser.spec_parse_rgx_empty.should eq ""
    parser.spec_parse_rgx_empty_match.should eq ""
    parser.spec_parse_rgx_i!.should eq "aAAa"
    parser.spec_parse_rgx_m!.should eq "bbb\ncc"

    # PENDING:
    # parser.spec_parse_rgx_x!.should eq "d"
  end

  it "fails parsing regex" do
    parser = TopDown::Spec.regex_parser
    parser.source = "§"
    parser.spec_parse_rgx_a.should be_a TopDown::Parser::Fail
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected patern /b+/") do
      parser.spec_parse_rgx_b!
    end
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:§, expected:/c+/") do
      parser.spec_parse_rgx_c_with_error!
    end
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error Proc: got:§, expected:(?-imsx:d+)") do
      parser.spec_parse_rgx_d_with_error_proc!
    end
    parser.location.should eq zero

    parser.source = "§"
    parser.spec_parse_rgx_e_with_block.should be_a TopDown::Parser::Fail
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected patern /(f)+/") do
      parser.spec_parse_rgx_f_with_block!
    end
    parser.location.should eq zero

    parser.spec_parse_rgx_empty.should eq ""
    parser.spec_parse_rgx_empty_match.should eq ""
    parser.location.should eq zero

    parser.source = "§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected patern /a+/i") do
      parser.spec_parse_rgx_i!
    end
    parser.location.should eq zero

    parser.source = "bbb§"
    # TODO improve this error:
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character 'b', expected patern /b+\\nc+/m") do
      parser.spec_parse_rgx_m!
    end
    parser.location.should eq zero

    # PENDING:
    # parser.source = "§"
    # expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected patern /  d+ #comment/x") do
    #   parser.spec_parse_rgx_x!
    # end
    # parser.location.should eq zero
  end

  it "parses syntax" do
    parser = TopDown::Spec.syntax_parser
    parser.source = "abbc;abbcc;abbccc;abbcccc;abbccc;abbcc;abbc;abbcc;"
    parser.spec_parse_syn.should eq({a: 'a', b: "bb", c: "c"})
    parser.spec_parse_syn!.should eq({a: 'a', b: "bb", c: "cc"})
    parser.spec_parse_syn_with_error!.should eq({a: 'a', b: "bb", c: "ccc"})
    parser.spec_parse_syn_with_error_proc!.should eq({a: 'a', b: "bb", c: "cccc"})
    parser.spec_parse_syn_with_block.should eq({"Custom return", {a: 'a', b: "bb", c: "ccc"}})
    parser.spec_parse_syn_with_block!.should eq({"Custom return", {a: 'a', b: "bb", c: "cc"}})

    parser.spec_parse_syn_empty.should be_nil
    parser.spec_parse_syn_with_prefix.should eq({a: 'a', b: "bb", c: "c"})
    parser.spec_parse_syn_blockless.should eq({'a', "bb", "cc", ';'})
  end

  it "fails parsing syntax" do
    parser = TopDown::Spec.syntax_parser
    parser.source = "abb§"
    parser.spec_parse_syn.should be_a TopDown::Parser::Fail
    # parser.location.should eq zero # PENDING

    parser.source = "abb§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected syntax") do
      parser.spec_parse_syn!
    end
    # parser.location.should eq zero # PENDING

    parser.source = "abb§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:§, expected:syntax") do
      parser.spec_parse_syn_with_error!
    end
    # parser.location.should eq zero # PENDING

    parser.source = "abb§"
    expect_raises(TopDown::Parser::SyntaxError, "Custom Error Proc: got:§, expected:syntax") do
      parser.spec_parse_syn_with_error_proc!
    end
    # parser.location.should eq zero # PENDING

    parser.source = "abb§"
    parser.spec_parse_syn_with_block.should be_a TopDown::Parser::Fail
    # parser.location.should eq zero # PENDING

    parser.source = "abb§"
    expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', expected syntax") do
      parser.spec_parse_syn_with_block!
    end
    # parser.location.should eq zero # PENDING

    parser.source = "§"
    parser.spec_parse_syn_empty.should be_nil
    parser.location.should eq zero

    parser.source = "abb§"
    parser.spec_parse_syn_with_prefix.should be_a TopDown::Parser::Fail
    # parser.location.should eq zero # PENDING

    parser.source = "abb§"
    parser.spec_parse_syn_blockless.should be_a TopDown::Parser::Fail
    # parser.location.should eq zero # PENDING
  end

  it "parses with skip" do
    parser = TopDown::Spec.skip_parser

    parser.source = "abbc;ab bcc"
    parser.spec_parse_with_skip.should eq [{a: 'a', b: "bb", c: "c"}, 'a', "b b", "cc"]

    parser.source = " a  bb\nc ;\t\ta b b  cc\n"
    parser.spec_parse_with_skip.should eq [{a: 'a', b: "bb", c: "c"}, 'a', "b b", "cc"]
  end

  it "fails parsing with skip" do
    parser = TopDown::Spec.skip_parser

    parser.source = " a  b   bcc"
    parser.spec_parse_with_skip.should eq ['a']
    parser.location.should eq TopDown::Location.new(2, line_number: 0, line_pos: 2)

    parser.source = "abb"
    parser.spec_parse_with_skip.should eq ['a']
    parser.location.should eq TopDown::Location.new(1, line_number: 0, line_pos: 1)
  end

  it "parses with skip syntax" do
    parser = TopDown::Spec.skip_syntax_parser

    parser.source = "((aaa))"
    parser.spec_parse_exp.should eq "aaa"

    parser.source = " ( ( aaa)  )"
    parser.spec_parse_exp.should eq "aaa"

    parser.source = "#(ccc) ( #(cc#(c)c#()) ( aaa#())  )# cc"
    parser.spec_parse_exp.should eq "aaa"

    parser.source = "(aaa)"
    parser.spec_parse_exp_with_no_skip.should eq "aaa"
  end
end
