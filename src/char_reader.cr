require "./location"

# Base class of a `Parser`.
#
# It composed from a `source` and can read or peek characters
# taking in account a complete `Location`
# on the source.
class TopDown::CharReader
  @char_reader : Char::Reader
  @line_number = 0
  @line_pos = 0

  # Creates a new `CharReader` (or `Parser`), initialized to read the *source*.
  def initialize(source : String)
    @char_reader = Char::Reader.new(source)
  end

  # Returns the next character to parse, without incrementing the cursor `location`.
  #
  # This method is currently the only way to look ahead during the parsing.
  # It allow for instance:
  # ```
  # parse("if") do
  #   break Fail.new if peek_char.alphanumeric?
  #   Token.new(:if)
  # end
  # # as an equivalent to:
  # parse(/if\b/) { Token.new(:if) }
  # ```
  def peek_char
    @char_reader.current_char
  end

  # Returns the next character to parse, and increments the cursor `location`.
  def next_char : Char
    char = peek_char
    @char_reader.next_char unless char == '\0'
    increment_location(char)
    char
  end

  # Iterates over each *source* character.
  #
  # `location` is incremented between each character.
  def each_char(& : Char ->)
    until (ch = self.next_char) == '\0'
      yield ch
    end
  end

  def source : String
    @char_reader.string
  end

  # Modifies the *source* and reset the cursor `location` to zero.
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

  # Returns the current cursor location.
  #
  # The location can be used later to raise an error at that point.
  # ```
  # loc = self.location
  # parse('(')
  # exp = parse!(:expression)
  # parse!(')', error: "Unterminated parenthesis expression", at: loc)
  # exp
  # ```
  def location : Location
    Location.new(@char_reader.pos, @line_number, @line_pos)
  end

  # Move the cursor to the new *location*.
  #
  # The *location* should be well formed, otherwise error display won't be right.
  # It is recommended to always use a location got by `self.location`.
  #
  # This methods is used backtrack the parser.
  # However, prefer using `Parser.union`, `Parser.maybe`, and `Parser.repeat` over manual backtracks.
  def location=(location : Location)
    @char_reader.pos = location.pos unless @char_reader.pos == location.pos
    @line_number = location.line_number
    @line_pos = location.line_pos
  end
end
