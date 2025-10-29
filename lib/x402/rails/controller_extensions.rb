# frozen_string_literal: true

module X402
  module Rails
    module ControllerExtensions
      extend ActiveSupport::Concern

      included do
        after_action :settle_x402_payment_if_needed
      end

      def x402_paywall(options = {})
        amount = options[:amount] or raise ArgumentError, "amount is required"
        chain = options[:chain] || X402.configuration.chain
        currency = options[:currency] || X402.configuration.currency

        # Check if payment header is present
        payment_header = request.headers["X-PAYMENT"]

        if payment_header.nil? || payment_header.empty?
          # No payment provided, return 402 with requirements
          return render_payment_required(amount, chain, currency)
        end

        # Payment provided, validate it
        process_payment(payment_header, amount, chain, currency)
      end

      private

      def generate_payment_required_response(amount, chain, currency, error_message = nil)
        requirement_response = X402::RequirementGenerator.generate(
          amount: amount,
          resource: request.original_url,
          description: "Payment required for #{request.path}",
          chain: chain,
          currency: currency
        )
        requirement_response[:error] = error_message if error_message
        requirement_response
      end

      def render_payment_required(amount, chain, currency)
        requirement_response = generate_payment_required_response(amount, chain, currency)

        # Detect if request is from browser or API client
        # if browser_request?
        #   render_html_paywall(requirement_response)
        # else
          render json: requirement_response, status: :payment_required
        # end
      end

      def process_payment(payment_header, amount, chain, currency)
        # Parse payment payload
        payment_payload = X402::PaymentPayload.from_header(payment_header)

        # Generate requirement for validation (must match the 402 response exactly!)
        requirement_data = X402::RequirementGenerator.generate(
          amount: amount,
          resource: request.original_url,
          description: "Payment required for #{request.path}",
          chain: chain,
          currency: currency
        )

        requirement = X402::PaymentRequirement.new(requirement_data[:accepts].first)

        # Validate payment (verify signature, but don't settle on blockchain yet)
        validator = X402::PaymentValidator.new
        validation_result = validator.validate(payment_payload, requirement)

        unless validation_result[:valid]
          requirement_response = generate_payment_required_response(amount, chain, currency, validation_result[:error])
          return render json: requirement_response, status: :payment_required
        end

        # Store payment info and requirement in request environment
        request.env["x402.payment"] = {
          payer: validation_result[:payer],
          amount: payment_payload.value,
          network: payment_payload.network,
          payload: payment_payload,
          requirement: requirement
        }

        # If non-optimistic mode, settle payment synchronously before continuing
        unless X402.configuration.optimistic
          settlement_result = settle_payment_now

          # If settlement failed, abort and return 402 with payment requirements
          if settlement_result.nil? || !settlement_result.success?
            error_message = settlement_result&.error_reason || "Settlement failed"
            requirement_response = generate_payment_required_response(amount, chain, currency, "failed to settle payment: #{error_message}")
            return render json: requirement_response, status: :payment_required
          end
        end

        # Payment verified, continue with action
        # In optimistic mode, settlement will happen automatically via after_action callback
      rescue X402::InvalidPaymentError => e
        requirement_response = generate_payment_required_response(amount, chain, currency, "Invalid payment: #{e.message}")
        render json: requirement_response, status: :payment_required
      rescue X402::FacilitatorError => e
        requirement_response = generate_payment_required_response(amount, chain, currency, "Verification error: #{e.message}")
        render json: requirement_response, status: :payment_required
      end

      def settle_x402_payment_if_needed
        # Only run in optimistic mode (non-optimistic settles synchronously)
        return unless X402.configuration.optimistic

        # Only settle if payment was verified
        payment_info = request.env["x402.payment"]
        return unless payment_info

        # Only settle if response is 2xx (success)
        return unless response.status >= 200 && response.status < 300

        perform_settlement(payment_info)
      end

      def settle_payment_now
        payment_info = request.env["x402.payment"]
        return unless payment_info

        ::Rails.logger.info("=== X402 Non-Optimistic Settlement (before response) ===")
        settlement_result = perform_settlement(payment_info)

        # Store settlement result for later use (e.g., adding to response body)
        request.env["x402.settlement_result"] = settlement_result
        settlement_result
      end

      def perform_settlement(payment_info)
        begin
          ::Rails.logger.info("=== X402 Settlement Attempt ===")
          ::Rails.logger.info("Optimistic mode: #{X402.configuration.optimistic}")
          ::Rails.logger.info("Payment payload class: #{payment_info[:payload].class}")
          ::Rails.logger.info("Payment payload: #{payment_info[:payload].inspect}")
          ::Rails.logger.info("Requirement class: #{payment_info[:requirement].class}")
          ::Rails.logger.info("Requirement hash: #{payment_info[:requirement].to_h.inspect}")

          facilitator_client = X402::FacilitatorClient.new
          settlement_result = facilitator_client.settle(
            payment_info[:payload],
            payment_info[:requirement].to_h
          )

          if settlement_result.success?
            # Add settlement response header
            response.headers["X-PAYMENT-RESPONSE"] = settlement_result.to_base64
            ::Rails.logger.info("x402 settlement successful: #{settlement_result.transaction}")
          else
            # Settlement failed - in optimistic mode, user already got the service
            # In non-optimistic mode, this will be caught before the response is sent
            ::Rails.logger.error("x402 settlement failed: #{settlement_result.error_reason}")
          end

          settlement_result
        rescue X402::FacilitatorError => e
          ::Rails.logger.error("x402 settlement error: #{e.message}")
          nil
        end
      end

      def browser_request?
        # If Accept header explicitly requests JSON, return JSON even from browsers
        accept_header = request.headers["Accept"].to_s
        return false if accept_header.include?("application/json")

        # Otherwise, check User-Agent for browser indicators
        user_agent = request.headers["User-Agent"].to_s
        user_agent.match?(/(Mozilla|Chrome|Safari|Firefox|Edge|Opera)/i)
      end

      def render_html_paywall(requirement_response)
        html = <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>Payment Required</title>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                margin: 0;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              }
              .paywall-container {
                background: white;
                padding: 3rem;
                border-radius: 1rem;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                max-width: 500px;
                text-align: center;
              }
              h1 {
                color: #333;
                margin-bottom: 1rem;
                font-size: 2rem;
              }
              p {
                color: #666;
                line-height: 1.6;
                margin-bottom: 2rem;
              }
              .amount {
                font-size: 2.5rem;
                font-weight: bold;
                color: #667eea;
                margin: 1.5rem 0;
              }
              .info {
                background: #f7f7f7;
                padding: 1rem;
                border-radius: 0.5rem;
                margin: 1.5rem 0;
                font-size: 0.9rem;
              }
              code {
                background: #e0e0e0;
                padding: 0.2rem 0.5rem;
                border-radius: 0.25rem;
                font-family: monospace;
              }
            </style>
          </head>
          <body>
            <div class="paywall-container">
              <h1>💳 Payment Required</h1>
              <p>This resource requires payment to access.</p>
              <div class="amount">$#{format('%.3f', requirement_response[:accepts].first[:maxAmountRequired].to_i / 1_000_000.0)}</div>
              <div class="info">
                <p><strong>Network:</strong> #{requirement_response[:accepts].first[:network]}</p>
                <p><strong>Asset:</strong> USDC</p>
                <p><strong>Resource:</strong> #{requirement_response[:accepts].first[:resource]}</p>
              </div>
              <p style="font-size: 0.85rem; color: #999;">
                This resource uses the x402 payment protocol.
                API clients can make payments programmatically by including the X-PAYMENT header.
              </p>
            </div>
          </body>
          </html>
        HTML

        render html: html.html_safe, status: :payment_required
      end
    end
  end
end
