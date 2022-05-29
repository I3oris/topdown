require "spec"
require "../src/topdown"

module TopDown::Spec
  extend self

  def char_reader
    CharReader.new("")
  end

  def char_reader_skip_whitespace
    CharReaderSkipWhitespace.new("")
  end

  class CharReaderSkipWhitespace < CharReader
    def hook_skip_char?(char : Char)
      char.in?(' ', '\n', '\t')
    end
  end
end
