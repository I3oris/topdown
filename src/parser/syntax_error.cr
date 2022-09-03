abstract class TopDown::Parser < TopDown::CharReader
  # Exception raised by the parser during `Parser#parse` and all instantiation of `Parser.parse!`.
  #
  # Contains `source` and `location` information, which are displayed when the error is dump.
  #
  # Use `Parser#raise_syntax_error` to raise a `SyntaxError` directly at parser location.
  class SyntaxError < Exception
    property message, source, location, end_location

    def initialize(@message : String, @source : String, @location : Location, @end_location : Location = location)
    end

    # Displays `message` and shows in `source` the range `location`:`end_location`.
    def to_s(io)
      io << message << "\n"

      io << "At [#{@location.line_number}:#{@location.line_pos}]:\n"
      @location.show_in_source(io, @source, end_location: @end_location)
    end

    # Displays `message` with backtrace and shows in `source` the range `begin_location`:`location`.
    def inspect_with_backtrace(io)
      io << message << " (" << self.class << ")\n"

      io << "At [#{@location.line_number}:#{@location.line_pos}]\n"
      @location.show_in_source(io, @source, end_location: @end_location)

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

  # Raises a `SyntaxError` at current `location` and current `source`.
  #
  # *location* could be a range between two `Location`. A endless range mean a location up to `self.location`.
  def raise_syntax_error(message : String, at location : Location = self.location, source : String = self.source)
    raise SyntaxError.new message, source, location, location
  end

  # :ditto:
  def raise_syntax_error(message : String, at location : Range(Location, Location), source : String = self.source)
    raise SyntaxError.new message, source, location.begin, location.end
  end

  # :ditto:
  def raise_syntax_error(message : String, at location : Range(Location, Nil), source : String = self.source)
    raise SyntaxError.new message, source, location.begin, self.location
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
      obj.inspect
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
