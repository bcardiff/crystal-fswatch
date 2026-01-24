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

## Contributing

1. Fork it (<https://github.com/bcardiff/crystal-fswatch/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Development

For docker there are a couple of images to test things in alpine and ubuntu with crystal and libfswatch installed.

```
% docker build -t cfsw-ubuntu -f docker/Dockerfile.ubuntu .
% docker run --rm -it -v $(pwd):/src -w /src cfsw-ubuntu /bin/sh
root@5be1b17d7eba:/src# crystal run playground/01_monitor_curdir.cr
root@5be1b17d7eba:/src# crystal spec
```

To build other platforms use `--platform linux/amd64`

```
% docker build -t cfsw-ubuntu -f docker/Dockerfile.ubuntu --platform linux/amd64 .
```

## Contributors

- [Brian J. Cardiff](https://github.com/bcardiff) - creator and maintainer
