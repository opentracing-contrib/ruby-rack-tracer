# Rack::Tracer

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rack-tracer'
```

## Usage

```ruby
require 'opentracing'
OpenTracing.global_tracer = TracerImplementation.new

require 'rack/tracer'
use Rack::Tracer
```

You can access the created span using
```ruby
env['rack.span']
```

or you can use
```ruby
OpenTracing.active_span
```
See [opentracing-ruby](https://github.com/opentracing/opentracing-ruby) for more information how active_span works and what are its limitations.

You can also add start and finish span callbacks
```ruby
use Rack::Tracer,
    on_start_span: ->(span) { do_something(span) },
    on_finish_span: ->(_span) { do_something(span) }
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/opentracing-contrib/ruby-rack-tracer.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
