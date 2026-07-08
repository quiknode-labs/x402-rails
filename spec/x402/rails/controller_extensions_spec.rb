# frozen_string_literal: true

RSpec.describe X402::Rails::ControllerExtensions do
  include_context "with a controller harness"

  before do
    X402.configure do |config|
      config.wallet_address = "0xRecipientWallet"
      config.chain = "base-sepolia"
      config.currency = "USDC"
    end
  end

  def decoded_header(controller)
    JSON.parse(Base64.decode64(controller.response.headers["PAYMENT-REQUIRED"]))
  end

  describe "x402_discovery macro" do
    it "attaches the declared extension to the 402 header and body for the matching action" do
      harness_class.x402_discovery(
        only: :create,
        body_type: "json",
        input: { "city" => "SF" },
        input_schema: { "properties" => { "city" => { "type" => "string" } } },
        output: { example: { "weather" => "foggy" } },
      )

      controller = harness_class.new
      controller.x402_paywall(amount: 0.001)

      header = decoded_header(controller)
      expect(header.dig("extensions", "bazaar", "info", "input", "bodyType")).to eq("json")
      expect(controller.rendered_json[:extensions].dig("bazaar", "info", "input", "body"))
        .to eq("city" => "SF")
      expect(controller.rendered_status).to eq(:payment_required)
    end

    it "stamps the request method at render time when the declaration omits it" do
      harness_class.x402_discovery(only: :create, body_type: "json", input: {})

      controller = harness_class.new(http_method: "POST")
      controller.x402_paywall(amount: 0.001)

      header = decoded_header(controller)
      expect(header.dig("extensions", "bazaar", "info", "input", "method")).to eq("POST")
      expect(header.dig("extensions", "bazaar", "schema", "properties", "input", "properties", "method"))
        .to eq("type" => "string", "enum" => ["POST"])
    end

    it "does not attach the extension to other actions" do
      harness_class.x402_discovery(only: :create, body_type: "json", input: {})

      controller = harness_class.new(action_name: "show", http_method: "GET")
      controller.x402_paywall(amount: 0.001)

      expect(decoded_header(controller)["extensions"]).to eq({})
    end

    it "applies controller-wide when only: is omitted" do
      harness_class.x402_discovery(body_type: "json", input: {})

      controller = harness_class.new(action_name: "anything")
      controller.x402_paywall(amount: 0.001)

      expect(decoded_header(controller).dig("extensions", "bazaar")).to be_present
    end

    it "accepts a prebuilt extensions hash" do
      prebuilt = { "bazaar" => { "info" => { "input" => { "type" => "http", "method" => "POST" } }, "schema" => {} } }
      harness_class.x402_discovery(only: :create, extensions: prebuilt)

      controller = harness_class.new
      controller.x402_paywall(amount: 0.001)

      expect(decoded_header(controller)["extensions"]).to eq(prebuilt)
    end
  end

  describe "#x402_payment_header / #x402_payment_attempted?" do
    it "returns the payment header for the configured version" do
      controller = harness_class.new
      controller.request.headers["PAYMENT-SIGNATURE"] = "encoded-payload"

      expect(controller.x402_payment_header).to eq("encoded-payload")
      expect(controller.x402_payment_attempted?).to be(true)
    end

    it "is nil/false when no payment header is present" do
      controller = harness_class.new

      expect(controller.x402_payment_header).to be_nil
      expect(controller.x402_payment_attempted?).to be(false)
    end

    it "is nil/false when the configured version is invalid" do
      X402.configuration.version = 99
      controller = harness_class.new

      expect(controller.x402_payment_header).to be_nil
      expect(controller.x402_payment_attempted?).to be(false)
    end
  end

  describe "x402_paywall(description:)" do
    it "sets the 402 resource description" do
      controller = harness_class.new
      controller.x402_paywall(amount: 0.001, description: "Weather data, paid per call")

      expect(decoded_header(controller).dig("resource", "description")).to eq("Weather data, paid per call")
    end

    it "defaults to the generated description" do
      controller = harness_class.new
      controller.x402_paywall(amount: 0.001)

      expect(decoded_header(controller).dig("resource", "description")).to eq("Payment required for /api/v1/things")
    end
  end

  describe "x402_paywall(extensions:)" do
    it "overrides the class-level declaration" do
      harness_class.x402_discovery(only: :create, body_type: "json", input: { "from" => "macro" })
      explicit = { "bazaar" => { "info" => { "input" => { "type" => "http", "method" => "POST" } }, "schema" => {} } }

      controller = harness_class.new
      controller.x402_paywall(amount: 0.001, extensions: explicit)

      expect(decoded_header(controller)["extensions"]).to eq(explicit)
    end
  end

  describe "backward compatibility" do
    it "renders empty extensions when nothing is declared (1.1.0 behavior)" do
      controller = harness_class.new
      controller.x402_paywall(amount: 0.001)

      expect(decoded_header(controller)["extensions"]).to eq({})
      expect(controller.rendered_json[:extensions]).to eq({})
    end

    it "keeps v1 responses free of extensions" do
      harness_class.x402_discovery(only: :create, body_type: "json", input: {})

      controller = harness_class.new
      controller.x402_paywall(amount: 0.001, version: 1)

      expect(controller.rendered_json).not_to have_key(:extensions)
    end
  end
end
