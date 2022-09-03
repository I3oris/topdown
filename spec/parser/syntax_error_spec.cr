require "./syntax_error_spec_helper"

describe TopDown::Parser do
  it "raises syntax error" do
    parser = TopDown::Spec.syntax_error_parser
    parser.source = source = " a  aa"
    parser.parse_a

    TopDown::Spec.expect_raises("Syntax Error", source, TopDown::Location.new(2, line_number: 0, line_pos: 2)) do
      parser.raise_syntax_error("Syntax Error")
    end
    parser.parse_a

    location = TopDown::Location.new(1, line_number: 0, line_pos: 1)
    TopDown::Spec.expect_raises("Syntax Error", source, location) do
      parser.raise_syntax_error("Syntax Error", at: location)
    end

    TopDown::Spec.expect_raises("Syntax Error", source, location, end_location: TopDown::Location.new(5, line_number: 0, line_pos: 5)) do
      parser.raise_syntax_error("Syntax Error", at: location..)
    end

    location2 = TopDown::Location.new(3, line_number: 0, line_pos: 3)
    TopDown::Spec.expect_raises("Syntax Error", source, location, end_location: location2) do
      parser.raise_syntax_error("Syntax Error", at: location..location2)
    end
  end
end
