# frozen_string_literal: true

RSpec.describe X402, "chains" do
  describe "CHAINS constant" do
    it "is frozen" do
      expect(X402::CHAINS).to be_frozen
    end

    it "includes base-sepolia configuration" do
      expect(X402::CHAINS["base-sepolia"]).to include(
        chain_id: 84532,
        rpc_url: "https://clean-snowy-hexagon.base-sepolia.quiknode.pro",
        usdc_address: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        explorer_url: "https://sepolia.basescan.org"
      )
    end

    it "includes base mainnet configuration" do
      expect(X402::CHAINS["base"]).to include(
        chain_id: 8453,
        rpc_url: "https://snowy-compatible-ensemble.base-mainnet.quiknode.pro",
        usdc_address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        explorer_url: "https://basescan.org"
      )
    end

    it "includes avalanche-fuji configuration" do
      expect(X402::CHAINS["avalanche-fuji"]).to include(
        chain_id: 43113,
        usdc_address: "0x5425890298aed601595a70AB815c96711a31Bc65"
      )
    end

    it "includes avalanche mainnet configuration" do
      expect(X402::CHAINS["avalanche"]).to include(
        chain_id: 43114,
        usdc_address: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E"
      )
    end
  end

  describe "CURRENCY_BY_CHAIN constant" do
    it "is frozen" do
      expect(X402::CURRENCY_BY_CHAIN).to be_frozen
    end

    it "includes configuration for all supported chains" do
      X402::CHAINS.keys.each do |chain_name|
        expect(X402::CURRENCY_BY_CHAIN).to have_key(chain_name)
      end
    end

    it "includes USDC configuration with decimals" do
      config = X402::CURRENCY_BY_CHAIN["base-sepolia"]
      expect(config).to include(
        symbol: "USDC",
        decimals: 6,
        version: "2"
      )
    end
  end

  describe ".chain_config" do
    it "returns configuration for supported chain" do
      config = X402.chain_config("base-sepolia")
      expect(config).to include(:chain_id, :rpc_url, :usdc_address, :explorer_url)
    end

    it "raises error for unsupported chain" do
      expect { X402.chain_config("ethereum") }.to raise_error(
        X402::ConfigurationError,
        "Unsupported chain: ethereum"
      )
    end
  end

  describe ".currency_config_for_chain" do
    it "returns currency configuration for supported chain" do
      config = X402.currency_config_for_chain("base-sepolia")
      expect(config).to include(:symbol, :decimals, :name, :version)
    end

    it "raises error for unsupported chain" do
      expect { X402.currency_config_for_chain("unknown") }.to raise_error(
        X402::ConfigurationError,
        "Unsupported chain for currency: unknown"
      )
    end
  end

  describe ".supported_chains" do
    it "returns array of supported chain names" do
      chains = X402.supported_chains
      expect(chains).to be_an(Array)
      expect(chains).to include("base-sepolia", "base", "avalanche-fuji", "avalanche")
    end

    it "returns all chain keys" do
      expect(X402.supported_chains).to eq(X402::CHAINS.keys)
    end
  end

  describe ".usdc_address_for" do
    it "returns USDC contract address for chain" do
      address = X402.usdc_address_for("base-sepolia")
      expect(address).to eq("0x036CbD53842c5426634e7929541eC2318f3dCF7e")
    end

    it "returns different addresses for different chains" do
      base_address = X402.usdc_address_for("base")
      avalanche_address = X402.usdc_address_for("avalanche")
      expect(base_address).not_to eq(avalanche_address)
    end

    it "raises error for unsupported chain" do
      expect { X402.usdc_address_for("polygon") }.to raise_error(X402::ConfigurationError)
    end
  end

  describe ".currency_decimals_for_chain" do
    it "returns decimals for supported chain" do
      decimals = X402.currency_decimals_for_chain("base-sepolia")
      expect(decimals).to eq(6)
    end

    it "returns same decimals for all USDC chains" do
      X402.supported_chains.each do |chain|
        expect(X402.currency_decimals_for_chain(chain)).to eq(6)
      end
    end

    it "raises error for unsupported chain" do
      expect { X402.currency_decimals_for_chain("unknown") }.to raise_error(X402::ConfigurationError)
    end
  end

  describe ".rpc_url_for" do
    before do
      X402.reset_configuration!
    end

    it "returns default RPC URL when no override is set" do
      rpc_url = X402.rpc_url_for("base-sepolia")
      expect(rpc_url).to eq("https://clean-snowy-hexagon.base-sepolia.quiknode.pro")
    end

    it "returns different URLs for different chains" do
      base_url = X402.rpc_url_for("base")
      avalanche_url = X402.rpc_url_for("avalanche")
      expect(base_url).to eq("https://snowy-compatible-ensemble.base-mainnet.quiknode.pro")
      expect(avalanche_url).to eq("https://floral-patient-panorama.avalanche-mainnet.quiknode.pro/ext/bc/C/rpc")
    end

    it "prefers environment variable over default" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("X402_BASE_SEPOLIA_RPC_URL").and_return("https://custom-env-rpc.com")

      rpc_url = X402.rpc_url_for("base-sepolia")
      expect(rpc_url).to eq("https://custom-env-rpc.com")
    end

    it "prefers programmatic config over environment variable" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("X402_BASE_SEPOLIA_RPC_URL").and_return("https://custom-env-rpc.com")

      X402.configure do |config|
        config.rpc_urls["base-sepolia"] = "https://custom-config-rpc.com"
      end

      rpc_url = X402.rpc_url_for("base-sepolia")
      expect(rpc_url).to eq("https://custom-config-rpc.com")
    end

    it "handles chain names with hyphens in environment variable names" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("X402_AVALANCHE_FUJI_RPC_URL").and_return("https://custom-fuji-rpc.com")

      rpc_url = X402.rpc_url_for("avalanche-fuji")
      expect(rpc_url).to eq("https://custom-fuji-rpc.com")
    end

    it "raises error for unsupported chain" do
      expect { X402.rpc_url_for("ethereum") }.to raise_error(X402::ConfigurationError)
    end
  end
end
