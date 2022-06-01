# TODO: docs
record TopDown::Location,
  pos : Int32,
  line_number : Int32,
  line_pos : Int32 do
  include Comparable(Location)

  # TODO: docs
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

  # TODO: docs
  def cursor_char(n)
    n == 0 ? '^' : '~'
  end

  # TODO: docs
  def line_prelude(line_number)
    line_number.to_s.rjust(4) + " | "
  end

  # TODO: docs
  def -(other : Location)
    Location.new(@pos - other.pos, @line_number - other.line_number, @line_pos - other.line_pos)
  end

  # TODO: docs
  def <=>(other : Location)
    @pos <=> other.pos
  end
end
