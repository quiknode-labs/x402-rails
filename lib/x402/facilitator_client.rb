# frozen_string_literal: true

require "faraday"
require "json"

module X402
  class FacilitatorClient
    attr_reader :facilitator_url

    def initialize(facilitator_url = nil)
      @facilitator_url = facilitator_url || X402.configuration.facilitator
    end

    def verify(payment_payload, payment_requirements)
      response = post_payment("verify", payment_payload, payment_requirements)
      handle_response(response, "verify")
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to verify payment: #{e.message}"
    end

    def settle(payment_payload, payment_requirements)
      response = post_payment("settle", payment_payload, payment_requirements)
      SettlementResponse.new(handle_response(response, "settle"))
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to settle payment: #{e.message}"
    end

    def supported_networks
      get_json("supported", action: "supported")
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to fetch supported networks: #{e.message}"
    end

    # Lists the facilitator's Bazaar discovery catalog (PayAI, CDP, and any
    # other facilitator implementing the x402 discovery spec expose this).
    # Params pass through as query string, e.g. type: "http", limit: 50.
    def discovery_resources(params = {})
      get_json("discovery/resources", action: "discovery", params: params)
    rescue Faraday::Error => e
      raise FacilitatorError, "Failed to fetch discovery resources: #{e.message}"
    end

    private

    def post_payment(endpoint, payment_payload, payment_requirements)
      request_body = {
        x402Version: payment_payload.x402_version,
        paymentPayload: payment_payload.to_h,
        paymentRequirements: payment_requirements
      }

      X402.logger.debug { "[x402] POST #{facilitator_url}/#{endpoint} #{request_body.to_json}" }

      response = connection.post(endpoint) do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers.update(auth_headers("POST", endpoint))
        req.body = request_body.to_json
      end

      X402.logger.debug { "[x402] #{endpoint} response #{response.status}: #{response.body}" }
      response
    end

    def get_json(endpoint, action:, params: {})
      response = connection.get(endpoint) do |req|
        req.params.update(params)
        req.headers.update(auth_headers("GET", endpoint))
      end
      handle_response(response, action)
    end

    def connection
      @connection ||= Faraday.new(url: facilitator_url) do |faraday|
        faraday.adapter Faraday.default_adapter
      end
    end

    # CDP requires a Bearer JWT on every request; all other facilitators get no auth.
    def auth_headers(http_method, endpoint)
      CdpFacilitatorAuth.headers_for(
        facilitator_url: facilitator_url,
        http_method: http_method,
        endpoint: endpoint,
      )
    end

    def handle_response(response, action)
      case response.status
      when 200..299
        JSON.parse(response.body)
      when 400
        error_body = JSON.parse(response.body) rescue {}
        raise InvalidPaymentError, "Invalid payment: #{error_body['error'] || response.body}"
      when 500..599
        raise FacilitatorError, "Facilitator error (#{action}): #{response.status}"
      else
        raise FacilitatorError, "Unexpected response (#{action}): #{response.status}"
      end
    rescue JSON::ParserError => e
      raise FacilitatorError, "Failed to parse facilitator response: #{e.message}"
    end
  end

  class FacilitatorError < StandardError; end
  class InvalidPaymentError < StandardError; end
end
