abstract class Let::Parser < Let::CharReader
  # TODO: docs
  class SyntaxError < Exception
    def initialize(@message : String, @source : String, @begin_location : Location, @end_location : Location = begin_location)
    end

    def to_s(io)
      io << message << "\n"

      io << "At [#{@begin_location.line_number}:#{@begin_location.line_pos}]:\n"
      @begin_location.show_in_source(io, @source, end_location: @end_location)
    end

    def inspect_with_backtrace(io)
      io << message << " (" << self.class << ")\n"

      io << "At [#{@begin_location.line_number}:#{@begin_location.line_pos}]\n"
      @begin_location.show_in_source(io, @source, end_location: @end_location)

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
  def raise_syntax_error(message : String, begin_location : Location = self.location, end_location : Location = begin_location, source : String = self.source)
    raise SyntaxError.new message, source, begin_location, end_location
  end
end
