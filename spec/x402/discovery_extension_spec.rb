# frozen_string_literal: true

RSpec.describe X402::DiscoveryExtension do
  describe ".declare" do
    context "body form (body_type given)" do
      subject(:extension) do
        described_class.declare(
          method: "POST",
          body_type: "json",
          input: { "city" => "San Francisco" },
          input_schema: {
            "type" => "object",
            "properties" => { "city" => { "type" => "string" } },
            "required" => ["city"],
          },
          output: { example: { "weather" => "foggy" }, schema: { "properties" => { "weather" => { "type" => "string" } } } },
        )
      end

      it "wraps the extension under the bazaar key" do
        expect(extension.keys).to eq(["bazaar"])
        expect(extension["bazaar"].keys).to match_array(%w[info schema])
      end

      it "builds info.input in the body shape" do
        input = extension.dig("bazaar", "info", "input")
        expect(input).to eq(
          "type" => "http",
          "method" => "POST",
          "bodyType" => "json",
          "body" => { "city" => "San Francisco" },
        )
      end

      it "embeds the caller's input schema verbatim as the body schema" do
        body_schema = extension.dig("bazaar", "schema", "properties", "input", "properties", "body")
        expect(body_schema["required"]).to eq(["city"])
      end

      it "requires the body-form fields and rejects extras" do
        input_schema = extension.dig("bazaar", "schema", "properties", "input")
        expect(input_schema["required"]).to eq(%w[type method bodyType body])
        expect(input_schema["additionalProperties"]).to be(false)
      end

      it "declares the json output with the example and merged schema" do
        expect(extension.dig("bazaar", "info", "output")).to eq(
          "type" => "json", "example" => { "weather" => "foggy" },
        )
        example_schema = extension.dig("bazaar", "schema", "properties", "output", "properties", "example")
        expect(example_schema["type"]).to eq("object")
        expect(example_schema.dig("properties", "weather", "type")).to eq("string")
      end

      it "uses the 2020-12 JSON Schema dialect" do
        expect(extension.dig("bazaar", "schema", "$schema")).to eq(described_class::JSON_SCHEMA_DIALECT)
      end
    end

    context "query form (no body_type)" do
      subject(:extension) do
        described_class.declare(
          method: "GET",
          input: { "city" => "sf" },
          input_schema: { "properties" => { "city" => { "type" => "string" } } },
        )
      end

      it "builds info.input with queryParams" do
        expect(extension.dig("bazaar", "info", "input")).to eq(
          "type" => "http", "method" => "GET", "queryParams" => { "city" => "sf" },
        )
      end

      it "merges the input schema into queryParams with object type" do
        query_schema = extension.dig(
          "bazaar", "schema", "properties", "input", "properties", "queryParams",
        )
        expect(query_schema["type"]).to eq("object")
        expect(query_schema.dig("properties", "city", "type")).to eq("string")
      end

      it "omits output when no example is given" do
        expect(extension.dig("bazaar", "info")).not_to have_key("output")
        expect(extension.dig("bazaar", "schema", "properties")).not_to have_key("output")
      end
    end

  end

  describe ".with_method" do
    it "stamps the method into info and schema when absent" do
      extension = described_class.declare(body_type: "json", input: { "a" => 1 })
      enriched = described_class.with_method(extension, "POST")

      expect(enriched.dig("bazaar", "info", "input", "method")).to eq("POST")
      expect(enriched.dig("bazaar", "schema", "properties", "input", "properties", "method"))
        .to eq("type" => "string", "enum" => ["POST"])
    end

    it "overwrites a declared method with the actual request method" do
      extension = described_class.declare(method: "PUT", body_type: "json")
      enriched = described_class.with_method(extension, "POST")

      expect(enriched.dig("bazaar", "info", "input", "method")).to eq("POST")
    end

    it "does not mutate the original declaration" do
      extension = described_class.declare(body_type: "json")
      described_class.with_method(extension, "POST")
      expect(extension.dig("bazaar", "info", "input")).not_to have_key("method")
    end
  end
end
