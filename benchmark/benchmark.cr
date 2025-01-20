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

# v0.1.0 (07/08/2023):
# === Small JSON ===
#            Crystal JSON 326.02k (  3.07µs) (± 4.53%)  2.76kB/op        fastest
#            TopDown JSON 171.82k (  5.82µs) (± 0.44%)  5.88kB/op   1.90× slower
# TopDown JSON with token  95.97k ( 10.42µs) (± 0.36%)  9.75kB/op   3.40× slower
# === Big JSON ===
#            Crystal JSON   1.38k (722.38µs) (± 0.32%)   228kB/op        fastest
#            TopDown JSON 770.75  (  1.30ms) (± 0.45%)  0.97MB/op   1.80× slower
# TopDown JSON with token 530.49  (  1.89ms) (± 0.51%)  1.53MB/op   2.61× slower

# v0.1.0 (13/08/2022):
# === Small JSON ===
#            Crystal JSON 147.76k (  6.77µs) (±17.12%)  2.77kB/op        fastest
#            TopDown JSON  48.91k ( 20.45µs) (± 5.74%)  5.84kB/op   3.02× slower
# TopDown JSON with token  28.58k ( 34.98µs) (± 5.65%)  7.96kB/op   5.17× slower
# === Big JSON ===
#            Crystal JSON 877.55  (  1.14ms) (±15.84%)   228kB/op        fastest
#            TopDown JSON 281.64  (  3.55ms) (± 8.67%)  0.97MB/op   3.12× slower
# TopDown JSON with token 255.37  (  3.92ms) (±26.02%)  1.14MB/op   3.44× slower

# v0.2.0 (20/01/2025):
# === Small JSON ===
#            Crystal JSON 359.30k (  2.78µs) (± 5.96%)  2.75kB/op        fastest
#            TopDown JSON 147.49k (  6.78µs) (± 5.49%)  7.84kB/op   2.44× slower
# TopDown JSON with token 118.59k (  8.43µs) (± 3.64%)  12.6kB/op   3.03× slower
# === Big JSON ===
#            Crystal JSON   1.35k (741.43µs) (±12.96%)   228kB/op        fastest
#            TopDown JSON 797.39  (  1.25ms) (± 8.35%)  0.95MB/op   1.69× slower
# TopDown JSON with token 661.97  (  1.51ms) (± 6.70%)  1.87MB/op   2.04× slower
