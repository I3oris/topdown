# TopDown

TopDown is a [crystal](https://crystal-lang.org) shard for writing a simple or evolved parser.

TopDown is at an early development stage.

It aims to keep itself simple and efficient thanks to [Top down operator precedence and Pratt Parsing](https://en.wikipedia.org/wiki/Operator-precedence_parser) in which it's inspired.

TopDown supports both token and tokenless parsing, each having their pros and cons, but each can fit better whether the use case.

Operator precedence can be handled rather naturally and doesn't involve complex machinery under the hood, simply recursive descent under top down parsing theory.

<!-- This lead TopDown to be very fast. (benchmark are not yet ready) -->

TopDown is designed to be extensible. Writing parsing rules is made in code directly, allowing to insert custom behaviour in each step of parsing, storing state for a state-based parser, or make more complex parsing operation.

Finally, TopDown is lightweight and doesn't require any dependencies.

## Overview

Write a simple parser:
```crystal
require "topdown"

class MyParser < TopDown::Parser
  root :expression

  syntax :expression do
    parse!(/\d+/).to_i
  end
end

source = "1"
puts MyParser.new(source).parse # => 1
```

Add basic operators with precedence:
```crystal
class MyParser < TopDown::Parser
  ...

  syntax :expression do
    union do
      parse(/\d+/).to_i
      infix(30, :pow)
      infix(20, :mul)
      infix(20, :div)
      infix(10, :add)
      infix(10, :sub)
    end
  end

  syntax :pow, "**" { left() ** parse!(:expression) }
  syntax :mul, '*' { left() * parse!(:expression) }
  syntax :div, '/' { left() / parse!(:expression) }
  syntax :add, '+' { left() + parse!(:expression) }
  syntax :sub, '-' { left() - parse!(:expression) }
end

source = "3*6+6*4"
puts MyParser.new(source).parse # => 42
```

Skip whitespaces and comments:
```crystal
class MyParser < TopDown::Parser
  ...

  skip do
    parse(' ' | '\n' | '\t')
    parse("//") { repeat { parse(not('\n')) } }
    parse("/*") do
      repeat { parse(not("*/")) }
      parse!("*/")
    end
  end
end

source = "3*6  + /* comment */ 6*4 // comment"
puts MyParser.new(source).parse # => 42
```

Add more prefix syntax:
```crystal
class MyParser < TopDown::Parser
  ...

  syntax :expression do
    union do
      parse(:parenthesis)
      parse(:positif, with_precedence: 40)
      parse(:negatif, with_precedence: 40)
      parse(/\d+/).to_i
      infix(30, :pow)
      infix(20, :mul)
      infix(20, :div)
      infix(10, :add)
      infix(10, :sub)
    end
  end

  syntax :parenthesis, '(' do
    exp = parse!(:expression)
    parse!(')', error: "Parenthesis '(' is not closed", at: begin_location())
    exp
  end

  syntax :positif, '+' { +parse!(:expression) }
  syntax :negatif, '-' { -parse!(:expression) }
end

source = "(-9 - 42 / (2*+5)**2) / -3"
puts MyParser.new(source).parse # => 3.14
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     topdown:
       github: I3oris/topdown
   ```

2. Run `shards install`

## Documentation

Read the [API documentation](https://i3oris.github.io/topdown/).

## Benchmark

```
# === Small JSON ===
#            Crystal JSON 147.76k (  6.77µs) (±17.12%)  2.77kB/op        fastest
#            TopDown JSON  48.91k ( 20.45µs) (± 5.74%)  5.84kB/op   3.02× slower
# TopDown JSON with token  28.58k ( 34.98µs) (± 5.65%)  7.96kB/op   5.17× slower
# === Big JSON ===
#            Crystal JSON 877.55  (  1.14ms) (±15.84%)   228kB/op        fastest
#            TopDown JSON 281.64  (  3.55ms) (± 8.67%)  0.97MB/op   3.12× slower
# TopDown JSON with token 255.37  (  3.92ms) (±26.02%)  1.14MB/op   3.44× slower
```

> See the [benchmark code](./benchmark/benchmark.cr).

## Roadmap

- [ ] Write docs (in progress)
- [ ] Write spec (in progress)
- [x] Write readme
- [ ] Write examples (in progress)
- [x] Write benchmarks
- [ ] Improve error handling
- [ ] Improve tokens
- [x] Improve characters parsing
- [ ] Improve unions

## Contributing

1. Fork it (<https://github.com/your-github-user/topdown/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [I3oris](https://github.com/your-github-user) - creator and maintainer
