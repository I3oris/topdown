module TopDown::Spec
  class SyntaxErrorParser < TopDown::Parser
    skip { parse(' ') }

    def parse_a
      handle_fail { parse("a") }
    end
  end

  def self.expect_raises(message, source, location, end_location = location, &)
    error = expect_raises(TopDown::Parser::SyntaxError, message) do
      yield
    end

    error.location.should eq location
    error.end_location.should eq end_location
    error.source.should eq source
  end

  class_getter syntax_error_parser = SyntaxErrorParser.new("")
end
