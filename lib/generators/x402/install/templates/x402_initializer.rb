# frozen_string_literal: true

# X402 Payment Protocol Configuration
# For more information, see: https://docs.cdp.coinbase.com/x402

X402.configure do |config|
  # Your wallet address (where payments will be received)
  # Set this via environment variable: X402_WALLET_ADDRESS
  config.wallet_address = ENV.fetch("X402_WALLET_ADDRESS", nil)

  # Facilitator URL (default: https://www.x402.org/facilitator)
  # The facilitator handles payment verification and settlement
  config.facilitator = ENV.fetch("X402_FACILITATOR_URL", "https://www.x402.org/facilitator")

  # Blockchain network to use
  # Options: "base-sepolia" (testnet), "base" (mainnet), "avalanche-fuji" (testnet), "avalanche" (mainnet)
  # For testing, use "base-sepolia". For production, use "base" (no fees!)
  config.chain = ENV.fetch("X402_CHAIN", "base-sepolia")

  # Currency symbol (currently only USDC is supported)
  config.currency = ENV.fetch("X402_CURRENCY", "USDC")

  # Coinbase CDP facilitator (https://api.cdp.coinbase.com/platform/v2/x402)
  # requires API credentials. These are read automatically from CDP_API_KEY_ID /
  # CDP_API_KEY_SECRET, or set them explicitly:
  # config.cdp_api_key_id = ENV.fetch("CDP_API_KEY_ID", nil)
  # config.cdp_api_key_secret = ENV.fetch("CDP_API_KEY_SECRET", nil)
end

# To list paywalled routes in facilitator Bazaar catalogs, declare discovery
# metadata in the controller with `x402_discovery` — see the README.

# Validate configuration on initialization
X402.configuration.validate!
