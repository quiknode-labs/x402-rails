# frozen_string_literal: true

RSpec.describe X402::RequirementGenerator do
  before do
    X402.configure do |config|
      config.wallet_address = "0xRecipientWallet"
      config.chain = "base-sepolia"
      config.currency = "USDC"
    end
  end

  after do
    X402.reset_configuration!
  end

  describe ".generate" do
    let(:resource) { "/api/weather" }
    let(:amount) { 0.001 }

    it "generates payment requirement with required fields" do
      result = described_class.generate(amount: amount, resource: resource)

      expect(result).to include(
        x402Version: 1,
        error: "Payment required to access this resource"
      )
      expect(result[:accepts]).to be_an(Array)
      expect(result[:accepts].size).to eq(1)
    end

    it "sets the scheme to exact" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:scheme]).to eq("exact")
    end

    it "uses configured chain" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:network]).to eq("base-sepolia")
    end

    it "converts amount to atomic units" do
      result = described_class.generate(amount: 0.001, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:maxAmountRequired]).to eq("1000")
    end

    it "sets correct USDC contract address for chain" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:asset]).to eq("0x036CbD53842c5426634e7929541eC2318f3dCF7e")
    end

    it "sets pay_to from configuration" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:payTo]).to eq("0xRecipientWallet")
    end

    it "sets resource path" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:resource]).to eq("/api/weather")
    end

    it "uses default description when not provided" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:description]).to eq("Payment required for /api/weather")
    end

    it "uses custom description when provided" do
      result = described_class.generate(
        amount: amount,
        resource: resource,
        description: "Weather API access"
      )
      requirement = result[:accepts].first

      expect(requirement[:description]).to eq("Weather API access")
    end

    it "sets max_timeout_seconds" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:maxTimeoutSeconds]).to eq(600)
    end

    it "sets mime_type to application/json" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:mimeType]).to eq("application/json")
    end

    it "includes EIP-712 domain in extra field" do
      result = described_class.generate(amount: amount, resource: resource)
      requirement = result[:accepts].first

      expect(requirement[:extra]).to include(
        name: "USDC",
        version: "2"
      )
    end

    it "uses custom chain when provided" do
      result = described_class.generate(
        amount: amount,
        resource: resource,
        chain: "base"
      )
      requirement = result[:accepts].first

      expect(requirement[:network]).to eq("base")
      expect(requirement[:asset]).to eq("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913")
    end

    it "uses correct currency name for mainnet" do
      result = described_class.generate(
        amount: amount,
        resource: resource,
        chain: "base"
      )
      requirement = result[:accepts].first

      expect(requirement[:extra][:name]).to eq("USD Coin")
    end
  end

  describe ".convert_to_atomic" do
    it "converts USD to atomic units with 6 decimals" do
      expect(described_class.convert_to_atomic(0.001, 6)).to eq(1000)
      expect(described_class.convert_to_atomic(1.0, 6)).to eq(1_000_000)
      expect(described_class.convert_to_atomic(0.5, 6)).to eq(500_000)
    end

    it "handles different decimal places" do
      expect(described_class.convert_to_atomic(1.0, 18)).to eq(1_000_000_000_000_000_000)
      expect(described_class.convert_to_atomic(1.0, 2)).to eq(100)
    end

    it "handles very small amounts" do
      expect(described_class.convert_to_atomic(0.000001, 6)).to eq(1)
    end
  end
end
