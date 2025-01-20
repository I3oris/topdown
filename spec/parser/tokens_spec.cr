require "./tokens_spec_helper"

def new_token(name, value = nil, end_location = TopDown::Location.new(0, 0, 0, 0))
  TopDown::Parser::Token.new(name, value, end_location: end_location)
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
    TopDown::Spec.verify_token(parser.spec_next_token, :name, "hey")
    TopDown::Spec.verify_token(parser.spec_next_token, :"=")
    TopDown::Spec.verify_token(parser.spec_next_token, :int, 3)
    TopDown::Spec.verify_token(parser.spec_next_token, :"*")
    TopDown::Spec.verify_token(parser.spec_next_token, :int, 7)
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "parses next token with skip" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey =3   \t\n* 7"
    TopDown::Spec.verify_token(parser.spec_next_token, :name, "hey")
    TopDown::Spec.verify_token(parser.spec_next_token, :"=")
    TopDown::Spec.verify_token(parser.spec_next_token, :int, 3)
    TopDown::Spec.verify_token(parser.spec_next_token, :"*")
    TopDown::Spec.verify_token(parser.spec_next_token, :int, 7)
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "parses next token (docs example)" do
    parser = TopDown::Spec.docs_token_parser
    parser.source = %(* / + "hello" \n - 123 ** hey)
    TopDown::Spec.verify_token(parser.spec_next_token, :"*")
    TopDown::Spec.verify_token(parser.spec_next_token, :"/")
    TopDown::Spec.verify_token(parser.spec_next_token, :"+")
    TopDown::Spec.verify_token(parser.spec_next_token, :string, "hello")
    TopDown::Spec.verify_token(parser.spec_next_token, :new_line)
    TopDown::Spec.verify_token(parser.spec_next_token, :"-")
    TopDown::Spec.verify_token(parser.spec_next_token, :int, 123)
    TopDown::Spec.verify_token(parser.spec_next_token, :"**")
    TopDown::Spec.verify_token(parser.spec_next_token, :hey)
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "raises on bad token" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=§"
    TopDown::Spec.verify_token(parser.spec_next_token, :name, "hey")
    TopDown::Spec.verify_token(parser.spec_next_token, :"=")
    e = expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§', could not parse any token") do
      parser.spec_next_token
    end
    e.location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4, token_pos: 0)
    e.end_location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4, token_pos: 0)
  end

  it "raises on bad token with skip" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey\t\n=\n   § "

    TopDown::Spec.verify_token(parser.spec_next_token, :name, "hey")
    TopDown::Spec.verify_token(parser.spec_next_token, :"=")
    e = expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§'") do
      parser.spec_next_token
    end
    e.location.should eq TopDown::Location.new(12, line_number: 2, line_pos: 3, token_pos: 0)
    e.end_location.should eq TopDown::Location.new(12, line_number: 2, line_pos: 3, token_pos: 0)
  end

  it "gives tokens" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=3*7"
    parser.tokens.should eq [
      new_token(:name, "hey", TopDown::Location.new(3, 0, 3, 1)),
      new_token(:"=", nil, TopDown::Location.new(4, 0, 4, 2)),
      new_token(:int, 3, TopDown::Location.new(5, 0, 5, 3)),
      new_token(:"*", nil, TopDown::Location.new(6, 0, 6, 4)),
      new_token(:int, 7, TopDown::Location.new(7, 0, 7, 5)),
    ]

    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey =3   \t\n* 7"

    parser.tokens.should eq [
      new_token(:name, "hey", TopDown::Location.new(5, 0, 5, 1)),
      new_token(:"=", nil, TopDown::Location.new(7, 0, 7, 2)),
      new_token(:int, 3, TopDown::Location.new(8, 0, 8, 3)),
      new_token(:"*", nil, TopDown::Location.new(14, 1, 1, 4)),
      new_token(:int, 7, TopDown::Location.new(16, 1, 3, 5)),
    ]
  end

  it "parses tokens" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=3*7"
    parser.spec_load_tokens
    parser.spec_parse_name.should eq "hey"
    parser.spec_parse_eq.should be_nil
    parser.spec_parse_int.should eq 3
    parser.spec_parse_star.should be_nil
    parser.spec_parse_int.should eq 7
  end

  it "fails on unexpected token" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "hey=  oups"
    parser.spec_load_tokens
    parser.spec_parse_name.should eq "hey"
    parser.spec_parse_eq.should be_nil
    parser.spec_parse_int.should be_a TopDown::Parser::Fail
    parser.location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4, token_pos: 0)
  end

  it "raises on unexpected token" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "hey=  oups"
    parser.spec_load_tokens
    parser.spec_parse_name_with_error!.should eq "hey"
    parser.spec_parse_eq_with_error!.should be_nil
    e = expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:oups, expected:int") do
      parser.spec_parse_int_with_error!
    end
    e.location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4, token_pos: 0)
    e.end_location.should eq TopDown::Location.new(10, line_number: 0, line_pos: 10, token_pos: 0)

    parser.location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4, token_pos: 0)
  end

  it "parses not token" do
    parser = TopDown::Spec.token_parser
    parser.source = "1+x"
    parser.spec_load_tokens
    parser.spec_parse_not_name.should eq 1
    parser.spec_parse_not_name.should be_nil
    parser.spec_parse_not_name.should be_a TopDown::Parser::Fail

    parser.source = "1+x"
    parser.spec_load_tokens
    parser.spec_parse_any.should eq 1
    parser.spec_parse_any.should be_nil
    parser.spec_parse_any.should eq "x"
    parser.spec_parse_any.should be_a TopDown::Parser::Fail
  end

  it "raises on not token" do
    parser = TopDown::Spec.token_parser
    parser.source = "1+oups"
    parser.spec_load_tokens
    parser.spec_parse_not_name_with_error!.should eq 1
    parser.spec_parse_not_name_with_error!.should be_nil
    e = expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:oups, expected:not name") do
      parser.spec_parse_not_name_with_error!
    end
    e.location.should eq TopDown::Location.new(2, line_number: 0, line_pos: 2, token_pos: 0)
    e.end_location.should eq TopDown::Location.new(6, line_number: 0, line_pos: 6, token_pos: 0)

    parser.location.should eq TopDown::Location.new(2, line_number: 0, line_pos: 2, token_pos: 0)

    parser.source = "1+"
    parser.spec_load_tokens
    parser.spec_parse_any_with_error!.should eq 1
    parser.spec_parse_any_with_error!.should be_nil
    e = expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:EOF, expected:not EOF") do
      parser.spec_parse_any_with_error!
    end
    e.location.should eq TopDown::Location.new(2, line_number: 0, line_pos: 2, token_pos: 0)
    e.end_location.should eq TopDown::Location.new(2, line_number: 0, line_pos: 3, token_pos: 0)

    parser.location.should eq TopDown::Location.new(2, line_number: 0, line_pos: 2, token_pos: 0)
  end
end
