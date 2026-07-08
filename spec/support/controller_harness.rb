# frozen_string_literal: true

# Minimal controller stand-in: provides the request/response/render surface
# ControllerExtensions touches, without booting a Rails app.
RSpec.shared_context "with a controller harness" do
  let(:harness_class) do
    request_struct = Struct.new(:headers, :original_url, :path, :method, :env, keyword_init: true)
    response_struct = Struct.new(:headers, :status, keyword_init: true)

    Class.new do
      def self.after_action(*); end

      include X402::Rails::ControllerExtensions

      attr_reader :request, :response, :rendered_json, :rendered_status, :action_name

      define_method(:initialize) do |action_name: "create", http_method: "POST"|
        @action_name = action_name
        @request = request_struct.new(
          headers: {},
          original_url: "https://api.example.com/api/v1/things",
          path: "/api/v1/things",
          method: http_method,
          env: {},
        )
        @response = response_struct.new(headers: {}, status: 200)
      end

      def render(json:, status:)
        @rendered_json = json
        @rendered_status = status
      end
    end
  end

  after do
    X402.reset_configuration!
  end
end
