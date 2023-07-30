require "./tokens_spec_helper"

def new_token(name, value = nil)
  TopDown::Parser::Token.new(name, value)
end

describe TopDown::Parser::Token do
  it "to_s" do
    new_token(:foo).to_s.should eq "[foo]"
    new_token(:"{").to_s.should eq "[{]"
    new_token(:"\"").to_s.should eq %q([\"])
    new_token(:foo, "").to_s.should eq "[foo:]"
    new_token(:foo, "bar").to_s.should eq "[foo:bar]"
    new_token(:foo, %(puts "Hello\nWorld")).to_s.should eq %q([foo:puts \"Hello\nWorld\"])
    new_token(:foo, 123).to_s.should eq %q([foo:123])
    new_token(:foo, [1, 2, 3]).to_s.should eq %q([foo:[1, 2, 3]])
    new_token(:":").to_s.should eq %q([:])
    new_token(:":", ":").to_s.should eq %q([:::])
  end

  it "parses next token" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=3*7"
    parser.spec_next_token.should eq new_token(:name, "hey")
    parser.spec_next_token.should eq new_token(:"=")
    parser.spec_next_token.should eq new_token(:int, 3)
    parser.spec_next_token.should eq new_token(:"*")
    parser.spec_next_token.should eq new_token(:int, 7)
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "parses next token with skip" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey =3   \t\n* 7"
    parser.spec_next_token.should eq new_token(:name, "hey")
    parser.spec_next_token.should eq new_token(:"=")
    parser.spec_next_token.should eq new_token(:int, 3)
    parser.spec_next_token.should eq new_token(:"*")
    parser.spec_next_token.should eq new_token(:int, 7)
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "parses next token with eof" do
    parser = TopDown::Spec.token_parser_with_eof
    parser.source = "hey=3*7"
    parser.spec_next_token.should eq new_token(:name, "hey")
    parser.spec_next_token.should eq new_token(:"=")
    parser.spec_next_token.should eq new_token(:int, 3)
    parser.spec_next_token.should eq new_token(:"*")
    parser.spec_next_token.should eq new_token(:int, 7)
    parser.spec_next_token.should eq new_token(:EOF)
    parser.spec_next_token.should eq new_token(:EOF)
  end

  it "parses next token (docs example)" do
    parser = TopDown::Spec.docs_token_parser
    parser.source = %(* / + "hello" \n - 123 ** hey)
    parser.spec_next_token.should eq new_token(:"*")
    parser.spec_next_token.should eq new_token(:"/")
    parser.spec_next_token.should eq new_token(:"+")
    parser.spec_next_token.should eq new_token(:string, "hello")
    parser.spec_next_token.should eq new_token(:new_line)
    parser.spec_next_token.should eq new_token(:"-")
    parser.spec_next_token.should eq new_token(:int, 123)
    parser.spec_next_token.should eq new_token(:"**")
    parser.spec_next_token.should eq new_token(:hey)
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "raises on bad token" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=§"
    parser.spec_next_token.should eq new_token(:name, "hey")
    parser.spec_next_token.should eq new_token(:"=")
    e = expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§'") do
      parser.spec_next_token
    end
    e.location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4)
    e.end_location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4)
  end

  it "raises on bad token with skip" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey\t\n=\n   § "
    parser.spec_next_token.should eq new_token(:name, "hey")
    parser.spec_next_token.should eq new_token(:"=")
    e = expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§'") do
      parser.spec_next_token
    end
    e.location.should eq TopDown::Location.new(12, line_number: 2, line_pos: 3)
    e.end_location.should eq TopDown::Location.new(12, line_number: 2, line_pos: 3)
  end

  it "gives tokens" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=3*7"
    parser.tokens.should eq [
      new_token(:name, "hey"),
      new_token(:"="),
      new_token(:int, 3),
      new_token(:"*"),
      new_token(:int, 7),
    ]

    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey =3   \t\n* 7"
    parser.tokens.should eq [
      new_token(:name, "hey"),
      new_token(:"="),
      new_token(:int, 3),
      new_token(:"*"),
      new_token(:int, 7),
    ]

    parser = TopDown::Spec.token_parser_with_eof
    parser.source = "hey=3*7"
    parser.tokens(:"EOF").should eq [
      new_token(:name, "hey"),
      new_token(:"="),
      new_token(:int, 3),
      new_token(:"*"),
      new_token(:int, 7),
    ]
  end

  it "parses tokens" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=3*7"
    parser.spec_parse_name.should eq "hey"
    parser.spec_parse_eq.should be_nil
    parser.spec_parse_int.should eq 3
    parser.spec_parse_star.should be_nil
    parser.spec_parse_int.should eq 7
  end

  it "fails on unexpected token" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "hey=  oups"
    parser.spec_parse_name.should eq "hey"
    parser.spec_parse_eq.should be_nil
    parser.spec_parse_int.should be_a TopDown::Parser::Fail
  end

  it "raises on unexpected token" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "hey=  oups"
    parser.spec_parse_name_with_error!.should eq "hey"
    parser.spec_parse_eq_with_error!.should be_nil
    e = expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:name, expected:int") do
      parser.spec_parse_int_with_error!
    end
    e.location.should eq TopDown::Location.new(6, line_number: 0, line_pos: 6)
    e.end_location.should eq TopDown::Location.new(10, line_number: 0, line_pos: 10)
  end

  it "parses not token" do
    parser = TopDown::Spec.token_parser
    parser.source = "1+x"
    parser.spec_parse_not_name.should eq 1
    parser.spec_parse_not_name.should be_nil
    parser.spec_parse_not_name.should be_a TopDown::Parser::Fail

    parser.source = "1+x"
    parser.spec_parse_any.should eq 1
    parser.spec_parse_any.should be_nil
    parser.spec_parse_any.should eq "x"
    parser.spec_parse_any.should be_a TopDown::Parser::Fail
  end
end
