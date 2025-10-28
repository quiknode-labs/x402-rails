# frozen_string_literal: true

module X402
  class SettlementJob < ActiveJob::Base
    queue_as :default

    def perform(payment_payload_hash, payment_requirements_hash)
      # Reconstruct payment payload from hash
      payment_payload = Models::PaymentPayload.new(payment_payload_hash)

      # Call facilitator to settle payment
      facilitator_client = FacilitatorClient.new
      settlement_response = facilitator_client.settle(payment_payload, payment_requirements_hash)

      if settlement_response.success?
        ::Rails.logger.info("[x402] Settlement successful: #{settlement_response.transaction} " \
                           "for payer #{settlement_response.payer}")
      else
        ::Rails.logger.error("[x402] Settlement failed: #{settlement_response.error_reason} " \
                            "for payer #{settlement_response.payer}")
      end
    rescue StandardError => e
      ::Rails.logger.error("[x402] Settlement job failed: #{e.message}")
      ::Rails.logger.error(e.backtrace.join("\n"))
      raise # Re-raise to allow retry mechanisms
    end
  end
end
