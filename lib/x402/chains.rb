# frozen_string_literal: true

module X402
  # Chain configurations for supported networks
  CHAINS = {
    "base-sepolia" => {
      chain_id: 84532,
      rpc_url: "https://clean-snowy-hexagon.base-sepolia.quiknode.pro",
      usdc_address: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      explorer_url: "https://sepolia.basescan.org"
    },
    "base" => {
      chain_id: 8453,
      rpc_url: "https://snowy-compatible-ensemble.base-mainnet.quiknode.pro",
      usdc_address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      explorer_url: "https://basescan.org"
    },
    "avalanche-fuji" => {
      chain_id: 43113,
      rpc_url: "https://muddy-sly-field.avalanche-testnet.quiknode.pro/ext/bc/C/rpc",
      usdc_address: "0x5425890298aed601595a70AB815c96711a31Bc65",
      explorer_url: "https://testnet.snowtrace.io"
    },
    "avalanche" => {
      chain_id: 43114,
      rpc_url: "https://floral-patient-panorama.avalanche-mainnet.quiknode.pro/ext/bc/C/rpc",
      usdc_address: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
      explorer_url: "https://snowtrace.io"
    },
    "solana-devnet" => {
      chain_id: 103,
      rpc_url: "https://bitter-twilight-vineyard.solana-devnet.quiknode.pro/",
      usdc_address: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
      explorer_url: "https://explorer.solana.com/?cluster=devnet",
      fee_payer: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5"
    },
    "solana" => {
      chain_id: 101,
      rpc_url: "https://alien-burned-energy.solana-mainnet.quiknode.pro/",
      usdc_address: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
      explorer_url: "https://explorer.solana.com",
      fee_payer: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5"
    }
  }.freeze

  # Currency configurations by chain
  CURRENCY_BY_CHAIN = {
    "base-sepolia" => {
      symbol: "USDC",
      decimals: 6,
      name: "USDC",  # Testnet uses "USDC"
      version: "2"
    },
    "base" => {
      symbol: "USDC",
      decimals: 6,
      name: "USD Coin",  # Mainnet uses "USD Coin"
      version: "2"
    },
    "avalanche-fuji" => {
      symbol: "USDC",
      decimals: 6,
      name: "USD Coin",  # Testnet uses "USD Coin"
      version: "2"
    },
    "avalanche" => {
      symbol: "USDC",
      decimals: 6,
      name: "USDC",  # Mainnet uses "USDC"
      version: "2"
    },
    "solana-devnet" => {
      symbol: "USDC",
      decimals: 6,
      name: "USDC",
      version: "2"
    },
    "solana" => {
      symbol: "USDC",
      decimals: 6,
      name: "USD Coin",
      version: "2"
    }
  }.freeze

  class << self
    def chain_config(chain_name)
      CHAINS[chain_name] || raise(ConfigurationError, "Unsupported chain: #{chain_name}")
    end

    def currency_config_for_chain(chain_name)
      CURRENCY_BY_CHAIN[chain_name] || raise(ConfigurationError, "Unsupported chain for currency: #{chain_name}")
    end

    def supported_chains
      CHAINS.keys
    end

    def usdc_address_for(chain_name)
      chain_config(chain_name)[:usdc_address]
    end

    def currency_decimals_for_chain(chain_name)
      currency_config_for_chain(chain_name)[:decimals]
    end

    def rpc_url_for(chain_name)
      # Priority: 1) Programmatic config, 2) ENV variable, 3) Default from CHAINS
      config = X402.configuration

      # Check programmatic configuration
      return config.rpc_urls[chain_name] if config.rpc_urls[chain_name]

      # Check environment variable
      # For Solana chains, use a single X402_SOLANA_RPC_URL env var
      if chain_name.start_with?("solana")
        env_rpc = ENV["X402_SOLANA_RPC_URL"]
        return env_rpc if env_rpc && !env_rpc.empty?
      else
        env_var_name = "X402_#{chain_name.upcase.gsub('-', '_')}_RPC_URL"
        env_rpc = ENV[env_var_name]
        return env_rpc if env_rpc && !env_rpc.empty?
      end

      # Fall back to default
      chain_config(chain_name)[:rpc_url]
    end

    def fee_payer_for(chain_name)
      # Priority: 1) Programmatic config, 2) ENV variable, 3) Default from CHAINS
      config = X402.configuration

      # Check programmatic configuration
      return config.solana_fee_payer if config.solana_fee_payer && !config.solana_fee_payer.empty?

      # Check environment variable
      env_fee_payer = ENV["X402_SOLANA_FEE_PAYER"]
      return env_fee_payer if env_fee_payer && !env_fee_payer.empty?

      # Fall back to default
      chain_config(chain_name)[:fee_payer]
    end
  end
end
