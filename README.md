# x402-rails

Accept instant blockchain micropayments in Rails applications using the [x402 payment protocol](https://docs.cdp.coinbase.com/x402). Enable HTTP 402 Payment Required with USDC payments on Base and other networks.

## Features

- **1 line of code** to accept digital dollars (USDC)
- **No fees** on supported networks (Base)
- **~1 second** response times (optimistic mode)
- **$0.001 minimum** payment amounts
- **Optimistic & non-optimistic** settlement modes
- **Automatic settlement** after successful responses
- **Browser paywall** and API support
- **Rails 7.0+** compatible

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
  config.chain = "base-sepolia"  # or "base" for mainnet
  config.currency = "USDC"
  config.optimistic = true  # Fast responses (default), false for guaranteed settlement
end
```

### 2. Protect your endpoints

Use `x402_paywall` in any controller action:

```ruby
class ApiController < ApplicationController
  def weather
    x402_paywall(amount: 0.001)  # $0.001 in USD

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
  # Action continues after payment verified
  render json: @data
end
```

### Before Action Hook

Protect multiple actions:

```ruby
class PremiumController < ApplicationController
  before_action :require_payment, only: [:show, :index]

  def require_payment
    x402_paywall(amount: 0.001, chain: "base")
  end

  def show
    # Payment already verified
    render json: @premium_content
  end
end
```

### Per-Action Pricing

Different prices for different actions:

```ruby
def basic_data
  x402_paywall(amount: 0.001)
  render json: basic_info
end

def premium_data
  x402_paywall(amount: 0.01)
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
  config.facilitator = "https://x402.org/facilitator"

  # Blockchain network (default: "base-sepolia")
  # Options: "base-sepolia", "base", "avalanche-fuji", "avalanche"
  config.chain = "base-sepolia"

  # Payment token (default: "USDC")
  # Currently only USDC is supported
  config.currency = "USDC"

  # Optimistic mode (default: true)
  # true: Fast response, settle payment after response is sent
  # false: Wait for blockchain settlement before sending response
  config.optimistic = true
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
```

## Examples

### Premium API

```ruby
class WeatherController < ApplicationController
  def current
    x402_paywall(amount: 0.001)
    render json: { temp: 72, condition: "sunny" }
  end

  def forecast
    x402_paywall(amount: 0.01)
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

MIT License. See LICENSE.txt for details.
