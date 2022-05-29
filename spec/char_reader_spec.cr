require "./spec_helper"

char_reader = TopDown::Spec.char_reader

describe TopDown::CharReader do
  describe "peek_char & next_char" do
    it "for empty source" do
      char_reader.source = ""
      char_reader.peek_char.should eq '\0'
      char_reader.next_char.should eq '\0'
      char_reader.next_char.should eq '\0'
    end

    it "for small source" do
      char_reader.source = "1+2"
      char_reader.peek_char.should eq '1'
      char_reader.next_char.should eq '1'
      char_reader.next_char.should eq '+'
      char_reader.peek_char.should eq '2'
      char_reader.next_char.should eq '2'
      char_reader.next_char.should eq '\0'
    end

    it "for unicode source" do
      char_reader.source = "♥+💎"
      char_reader.peek_char.should eq '♥'
      char_reader.next_char.should eq '♥'
      char_reader.next_char.should eq '+'
      char_reader.peek_char.should eq '💎'
      char_reader.next_char.should eq '💎'
      char_reader.next_char.should eq '\0'
    end
  end

  describe "each_char" do
    it "on empty source" do
      chars = [] of Char
      char_reader.source = ""
      char_reader.each_char { |c| chars << c }
      chars.should be_empty
    end

    it "on small source" do
      chars = [] of Char
      char_reader.source = "1+2"
      char_reader.each_char { |c| chars << c }
      chars.should eq ['1', '+', '2']
    end

    it "on unicode source" do
      chars = [] of Char
      char_reader.source = "♥+💎"
      char_reader.each_char { |c| chars << c }
      chars.should eq ['♥', '+', '💎']
    end
  end

  it "get & set source" do
    char_reader.source = "Hello\nWorld\n"
    char_reader.source.should eq "Hello\nWorld\n"

    7.times { char_reader.next_char }
    char_reader.source.should eq "Hello\nWorld\n"

    char_reader.source = "Hey"
    char_reader.source.should eq "Hey"
    char_reader.location.should eq TopDown::Location.new(0, 0, 0)
  end

  it "get location" do
    char_reader.source = <<-SOURCE
      puts "Hello World"
      puts "Hello 💎"
      puts "Hello ♥"
      SOURCE

    char_reader.location.should eq TopDown::Location.new(0, 0, 0)
    18.times { char_reader.next_char }
    char_reader.location.should eq TopDown::Location.new(18, line_number: 0, line_pos: 18)
    char_reader.next_char.should eq '\n'
    char_reader.location.should eq TopDown::Location.new(19, line_number: 1, line_pos: 0)

    12.times { char_reader.next_char }
    char_reader.location.should eq TopDown::Location.new(31, line_number: 1, line_pos: 12)
    char_reader.next_char.should eq '💎'
    char_reader.location.should eq TopDown::Location.new(35, line_number: 1, line_pos: 13)
  end

  it "set location" do
    char_reader.source = <<-SOURCE
      puts "Hello World"
      puts "Hello 💎"
      puts "Hello ♥"
      SOURCE

    char_reader.location.should eq TopDown::Location.new(0, 0, 0)

    char_reader.location = TopDown::Location.new(49, line_number: 2, line_pos: 12)
    char_reader.location.should eq TopDown::Location.new(49, line_number: 2, line_pos: 12)
    char_reader.peek_char.should eq '♥'

    char_reader.location = TopDown::Location.new(31, line_number: 1, line_pos: 12)
    char_reader.location.should eq TopDown::Location.new(31, line_number: 1, line_pos: 12)
    char_reader.peek_char.should eq '💎'
  end
end

char_reader_skip = TopDown::Spec.char_reader_skip_whitespace

describe TopDown::Spec::CharReaderSkipWhitespace do
  it "peek_char & next_char" do
    char_reader_skip.source = <<-SOURCE
      puts "Hello 💎"
      \n\t  puts "Hello ♥"
      SOURCE

    3.times { char_reader_skip.next_char }
    char_reader_skip.peek_char.should eq 's'
    char_reader_skip.next_char.should eq 's'

    char_reader_skip.peek_char.should eq '"'
    char_reader_skip.next_char.should eq '"'

    5.times { char_reader_skip.next_char }
    char_reader_skip.peek_char.should eq '💎'
    char_reader_skip.next_char.should eq '💎'
    char_reader_skip.next_char.should eq '"'
    char_reader_skip.next_char.should eq 'p'
  end

  it "each_char" do
    char_reader_skip.source = "Hey  \n\t💎\n"
    chars = [] of Char
    char_reader_skip.each_char { |c| chars << c }
    chars.should eq ['H', 'e', 'y', '💎']
  end

  it "get location" do
    char_reader_skip.source = <<-SOURCE
      puts "Hello 💎"
      \n\t  puts "Hello ♥"
      SOURCE

    10.times { char_reader_skip.next_char }
    char_reader_skip.location.should eq TopDown::Location.new(11, line_number: 0, line_pos: 11)

    char_reader_skip.peek_char.should eq '💎'
    char_reader_skip.location.should eq TopDown::Location.new(12, line_number: 0, line_pos: 12)

    char_reader_skip.next_char.should eq '💎'
    char_reader_skip.location.should eq TopDown::Location.new(16, line_number: 0, line_pos: 13)
    char_reader_skip.next_char.should eq '"'
    char_reader_skip.location.should eq TopDown::Location.new(17, line_number: 0, line_pos: 11)

    char_reader_skip.peek_char.should eq 'p'
    char_reader_skip.location.should eq TopDown::Location.new(22, line_number: 2, line_pos: 3)
    char_reader_skip.next_char.should eq 'p'
    char_reader_skip.location.should eq TopDown::Location.new(23, line_number: 2, line_pos: 4)
  end
end
