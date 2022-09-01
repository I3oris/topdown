require "spec"
require "../src/topdown"

module TopDown::Spec
  extend self
end

class IO::FileDescriptor
  property? quiet = true

  def write(slice : Bytes) : Nil
    super unless quiet?
  end
end
