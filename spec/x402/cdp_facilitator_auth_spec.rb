# frozen_string_literal: true

require "jwt"

RSpec.describe X402::CdpFacilitatorAuth do
  include_context "with CDP credentials"

  describe ".headers_for" do
    it "returns empty headers for non-CDP facilitators" do
      headers = described_class.headers_for(
        facilitator_url: "https://facilitator.payai.network",
        http_method: "POST",
        endpoint: "verify",
      )

      expect(headers).to eq({})
    end

    it "returns empty headers when credentials are missing" do
      X402.configuration.cdp_api_key_id = nil

      headers = described_class.headers_for(
        facilitator_url: cdp_url, http_method: "POST", endpoint: "verify",
      )

      expect(headers).to eq({})
    end

    context "with an EC (ES256) key" do
      it "builds a Bearer JWT with CDP claims, verifiable with the key" do
        headers = described_class.headers_for(
          facilitator_url: cdp_url, http_method: "POST", endpoint: "verify",
        )

        expect(headers["Authorization"]).to start_with("Bearer ")
        token = headers["Authorization"].delete_prefix("Bearer ")
        claims, header = JWT.decode(token, ec_key, true, algorithm: "ES256")

        expect(header["alg"]).to eq("ES256")
        expect(header["kid"]).to eq("test-key-id")
        expect(header["typ"]).to eq("JWT")
        expect(header["nonce"]).to match(/\A\h{32}\z/)

        expect(claims["sub"]).to eq("test-key-id")
        expect(claims["iss"]).to eq("cdp")
        expect(claims["uris"]).to eq(["POST api.cdp.coinbase.com/platform/v2/x402/verify"])
        expect(claims["exp"] - claims["iat"]).to eq(described_class::EXPIRY_SECONDS)
        expect(claims["nbf"]).to eq(claims["iat"])
      end

      it "binds the uris claim to the requested endpoint" do
        headers = described_class.headers_for(
          facilitator_url: cdp_url, http_method: "GET", endpoint: "supported",
        )

        token = headers["Authorization"].delete_prefix("Bearer ")
        claims, = JWT.decode(token, ec_key, true, algorithm: "ES256")
        expect(claims["uris"]).to eq(["GET api.cdp.coinbase.com/platform/v2/x402/supported"])
      end

      it "accepts a PEM with escaped newlines" do
        X402.configuration.cdp_api_key_secret = ec_key.to_pem.gsub("\n", "\\n")

        headers = described_class.headers_for(
          facilitator_url: cdp_url, http_method: "POST", endpoint: "verify",
        )

        expect(headers["Authorization"]).to start_with("Bearer ")
      end
    end

    context "with an Ed25519 key" do
      let(:ed_key) { OpenSSL::PKey.generate_key("ED25519") }

      before do
        X402.configuration.cdp_api_key_secret =
          Base64.strict_encode64(ed_key.raw_private_key + ed_key.raw_public_key)
      end

      it "builds an EdDSA JWT whose signature verifies against the key" do
        headers = described_class.headers_for(
          facilitator_url: cdp_url, http_method: "POST", endpoint: "settle",
        )

        token = headers["Authorization"].delete_prefix("Bearer ")
        header_segment, claims_segment, signature_segment = token.split(".")

        header = JSON.parse(Base64.urlsafe_decode64(header_segment))
        expect(header["alg"]).to eq("EdDSA")
        expect(header["kid"]).to eq("test-key-id")

        claims = JSON.parse(Base64.urlsafe_decode64(claims_segment))
        expect(claims["uris"]).to eq(["POST api.cdp.coinbase.com/platform/v2/x402/settle"])

        signing_input = [header_segment, claims_segment].join(".")
        signature = Base64.urlsafe_decode64(signature_segment)
        expect(ed_key.verify(nil, signature, signing_input)).to be(true)
      end
    end

    it "returns empty headers for an unusable secret" do
      X402.configuration.cdp_api_key_secret = "not-a-key"

      headers = described_class.headers_for(
        facilitator_url: cdp_url, http_method: "POST", endpoint: "verify",
      )

      expect(headers).to eq({})
    end

    it "returns empty headers when a PEM-looking secret cannot be parsed" do
      X402.configuration.cdp_api_key_secret =
        "-----BEGIN PRIVATE KEY-----\nnot real key material\n-----END PRIVATE KEY-----"

      headers = described_class.headers_for(
        facilitator_url: cdp_url, http_method: "POST", endpoint: "verify",
      )

      expect(headers).to eq({})
    end
  end
end
