abstract class TopDown::Parser < TopDown::CharReader
  # TODO: docs
  class SyntaxError < Exception
    # TODO: docs
    property source, location, begin_location

    # TODO: docs
    def initialize(@message : String, @source : String, @location : Location, @begin_location : Location = location)
    end

    # TODO: docs
    def to_s(io)
      io << message << "\n"

      io << "At [#{@begin_location.line_number}:#{@begin_location.line_pos}]:\n"
      @location.show_in_source(io, @source, begin_location: @begin_location)
    end

    # TODO: docs
    def inspect_with_backtrace(io)
      io << message << " (" << self.class << ")\n"

      io << "At [#{@begin_location.line_number}:#{@begin_location.line_pos}]\n"
      @location.show_in_source(io, @source, begin_location: @begin_location)

      backtrace?.try &.each do |frame|
        io.print "  from "
        io.puts frame
      end

      if cause = @cause
        io << "Caused by: "
        cause.inspect_with_backtrace(io)
      end

      io.flush
    end
  end

  # TODO: docs
  def raise_syntax_error(message : String, location : Location = self.location, begin_location : Location = location, source : String = self.source)
    raise SyntaxError.new message, source, location, begin_location
  end

  private def error_message(error, got, expected)
    case error
    when Proc
      error.call(got, expected)
    else
      error % {got: dump_in_error(got), expected: dump_in_error(expected)}
    end
  end

  private def dump_in_error(obj)
    case obj
    when '\0', Nil
      "EOF"
    when Char
      obj.to_s
    when String
      obj
    when Regex
      obj.source
    when .responds_to?(:type)
      obj.type.to_s
    else
      obj.to_s
    end
      .chars.join do |c|
        c.printable? ? c : c.to_s.dump_unquoted
      end
  end
end
