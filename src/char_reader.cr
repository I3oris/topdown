# TODO: docs
record Let::Location,
  pos : Int32,
  line_number : Int32,
  line_pos : Int32 do
  include Comparable(Location)

  # TODO: docs
  def show_in_source(io : IO, source : String, radius : Int32 = 2, end_location : Location = self)
    diff_location = end_location - self

    cursor_size = diff_location.pos
    cursor_n = 0
    each_lines_in_radius(source, radius) do |line, i|
      io << line_prelude(i) << line << '\n'

      if @line_number <= i <= end_location.line_number
        offset = (i == @line_number) ? @line_pos : 0

        (line_prelude(i).size + offset).times { io << ' ' }

        0.upto(line.size - 1 - offset) do
          io << cursor_char(cursor_n)
          cursor_n += 1
          break if cursor_n >= cursor_size
        end
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

# TODO: docs
class Let::CharReader
  @char_reader : Char::Reader
  @line_number = 0
  @line_pos = 0

  # TODO: docs
  def initialize(string : String)
    @char_reader = Char::Reader.new(string)
  end

  # TODO: docs
  def peek_char
    while hook_skip_char?(char = @char_reader.current_char)
      @char_reader.next_char unless char == '\0'
      increment_location(char)
    end
    char
  end

  # TODO: docs
  def next_char : Char
    char = @char_reader.current_char
    @char_reader.next_char unless char == '\0'

    increment_location(char)

    if hook_skip_char?(char)
      char = next_char
    end
    char
  end

  # TODO: docs
  def each_char(& : Char ->)
    until (ch = self.next_char) == '\0'
      yield ch
    end
  end

  # TODO: docs
  def string : String
    @char_reader.string
  end

  # TODO: docs
  def string=(string : String)
    @char_reader = Char::Reader.new(string)
    self.location = Location.new(0, 0, 0)
  end

  private def increment_location(char)
    if char == '\n'
      @line_number += 1
      @line_pos = 0
    else
      @line_pos += 1
    end
  end

  # TODO: docs
  def location : Location
    Location.new(@char_reader.pos, @line_number, @line_pos)
  end

  # TODO: docs
  def location=(location : Location)
    @char_reader.pos = location.pos
    @line_number = location.line_number
    @line_pos = location.line_pos
  end
end
