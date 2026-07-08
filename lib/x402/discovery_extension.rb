# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"

module X402
  # Builds the x402 Bazaar discovery extension for a route, matching the wire
  # shape of the official @x402/extensions `declareDiscoveryExtension` helper.
  #
  # Facilitators index a resource only when the paying client echoes this
  # extension back in its PaymentPayload and `info` validates against `schema`.
  # A mismatch is skipped silently, so example inputs must satisfy the declared
  # input schema.
  #
  #   X402::DiscoveryExtension.declare(
  #     body_type: "json",
  #     input: { "city" => "San Francisco" },
  #     input_schema: {
  #       "type" => "object",
  #       "properties" => { "city" => { "type" => "string" } },
  #       "required" => ["city"],
  #     },
  #     output: { example: { "weather" => "foggy" } },
  #   )
  #
  # `body_type` selects the body form (POST/PUT/PATCH); without it the query
  # form (GET/HEAD/DELETE) is used and `input` describes query params. The
  # actual request method is stamped at render time via `with_method`.
  class DiscoveryExtension
    JSON_SCHEMA_DIALECT = "https://json-schema.org/draft/2020-12/schema"
    QUERY_METHODS = %w[GET HEAD DELETE].freeze
    BODY_METHODS = %w[POST PUT PATCH].freeze
    BODY_TYPES = %w[json form-data text].freeze

    class << self
      def declare(method: nil, body_type: nil, input: {}, input_schema: { "properties" => {} },
                  output: nil)
        info, schema =
          if body_type
            body_form(method: method, body_type: body_type, input: input, input_schema: input_schema)
          else
            query_form(method: method, input: input, input_schema: input_schema)
          end

        attach_output(info, schema, output)
        { "bazaar" => { "info" => info, "schema" => schema } }
      end

      # Stamps the actual HTTP method into the declaration at request time,
      # overwriting any declared method — mirroring the reference server
      # extension's enrichment, which always reports the live request verb.
      def with_method(extension, http_method)
        input = extension.dig("bazaar", "info", "input")
        return extension if input.nil?

        extension.deep_dup.tap do |enriched|
          enriched["bazaar"]["info"]["input"]["method"] = http_method
          method_schema = enriched.dig("bazaar", "schema", "properties", "input", "properties")
          method_schema["method"] = { "type" => "string", "enum" => [http_method] } if method_schema
        end
      end

      private

      def query_form(method:, input:, input_schema:)
        info_input = { "type" => "http" }
        info_input["method"] = method if method
        info_input["queryParams"] = input if input

        properties = {
          "type" => { "type" => "string", "const" => "http" },
          "method" => { "type" => "string", "enum" => QUERY_METHODS },
        }
        properties["queryParams"] = { "type" => "object" }.merge(input_schema) if input_schema

        [{ "input" => info_input }, schema_for(properties, required: %w[type method])]
      end

      def body_form(method:, body_type:, input:, input_schema:)
        info_input = { "type" => "http" }
        info_input["method"] = method if method
        info_input["bodyType"] = body_type
        info_input["body"] = input || {}

        properties = {
          "type" => { "type" => "string", "const" => "http" },
          "method" => { "type" => "string", "enum" => BODY_METHODS },
          "bodyType" => { "type" => "string", "enum" => BODY_TYPES },
          "body" => input_schema,
        }

        [{ "input" => info_input }, schema_for(properties, required: %w[type method bodyType body])]
      end

      def schema_for(input_properties, required:)
        {
          "$schema" => JSON_SCHEMA_DIALECT,
          "type" => "object",
          "properties" => {
            "input" => {
              "type" => "object",
              "properties" => input_properties,
              "required" => required,
              "additionalProperties" => false,
            },
          },
          "required" => ["input"],
        }
      end

      def attach_output(info, schema, output)
        example = output && (output[:example] || output["example"])
        return unless example

        output_schema = output[:schema] || output["schema"]
        info["output"] = { "type" => "json", "example" => example }
        schema["properties"]["output"] = {
          "type" => "object",
          "properties" => {
            "type" => { "type" => "string" },
            "example" => { "type" => "object" }.merge(output_schema.is_a?(Hash) ? output_schema : {}),
          },
          "required" => ["type"],
        }
      end
    end
  end
end
