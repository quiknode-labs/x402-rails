# frozen_string_literal: true

RSpec.describe X402::Versions::Base do
  subject(:strategy) { described_class.new }

  %i[version_number payment_header_name response_header_name requirement_header_name].each do |method|
    it "requires subclasses to implement ##{method}" do
      expect { strategy.public_send(method) }.to raise_error(NotImplementedError)
    end
  end

  it "requires subclasses to implement #format_network" do
    expect { strategy.format_network("base-sepolia") }.to raise_error(NotImplementedError)
  end

  it "requires subclasses to implement #parse_network" do
    expect { strategy.parse_network("eip155:84532") }.to raise_error(NotImplementedError)
  end

  it "requires subclasses to implement #format_requirement" do
    expect { strategy.format_requirement({}) }.to raise_error(NotImplementedError)
  end

  it "requires subclasses to implement #format_requirement_response" do
    expect { strategy.format_requirement_response(accepts: [], resource: {}, error: nil) }
      .to raise_error(NotImplementedError)
  end
end
