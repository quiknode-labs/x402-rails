# frozen_string_literal: true

RSpec.describe X402::Configuration do
  after do
    X402.reset_configuration!
  end

  describe "#initialize" do
    it "sets default values from environment variables" do
      config = described_class.new
      expect(config.facilitator).to eq("https://x402.org/facilitator")
      expect(config.chain).to eq("base-sepolia")
      expect(config.currency).to eq("USDC")
      expect(config.optimistic).to be true
    end

    it "reads wallet_address from environment" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("X402_WALLET_ADDRESS", nil).and_return("0x123")
      config = described_class.new
      expect(config.wallet_address).to eq("0x123")
    end

    it "parses optimistic as boolean" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("X402_OPTIMISTIC", "true").and_return("false")
      config = described_class.new
      expect(config.optimistic).to be false
    end
  end

  describe "#validate!" do
    let(:config) { described_class.new }

    it "raises error when wallet_address is nil" do
      config.wallet_address = nil
      expect { config.validate! }.to raise_error(X402::ConfigurationError, "wallet_address is required")
    end

    it "raises error when wallet_address is empty" do
      config.wallet_address = ""
      expect { config.validate! }.to raise_error(X402::ConfigurationError, "wallet_address is required")
    end

    it "raises error when facilitator is nil" do
      config.wallet_address = "0x123"
      config.facilitator = nil
      expect { config.validate! }.to raise_error(X402::ConfigurationError, "facilitator URL is required")
    end

    it "raises error when chain is empty" do
      config.wallet_address = "0x123"
      config.chain = ""
      expect { config.validate! }.to raise_error(X402::ConfigurationError, "chain is required")
    end

    it "raises error when currency is empty" do
      config.wallet_address = "0x123"
      config.currency = ""
      expect { config.validate! }.to raise_error(X402::ConfigurationError, "currency is required")
    end

    it "passes validation with all required fields" do
      config.wallet_address = "0x123"
      expect { config.validate! }.not_to raise_error
    end
  end
end

RSpec.describe X402 do
  after do
    X402.reset_configuration!
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(X402.configuration).to be_a(X402::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = X402.configuration
      config2 = X402.configuration
      expect(config1).to equal(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      expect { |b| X402.configure(&b) }.to yield_with_args(X402::Configuration)
    end

    it "allows setting configuration values" do
      X402.configure do |config|
        config.wallet_address = "0xtest"
        config.chain = "base"
        config.optimistic = false
      end

      expect(X402.configuration.wallet_address).to eq("0xtest")
      expect(X402.configuration.chain).to eq("base")
      expect(X402.configuration.optimistic).to be false
    end
  end

  describe ".reset_configuration!" do
    it "creates a new configuration instance" do
      old_config = X402.configuration
      X402.reset_configuration!
      new_config = X402.configuration
      expect(new_config).not_to equal(old_config)
    end

    it "resets configuration to defaults" do
      X402.configure do |config|
        config.wallet_address = "0xtest"
      end

      X402.reset_configuration!
      expect(X402.configuration.wallet_address).to be_nil
    end
  end
end
