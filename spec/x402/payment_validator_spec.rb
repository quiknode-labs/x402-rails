# frozen_string_literal: true

RSpec.describe X402::PaymentValidator do
  let(:facilitator_client) { instance_double(X402::FacilitatorClient) }
  let(:validator) { described_class.new(facilitator_client) }

  let(:requirement) do
    X402::PaymentRequirement.new(
      scheme: "exact",
      network: "base-sepolia",
      max_amount_required: 1000,
      asset: "0xUSDC",
      pay_to: "0xRecipient"
    )
  end

  let(:payment_payload) do
    X402::PaymentPayload.new(
      scheme: "exact",
      network: "base-sepolia",
      payload: {
        authorization: {
          from: "0xPayer",
          to: "0xRecipient",
          value: "1000"
        }
      }
    )
  end

  describe "#initialize" do
    it "accepts a facilitator client" do
      client = instance_double(X402::FacilitatorClient)
      validator = described_class.new(client)
      expect(validator.facilitator_client).to eq(client)
    end

    it "creates default facilitator client when none provided" do
      validator = described_class.new
      expect(validator.facilitator_client).to be_a(X402::FacilitatorClient)
    end
  end

  describe "#validate" do
    context "when scheme does not match" do
      before do
        payment_payload.scheme = "streaming"
      end

      it "returns validation error" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("Scheme mismatch")
      end
    end

    context "when network does not match" do
      before do
        payment_payload.network = "base"
      end

      it "returns validation error" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("Network mismatch")
      end
    end

    context "when recipient address does not match" do
      before do
        allow(payment_payload).to receive(:to_address).and_return("0xWrongRecipient")
      end

      it "returns validation error" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("Recipient mismatch")
      end
    end

    context "when recipient address case is different" do
      before do
        requirement.pay_to = "0xRECIPIENT"
        allow(payment_payload).to receive(:to_address).and_return("0xrecipient")
      end

      it "performs case-insensitive comparison" do
        allow(facilitator_client).to receive(:verify).and_return({
          "isValid" => true,
          "payer" => "0xPayer"
        })

        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be true
      end
    end

    context "when payment amount is insufficient" do
      before do
        allow(payment_payload).to receive(:value).and_return("500")
      end

      it "returns validation error" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("Insufficient amount")
      end
    end

    context "when payment amount is exact" do
      before do
        allow(facilitator_client).to receive(:verify).and_return({
          "isValid" => true,
          "payer" => "0xPayer"
        })
      end

      it "passes validation" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be true
      end
    end

    context "when payment amount is more than required" do
      before do
        allow(payment_payload).to receive(:value).and_return("2000")
        allow(facilitator_client).to receive(:verify).and_return({
          "isValid" => true,
          "payer" => "0xPayer"
        })
      end

      it "passes validation" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be true
      end
    end

    context "when facilitator validation succeeds" do
      before do
        allow(facilitator_client).to receive(:verify).and_return({
          "isValid" => true,
          "payer" => "0xPayerAddress",
          "txHash" => "0xabcdef"
        })
      end

      it "returns successful validation" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be true
        expect(result[:payer]).to eq("0xPayerAddress")
      end

      it "includes facilitator data" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:data]).to include("payer" => "0xPayerAddress")
      end

      it "calls facilitator with correct parameters" do
        expect(facilitator_client).to receive(:verify).with(
          payment_payload,
          requirement.to_h
        )
        validator.validate(payment_payload, requirement)
      end
    end

    context "when facilitator validation fails" do
      before do
        allow(facilitator_client).to receive(:verify).and_return({
          "isValid" => false,
          "invalidReason" => "Invalid signature"
        })
      end

      it "returns validation error" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("Invalid signature")
      end
    end

    context "when facilitator returns no payer address" do
      before do
        allow(facilitator_client).to receive(:verify).and_return({
          "isValid" => true,
          "payer" => nil
        })
      end

      it "returns validation error" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("no payer address returned")
      end
    end

    context "when facilitator raises InvalidPaymentError" do
      before do
        allow(facilitator_client).to receive(:verify).and_raise(
          X402::InvalidPaymentError, "Bad signature format"
        )
      end

      it "returns validation error" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("Bad signature format")
      end
    end

    context "when facilitator raises FacilitatorError" do
      before do
        allow(facilitator_client).to receive(:verify).and_raise(
          X402::FacilitatorError, "Connection timeout"
        )
      end

      it "returns validation error" do
        result = validator.validate(payment_payload, requirement)
        expect(result[:valid]).to be false
        expect(result[:error]).to include("Connection timeout")
      end
    end
  end
end
