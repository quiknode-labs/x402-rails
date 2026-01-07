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
        chain = options[:chain]
        currency = options[:currency]
        protocol_version = options[:version] || X402.configuration.version
        wallet_address = options[:wallet_address]
        fee_payer = options[:fee_payer]
        accepts = options[:accepts]

        version_strategy = X402::Versions.for(protocol_version)

        payment_header = request.headers[version_strategy.payment_header_name]

        if payment_header.nil? || payment_header.empty?
          return render_payment_required(
            amount,
            chain: chain,
            currency: currency,
            version: protocol_version,
            wallet_address: wallet_address,
            fee_payer: fee_payer,
            accepts: accepts
          )
        end

        process_payment(
          payment_header, amount,
          chain: chain,
          currency: currency,
          version: protocol_version,
          wallet_address: wallet_address,
          fee_payer: fee_payer,
          accepts: accepts
        )
      end

      private

      def generate_payment_required_response(amount, error_message = nil,
                                              chain: nil, currency: nil, version: nil,
                                              wallet_address: nil, fee_payer: nil, accepts: nil)
        protocol_version = version || X402.configuration.version

        requirement_response = X402::RequirementGenerator.generate(
          amount: amount,
          resource: request.original_url,
          description: "Payment required for #{request.path}",
          chain: chain,
          currency: currency,
          version: protocol_version,
          wallet_address: wallet_address,
          fee_payer: fee_payer,
          accepts: accepts
        )
        requirement_response[:error] = error_message if error_message
        requirement_response
      end

      def render_payment_required(amount, chain: nil, currency: nil, version: nil,
                                   wallet_address: nil, fee_payer: nil, accepts: nil)
        protocol_version = version || X402.configuration.version
        version_strategy = X402::Versions.for(protocol_version)

        requirement_response = generate_payment_required_response(
          amount,
          chain: chain,
          currency: currency,
          version: protocol_version,
          wallet_address: wallet_address,
          fee_payer: fee_payer,
          accepts: accepts
        )

        render_402_response(requirement_response, version_strategy)
      end

      def render_402_response(requirement_response, version_strategy)
        if version_strategy.requirement_header_name
          response.headers[version_strategy.requirement_header_name] =
            Base64.strict_encode64(requirement_response.to_json)
        end
        render json: requirement_response, status: :payment_required
      end

      def process_payment(payment_header, amount, chain: nil, currency: nil,
                          version: nil, wallet_address: nil, fee_payer: nil, accepts: nil)
        protocol_version = version || X402.configuration.version
        version_strategy = X402::Versions.for(protocol_version)

        payment_payload = X402::PaymentPayload.from_header(payment_header)

        requirement_data = X402::RequirementGenerator.generate(
          amount: amount,
          resource: request.original_url,
          description: "Payment required for #{request.path}",
          chain: chain,
          currency: currency,
          version: protocol_version,
          wallet_address: wallet_address,
          fee_payer: fee_payer,
          accepts: accepts
        )

        matching_accept = find_matching_accept(requirement_data[:accepts], payment_payload, version_strategy)

        unless matching_accept
          requirement_response = generate_payment_required_response(
            amount, "Payment network not accepted: #{payment_payload.network}",
            chain: chain, currency: currency, version: protocol_version,
            wallet_address: wallet_address, fee_payer: fee_payer, accepts: accepts
          )
          return render_402_response(requirement_response, version_strategy)
        end

        resource_info = requirement_data[:resource] || {}
        requirement_attrs = matching_accept.merge(
          {
            version: protocol_version,
            resource: resource_info[:url],
            description: resource_info[:description],
            mime_type: resource_info[:mimeType]
          }.compact
        )
        requirement = X402::PaymentRequirement.new(requirement_attrs)

        validator = X402::PaymentValidator.new
        validation_result = validator.validate(payment_payload, requirement)

        unless validation_result[:valid]
          requirement_response = generate_payment_required_response(
            amount, validation_result[:error],
            chain: chain, currency: currency, version: protocol_version,
            wallet_address: wallet_address, fee_payer: fee_payer, accepts: accepts
          )
          return render_402_response(requirement_response, version_strategy)
        end

        request.env["x402.payment"] = {
          payer: validation_result[:payer],
          amount: payment_payload.value,
          network: payment_payload.network,
          payload: payment_payload,
          requirement: requirement,
          version: protocol_version
        }

        unless X402.configuration.optimistic
          settlement_result = settle_payment_now

          if settlement_result.nil? || !settlement_result.success?
            error_message = settlement_result&.error_reason || "Settlement failed"
            requirement_response = generate_payment_required_response(
              amount, "failed to settle payment: #{error_message}",
              chain: chain, currency: currency, version: protocol_version,
              wallet_address: wallet_address, fee_payer: fee_payer, accepts: accepts
            )
            return render_402_response(requirement_response, version_strategy)
          end
        end

      rescue X402::InvalidPaymentError => e
        requirement_response = generate_payment_required_response(
          amount, "Invalid payment: #{e.message}",
          chain: chain, currency: currency, version: protocol_version,
          wallet_address: wallet_address, fee_payer: fee_payer, accepts: accepts
        )
        render_402_response(requirement_response, version_strategy)
      rescue X402::FacilitatorError => e
        requirement_response = generate_payment_required_response(
          amount, "Verification error: #{e.message}",
          chain: chain, currency: currency, version: protocol_version,
          wallet_address: wallet_address, fee_payer: fee_payer, accepts: accepts
        )
        render_402_response(requirement_response, version_strategy)
      end

      def find_matching_accept(accepts, payment_payload, version_strategy)
        payment_network = payment_payload.network

        accepts.find do |accept|
          accept_network = accept[:network]
          next false unless accept_network.present?
          
          if accept_network.to_s.include?(":")
            accept_network == payment_network ||
              version_strategy.parse_network(accept_network) == payment_network
          else
            accept_network == payment_network ||
              version_strategy.format_network(accept_network) == payment_network
          end
        end
      end

      def settle_x402_payment_if_needed
        return unless X402.configuration.optimistic

        payment_info = request.env["x402.payment"]
        return unless payment_info

        return unless response.status >= 200 && response.status < 300

        perform_settlement(payment_info)
      end

      def settle_payment_now
        payment_info = request.env["x402.payment"]
        return unless payment_info

        ::Rails.logger.info("=== X402 Non-Optimistic Settlement (before response) ===")
        settlement_result = perform_settlement(payment_info)

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

          protocol_version = payment_info[:version] || X402.configuration.version
          version_strategy = X402::Versions.for(protocol_version)

          facilitator_client = X402::FacilitatorClient.new
          settlement_result = facilitator_client.settle(
            payment_info[:payload],
            payment_info[:requirement].to_h(version: protocol_version)
          )

          if settlement_result.success?
            response.headers[version_strategy.response_header_name] = settlement_result.to_base64
            ::Rails.logger.info("x402 settlement successful: #{settlement_result.transaction}")
          else
            ::Rails.logger.error("x402 settlement failed: #{settlement_result.error_reason}")
          end

          settlement_result
        rescue X402::FacilitatorError => e
          ::Rails.logger.error("x402 settlement error: #{e.message}")
          nil
        end
      end

      def browser_request?
        accept_header = request.headers["Accept"].to_s
        return false if accept_header.include?("application/json")

        user_agent = request.headers["User-Agent"].to_s
        user_agent.match?(/(Mozilla|Chrome|Safari|Firefox|Edge|Opera)/i)
      end

      def render_html_paywall(requirement_response)
        amount_field = requirement_response[:accepts].first[:maxAmountRequired] ||
                       requirement_response[:accepts].first[:amount]

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
              <h1>Payment Required</h1>
              <p>This resource requires payment to access.</p>
              <div class="amount">$#{format('%.3f', amount_field.to_i / 1_000_000.0)}</div>
              <div class="info">
                <p><strong>Network:</strong> #{requirement_response[:accepts].first[:network]}</p>
                <p><strong>Asset:</strong> USDC</p>
              </div>
              <p style="font-size: 0.85rem; color: #999;">
                This resource uses the x402 payment protocol.
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
