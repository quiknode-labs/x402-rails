# frozen_string_literal: true

require "openssl"
require "securerandom"

module X402
  # Bearer JWT auth for the Coinbase CDP facilitator, mirroring
  # @coinbase/cdp-sdk generateJwt: per-request, URI-bound claims, signed with
  # ES256 (PEM EC key) or EdDSA (base64 Ed25519 seed+public key).
  #
  # Applied automatically by FacilitatorClient when the configured facilitator
  # host is api.cdp.coinbase.com. Credentials come from `config.cdp_api_key_id`
  # and `config.cdp_api_key_secret` (or the CDP_API_KEY_ID / CDP_API_KEY_SECRET
  # env vars CDP's own SDKs use). Other facilitators are untouched.
  class CdpFacilitatorAuth
    CDP_HOST = "api.cdp.coinbase.com"
    EXPIRY_SECONDS = 120

    class << self
      def headers_for(facilitator_url:, http_method:, endpoint:)
        uri = URI(facilitator_url)
        return {} unless uri.host == CDP_HOST

        config = X402.configuration
        key_id = config.cdp_api_key_id
        secret = config.cdp_api_key_secret
        if key_id.nil? || key_id.empty? || secret.nil? || secret.empty?
          X402.logger.error(
            "[x402] CDP facilitator requires cdp_api_key_id and cdp_api_key_secret " \
            "(or CDP_API_KEY_ID / CDP_API_KEY_SECRET); sending the request unauthenticated",
          )
          return {}
        end

        jwt = bearer_jwt(
          key_id: key_id,
          secret: secret,
          http_method: http_method,
          request_host: uri.host,
          request_path: "#{uri.path}/#{endpoint}",
        )
        jwt ? { "Authorization" => "Bearer #{jwt}" } : {}
      end

      private

      def bearer_jwt(key_id:, secret:, http_method:, request_host:, request_path:)
        now = Time.now.to_i
        claims = {
          sub: key_id,
          iss: "cdp",
          uris: ["#{http_method} #{request_host}#{request_path}"],
          iat: now,
          nbf: now,
          exp: now + EXPIRY_SECONDS,
        }
        header = { kid: key_id, typ: "JWT", nonce: SecureRandom.hex(16) }

        if (key = ec_key(secret))
          signed_jwt(claims, header.merge(alg: "ES256")) { |input| ecdsa_raw_signature(key, input) }
        elsif (key = ed25519_key(secret))
          signed_jwt(claims, header.merge(alg: "EdDSA")) { |input| key.sign(nil, input) }
        else
          X402.logger.error("[x402] CDP_API_KEY_SECRET is neither a PEM EC key nor a base64 Ed25519 key")
          nil
        end
      end

      def signed_jwt(claims, header)
        signing_input = [encode_segment(header.to_json), encode_segment(claims.to_json)].join(".")
        [signing_input, encode_segment(yield(signing_input))].join(".")
      end

      def encode_segment(bytes)
        Base64.urlsafe_encode64(bytes, padding: false)
      end

      def ec_key(secret)
        pem = secret.gsub("\\n", "\n")
        return nil unless pem.include?("PRIVATE KEY")

        key = OpenSSL::PKey.read(pem)
        key.is_a?(OpenSSL::PKey::EC) ? key : nil
      rescue OpenSSL::PKey::PKeyError
        nil
      end

      # CDP Ed25519 secrets are base64(seed(32) || public_key(32)); OpenSSL only
      # imports the seed wrapped in PKCS#8 DER.
      def ed25519_key(secret)
        decoded = Base64.strict_decode64(secret)
        return nil unless decoded.bytesize == 64

        seed = decoded.byteslice(0, 32)
        der = OpenSSL::ASN1::Sequence([
          OpenSSL::ASN1::Integer(0),
          OpenSSL::ASN1::Sequence([OpenSSL::ASN1::ObjectId("ED25519")]),
          OpenSSL::ASN1::OctetString(OpenSSL::ASN1::OctetString(seed).to_der),
        ]).to_der
        OpenSSL::PKey.read(der)
      rescue ArgumentError, OpenSSL::PKey::PKeyError
        nil
      end

      # JWS ES256 signatures are raw r||s (32 bytes each); OpenSSL emits DER.
      def ecdsa_raw_signature(key, signing_input)
        der = key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
        r, s = OpenSSL::ASN1.decode(der).value.map(&:value)
        [r, s].map { |bn| bn.to_s(2).rjust(32, "\x00".b) }.join
      end
    end
  end
end
