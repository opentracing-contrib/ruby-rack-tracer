require 'opentracing'

module Rack
  class Tracer
    REQUEST_URI = 'REQUEST_URI'.freeze
    REQUEST_METHOD = 'REQUEST_METHOD'.freeze

    def initialize(app, tracer = OpenTracing.global_tracer)
      @app = app
      @tracer = tracer
    end

    def call(env)
      method = env[REQUEST_METHOD]

      context = @tracer.extract(OpenTracing::FORMAT_RACK, env)
      span = @tracer.start_span(method,
        child_of: context,
        tags: {
          'component' => 'rack',
          'span.kind' => 'server',
          'http.method' => method,
          'http.url' => env[REQUEST_URI],
          'http.uri' => env[REQUEST_URI] # For zipkin, not OT convention
        }
      )

      env['rack.span'] = span

      @app.call(env).tap do |status_code, _headers, _body|
        span.set_tag('http.status_code', status_code)

        if route = route_from_env(env)
          span.set_tag('route', route)
        end
      end
    ensure
      span.finish
    end

    private

    def route_from_env(env)
      if route = env['sinatra.route']
        route.split(' ').last
      end
    end
  end
end
