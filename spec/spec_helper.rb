require 'bundler/setup'
require 'rack/tracer'
require 'rack/mock'
require 'test/tracer'
require 'tracing/matchers'
require 'support/test_tracer_ext'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

class ArrayLogger
  attr_accessor :calls

  def initialize
    @calls = []
  end

  def info(*args)
    @calls << args
  end
end
