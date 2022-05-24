record Let::Location,
  pos : Int32,
  line_number : Int32,
  line_pos : Int32

class Let::CharReader
  @char_reader : Char::Reader
  @line_number = 0
  @line_pos = 0

  def initialize(string : String)
    @char_reader = Char::Reader.new(string)
  end

  def skip_char?(char : Char)
    false
  end

  def peek_char
    while skip_char?(char = @char_reader.current_char)
      # next_char
      @char_reader.next_char unless char == '\0'
      increment_location(char)
    end
    char
  end

  # def peek_char : Char
  #   @char_reader.current_char
  # end

  def next_char : Char
    char = @char_reader.current_char
    @char_reader.next_char unless char == '\0'

    increment_location(char)

    if skip_char?(char)
      char = next_char
    end
    char
  end

  def each_char(& : Char ->)
    until (ch = self.next_char) == '\0'
      yield ch
    end
  end

  def string : String
    @char_reader.string
  end

  def string=(string : String)
    @char_reader = Char::Reader.new(string)
    self.location = Location.new(0, 0, 0)
  end

  @[Deprecated]
  def with_string(string : String) : self
    self.string = string
    self
  end

  private def increment_location(char)
    if char == '\n'
      @line_number += 1
      @line_pos = 0
    else
      @line_pos += 1
    end
  end

  def location : Location
    Location.new(@char_reader.pos, @line_number, @line_pos)
  end

  def location=(location : Location)
    @char_reader.pos = location.pos
    @line_number = location.line_number
    @line_pos = location.line_pos
  end
end
