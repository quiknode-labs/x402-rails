# frozen_string_literal: true

module X402
  class PaymentPayload
    attr_accessor :x402_version, :scheme, :network, :payload, :accepted, :resource_info

    def initialize(attributes = {})
      attrs = attributes.with_indifferent_access

      @x402_version = attrs[:x402Version] || attrs[:x402_version] || 1
      @accepted = attrs[:accepted]
      @resource_info = attrs[:resource]

      if @accepted
        @scheme = @accepted.with_indifferent_access[:scheme]
        @network = normalize_network(@accepted.with_indifferent_access[:network])
      else
        @scheme = attrs[:scheme]
        @network = normalize_network(attrs[:network])
      end

      @payload = attrs[:payload]
    end

    def self.from_header(header_value)
      return nil if header_value.nil? || header_value.empty?

      begin
        decoded = Base64.strict_decode64(header_value)
        json = JSON.parse(decoded)
        new(json)
      rescue StandardError => e
        raise InvalidPaymentError, "Failed to decode payment payload: #{e.message}"
      end
    end

    def authorization
      @authorization ||= payload&.with_indifferent_access&.[](:authorization)
    end

    def signature
      payload&.with_indifferent_access&.[](:signature)
    end

    def from_address
      authorization&.with_indifferent_access&.[](:from)
    end

    def to_address
      authorization&.with_indifferent_access&.[](:to)
    end

    def value
      authorization&.with_indifferent_access&.[](:value)
    end

    def valid_after
      authorization&.with_indifferent_access&.[](:validAfter) || authorization&.with_indifferent_access&.[](:valid_after)
    end

    def valid_before
      authorization&.with_indifferent_access&.[](:validBefore) || authorization&.with_indifferent_access&.[](:valid_before)
    end

    def nonce
      authorization&.with_indifferent_access&.[](:nonce)
    end

    def to_h
      version_strategy = X402::Versions.for(x402_version)

      if x402_version >= 2
        base = {
          x402Version: x402_version,
          scheme: scheme,
          network: version_strategy.format_network(network),
          accepted: format_accepted_for_version(version_strategy),
          payload: payload,
          extensions: {}
        }
        base[:resource] = resource_info if resource_info
        base
      else
        {
          x402Version: x402_version,
          scheme: scheme,
          network: version_strategy.format_network(network),
          payload: payload
        }
      end
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    private

    def normalize_network(network_value)
      return network_value unless network_value

      if network_value.to_s.include?(":")
        X402.from_caip2(network_value)
      else
        network_value
      end
    rescue X402::ConfigurationError
      network_value
    end

    def format_accepted_for_version(version_strategy)
      return nil unless accepted

      acc = accepted.with_indifferent_access
      {
        scheme: acc[:scheme],
        network: version_strategy.format_network(network),
        amount: (acc[:amount] || acc[:maxAmountRequired]).to_s,
        asset: acc[:asset],
        payTo: acc[:payTo] || acc[:pay_to],
        maxTimeoutSeconds: acc[:maxTimeoutSeconds] || acc[:max_timeout_seconds],
        extra: acc[:extra]
      }.compact
    end
  end
end
