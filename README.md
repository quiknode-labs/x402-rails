# x402-rails

![Coverage](./coverage/coverage.svg)

Accept instant blockchain micropayments in your Rails applications using the [x402 payment protocol](https://www.x402.org/).

Supports Base, avalanche, and other blockchain networks.

## Features

- **1 line of code** to accept digital dollars (USDC)
- **No fees** on supported networks (Base)
- **~1 second** response times (optimistic mode)
- **$0.001 minimum** payment amounts
- **Optimistic & non-optimistic** settlement modes
- **Automatic settlement** after successful responses
- **Browser paywall** and API support
- **Rails 7.0+** compatible

## Example Video

https://github.com/user-attachments/assets/05983bb3-7422-4c06-97ab-2fb53d6428cc

## Installation

Add to your Gemfile:

```ruby
gem 'x402-rails'
```

Then run:

```bash
bundle install
```

## Quick Start

### 1. Configure the gem

Create `config/initializers/x402.rb`:

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']  # Your recipient wallet
  config.facilitator = "https://x402.org/facilitator"
  config.chain = "base-sepolia"  # or "base" for base mainnet
  config.currency = "USDC"
  config.optimistic = false  # Forces to check for settlement before giving response.
end
```

### 2. Protect your endpoints

Use `x402_paywall` in any controller action:

```ruby
class ApiController < ApplicationController
  def weather
    x402_paywall(amount: 0.001)  # $0.001 in USD
    return if performed?

    render json: {
      temperature: 72,
      paid_by: request.env['x402.payment'][:payer]
    }
  end
end
```

That's it! Your endpoint now requires payment.

## Usage Patterns

### Direct Method Call

Call `x402_paywall` in any action:

```ruby
def show
  x402_paywall(amount: 0.01)
  return if performed?
  # Action continues after payment verified
  render json: @data
end
```

### Before Action Hook

Protect multiple actions:

```ruby
class PremiumController < ApplicationController
  before_action :require_payment, only: [:show, :index]

  def show
    # Payment already verified
    render json: @premium_content
  end

  private

  def require_payment
    x402_paywall(amount: 0.001, chain: "base")
    return if performed?
  end
end
```

### Per-Action Pricing

Different prices for different actions:

```ruby
def basic_data
  x402_paywall(amount: 0.001)
  return if performed?
  render json: basic_info
end

def premium_data
  x402_paywall(amount: 0.01)
  return if performed?
  render json: premium_info
end
```

## Configuration Options

### Global Configuration

Set defaults in `config/initializers/x402.rb`:

```ruby
X402.configure do |config|
  # Required: Your wallet address where payments will be received
  config.wallet_address = ENV['X402_WALLET_ADDRESS']

  # Facilitator service URL (default: "https://x402.org/facilitator")
  config.facilitator = ENV.fetch("X402_FACILITATOR_URL", "https://x402.org/facilitator")

  # Blockchain network (default: "base-sepolia")
  # Options: "base-sepolia", "base", "avalanche-fuji", "avalanche"
  config.chain = ENV.fetch("X402_CHAIN", "base-sepolia")

  # Payment token (default: "USDC")
  # Currently only USDC is supported
  config.currency = ENV.fetch("X402_CURRENCY","USDC")

  # Optimistic mode (default: true)
  # true: Fast response, settle payment after response is sent
  # false: Wait for blockchain settlement before sending response
  config.optimistic = ENV.fetch("X402_OPTIMISTIC",false)
end
```

### Configuration Attributes

| Attribute        | Required | Default                          | Description                                                                       |
| ---------------- | -------- | -------------------------------- | --------------------------------------------------------------------------------- |
| `wallet_address` | **Yes**  | -                                | Your Ethereum wallet address where payments will be received                      |
| `facilitator`    | No       | `"https://x402.org/facilitator"` | Facilitator service URL for payment verification and settlement                   |
| `chain`          | No       | `"base-sepolia"`                 | Blockchain network to use (`base-sepolia`, `base`, `avalanche-fuji`, `avalanche`) |
| `currency`       | No       | `"USDC"`                         | Payment token symbol (currently only USDC supported)                              |
| `optimistic`     | No       | `true`                           | Settlement mode (see Optimistic vs Non-Optimistic Mode below)                     |
| `rpc_urls`       | No       | `{}`                             | Custom RPC endpoint URLs per chain (see Custom RPC URLs below)                    |

### Custom RPC URLs

By default, x402-rails uses public QuickNode RPC endpoints for each supported chain. For production use or higher reliability, you can configure custom RPC URLs from providers like [QuickNode](https://www.quicknode.com/).

**Configuration Priority** (highest to lowest):

1. Programmatic configuration via `config.rpc_urls`
2. Per-chain environment variables
3. Built-in default RPC URLs

#### Method 1: Programmatic Configuration

Configure RPC URLs in your initializer:

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']

  # Custom RPC URLs per chain
  config.rpc_urls["base"] = "https://your-base-rpc.quiknode.pro/your-key"
  config.rpc_urls["base-sepolia"] = "https://your-sepolia-rpc.quiknode.pro/your-key"
  config.rpc_urls["avalanche"] = "https://your-avalanche-rpc.quiknode.pro/your-key"
end
```

#### Method 2: Environment Variables

Set per-chain environment variables:

```bash
# Per-chain RPC URL overrides
X402_BASE_RPC_URL=https://your-base-rpc.quiknode.pro/your-key
X402_BASE_SEPOLIA_RPC_URL=https://your-sepolia-rpc.quiknode.pro/your-key
X402_AVALANCHE_RPC_URL=https://your-avalanche-rpc.quiknode.pro/your-key
X402_AVALANCHE_FUJI_RPC_URL=https://your-fuji-rpc.quiknode.pro/your-key
```

#### Method 3: Default RPC URLs

If no custom RPC URL is configured, it will default to the public QuickNode RPC urls.

### Custom Chains and Tokens

You can register custom EVM chains and tokens beyond the built-in options.

#### Register a Custom Chain

Add support for any EVM-compatible chain:

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']

  # Register Polygon mainnet
  config.register_chain(
    name: "polygon",
    chain_id: 137,
    standard: "eip155"
  )

  # Register the token for that chain
  config.register_token(
    chain: "polygon",
    symbol: "USDC",
    address: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
    decimals: 6,
    name: "USD Coin",
    version: "2"
  )

  config.chain = "polygon"
  config.currency = "USDC"
end
```

#### Register a Custom Token on a Built-in Chain

Accept different tokens on existing chains:

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']

  # Accept WETH on Base instead of USDC
  config.register_token(
    chain: "base",
    symbol: "WETH",
    address: "0x4200000000000000000000000000000000000006",
    decimals: 18,
    name: "Wrapped Ether",
    version: "1"
  )

  config.chain = "base"
  config.currency = "WETH"
end
```

#### Token Registration Parameters

| Parameter  | Required | Description                                     |
| ---------- | -------- | ----------------------------------------------- |
| `chain`    | Yes      | Chain name (built-in or custom registered)      |
| `symbol`   | Yes      | Token symbol (e.g., "USDC", "WETH")             |
| `address`  | Yes      | Token contract address                          |
| `decimals` | Yes      | Token decimals (e.g., 6 for USDC, 18 for WETH)  |
| `name`     | Yes      | Token name for EIP-712 domain                   |
| `version`  | No       | EIP-712 version (default: "1")                  |

**Note:** Custom chains and tokens are only supported for EVM (eip155) networks. Solana chains use a different implementation.

### Accept Multiple Payment Options

Allow clients to pay on any of several supported chains by using `config.accept()`:

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']

  # Register a custom chain
  config.register_chain(name: "polygon-amoy", chain_id: 80002, standard: "eip155")
  config.register_token(
    chain: "polygon-amoy",
    symbol: "USDC",
    address: "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582",
    decimals: 6,
    name: "USD Coin",
    version: "2"
  )

  # Accept payments on multiple chains
  config.accept(chain: "base-sepolia", currency: "USDC")
  config.accept(chain: "polygon-amoy", currency: "USDC")
end
```

When `config.accept()` is used, the 402 response will include all accepted payment options:

```json
{
  "accepts": [
    { "network": "eip155:84532", "asset": "0x036CbD53842c5426634e7929541eC2318f3dCF7e", ... },
    { "network": "eip155:80002", "asset": "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582", ... }
  ]
}
```

Clients can then choose which chain to pay on based on their preferences or available funds.

**Per-accept wallet addresses:** You can specify different recipient addresses per chain:

```ruby
config.accept(chain: "base-sepolia", currency: "USDC", wallet_address: "0xWallet1")
config.accept(chain: "polygon-amoy", currency: "USDC", wallet_address: "0xWallet2")
```

**Fallback behavior:** If no `config.accept()` calls are made, the default `config.chain` and `config.currency` are used.

## Environment Variables

Configure via environment variables:

```bash
# Required
X402_WALLET_ADDRESS=0xYourAddress

# Optional (with defaults)
X402_FACILITATOR_URL=https://x402.org/facilitator
X402_CHAIN=base-sepolia
X402_CURRENCY=USDC
X402_OPTIMISTIC=true  # "true" or "false"

# Custom RPC URLs (optional, per-chain overrides)
X402_BASE_RPC_URL=https://your-base-rpc.quiknode.pro/your-key
X402_BASE_SEPOLIA_RPC_URL=https://your-base-speoliarpc.quiknode.pro/your-key
X402_AVALANCHE_RPC_URL=https://your-avalanche.quiknode.pro/your-key
X402_AVALANCHE_FUJI_RPC_URL=https://your-fuji-rpc.quiknode.pro/your-key
```

## Examples

### Weather API

```ruby
class WeatherController < ApplicationController
  def current
    x402_paywall(amount: 0.001)
    return if performed?
    render json: { temp: 72, condition: "sunny" }
  end

  def forecast
    x402_paywall(amount: 0.01)
    return if performed?
    render json: { forecast: [...] }
  end
end
```

## x402 Architecture

```
┌──────────┐      ┌──────────┐      ┌─────────────┐
│  Client  │─────▶│   Rails  │─────▶│ Facilitator │
│          │      │   x402   │      │   (x402.org) │
└──────────┘      └──────────┘      └─────────────┘
     │                  │                    │
     │                  │                    ▼
     │                  │             ┌──────────────┐
     │                  │             │  Blockchain  │
     │                  │             │   (Base)     │
     └──────────────────┴─────────────┴──────────────┘
```

## Error Handling

The gem raises these errors:

- `X402::ConfigurationError` - Invalid configuration
- `X402::InvalidPaymentError` - Invalid payment payload
- `X402::FacilitatorError` - Facilitator communication issues

## Security

- Payments validated via EIP-712 signatures
- Nonce prevents replay attacks
- Time windows limit authorization validity
- Facilitator verifies all parameters
- Settlement happens on-chain (immutable)

## Requirements

- Ruby 3.0+
- Rails 7.0+

## Resources

- [x402 Protocol Docs](https://docs.cdp.coinbase.com/x402)
- [GitHub Repository](https://github.com/coinbase/x402)
- [Facilitator API](https://x402.org/facilitator)

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
