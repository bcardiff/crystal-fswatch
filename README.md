# crystal-fswatch

[fswatch](https://emcrisostomo.github.io/fswatch/) bindings for [Crystal](https://crystal-lang.org/)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     fswatch:
       github: bcardiff/crystal-fswatch
   ```

2. Run `shards install`

## Usage

```crystal
require "fswatch"

FSWatch.watch "." do |event|
  pp! event
end

sleep 10 # keep main fiber busy to prevent exiting
```

If libfswatch is not found you can try using the provided `libfswatch.pc` file:

```
# Homebrew
$ export PKG_CONFIG_PATH="./pkg_config/brew:$PKG_CONFIG_PATH"
```

## Contributing

1. Fork it (<https://github.com/bcardiff/crystal-fswatch/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Brian J. Cardiff](https://github.com/bcardiff) - creator and maintainer
