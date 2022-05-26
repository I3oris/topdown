abstract class Let::Parser < Let::CharReader
  class SyntaxError < Exception
    def initialize(@message : String, @location : Location, @string : String)
    end

    def show_location(io)
      line_number, line_pos = @location.line_number, @location.line_pos
      io << "at [#{line_number}:#{line_pos}]\n"

      lines = @string.split('\n')
      start = {0, line_number - 2}.max
      end_ = {line_number + 2, lines.size}.min
      return if start > end_

      lines[start..end_].each_with_index do |l, i|
        io << l << '\n'
        if start + i == line_number
          line_pos.times { io << ' ' }
          io << "^\n"
        end
      end
    end

    def inspect_with_backtrace(io)
      io << message << " (" << self.class << ")\n"

      show_location(io)

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

  def raise_syntax_error(message, location = self.location, string = self.string)
    raise SyntaxError.new message, location, string
  end
end
