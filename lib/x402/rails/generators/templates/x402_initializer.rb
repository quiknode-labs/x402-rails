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
  # EVM Options: "base-sepolia" (testnet), "base" (mainnet), "avalanche-fuji" (testnet), "avalanche" (mainnet)
  # Solana Options: "solana-devnet" (testnet), "solana" (mainnet)
  # For testing, use "base-sepolia" or "solana-devnet". For production, use "base" or "solana"
  config.chain = ENV.fetch("X402_CHAIN", "base-sepolia")

  # Currency symbol (currently only USDC is supported)
  config.currency = ENV.fetch("X402_CURRENCY", "USDC")

  # Solana Fee Payer (optional, only needed for Solana networks)
  # The fee payer covers transaction fees for Solana payments
  # If not set, uses default fee payer for the network
  # config.solana_fee_payer = ENV.fetch("X402_SOLANA_FEE_PAYER", nil)

  # Custom RPC URLs (optional)
  # Use custom RPC endpoints from providers like QuickNode, Alchemy, or Infura
  # for better reliability and rate limits. Uncomment and configure as needed:
  #
  # EVM chains:
  # config.rpc_urls["base"] = "https://your-base-rpc.quiknode.pro/your-key"
  # config.rpc_urls["base-sepolia"] = "https://your-sepolia-rpc.quiknode.pro/your-key"
  # config.rpc_urls["avalanche"] = "https://your-avalanche-rpc.quiknode.pro/your-key"
  #
  # Solana chains (use the same RPC URL for both devnet and mainnet, network determined by config.chain):
  # config.rpc_urls["solana"] = "https://your-solana-rpc.quiknode.pro/your-key"
  # config.rpc_urls["solana-devnet"] = "https://your-solana-rpc.quiknode.pro/your-key"
  #
  # Or use environment variables:
  # EVM: X402_BASE_RPC_URL, X402_BASE_SEPOLIA_RPC_URL, etc.
  # Solana: X402_SOLANA_RPC_URL (works for both devnet and mainnet based on your chain config)
end

# Validate configuration on initialization
X402.configuration.validate!
