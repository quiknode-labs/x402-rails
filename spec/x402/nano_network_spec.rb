# frozen_string_literal: true

RSpec.describe "Nano (XNO) network" do
  let(:nano_wallet) { "nano_3t6k35gi95xu6tergt6p69ck76ogmitsa8mnijtpxm9fkcm736xtoncuohr3" }

  after { X402.reset_configuration! }

  describe "chain registry" do
    it "maps nano to the nano:mainnet CAIP-2 id and back" do
      expect(X402.to_caip2("nano")).to eq("nano:mainnet")
      expect(X402.from_caip2("nano:mainnet")).to eq("nano")
    end

    it "uses the native XNO coin with 30 decimals" do
      expect(X402.currency_config_for_chain("nano")).to include(symbol: "XNO", decimals: 30)
      expect(X402.currency_decimals_for_chain("nano")).to eq(30)
      expect(X402.token_config_for("nano", "XNO")).to eq(X402::XNO_NATIVE)
      expect(X402.token_config_for("nano", "xno")).to eq(X402::XNO_NATIVE)
      expect(X402.asset_address_for("nano", "XNO")).to eq("XNO")
    end

    it "has no USDC on nano" do
      expect(X402.usdc_address_for("nano")).to be_nil
      expect { X402.asset_address_for("nano", "USDC") }.to raise_error(X402::ConfigurationError, /Unknown token USDC/)
      expect { X402.token_config_for("nano", "USDC") }.to raise_error(X402::ConfigurationError, /Unknown token USDC/)
    end

    it "does not treat XNO as native on other chains" do
      expect { X402.asset_address_for("base", "XNO") }.to raise_error(X402::ConfigurationError)
    end

    it "classifies nano as neither Solana nor EVM" do
      expect(X402.nano_chain?("nano")).to be true
      expect(X402.nano_chain?("base")).to be false
      expect(X402.solana_chain?("nano")).to be false
      expect(X402.supported_chains).to include("nano")
    end

    it "leaves the existing chains unchanged" do
      expect(X402.to_caip2("base")).to eq("eip155:8453")
      expect(X402.to_caip2("solana")).to eq("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
    end

    it "refuses custom tokens on nano" do
      expect do
        X402.configuration.register_token(chain: "nano", symbol: "FOO", address: "x", decimals: 1, name: "Foo")
      end.to raise_error(X402::ConfigurationError, /only supported on EVM/)
    end
  end

  describe X402::RequirementGenerator do
    it "builds a v2 nano:mainnet requirement in raw with no EIP-712 extra" do
      result = described_class.generate(
        amount: 0.001, resource: "/api/data", chain: "nano", currency: "XNO", wallet_address: nano_wallet
      )
      requirement = result[:accepts].first

      expect(requirement).to eq(
        scheme: "exact",
        network: "nano:mainnet",
        amount: "1000000000000000000000000000",
        asset: "XNO",
        payTo: nano_wallet,
        maxTimeoutSeconds: 600
      )
    end

    it "converts XNO amounts exactly (no Float rounding)" do
      expect(described_class.convert_to_atomic(0.000001, 30)).to eq(10**24)
      expect(described_class.convert_to_atomic("1.23", 30)).to eq(123 * 10**28)
      expect(described_class.convert_to_atomic(0.001, 6)).to eq(1000)
    end

    it "offers XNO beside USDC when both are accepted" do
      X402.configure do |config|
        config.wallet_address = "0xRecipientWallet"
        config.accept(chain: "base", currency: "USDC")
        config.accept(chain: "nano", currency: "XNO", wallet_address: nano_wallet)
      end

      accepts = described_class.generate(amount: 0.01, resource: "/api/data")[:accepts]

      expect(accepts.map { |a| a[:network] }).to eq(["eip155:8453", "nano:mainnet"])
      expect(accepts.first).to include(asset: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", amount: "10000")
      expect(accepts.last).to include(asset: "XNO", payTo: nano_wallet, amount: "10000000000000000000000000000")
    end

    it "works with v1 too" do
      result = described_class.generate(
        amount: 1, resource: "/api/data", chain: "nano", currency: "XNO", wallet_address: nano_wallet, version: 1
      )
      requirement = result[:accepts].first

      expect(requirement).to include(network: "nano", maxAmountRequired: (10**30).to_s, asset: "XNO")
      expect(requirement).not_to have_key(:extra)
    end

    it "rejects a payTo with a bad checksum" do
      expect do
        described_class.generate(
          amount: 0.001, resource: "/api/data", chain: "nano", currency: "XNO",
          wallet_address: "#{nano_wallet[0..-2]}1"
        )
      end.to raise_error(X402::ConfigurationError, /Invalid Nano address/)
    end

    it "rejects an EVM payTo on nano" do
      expect do
        described_class.generate(
          amount: 0.001, resource: "/api/data", chain: "nano", currency: "XNO", wallet_address: "0xRecipientWallet"
        )
      end.to raise_error(X402::ConfigurationError, /Invalid Nano address/)
    end
  end

  describe X402::PaymentPayload do
    it "parses a v2 nano:mainnet payload" do
      payload = described_class.new(
        x402Version: 2,
        accepted: { scheme: "exact", network: "nano:mainnet" },
        payload: { blockHash: "B749B757" }
      )

      expect(payload.network).to eq("nano")
      expect(payload.nano_chain?).to be true
      expect(payload.solana_chain?).to be false
      expect(payload.evm_chain?).to be false
    end
  end

  describe X402::PaymentValidator do
    let(:facilitator_client) { instance_double(X402::FacilitatorClient) }
    let(:validator) { described_class.new(facilitator_client) }
    let(:requirement) do
      X402::PaymentRequirement.new(
        scheme: "exact", network: "nano", max_amount_required: 10**27, asset: "XNO", pay_to: nano_wallet
      )
    end

    it "hands a nano payment to the facilitator" do
      payload = X402::PaymentPayload.new(scheme: "exact", network: "nano", payload: { blockHash: "B749B757" })
      allow(facilitator_client).to receive(:verify).and_return("isValid" => true, "payer" => nano_wallet)

      result = validator.validate(payload, requirement)

      expect(result).to include(valid: true, payer: nano_wallet)
      expect(facilitator_client).to have_received(:verify)
    end

    it "rejects a nano payment with no payload before calling the facilitator" do
      payload = X402::PaymentPayload.new(scheme: "exact", network: "nano", payload: {})
      allow(facilitator_client).to receive(:verify)

      result = validator.validate(payload, requirement)

      expect(result).to eq(valid: false, error: "Nano payment missing payload")
      expect(facilitator_client).not_to have_received(:verify)
    end
  end
end
