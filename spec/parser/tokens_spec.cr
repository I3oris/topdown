require "./tokens_spec_helper"

describe TopDown::Parser::Token do
  it "tests is?" do
    TopDown::Parser::Token.new(:foo).is?(:foo).should be_true
    TopDown::Parser::Token.new(:foo).is?(:bar).should be_false
    TopDown::Parser::Token.new(:foo, "bar").is?(:foo).should be_true
    TopDown::Parser::Token.new(:foo, "bar").is?(:bar).should be_false

    TopDown::Parser::Token.new([1, '2', /3/]).is?([1, '2', /3/]).should be_true
    TopDown::Parser::Token.new([1, '2', /3/]).is?(['b', 'a', /r/]).should be_false
    TopDown::Parser::Token.new("foo").is?("foo").should be_true
    TopDown::Parser::Token.new("foo").is?("bar").should be_false

    TopDown::Parser::Token.new(TopDown::Spec::CustomTokenType::PLUS).is?(TopDown::Spec::CustomTokenType::PLUS).should be_true
    TopDown::Parser::Token.new(TopDown::Spec::CustomTokenType::PLUS).is?(TopDown::Spec::CustomTokenType::STAR).should be_false
    TopDown::Parser::Token.new(TopDown::Spec::CustomTokenType::PLUS).is?(:PLUS).should be_true
    TopDown::Parser::Token.new(TopDown::Spec::CustomTokenType::PLUS).is?(:STAR).should be_false

    TopDown::Spec::CustomToken.new(:PLUS).is?(:PLUS).should be_true
    TopDown::Spec::CustomToken.new(:PLUS).is?(:STAR).should be_false
  end

  it "to_s" do
    TopDown::Parser::Token.new(:foo).to_s.should eq "[foo]"
    TopDown::Parser::Token.new(:"{").to_s.should eq "[{]"
    TopDown::Parser::Token.new(:"\"").to_s.should eq %q([\"])
    TopDown::Parser::Token.new("\"").to_s.should eq %q([\"])
    TopDown::Parser::Token.new(:foo, "").to_s.should eq "[foo]"
    TopDown::Parser::Token.new(:foo, "bar").to_s.should eq "[foo:bar]"
    TopDown::Parser::Token.new(:foo, %(puts "Hello\nWorld")).to_s.should eq %q([foo:puts \"Hello\nWorld\"])
    TopDown::Parser::Token.new(:":").to_s.should eq %q([:])
    TopDown::Parser::Token.new(:":", ":").to_s.should eq %q([:::])
    TopDown::Parser::Token.new(TopDown::Spec::CustomTokenType::PLUS).to_s.should eq "[PLUS]"
  end

  it "parses next token" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=3*7"
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:name, "hey")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:"=")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:int, "3")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:"*")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:int, "7")
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "parses next token with skip" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey =3   \t\n* 7"
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:name, "hey")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:"=")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:int, "3")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:"*")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:int, "7")
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "parses next token with eof" do
    parser = TopDown::Spec.token_parser_with_eof
    parser.source = "hey=3*7"
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:name, "hey")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:"=")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:int, "3")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:"*")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:int, "7")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:EOF)
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:EOF)
  end

  it "parses next token (custom tokens)" do
    parser = TopDown::Spec.custom_token_parser
    parser.source = "  hey =3   \t\n* 7"
    parser.spec_next_token.should eq TopDown::Spec::CustomToken.new(:NAME, "hey")
    parser.spec_next_token.should eq TopDown::Spec::CustomToken.new(:EQ)
    parser.spec_next_token.should eq TopDown::Spec::CustomToken.new(:INT, 3)
    parser.spec_next_token.should eq TopDown::Spec::CustomToken.new(:STAR)
    parser.spec_next_token.should eq TopDown::Spec::CustomToken.new(:INT, 7)
    parser.spec_next_token.should be_nil
    parser.spec_next_token.should be_nil
  end

  it "raises on bad token" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=§"
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:name, "hey")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:"=")
    e = expect_raises(TopDown::Parser::SyntaxError, "Unexpected character '§'") do
      parser.spec_next_token
    end
    e.location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4)
    e.end_location.should eq TopDown::Location.new(4, line_number: 0, line_pos: 4)
  end

  it "raises on bad token with skip" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey\t\n=\n   § "
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:name, "hey")
    parser.spec_next_token.should eq TopDown::Parser::Token.new(:"=")
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
      TopDown::Parser::Token.new(:name, "hey"),
      TopDown::Parser::Token.new(:"="),
      TopDown::Parser::Token.new(:int, "3"),
      TopDown::Parser::Token.new(:"*"),
      TopDown::Parser::Token.new(:int, "7"),
    ]

    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "  hey =3   \t\n* 7"
    parser.tokens.should eq [
      TopDown::Parser::Token.new(:name, "hey"),
      TopDown::Parser::Token.new(:"="),
      TopDown::Parser::Token.new(:int, "3"),
      TopDown::Parser::Token.new(:"*"),
      TopDown::Parser::Token.new(:int, "7"),
    ]
  end

  it "parses tokens" do
    parser = TopDown::Spec.token_parser
    parser.source = "hey=3*7"
    parser.spec_parse_name.should eq "hey"
    parser.spec_parse_eq.should eq ""
    parser.spec_parse_int.should eq "3"
    parser.spec_parse_star.should eq ""
    parser.spec_parse_int.should eq "7"
  end

  it "fails on unexpected token" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "hey=  oups"
    parser.spec_parse_name.should eq "hey"
    parser.spec_parse_eq.should eq ""
    parser.spec_parse_int.should be_a TopDown::Parser::Fail
  end

  it "raises on unexpected token" do
    parser = TopDown::Spec.token_parser_with_skip
    parser.source = "hey=  oups"
    parser.spec_parse_name_with_error!.should eq "hey"
    parser.spec_parse_eq_with_error!.should eq ""
    e = expect_raises(TopDown::Parser::SyntaxError, "Custom Error: got:name, expected:int") do
      parser.spec_parse_int_with_error!
    end
    e.location.should eq TopDown::Location.new(6, line_number: 0, line_pos: 6)
    e.end_location.should eq TopDown::Location.new(10, line_number: 0, line_pos: 10)
  end

  it "parses not token" do
    parser = TopDown::Spec.token_parser
    parser.source = "1+x"
    parser.spec_parse_not_name.should eq "1"
    parser.spec_parse_not_name.should eq ""
    parser.spec_parse_not_name.should be_a TopDown::Parser::Fail

    parser.source = "1+x"
    parser.spec_parse_any.should eq "1"
    parser.spec_parse_any.should eq ""
    parser.spec_parse_any.should eq "x"
    parser.spec_parse_any.should be_a TopDown::Parser::Fail
  end
end
