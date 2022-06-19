# Represents a location into a parser source.
#
# `pos` is the position on string (in number of bytes).
#
# `line_number` start by 0.
#
# `line_pos` is the position on line (in number of characters).
record TopDown::Location,
  pos : Int32,
  line_number : Int32,
  line_pos : Int32 do
  include Comparable(Location)

  # Displays this location in *source*.
  #
  # * *io* : the output io.
  # * *source* : the source string.
  # * *radius* : how many lines above and below to show.
  # * *begin_location* : if set other than `self`, the function show the range location between `self` and *begin_location*.
  #
  # ```
  # l1 = TopDown::Location.new(5, line_number: 0, line_pos: 5)
  # l2 = TopDown::Location.new(17, line_number: 0, line_pos: 17)
  # source = <<-SOURCE
  #   puts "Hello World"
  #   puts "Hello 💎"
  #   puts "Hello ♥"
  #   SOURCE
  #
  # l1.show_in_source(STDOUT, source)
  # #   0 | puts "Hello World"
  # #            ^
  # #   1 | puts "Hello 💎"
  # #   2 | puts "Hello ♥"\n
  #
  # l2.show_in_source(STDOUT, source, begin_location: l1)
  # #   0 | puts "Hello World"
  # #            ^~~~~~~~~~~~
  # #   1 | puts "Hello 💎"
  # #   2 | puts "Hello ♥"\n
  # ```
  def show_in_source(io : IO, source : String, radius : Int32 = 2, begin_location : Location = self)
    diff_location = self - begin_location

    cursor_size = diff_location.pos
    cursor_n = 0
    each_lines_in_radius(source, radius) do |line, i|
      io << line_prelude(i) << line << '\n'

      if begin_location.line_number <= i <= @line_number
        offset = (i == begin_location.line_number) ? begin_location.line_pos : 0

        (line_prelude(i).size + offset).times { io << ' ' }

        0.upto(line.size - 1 - offset) do
          io << cursor_char(cursor_n)
          cursor_n += 1
          break if cursor_n >= cursor_size
        end

        io << cursor_char(cursor_n) if offset == line.size
        cursor_n += 1

        io << '\n'
      end
    end
  end

  private def each_lines_in_radius(source : String, radius : Int32 = 2)
    start = {0, @line_number - radius}.max

    source.each_line.with_index.each do |line, i|
      yield line, i if i >= start
      break if i >= @line_number + radius
    end
  end

  private def cursor_char(n)
    n == 0 ? '^' : '~'
  end

  private def line_prelude(line_number)
    line_number.to_s.rjust(4) + " | "
  end

  # Gives the relative location between two others.
  #
  # NOTE: `line_pos` may be negative even `self` > `other`.
  #
  # ```
  # l1 = TopDown::Location.new(5, line_number: 0, line_pos: 5)
  # l2 = TopDown::Location.new(17, line_number: 0, line_pos: 17)
  # l3 = TopDown::Location.new(32, line_number: 1, line_pos: 13)
  #
  # l2 - l1 # => TopDown::Location(@pos=12, @line_number=0, @line_pos=12)
  # l3 - l2 # => TopDown::Location(@pos=15, @line_number=1, @line_pos=-4)
  # ```
  def -(other : Location)
    Location.new(@pos - other.pos, @line_number - other.line_number, @line_pos - other.line_pos)
  end

  # Compares two locations by their `pos` only.
  #
  # Returns `self.pos <=> other.pos`.
  def <=>(other : Location)
    @pos <=> other.pos
  end
end
