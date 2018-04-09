require 'spec_helper'
require 'timeout'

RSpec.describe Rack::Tracer do
  let(:logger) { ArrayLogger.new }
  let(:tracer) { Logasm::Tracer.new(logger) }
  let(:on_start_span) { spy }
  let(:on_finish_span) { spy }

  let(:ok_response) { [200, {'Content-Type' => 'application/json'}, ['{"ok": true}']] }

  let(:env) do
    Rack::MockRequest.env_for('/test/this/route', {
      method: method
    })
  end

  let(:method) { 'POST' }

  shared_examples 'calls on_start_span and on_finish_span callbacks' do
    it 'calls on_start_span callback' do
      respond_with { ok_response }
      expect(on_start_span).to have_received(:call).with(instance_of(Logasm::Tracer::Span))
    end

    it 'calls on_finish_span callback' do
      respond_with { ok_response }
      expect(on_finish_span).to have_received(:call).with(instance_of(Logasm::Tracer::Span))
    end
  end

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

    it_behaves_like 'calls on_start_span and on_finish_span callbacks'
  end

  context 'when already traced request' do
    let(:parent_span_name) { 'parent span' }
    let(:parent_span) { tracer.start_span(parent_span_name) }

    before { inject(parent_span.context, env) }

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

    it_behaves_like 'calls on_start_span and on_finish_span callbacks'
  end

  context 'when already traced but untrusted request' do
    it 'starts a new trace' do
      respond_with(trust_incoming_span: false) { ok_response }

      expect(logger.calls.map(&:first)).to eq([
        "Span [#{method}] started",
        "Span [#{method}] finished"
      ])
    end

    it 'does not pass incoming span to downstream' do
      respond_with(trust_incoming_span: false) do |env|
        expect(env['rack.span']).to be_a(Logasm::Tracer::Span)
        expect(env['rack.span'].context.parent_id).to be_nil
        ok_response
      end
    end

    it_behaves_like 'calls on_start_span and on_finish_span callbacks'
  end

  context 'when an exception bubbles-up through the middlewares' do
    it 'finishes the span' do
      expect { respond_with { |env| raise Timeout::Error } }.to raise_error { |_|
        msg, _ = logger.calls.last

        expect(msg).to eq("Span [#{method}] finished")
      }
    end

    it 'marks the span as failed' do
      expect { respond_with { |env| raise Timeout::Error } }.to raise_error { |_|
        _, trace_info = logger.calls.last

        expect(trace_info[:trace]['error']).to eq(true)
      }
    end

    it 'logs the error' do
      exception = Timeout::Error.new
      expect { respond_with { |env| raise exception } }.to raise_error { |thrown_exception|
        msg, trace_info = logger.calls.find { |d, _| d.include?("error") }

        expect(msg).to eq("Span [#{method}] error")
        expect(trace_info[:'error.object']).to eq(thrown_exception)
        expect(trace_info[:'error.object']).to eq(exception)
      }
    end

    it 're-raise original exception' do
      expect { respond_with { |env| raise Timeout::Error } }.to raise_error(Timeout::Error)
    end
  end

  def respond_with(trust_incoming_span: true, &app)
    middleware = described_class.new(
      app,
      tracer: tracer,
      on_start_span: on_start_span,
      on_finish_span: on_finish_span,
      trust_incoming_span: trust_incoming_span
    )
    middleware.call(env)
  end

  def inject(span_context, env)
    carrier = Hash.new
    tracer.inject(span_context, OpenTracing::FORMAT_RACK, carrier)
    carrier.each do |k, v|
      env['HTTP_' + k.upcase.gsub('-', '_')] = v
    end
  end
end
