require "spec_helper"

RSpec.describe Rack::Tracer do
  it "has a version number" do
    expect(Rack::Tracer::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
