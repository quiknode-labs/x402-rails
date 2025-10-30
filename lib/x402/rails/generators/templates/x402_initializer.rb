# frozen_string_literal: true

# X402 Payment Protocol Configuration
# For more information, see: https://docs.cdp.coinbase.com/x402

X402.configure do |config|
  # Your wallet address (where payments will be received)
  # Set this via environment variable: X402_WALLET_ADDRESS
  config.wallet_address = ENV.fetch("X402_WALLET_ADDRESS", nil)

  # Facilitator URL (default: https://x402.org/facilitator)
  # The facilitator handles payment verification and settlement
  config.facilitator = ENV.fetch("X402_FACILITATOR_URL", "https://x402.org/facilitator")

  # Blockchain network to use
  # Options: "base-sepolia" (testnet), "base" (mainnet), "avalanche-fuji" (testnet), "avalanche" (mainnet)
  # For testing, use "base-sepolia". For production, use "base" (no fees!)
  config.chain = ENV.fetch("X402_CHAIN", "base-sepolia")

  # Currency symbol (currently only USDC is supported)
  config.currency = ENV.fetch("X402_CURRENCY", "USDC")

  # Custom RPC URLs (optional)
  # Use custom RPC endpoints from providers like QuickNode, Alchemy, or Infura
  # for better reliability and rate limits. Uncomment and configure as needed:
  #
  # config.rpc_urls["base"] = "https://your-base-rpc.quiknode.pro/your-key"
  # config.rpc_urls["base-sepolia"] = "https://your-sepolia-rpc.quiknode.pro/your-key"
  # config.rpc_urls["avalanche"] = "https://your-avalanche-rpc.quiknode.pro/your-key"
  #
  # Or use environment variables (see README.md for details):
  # X402_BASE_RPC_URL, X402_BASE_SEPOLIA_RPC_URL, etc.
end

# Validate configuration on initialization
X402.configuration.validate!
