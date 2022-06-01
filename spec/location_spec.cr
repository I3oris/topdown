require "./spec_helper"

zero = TopDown::Location.new(0, 0, 0)
l1 = TopDown::Location.new(5, line_number: 0, line_pos: 5)
l2 = TopDown::Location.new(17, line_number: 0, line_pos: 17)
l3 = TopDown::Location.new(32, line_number: 1, line_pos: 13)
l_end_line = TopDown::Location.new(18, line_number: 0, line_pos: 18)

source = <<-SOURCE
  puts "Hello World"
  puts "Hello 💎"
  puts "Hello ♥"
  SOURCE

describe TopDown::Location do
  it "show in source l1" do
    output = String.build do |io|
      l1.show_in_source(io, source)
    end

    output.should eq <<-OUTPUT
         0 | puts "Hello World"
                  ^
         1 | puts "Hello 💎"
         2 | puts "Hello ♥"\n
      OUTPUT
  end

  it "show in source l1-l2" do
    output = String.build do |io|
      l2.show_in_source(io, source, begin_location: l1)
    end

    output.should eq <<-OUTPUT
         0 | puts "Hello World"
                  ^~~~~~~~~~~~
         1 | puts "Hello 💎"
         2 | puts "Hello ♥"\n
      OUTPUT
  end

  it "show in source l1-l3" do
    output = String.build do |io|
      l3.show_in_source(io, source, begin_location: l1)
    end

    output.should eq <<-OUTPUT
         0 | puts "Hello World"
                  ^~~~~~~~~~~~~
         1 | puts "Hello 💎"
             ~~~~~~~~~~~~~
         2 | puts "Hello ♥"\n
      OUTPUT
  end

  it "show in source zero-l1" do
    output = String.build do |io|
      l1.show_in_source(io, source, begin_location: zero)
    end

    output.should eq <<-OUTPUT
         0 | puts "Hello World"
             ^~~~~
         1 | puts "Hello 💎"
         2 | puts "Hello ♥"\n
      OUTPUT
  end

  it "show in source on '\\n'" do
    output = String.build do |io|
      l_end_line.show_in_source(io, source)
    end

    output.should eq <<-OUTPUT
         0 | puts "Hello World"
                               ^
         1 | puts "Hello 💎"
         2 | puts "Hello ♥"\n
      OUTPUT
  end

  it "substract" do
    (l1 - zero).should eq l1
    (l2 - l1).should eq TopDown::Location.new(12, line_number: 0, line_pos: 12)
    (l3 - l2).should eq TopDown::Location.new(15, line_number: 1, line_pos: -4)
  end

  it "compare" do
    (l1 <=> l2).should eq -1
    (zero < l1 < l2 < l3).should be_true
    (l1 > l3).should be_false

    l2.in?(l1..l3).should be_true
    l1.in?(l2..l3).should be_false

    l3.in?(l1..l3).should be_true
    l3.in?(l1...l3).should be_false
  end
end
