require 'spec_helper'

RSpec.describe Rack::Tracer do
  let(:logger) { ArrayLogger.new }
  let(:tracer) { Logasm::Tracer.new(logger) }
  let(:middleware) { described_class.new(app, tracer) }

  let(:ok_response) { [200, {'Content-Type' => 'application/json'}, ['{"ok": true}']] }

  let(:env) do
    Rack::MockRequest.env_for('/test/this/route', {
      method: method
    })
  end

  let(:method) { 'POST' }

  context 'when a new request' do
    it 'starts a new trace' do
      respond_with { ok_response }

      expect(logger.calls.map(&:first)).to eq([
        "Span [#{method}] started",
        "Span [#{method}] finished"
      ])
    end

    it 'passes span to downstream' do
      respond_with do |env|
        expect(env['rack.span']).to be_a(Logasm::Tracer::Span)
        expect(env['rack.span'].context.parent_id).to be_nil
        ok_response
      end
    end
  end

  context 'when already traced request' do
    let(:parent_span_name) { 'parent span' }
    let(:parent_span) { tracer.start_span(parent_span_name) }

    before { tracer.inject(parent_span.context, OpenTracing::FORMAT_RACK, env) }

    it 'starts a child trace' do
      respond_with { ok_response }
      parent_span.finish

      expect(logger.calls.map(&:first)).to eq([
        "Span [#{parent_span_name}] started",
        "Span [#{method}] started",
        "Span [#{method}] finished",
        "Span [#{parent_span_name}] finished"
      ])
    end

    it 'passes span to downstream' do
      respond_with do |env|
        expect(env['rack.span']).to be_a(Logasm::Tracer::Span)
        expect(env['rack.span'].context.parent_id).to_not be_nil
        ok_response
      end
    end
  end

  def respond_with(&app)
    middleware = described_class.new(app, tracer)
    middleware.call(env)
  end
end
