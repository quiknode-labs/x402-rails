# frozen_string_literal: true

module X402
  module Rails
    module ControllerExtensions
      extend ActiveSupport::Concern

      included do
        after_action :settle_x402_payment_if_needed
        class_attribute :x402_discovery_declarations, instance_writer: false, default: {}
      end

      class_methods do
        # Declares Bazaar discovery metadata for paywalled actions so 402
        # responses advertise the route to facilitator discovery catalogs.
        #
        #   x402_discovery only: :create,
        #                  body_type: "json",
        #                  input: { "city" => "SF" },
        #                  input_schema: { "properties" => { "city" => { "type" => "string" } } },
        #                  output: { example: { "weather" => "foggy" } }
        #
        # Accepts either DiscoveryExtension.declare kwargs (as above) or a
        # prebuilt hash via `extensions:`, plus `description:` for the 402's
        # resource.description — the text facilitator catalogs display for the
        # route. A description alone names the route without making it
        # discoverable. Without `only:`, applies to every paywalled action in
        # the controller. `method` is stamped from the actual request at render
        # time.
        def x402_discovery(only: nil, **config)
          actions = only.nil? ? [:__all__] : Array(only).map(&:to_sym)
          self.x402_discovery_declarations = x402_discovery_declarations.merge(
            actions.to_h { |action| [action, config] }
          )
        end
      end

      def x402_paywall(options = {})
        amount = options[:amount] or raise ArgumentError, "amount is required"
        chain = options[:chain]
        currency = options[:currency]
        protocol_version = options[:version] || X402.configuration.version
        wallet_address = options[:wallet_address]
        fee_payer = options[:fee_payer]
        accepts = options[:accepts]
        @x402_paywall_extensions = options[:extensions]

        begin
          version_strategy = X402::Versions.for(protocol_version)
        rescue X402::ConfigurationError => e
          return render_configuration_error(e.message)
        end

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

      # The raw payment header, or nil when absent (or when the version is
      # invalid). Pass version: on endpoints that override it via
      # x402_paywall(version:).
      def x402_payment_header(version: nil)
        version_strategy = X402::Versions.for(version || X402.configuration.version)
        request.headers[version_strategy.payment_header_name].presence
      rescue X402::ConfigurationError
        nil
      end

      def x402_payment_attempted?(version: nil)
        x402_payment_header(version: version).present?
      end

      private

      def generate_payment_required_response(amount, error_message = nil,
                                              chain: nil, currency: nil, version: nil,
                                              wallet_address: nil, fee_payer: nil, accepts: nil)
        protocol_version = version || X402.configuration.version

        requirement_response = X402::RequirementGenerator.generate(
          amount: amount,
          resource: request.original_url,
          description: x402_declared_description || "Payment required for #{request.path}",
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
        # The version strategy's output declares whether this protocol version
        # carries extensions (v2 emits the key, v1 does not).
        discovery = x402_resolved_discovery_extensions
        if discovery.present? && requirement_response.key?(:extensions)
          requirement_response[:extensions] = discovery
        end

        if version_strategy.requirement_header_name
          response.headers[version_strategy.requirement_header_name] =
            Base64.strict_encode64(requirement_response.to_json)
        end
        # payment challenges are per-request and must not be cached
        response.headers["Cache-Control"] = "no-store"
        render json: requirement_response, status: :payment_required
      end

      # Explicit x402_paywall(extensions:) wins over the class-level
      # x402_discovery declaration for the current action. Either way the
      # actual request method is stamped in, mirroring the reference server
      # extension's request-time enrichment.
      def x402_resolved_discovery_extensions
        extension = @x402_paywall_extensions.presence || x402_declared_extension
        return nil if extension.nil?

        X402::DiscoveryExtension.with_method(extension, request.method)
      end

      # A description-only declaration just names the route; the extension is
      # built only when I/O metadata (or a prebuilt hash) is declared.
      def x402_declared_extension
        config = x402_discovery_config
        return nil if config.blank?
        return config[:extensions] if config[:extensions]

        declare_kwargs = config.except(:description)
        declare_kwargs.presence && X402::DiscoveryExtension.declare(**declare_kwargs)
      end

      # The catalog display text declared via x402_discovery(description:) —
      # facilitators surface it from the 402's resource.description.
      def x402_declared_description
        x402_discovery_config&.dig(:description)
      end

      def x402_discovery_config
        x402_discovery_declarations[action_name&.to_sym] || x402_discovery_declarations[:__all__]
      end

      def render_configuration_error(message)
        # Use V1 as a safe fallback when version is invalid to avoid recursive errors
        fallback_strategy = X402::Versions::V1.new
        error_response = {
          x402Version: 1,
          error: "Configuration error: #{message}",
          accepts: []
        }
        render_402_response(error_response, fallback_strategy)
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
        additional_attrs = { version: protocol_version }
        additional_attrs[:resource] = resource_info[:url] if resource_info[:url]
        additional_attrs[:description] = resource_info[:description] if resource_info[:description]
        additional_attrs[:mime_type] = resource_info[:mimeType] if resource_info[:mimeType]
        requirement_attrs = matching_accept.merge(additional_attrs)
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
      rescue X402::ConfigurationError => e
        render_configuration_error(e.message)
      end

      def find_matching_accept(accepts, payment_payload, version_strategy)
        payment_network = payment_payload.network

        accepts.find do |accept|
          accept_network = accept[:network]
          next false unless accept_network.present?

          if accept_network.to_s.include?(":")
            version_strategy.parse_network(accept_network) == payment_network
          else
            accept_network == payment_network
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

        settlement_result = perform_settlement(payment_info)

        request.env["x402.settlement_result"] = settlement_result
        settlement_result
      end

      def perform_settlement(payment_info)
        begin
          X402.logger.debug do
            "[x402] settling payment optimistic=#{X402.configuration.optimistic} " \
              "payload=#{payment_info[:payload].inspect} " \
              "requirement=#{payment_info[:requirement].to_h.inspect}"
          end

          protocol_version = payment_info[:version] || X402.configuration.version
          version_strategy = X402::Versions.for(protocol_version)

          facilitator_client = X402::FacilitatorClient.new
          settlement_result = facilitator_client.settle(
            payment_info[:payload],
            payment_info[:requirement].to_h(version: protocol_version)
          )

          if settlement_result.success?
            response.headers[version_strategy.response_header_name] = settlement_result.to_base64
            X402.logger.info("x402 settlement successful: #{settlement_result.transaction}")
          else
            X402.logger.error("x402 settlement failed: #{settlement_result.error_reason}")
          end

          settlement_result
        rescue X402::FacilitatorError, X402::InvalidPaymentError => e
          X402.logger.error("x402 settlement error: #{e.message}")
          nil
        end
      end

    end
  end
end
