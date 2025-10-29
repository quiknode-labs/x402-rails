# frozen_string_literal: true

module X402
  class PaymentPayload
    attr_accessor :x402_version, :scheme, :network, :payload

    def initialize(attributes = {})
      attrs = attributes.with_indifferent_access

      @x402_version = attrs[:x402Version] || attrs[:x402_version] || 1
      @scheme = attrs[:scheme]
      @network = attrs[:network]
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
      {
        x402Version: x402_version,
        scheme: scheme,
        network: network,
        payload: payload
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
