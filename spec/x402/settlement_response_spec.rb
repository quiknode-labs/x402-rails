# frozen_string_literal: true

RSpec.describe X402::SettlementResponse do
  let(:attributes) do
    { "success" => true, "transaction" => "0xtx", "network" => "base-sepolia", "payer" => "0xpayer" }
  end

  describe "#success?" do
    it "is true only when success is exactly true" do
      expect(described_class.new(attributes).success?).to be(true)
      expect(described_class.new("success" => "yes").success?).to be(false)
      expect(described_class.new({}).success?).to be(false)
    end
  end

  describe "#to_h" do
    it "serializes with a camelCase errorReason key" do
      response = described_class.new("success" => false, "errorReason" => "insufficient_funds")

      expect(response.to_h).to eq(
        success: false,
        transaction: nil,
        network: nil,
        payer: nil,
        errorReason: "insufficient_funds"
      )
    end
  end

  describe "#to_base64" do
    it "round-trips through Base64-encoded JSON" do
      decoded = JSON.parse(Base64.strict_decode64(described_class.new(attributes).to_base64))

      expect(decoded).to eq(
        "success" => true,
        "transaction" => "0xtx",
        "network" => "base-sepolia",
        "payer" => "0xpayer",
        "errorReason" => nil
      )
    end
  end
end
