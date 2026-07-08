# frozen_string_literal: true

RSpec.describe X402::PaymentRequirement do
  describe "network normalization" do
    it "converts CAIP-2 network identifiers to internal chain names" do
      requirement = described_class.new(network: "eip155:84532", amount: "1000")

      expect(requirement.network).to eq("base-sepolia")
    end

    it "keeps unknown CAIP-2 identifiers as-is" do
      requirement = described_class.new(network: "eip155:999999", amount: "1000")

      expect(requirement.network).to eq("eip155:999999")
    end
  end

  describe "#to_json" do
    it "serializes the version-formatted requirement" do
      requirement = described_class.new(
        network: "base-sepolia",
        amount: "1000",
        asset: "0xAsset",
        payTo: "0xWallet",
        version: 2,
      )

      parsed = JSON.parse(requirement.to_json)
      expect(parsed["network"]).to eq("eip155:84532")
      expect(parsed["amount"]).to eq("1000")
      expect(parsed["payTo"]).to eq("0xWallet")
    end
  end
end
