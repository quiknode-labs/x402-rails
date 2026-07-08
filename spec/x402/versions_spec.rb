# frozen_string_literal: true

RSpec.describe X402::Versions do
  describe ".for" do
    it "returns the V1 strategy for version 1" do
      expect(described_class.for(1)).to be_a(X402::Versions::V1)
    end

    it "returns the V2 strategy for version 2" do
      expect(described_class.for(2)).to be_a(X402::Versions::V2)
    end

    it "raises ConfigurationError for unsupported versions" do
      expect { described_class.for(3) }
        .to raise_error(X402::ConfigurationError, "Unsupported x402 version: 3")
    end
  end
end
