require "./spec_helper"

STDOUT.quiet = true
require "../examples/**"
STDOUT.quiet = false

describe TopDown do
  it "runs json example" do
    json = %q(
      {
        "string": "Hello World",
        "int": -42,
        "float": 3.14,
        "bool": true,
        "null": null,
        "exponent": 2.99792458e+8,
        "object": {"a": 1, "b": 2, "c": []},
        "array": [1, "2", false],
        "escapes": "\b\t \" \u2665"
      }
    )

    json_object = {
      "string"   => "Hello World",
      "int"      => -42,
      "float"    => 3.14,
      "bool"     => true,
      "null"     => nil,
      "exponent" => 299792458.0,
      "object"   => {"a" => 1, "b" => 2, "c" => [] of JSONParser::Value},
      "array"    => [1, "2", false],
      "escapes"  => "\b\t \" ♥",
    }

    JSONParser.new(json).parse.should eq json_object
    JSONParserWithToken.new(json).parse.should eq json_object
  end
end
