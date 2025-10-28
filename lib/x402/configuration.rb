# frozen_string_literal: true

module X402
  class Configuration
    attr_accessor :wallet_address, :facilitator, :chain, :currency, :optimistic

    def initialize
      @wallet_address = ENV.fetch("X402_WALLET_ADDRESS", nil)
      @facilitator = ENV.fetch("X402_FACILITATOR_URL", "https://x402.org/facilitator")
      @chain = ENV.fetch("X402_CHAIN", "base-sepolia")
      @currency = ENV.fetch("X402_CURRENCY", "USDC")
      @optimistic = ENV.fetch("X402_OPTIMISTIC", "true") == "true"  # Default to optimistic mode (fast response, settle after)
    end

    def validate!
      raise ConfigurationError, "wallet_address is required" if wallet_address.nil? || wallet_address.empty?
      raise ConfigurationError, "facilitator URL is required" if facilitator.nil? || facilitator.empty?
      raise ConfigurationError, "chain is required" if chain.nil? || chain.empty?
      raise ConfigurationError, "currency is required" if currency.nil? || currency.empty?
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end

  class ConfigurationError < StandardError; end
end
