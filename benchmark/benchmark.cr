require "json"
require "benchmark"
require "../examples/json"
require "../examples/json_with_token"

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

puts "=== Small JSON ==="
Benchmark.ips do |x|
  x.report("Crystal JSON") { JSON.parse(json) }
  x.report("TopDown JSON") { JSONParser.new(json).parse }
  x.report("TopDown JSON with token") { JSONParserWithToken.new(json).parse }
end

json = File.read("index.json")

puts "=== Big JSON ==="
Benchmark.ips do |x|
  x.report("Crystal JSON") { JSON.parse(json) }
  x.report("TopDown JSON") { JSONParser.new(json).parse }
  x.report("TopDown JSON with token") { JSONParserWithToken.new(json).parse }
end

# v0.1.0 (13/08/2022):
# === Small JSON ===
#            Crystal JSON 147.76k (  6.77µs) (±17.12%)  2.77kB/op        fastest
#            TopDown JSON  48.91k ( 20.45µs) (± 5.74%)  5.84kB/op   3.02× slower
# TopDown JSON with token  28.58k ( 34.98µs) (± 5.65%)  7.96kB/op   5.17× slower
# === Big JSON ===
#            Crystal JSON 877.55  (  1.14ms) (±15.84%)   228kB/op        fastest
#            TopDown JSON 281.64  (  3.55ms) (± 8.67%)  0.97MB/op   3.12× slower
# TopDown JSON with token 255.37  (  3.92ms) (±26.02%)  1.14MB/op   3.44× slower
