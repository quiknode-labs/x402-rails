# frozen_string_literal: true

RSpec.shared_context "with CDP credentials" do
  let(:cdp_url) { "https://api.cdp.coinbase.com/platform/v2/x402" }
  let(:ec_key) { OpenSSL::PKey::EC.generate("prime256v1") }

  before do
    X402.configure do |config|
      config.cdp_api_key_id = "test-key-id"
      config.cdp_api_key_secret = ec_key.to_pem
    end
  end

  after do
    X402.reset_configuration!
  end
end
