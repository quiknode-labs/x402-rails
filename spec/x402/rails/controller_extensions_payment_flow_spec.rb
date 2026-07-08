# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe X402::Rails::ControllerExtensions, "payment processing" do
  include_context "with a controller harness"

  let(:facilitator_url) { "https://facilitator.example.com" }
  let(:wallet) { "0xRecipientWallet" }

  before do
    X402.configure do |config|
      config.wallet_address = wallet
      config.chain = "base-sepolia"
      config.currency = "USDC"
      config.facilitator = facilitator_url
    end
  end

  def evm_authorization(value: "1000")
    {
      "from" => "0xPayer",
      "to" => wallet,
      "value" => value,
      "validAfter" => "0",
      "validBefore" => "9999999999",
      "nonce" => "0xnonce",
    }
  end

  def v2_payment_header(network: "eip155:84532")
    Base64.strict_encode64({
      x402Version: 2,
      accepted: { scheme: "exact", network: network, amount: "1000", payTo: wallet },
      payload: { signature: "0xsig", authorization: evm_authorization },
    }.to_json)
  end

  def v1_payment_header
    Base64.strict_encode64({
      x402Version: 1,
      scheme: "exact",
      network: "base-sepolia",
      payload: { signature: "0xsig", authorization: evm_authorization },
    }.to_json)
  end

  def stub_verify(body = { isValid: true, payer: "0xPayer" })
    stub_request(:post, "#{facilitator_url}/verify").to_return(status: 200, body: body.to_json)
  end

  def stub_settle(body = { success: true, transaction: "0xtx", network: "base-sepolia", payer: "0xPayer" })
    stub_request(:post, "#{facilitator_url}/settle").to_return(status: 200, body: body.to_json)
  end

  def paywalled_controller(payment_header, header_name: "PAYMENT-SIGNATURE")
    controller = harness_class.new
    controller.request.headers[header_name] = payment_header
    controller
  end

  describe "valid payment (pessimistic mode)" do
    it "verifies, settles immediately, and exposes payment details on the request" do
      stub_verify
      stub_settle
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_json).to be_nil
      payment = controller.request.env["x402.payment"]
      expect(payment[:payer]).to eq("0xPayer")
      expect(payment[:network]).to eq("base-sepolia")
      expect(payment[:amount]).to eq("1000")
      expect(controller.request.env["x402.settlement_result"]).to be_success

      settlement = JSON.parse(Base64.decode64(controller.response.headers["PAYMENT-RESPONSE"]))
      expect(settlement["transaction"]).to eq("0xtx")
    end

    it "logs settlement diagnostics at debug level" do
      log_output = StringIO.new
      Rails.logger = Logger.new(log_output)
      stub_verify
      stub_settle
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)

      expect(log_output.string).to include("[x402] settling payment optimistic=false")
      expect(log_output.string).to include("x402 settlement successful: 0xtx")
    ensure
      Rails.logger = Logger.new(File::NULL)
    end

    it "matches plain network names for v1 payments" do
      stub_verify
      stub_settle
      controller = paywalled_controller(v1_payment_header, header_name: "X-PAYMENT")

      controller.x402_paywall(amount: 0.001, version: 1)

      expect(controller.rendered_json).to be_nil
      expect(controller.response.headers["X-PAYMENT-RESPONSE"]).to be_present
    end
  end

  describe "rejected payment" do
    it "keeps the declared description on error 402s" do
      harness_class.x402_discovery(only: :create, description: "Premium weather data")
      stub_verify(isValid: false, invalidReason: "insufficient_funds")
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json.dig(:resource, :description)).to eq("Premium weather data")
    end

    it "renders 402 when the payment header cannot be decoded" do
      controller = paywalled_controller("not-valid-base64!")

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json[:error]).to match(/Invalid payment/)
    end

    it "renders 402 when the payment network is not accepted" do
      controller = paywalled_controller(v2_payment_header(network: "eip155:43114"))

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json[:error]).to eq("Payment network not accepted: avalanche")
    end

    it "renders 402 when the facilitator rejects the payment" do
      stub_verify(isValid: false, invalidReason: "invalid_signature")
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json[:error]).to match(/invalid_signature/)
    end

    it "renders 402 with a verification error when verification raises FacilitatorError" do
      validator = instance_double(X402::PaymentValidator)
      allow(validator).to receive(:validate).and_raise(X402::FacilitatorError, "facilitator unreachable")
      allow(X402::PaymentValidator).to receive(:new).and_return(validator)
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json[:error]).to eq("Verification error: facilitator unreachable")
    end
  end

  describe "immediate settlement failures (pessimistic mode)" do
    it "renders 402 when the facilitator declines settlement" do
      stub_verify
      stub_settle(success: false, errorReason: "insufficient_funds")
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json[:error]).to eq("failed to settle payment: insufficient_funds")
    end

    it "renders 402 when the facilitator errors during settlement" do
      stub_verify
      stub_request(:post, "#{facilitator_url}/settle").to_return(status: 500, body: "")
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json[:error]).to eq("failed to settle payment: Settlement failed")
    end
  end

  describe "optimistic settlement (after_action)" do
    before do
      X402.configuration.optimistic = true
    end

    it "settles only after the action responds successfully" do
      stub_verify
      settle_stub = stub_settle
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)

      expect(controller.rendered_json).to be_nil
      expect(settle_stub).not_to have_been_requested

      controller.send(:settle_x402_payment_if_needed)

      expect(settle_stub).to have_been_requested
      expect(controller.response.headers["PAYMENT-RESPONSE"]).to be_present
    end

    it "skips settlement when the action did not succeed" do
      stub_verify
      settle_stub = stub_settle
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001)
      controller.response.status = 404
      controller.send(:settle_x402_payment_if_needed)

      expect(settle_stub).not_to have_been_requested
    end

    it "skips settlement when no payment was processed" do
      settle_stub = stub_settle
      controller = harness_class.new

      controller.send(:settle_x402_payment_if_needed)

      expect(settle_stub).not_to have_been_requested
    end
  end

  describe "configuration errors" do
    it "renders a v1 fallback 402 for an unsupported protocol version" do
      controller = harness_class.new

      controller.x402_paywall(amount: 0.001, version: 3)

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json[:x402Version]).to eq(1)
      expect(controller.rendered_json[:error]).to eq("Configuration error: Unsupported x402 version: 3")
      expect(controller.rendered_json[:accepts]).to eq([])
    end

    it "renders a configuration error when the paywall chain is unknown" do
      controller = paywalled_controller(v2_payment_header)

      controller.x402_paywall(amount: 0.001, chain: "unknown-chain")

      expect(controller.rendered_status).to eq(:payment_required)
      expect(controller.rendered_json[:error]).to match(/Configuration error: Unknown token/)
    end
  end
end
