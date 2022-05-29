require "./location"

# TODO: docs
class TopDown::CharReader
  @char_reader : Char::Reader
  @line_number = 0
  @line_pos = 0

  # TODO: docs
  def initialize(source : String)
    @char_reader = Char::Reader.new(source)
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
    char = peek_char
    @char_reader.next_char unless char == '\0'
    increment_location(char)
    char
  end

  # TODO: docs
  def each_char(& : Char ->)
    until (ch = self.next_char) == '\0'
      yield ch
    end
  end

  # TODO: docs
  def source : String
    @char_reader.string
  end

  # TODO: docs
  def source=(source : String)
    @char_reader = Char::Reader.new(source)
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
