# frozen_string_literal: true

require 'opentracing'

module Rack
  class Tracer
    REQUEST_URI = 'REQUEST_URI'.freeze
    REQUEST_METHOD = 'REQUEST_METHOD'.freeze

    # Create a new Rack Tracer middleware.
    #
    # @param app The Rack application/middlewares stack.
    # @param tracer [OpenTracing::Tracer] A tracer to be used when start_span, and extract
    #        is called.
    # @param on_start_span [Proc, nil] A callback evaluated after a new span is created.
    # @param on_finish_span [Proc, nil] A callback evaluated after a span is finished.
    # @param errors [Array<Class>] An array of error classes to be captured by the tracer
    #        as errors. Errors are **not** muted by the middleware, they're re-raised afterwards.
    def initialize(app, # rubocop:disable Metrics/ParameterLists
                   tracer: OpenTracing.global_tracer,
                   on_start_span: nil,
                   on_finish_span: nil,
                   trust_incoming_span: true,
                   errors: [StandardError])
      @app = app
      @tracer = tracer
      @on_start_span = on_start_span
      @on_finish_span = on_finish_span
      @trust_incoming_span = trust_incoming_span
      @errors = errors
    end

    def call(env)
      method = env[REQUEST_METHOD]

      context = @tracer.extract(OpenTracing::FORMAT_RACK, env) if @trust_incoming_span
      scope = @tracer.start_active_span(
        method,
        child_of: context,
        tags: {
          'component' => 'rack',
          'span.kind' => 'server',
          'http.method' => method,
          'http.url' => env[REQUEST_URI]
        }
      )
      span = scope.span

      @on_start_span.call(span) if @on_start_span

      env['rack.span'] = span

      @app.call(env).tap do |status_code, _headers, _body|
        span.set_tag('http.status_code', status_code)
        if status_code >= 400
          span.set_tag('error', true)
        end

        route = route_from_env(env)
        span.operation_name = route if route
      end
    rescue *@errors => e
      span.set_tag('error', true)
      span.log_kv(
        event: 'error',
        :'error.kind' => e.class.to_s,
        :'error.object' => e,
        message: e.message,
        stack: e.backtrace.join("\n")
      )
      raise
    ensure
      begin
        scope.close
      ensure
        @on_finish_span.call(span) if @on_finish_span
      end
    end

    private

    def route_from_env(env)
      if (sinatra_route = env['sinatra.route'])
        sinatra_route
      elsif (rails_controller = env['action_controller.instance'])
        "#{env[REQUEST_METHOD]} #{rails_controller.controller_name}/#{rails_controller.action_name}"
      elsif (grape_route_args = env['grape.routing_args'] || env['rack.routing_args'])
        grape_route_from_args(grape_route_args)
      end
    end

    def grape_route_from_args(route_args)
      route_info = route_args[:route_info]
      if route_info.respond_to?(:path)
        route_info.path
      elsif (rack_route_options = route_info.instance_variable_get(:@options))
        rack_route_options[:path]
      end
    end
  end
end
