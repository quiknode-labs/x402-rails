# frozen_string_literal: true

module X402
  class RequirementGenerator
    def self.generate(amount:, resource:, description: nil, chain: nil, currency: nil)
      config = X402.configuration
      chain_name = chain || config.chain

      # Get chain and currency configuration for this specific chain
      chain_config = X402.chain_config(chain_name)
      currency_config = X402.currency_config_for_chain(chain_name)

      # Convert amount to atomic units
      atomic_amount = convert_to_atomic(amount, currency_config[:decimals])

      # Get asset address (USDC contract address for the chain)
      asset_address = X402.usdc_address_for(chain_name)

      # Build EIP-712 domain info (required for signature verification)
      # IMPORTANT: The name must match what the USDC contract returns for name()
      # Testnets use "USDC", mainnets use "USD Coin" or "USDC" depending on chain
      eip712_domain = {
        name: currency_config[:name],
        version: currency_config[:version]
      }

      # Create payment requirement
      requirement = Models::PaymentRequirement.new(
        scheme: "exact",
        network: chain_name,
        max_amount_required: atomic_amount,
        asset: asset_address,
        pay_to: config.wallet_address,
        resource: resource,
        description: description || "Payment required for #{resource}",
        max_timeout_seconds: 600,
        mime_type: "application/json",
        extra: eip712_domain
      )

      # Build full response
      {
        x402Version: 1,
        error: "Payment required to access this resource",
        accepts: [requirement.to_h]
      }
    end

    def self.convert_to_atomic(amount, decimals)
      # Convert USD amount to atomic units
      # For USDC with 6 decimals: $0.001 = 1000 atomic units
      (amount.to_f * (10**decimals)).to_i
    end
  end
end
