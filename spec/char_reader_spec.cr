require "./spec_helper"

char_reader = TopDown::CharReader.new("")

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
    char_reader.location.should eq TopDown::Location.new(0, 0, 0, 0)
  end

  it "get location" do
    char_reader.source = <<-SOURCE
      puts "Hello World"
      puts "Hello 💎"
      puts "Hello ♥"
      SOURCE

    char_reader.location.should eq TopDown::Location.new(0, 0, 0, 0)
    18.times { char_reader.next_char }
    char_reader.location.should eq TopDown::Location.new(18, line_number: 0, line_pos: 18, token_pos: 0)
    char_reader.next_char.should eq '\n'
    char_reader.location.should eq TopDown::Location.new(19, line_number: 1, line_pos: 0, token_pos: 0)

    12.times { char_reader.next_char }
    char_reader.location.should eq TopDown::Location.new(31, line_number: 1, line_pos: 12, token_pos: 0)
    char_reader.next_char.should eq '💎'
    char_reader.location.should eq TopDown::Location.new(35, line_number: 1, line_pos: 13, token_pos: 0)
  end

  it "set location" do
    char_reader.source = <<-SOURCE
      puts "Hello World"
      puts "Hello 💎"
      puts "Hello ♥"
      SOURCE

    char_reader.location.should eq TopDown::Location.new(0, 0, 0, 0)

    char_reader.location = TopDown::Location.new(49, line_number: 2, line_pos: 12, token_pos: 0)
    char_reader.location.should eq TopDown::Location.new(49, line_number: 2, line_pos: 12, token_pos: 0)
    char_reader.peek_char.should eq '♥'

    char_reader.location = TopDown::Location.new(31, line_number: 1, line_pos: 12, token_pos: 0)
    char_reader.location.should eq TopDown::Location.new(31, line_number: 1, line_pos: 12, token_pos: 0)
    char_reader.peek_char.should eq '💎'
  end
end
