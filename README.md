# TopDown

TopDown is a [crystal](https://crystal-lang.org) shard for writing a simple or evolved parser.

TopDown is at an early development stage.

It aims to keep itself simple and efficient thanks to [Top down operator precedence and Pratt Parsing](https://en.wikipedia.org/wiki/Operator-precedence_parser) in which it's inspired.

TopDown supports both token and tokenless parsing, each having their pros and cons, but each can fit better whether the use case.

Operator precedence can be handled rather naturally and doesn't involve complex machinery under the hood, simply recursive descent under top down parsing theory.

<!-- This lead TopDown to be very fast. (benchmark are not yet ready) -->

TopDown is designed to be extensible. Writing parsing rules is made in code directly, allowing to insert custom behaviour in each step of parsing, storing state for a state-based parser, or make more complex parsing operation.

Finally, TopDown is lightweight and doesn't require any dependencies.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     topdown:
       github: I3oris/topdown
   ```

2. Run `shards install`

## Usage

```crystal
require "topdown"
```

TODO: Write usage instructions here

## Roadmap

- [ ] Write docs (in progress)
- [ ] Write spec (in progress)
- [ ] Write readme (in progress)
- [ ] Write examples (in progress)
- [x] Write benchmarks
- [ ] Improve error handling
- [ ] Improve tokens
- [x] Improve characters parsing
- [ ] Improve unions

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/topdown/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [I3oris](https://github.com/your-github-user) - creator and maintainer
