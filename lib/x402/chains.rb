# frozen_string_literal: true

module X402
  # Chain configurations for supported networks
  CHAINS = {
    # --- Base ---
    "base" => {
      chain_id: 8453,
      usdc_address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      explorer_url: "https://basescan.org",
    },
    "base-sepolia" => {
      chain_id: 84532,
      usdc_address: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      explorer_url: "https://sepolia.basescan.org",
    },

    # --- Polygon ---
    "polygon" => {
      chain_id: 137,
      usdc_address: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
      explorer_url: "https://polygonscan.com",
    },
    "polygon-amoy" => {
      chain_id: 80002,
      usdc_address: "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582",
      explorer_url: "https://amoy.polygonscan.com",
    },

    # --- Avalanche ---
    "avalanche" => {
      chain_id: 43114,
      usdc_address: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
      explorer_url: "https://snowtrace.io",
    },
    "avalanche-fuji" => {
      chain_id: 43113,
      usdc_address: "0x5425890298aed601595a70AB815c96711a31Bc65",
      explorer_url: "https://testnet.snowtrace.io",
    },

    # --- Sei ---
    "sei" => {
      chain_id: 1329,
      usdc_address: "0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392",
      explorer_url: "https://seitrace.com",
    },
    "sei-testnet" => {
      chain_id: 713715,
      explorer_url: "https://seitrace.com/?chain=arctic-1",
    },

    # --- X Layer ---
    "xlayer" => {
      chain_id: 196,
      explorer_url: "https://www.oklink.com/xlayer",
    },
    "xlayer-testnet" => {
      chain_id: 1952,
      explorer_url: "https://www.oklink.com/xlayer-test",
    },

    # --- SKALE ---
    "skale-base" => {
      chain_id: 1_187_947_933,
      explorer_url: "https://elated-tan-skat.explorer.mainnet.skalenodes.com",
    },
    "skale-base-sepolia" => {
      chain_id: 324_705_682,
      explorer_url: "https://lanky-ill-funny-testnet.explorer.testnet.skalenodes.com",
    },

    # --- KiteAI ---
    "kiteai" => {
      chain_id: 2366,
      explorer_url: "https://kitescan.ai",
    },
    "kiteai-testnet" => {
      chain_id: 2368,
      explorer_url: "https://testnet.kitescan.ai",
    },

    # --- IoTeX (mainnet only) ---
    "iotex" => {
      chain_id: 4689,
      explorer_url: "https://iotexscan.io",
    },

    # --- Peaq (mainnet only) ---
    "peaq" => {
      chain_id: 3338,
      explorer_url: "https://peaq.subscan.io",
    },

    # --- Solana ---
    # Default fee_payer is for the Coinbase facilitator (x402.org).
    # If using PayAI facilitator, set X402_SOLANA_FEE_PAYER or X402_SOLANA_DEVNET_FEE_PAYER
    # to PayAI's fee payer: 2wKupLR9q6wXYppw8Gr2NvWxKBUqm4PPJKkQfoxHDBg4
    "solana" => {
      chain_id: 101,
      usdc_address: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
      explorer_url: "https://explorer.solana.com",
      fee_payer: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5",
    },
    "solana-devnet" => {
      chain_id: 103,
      usdc_address: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
      explorer_url: "https://explorer.solana.com/?cluster=devnet",
      fee_payer: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5",
    },
  }.freeze

  # Currency configurations by chain
  CURRENCY_BY_CHAIN = {
    "base" => { symbol: "USDC", decimals: 6, name: "USD Coin", version: "2" },
    "base-sepolia" => { symbol: "USDC", decimals: 6, name: "USDC", version: "2" },
    "polygon" => { symbol: "USDC", decimals: 6, name: "USD Coin", version: "2" },
    "polygon-amoy" => { symbol: "USDC", decimals: 6, name: "USDC", version: "2" },
    "avalanche" => { symbol: "USDC", decimals: 6, name: "USDC", version: "2" },
    "avalanche-fuji" => { symbol: "USDC", decimals: 6, name: "USD Coin", version: "2" },
    "sei" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "sei-testnet" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "xlayer" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "xlayer-testnet" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "skale-base" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "skale-base-sepolia" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "kiteai" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "kiteai-testnet" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "iotex" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "peaq" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
    "solana" => { symbol: "USDC", decimals: 6, name: "USD Coin", version: nil },
    "solana-devnet" => { symbol: "USDC", decimals: 6, name: "USDC", version: nil },
  }.freeze

  CAIP2_MAPPING = {
    # Base
    "base" => "eip155:8453",
    "base-sepolia" => "eip155:84532",
    # Polygon
    "polygon" => "eip155:137",
    "polygon-amoy" => "eip155:80002",
    # Avalanche
    "avalanche" => "eip155:43114",
    "avalanche-fuji" => "eip155:43113",
    # Sei
    "sei" => "eip155:1329",
    "sei-testnet" => "eip155:713715",
    # X Layer
    "xlayer" => "eip155:196",
    "xlayer-testnet" => "eip155:1952",
    # SKALE
    "skale-base" => "eip155:1187947933",
    "skale-base-sepolia" => "eip155:324705682",
    # KiteAI
    "kiteai" => "eip155:2366",
    "kiteai-testnet" => "eip155:2368",
    # IoTeX
    "iotex" => "eip155:4689",
    # Peaq
    "peaq" => "eip155:3338",
    # Solana
    "solana" => "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp",
    "solana-devnet" => "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
  }.freeze

  REVERSE_CAIP2_MAPPING = CAIP2_MAPPING.invert.freeze

  class << self
    def chain_config(chain_name)
      custom = X402.configuration.chain_config(chain_name)
      return custom if custom

      CHAINS[chain_name] || raise(ConfigurationError, "Unsupported chain: #{chain_name}. Register with config.register_chain()")
    end

    def currency_config_for_chain(chain_name)
      CURRENCY_BY_CHAIN[chain_name] || raise(ConfigurationError, "Unsupported chain for currency: #{chain_name}")
    end

    def supported_chains
      CHAINS.keys + X402.configuration.custom_chains.keys
    end

    def usdc_address_for(chain_name)
      builtin = CHAINS[chain_name]
      builtin ? builtin[:usdc_address] : nil
    end

    def asset_address_for(chain_name, symbol = nil)
      symbol ||= X402.configuration.currency

      custom = X402.configuration.token_config(chain_name, symbol)
      return custom[:address] if custom

      if symbol.upcase == "USDC"
        builtin = CHAINS[chain_name]
        return builtin[:usdc_address] if builtin && builtin[:usdc_address]
      end

      raise ConfigurationError, "Unknown token #{symbol} for chain #{chain_name}. Register with config.register_token()"
    end

    def token_config_for(chain_name, symbol = nil)
      symbol ||= X402.configuration.currency

      custom = X402.configuration.token_config(chain_name, symbol)
      return custom if custom

      if symbol.upcase == "USDC" && CURRENCY_BY_CHAIN[chain_name]
        currency_config_for_chain(chain_name)
      else
        raise ConfigurationError, "Unknown token #{symbol} for chain #{chain_name}. Register with config.register_token()"
      end
    end

    def currency_decimals_for_chain(chain_name)
      currency_config_for_chain(chain_name)[:decimals]
    end

    def fee_payer_for(chain_name)
      # Priority: 1) Programmatic config, 2) Per-chain ENV variable, 3) Generic ENV variable, 4) Default from CHAINS
      config = X402.configuration

      # Check programmatic configuration
      return config.fee_payer if config.fee_payer && !config.fee_payer.empty?

      # Check per-chain environment variable (e.g., X402_SOLANA_DEVNET_FEE_PAYER, X402_SOLANA_FEE_PAYER)
      env_var_name = "X402_#{chain_name.upcase.gsub('-', '_')}_FEE_PAYER"
      env_fee_payer = ENV[env_var_name]
      return env_fee_payer if env_fee_payer && !env_fee_payer.empty?

      # Check generic environment variable
      env_fee_payer = ENV["X402_FEE_PAYER"]
      return env_fee_payer if env_fee_payer && !env_fee_payer.empty?

      # Fall back to default from chain config
      chain_config(chain_name)[:fee_payer]
    end

    def to_caip2(network_name)
      custom = X402.configuration.chain_config(network_name)
      if custom
        return "#{custom[:standard]}:#{custom[:chain_id]}"
      end

      CAIP2_MAPPING[network_name] || raise(ConfigurationError, "No CAIP-2 mapping for: #{network_name}")
    end

    def from_caip2(caip2_string)
      return REVERSE_CAIP2_MAPPING[caip2_string] if REVERSE_CAIP2_MAPPING[caip2_string]

      X402.configuration.custom_chains.each do |name, config|
        caip2 = "#{config[:standard]}:#{config[:chain_id]}"
        return name if caip2 == caip2_string
      end

      raise(ConfigurationError, "Unknown CAIP-2 network: #{caip2_string}")
    end

    SOLANA_CHAINS = %w[solana solana-devnet].freeze

    def solana_chain?(chain_name)
      SOLANA_CHAINS.include?(chain_name)
    end
  end
end
