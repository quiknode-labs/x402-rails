# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe X402::FacilitatorClient do
  include_context "with CDP credentials"

  let(:payment_payload) do
    X402::PaymentPayload.new(
      "x402Version" => 2,
      "accepted" => { "scheme" => "exact", "network" => "base-sepolia", "amount" => "1000", "payTo" => "0xabc" },
      "payload" => { "signature" => "0xsig" },
    )
  end

  describe "facilitator auth headers" do
    it "sends a CDP Bearer JWT on verify when the facilitator is CDP" do
      captured = nil
      stub_request(:post, "#{cdp_url}/verify").with do |request|
        captured = request.headers["Authorization"]
        true
      end.to_return(status: 200, body: { isValid: true }.to_json)

      described_class.new(cdp_url).verify(payment_payload, { scheme: "exact" })

      expect(captured).to start_with("Bearer ")
    end

    it "sends no Authorization header to non-CDP facilitators" do
      captured = nil
      stub_request(:post, "https://facilitator.payai.network/verify").with do |request|
        captured = request.headers
        true
      end.to_return(status: 200, body: { isValid: true }.to_json)

      described_class.new("https://facilitator.payai.network").verify(payment_payload, { scheme: "exact" })

      expect(captured["Authorization"]).to be_nil
    end

    it "sends a CDP Bearer JWT on settle" do
      captured = nil
      stub_request(:post, "#{cdp_url}/settle").with do |request|
        captured = request.headers["Authorization"]
        true
      end.to_return(status: 200, body: { success: true, transaction: "0xtx", network: "base-sepolia" }.to_json)

      described_class.new(cdp_url).settle(payment_payload, { scheme: "exact" })

      expect(captured).to start_with("Bearer ")
    end

    it "lists discovery resources from any facilitator with query params" do
      stub_request(:get, "https://facilitator.payai.network/discovery/resources?type=http")
        .to_return(status: 200, body: { items: [{ resource: "https://api.example.com/thing" }] }.to_json)

      result = described_class.new("https://facilitator.payai.network").discovery_resources(type: "http")

      expect(result["items"].first["resource"]).to eq("https://api.example.com/thing")
    end

    it "authenticates discovery_resources against CDP" do
      captured = nil
      stub_request(:get, "#{cdp_url}/discovery/resources?type=http").with do |request|
        captured = request.headers["Authorization"]
        true
      end.to_return(status: 200, body: { items: [] }.to_json)

      described_class.new(cdp_url).discovery_resources(type: "http")

      expect(captured).to start_with("Bearer ")
    end

    it "authenticates supported_networks against CDP" do
      captured = nil
      stub_request(:get, "#{cdp_url}/supported").with do |request|
        captured = request.headers["Authorization"]
        true
      end.to_return(status: 200, body: { kinds: [] }.to_json)

      described_class.new(cdp_url).supported_networks

      expect(captured).to start_with("Bearer ")
    end
  end

  describe "error handling" do
    let(:facilitator_url) { "https://facilitator.payai.network" }
    let(:client) { described_class.new(facilitator_url) }

    it "wraps connection failures on verify in FacilitatorError" do
      stub_request(:post, "#{facilitator_url}/verify").to_timeout

      expect { client.verify(payment_payload, { scheme: "exact" }) }
        .to raise_error(X402::FacilitatorError, /Failed to verify payment/)
    end

    it "wraps connection failures on settle in FacilitatorError" do
      stub_request(:post, "#{facilitator_url}/settle").to_timeout

      expect { client.settle(payment_payload, { scheme: "exact" }) }
        .to raise_error(X402::FacilitatorError, /Failed to settle payment/)
    end

    it "wraps connection failures on supported_networks in FacilitatorError" do
      stub_request(:get, "#{facilitator_url}/supported").to_timeout

      expect { client.supported_networks }
        .to raise_error(X402::FacilitatorError, /Failed to fetch supported networks/)
    end

    it "wraps connection failures on discovery_resources in FacilitatorError" do
      stub_request(:get, "#{facilitator_url}/discovery/resources").to_timeout

      expect { client.discovery_resources }
        .to raise_error(X402::FacilitatorError, /Failed to fetch discovery resources/)
    end

    it "raises InvalidPaymentError with the facilitator's error on 400" do
      stub_request(:post, "#{facilitator_url}/verify")
        .to_return(status: 400, body: { error: "insufficient_funds" }.to_json)

      expect { client.verify(payment_payload, { scheme: "exact" }) }
        .to raise_error(X402::InvalidPaymentError, /insufficient_funds/)
    end

    it "falls back to the raw body when a 400 response is not JSON" do
      stub_request(:post, "#{facilitator_url}/verify").to_return(status: 400, body: "bad request")

      expect { client.verify(payment_payload, { scheme: "exact" }) }
        .to raise_error(X402::InvalidPaymentError, /bad request/)
    end

    it "raises FacilitatorError on 5xx responses" do
      stub_request(:post, "#{facilitator_url}/verify").to_return(status: 503, body: "")

      expect { client.verify(payment_payload, { scheme: "exact" }) }
        .to raise_error(X402::FacilitatorError, "Facilitator error (verify): 503")
    end

    it "raises FacilitatorError on unexpected statuses" do
      stub_request(:post, "#{facilitator_url}/verify").to_return(status: 301, body: "")

      expect { client.verify(payment_payload, { scheme: "exact" }) }
        .to raise_error(X402::FacilitatorError, "Unexpected response (verify): 301")
    end

    it "raises FacilitatorError when a success response is not parseable JSON" do
      stub_request(:post, "#{facilitator_url}/verify").to_return(status: 200, body: "not json")

      expect { client.verify(payment_payload, { scheme: "exact" }) }
        .to raise_error(X402::FacilitatorError, /Failed to parse facilitator response/)
    end
  end
end
