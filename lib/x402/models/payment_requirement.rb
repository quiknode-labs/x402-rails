# frozen_string_literal: true

module X402
  module Models
    class PaymentRequirement
      attr_accessor :scheme, :network, :max_amount_required, :asset, :pay_to, :resource, :description, :max_timeout_seconds, :mime_type, :output_schema, :extra

      def initialize(attributes = {})
        attrs = attributes.with_indifferent_access

        @scheme = attrs[:scheme] || "exact"
        @network = attrs[:network]
        @max_amount_required = attrs[:maxAmountRequired] || attrs[:max_amount_required]
        @asset = attrs[:asset]
        @pay_to = attrs[:payTo] || attrs[:pay_to]
        @resource = attrs[:resource]
        @description = attrs[:description]
        @max_timeout_seconds = attrs[:maxTimeoutSeconds] || attrs[:max_timeout_seconds] || 600
        @mime_type = attrs[:mimeType] || attrs[:mime_type] || "application/json"
        @output_schema = attrs[:outputSchema] || attrs[:output_schema]
        @extra = attrs[:extra]
      end

      def to_h
        h = {
          scheme: scheme,
          network: network,
          maxAmountRequired: max_amount_required.to_s,
          asset: asset,
          payTo: pay_to,
          resource: resource,
          description: description,
          maxTimeoutSeconds: max_timeout_seconds,
          mimeType: mime_type
        }
        h[:outputSchema] = output_schema if output_schema
        h[:extra] = extra if extra
        h
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end
  end
end
