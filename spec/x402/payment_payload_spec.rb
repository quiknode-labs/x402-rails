# frozen_string_literal: true

RSpec.describe X402::PaymentPayload do
  let(:bazaar_extensions) do
    { "bazaar" => { "info" => { "input" => { "type" => "http", "method" => "POST" } } } }
  end

  let(:v2_attributes) do
    {
      "x402Version" => 2,
      "accepted" => { "scheme" => "exact", "network" => "base", "amount" => "1000000", "payTo" => "0xabc" },
      "payload" => { "signature" => "0xsig", "authorization" => { "from" => "0xpayer" } },
      "resource" => { "url" => "https://api.example.com/search" },
    }
  end

  describe "#to_h with client-echoed extensions (v2)" do
    it "forwards extensions to the facilitator payload" do
      payload = described_class.new(v2_attributes.merge("extensions" => bazaar_extensions))

      expect(payload.to_h[:extensions]).to eq(bazaar_extensions)
    end

    it "defaults to empty extensions when the client omitted them" do
      payload = described_class.new(v2_attributes)

      expect(payload.to_h[:extensions]).to eq({})
    end

    it "treats an explicitly empty extensions object as absent" do
      payload = described_class.new(v2_attributes.merge("extensions" => {}))

      expect(payload.to_h[:extensions]).to eq({})
    end

    it "survives a from_header round-trip" do
      header = Base64.strict_encode64(v2_attributes.merge("extensions" => bazaar_extensions).to_json)
      payload = described_class.from_header(header)

      expect(payload.to_h[:extensions]).to eq(bazaar_extensions)
      expect(payload.to_h[:resource]).to eq(v2_attributes["resource"])
    end
  end

  describe "#to_h (v1)" do
    it "has no extensions field regardless of input" do
      payload = described_class.new(
        "x402Version" => 1,
        "scheme" => "exact",
        "network" => "base",
        "payload" => { "signature" => "0xsig" },
        "extensions" => bazaar_extensions,
      )

      expect(payload.to_h).not_to have_key(:extensions)
    end
  end

  describe ".from_header" do
    it "raises InvalidPaymentError when the header is not decodable" do
      expect { described_class.from_header("not-valid-base64!") }
        .to raise_error(X402::InvalidPaymentError, /Failed to decode payment payload/)
    end
  end

  describe "EVM authorization accessors" do
    let(:payload) do
      described_class.new(
        "x402Version" => 2,
        "accepted" => { "scheme" => "exact", "network" => "base", "amount" => "1000", "payTo" => "0xabc" },
        "payload" => {
          "signature" => "0xsig",
          "authorization" => {
            "from" => "0xpayer",
            "to" => "0xrecipient",
            "value" => "1000",
            "validAfter" => "0",
            "validBefore" => "9999999999",
            "nonce" => "0xnonce",
          },
        },
      )
    end

    it "exposes the signature and authorization fields" do
      expect(payload.signature).to eq("0xsig")
      expect(payload.from_address).to eq("0xpayer")
      expect(payload.to_address).to eq("0xrecipient")
      expect(payload.value).to eq("1000")
      expect(payload.valid_after).to eq("0")
      expect(payload.valid_before).to eq("9999999999")
      expect(payload.nonce).to eq("0xnonce")
    end

    it "reads snake_case validity window keys" do
      snake = described_class.new(
        "x402Version" => 2,
        "accepted" => { "scheme" => "exact", "network" => "base" },
        "payload" => { "authorization" => { "valid_after" => "1", "valid_before" => "2" } },
      )

      expect(snake.valid_after).to eq("1")
      expect(snake.valid_before).to eq("2")
    end
  end

  describe "Solana payloads" do
    let(:payload) do
      described_class.new(
        "x402Version" => 2,
        "accepted" => { "scheme" => "exact", "network" => "solana", "amount" => "1000", "payTo" => "SolAddr" },
        "payload" => { "transaction" => "base64tx" },
      )
    end

    it "exposes the transaction and no EVM authorization fields" do
      expect(payload.transaction).to eq("base64tx")
      expect(payload.signature).to be_nil
      expect(payload.from_address).to be_nil
      expect(payload.to_address).to be_nil
      expect(payload.value).to be_nil
      expect(payload.valid_after).to be_nil
      expect(payload.valid_before).to be_nil
      expect(payload.nonce).to be_nil
    end
  end

  describe "network normalization" do
    it "converts CAIP-2 identifiers to internal chain names" do
      payload = described_class.new(
        "x402Version" => 2,
        "accepted" => { "scheme" => "exact", "network" => "eip155:8453" },
      )

      expect(payload.network).to eq("base")
    end

    it "keeps unknown CAIP-2 identifiers as-is" do
      payload = described_class.new("x402Version" => 1, "network" => "eip155:424242")

      expect(payload.network).to eq("eip155:424242")
    end
  end

  describe "#to_json" do
    it "serializes to_h as JSON" do
      parsed = JSON.parse(described_class.new(v2_attributes).to_json)

      expect(parsed["x402Version"]).to eq(2)
      expect(parsed["accepted"]["network"]).to eq("eip155:8453")
    end
  end
end
