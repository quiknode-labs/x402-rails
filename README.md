# x402-rails

## Now supporting x402 v2!

> **⚠️ Note:** This gem now defaults to x402 protocol **v2**. If you need v1 compatibility, set `config.version = 1` in your initializer. See [Protocol Versions](#protocol-versions) for details on the differences.

![Coverage](./coverage/coverage.svg)

Accept instant blockchain micropayments in your Rails applications using the [x402 payment protocol](https://www.x402.org/).

Supports 20 networks including Base, Arbitrum, Polygon, Avalanche, Sei, Solana, and more.

## Features

- **1 line of code** to accept digital dollars (USDC)
- **No fees** on supported networks (Base)
- **~1 second** response times (optimistic mode)
- **$0.001 minimum** payment amounts
- **Optimistic & non-optimistic** settlement modes
- **Automatic settlement** after successful responses
- **API paywall** with 402 payment-required responses
- **Bazaar discovery** to list your routes in facilitator catalogs (PayAI, Coinbase CDP)
- **Coinbase CDP facilitator** support with built-in auth
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

Generate the initializer:

```bash
bin/rails generate x402:install
```

Then edit `config/initializers/x402.rb`:

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']  # Your recipient wallet
  config.facilitator = "https://www.x402.org/facilitator"
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

### 3. (Optional) Make it discoverable

Declare discovery metadata and agents can find your route in facilitator catalogs (see [Bazaar Discovery](#bazaar-discovery)):

```ruby
class ApiController < ApplicationController
  x402_discovery only: :weather,
                 input: { "city" => "San Francisco" },
                 input_schema: { "properties" => { "city" => { "type" => "string" } } },
                 output: { example: { "temperature" => 72 } }
end
```

Indexing happens when a client pays: the extension rides the 402, the paying client echoes it, and the facilitator catalogs the route on settle.

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

  # Facilitator service URL (default: "https://www.x402.org/facilitator")
  config.facilitator = ENV.fetch("X402_FACILITATOR_URL", "https://www.x402.org/facilitator")

  # Blockchain network (default: "base-sepolia")
  # Built-in: base, base-sepolia, arbitrum, arbitrum-sepolia, polygon, polygon-amoy,
  #           avalanche, avalanche-fuji, sei, sei-testnet, iotex, peaq,
  #           xlayer, xlayer-testnet, skale-base, skale-base-sepolia,
  #           kiteai, kiteai-testnet, solana, solana-devnet
  config.chain = ENV.fetch("X402_CHAIN", "base-sepolia")

  # Payment token (default: "USDC")
  # Currently only USDC is supported
  config.currency = ENV.fetch("X402_CURRENCY","USDC")

  # Optimistic mode (default: false)
  # true: Fast response, settle payment after response is sent
  # false: Wait for blockchain settlement before sending response
  config.optimistic = ENV.fetch("X402_OPTIMISTIC", "false") == "true"
end
```

### Configuration Attributes

| Attribute        | Required | Default                          | Description                                                                       |
| ---------------- | -------- | -------------------------------- | --------------------------------------------------------------------------------- |
| `wallet_address` | **Yes**  | -                                | Your Ethereum wallet address where payments will be received                      |
| `facilitator`    | No       | `"https://www.x402.org/facilitator"` | Facilitator service URL for payment verification and settlement               |
| `chain`          | No       | `"base-sepolia"`                 | Blockchain network (see built-in list above) |
| `currency`       | No       | `"USDC"`                         | Payment token symbol (currently only USDC supported)                              |
| `optimistic`     | No       | `false`                          | `true`: respond before settlement; `false`: settle before responding             |
| `version`        | No       | `2`                              | Protocol version (1 or 2). See Protocol Versions section                          |
| `cdp_api_key_id` | No       | `ENV["CDP_API_KEY_ID"]`          | Coinbase CDP API key id — only used when the facilitator is CDP                   |
| `cdp_api_key_secret` | No   | `ENV["CDP_API_KEY_SECRET"]`      | Coinbase CDP API key secret (ECDSA PEM or Ed25519 base64)                         |

### Custom Chains and Tokens

You can register custom EVM chains and tokens beyond the built-in options.

#### Register a Custom Chain

Add support for any EVM-compatible chain beyond the 20 built-in networks:

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']

  # Register Optimism (not built-in)
  config.register_chain(
    name: "optimism",
    chain_id: 10,
    standard: "eip155"
  )

  # Register the token for that chain
  config.register_token(
    chain: "optimism",
    symbol: "USDC",
    address: "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85",
    decimals: 6,
    name: "USD Coin",
    version: "2"
  )

  config.chain = "optimism"
  config.currency = "USDC"
end
```

#### Register a Custom Token on a Built-in Chain

> **⚠️ Note:** The Facilitator used **must support** the specified chain and token to ensure proper functionality.

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

| Parameter  | Required | Description                                    |
| ---------- | -------- | ---------------------------------------------- |
| `chain`    | Yes      | Chain name (built-in or custom registered)     |
| `symbol`   | Yes      | Token symbol (e.g., "USDC", "WETH")            |
| `address`  | Yes      | Token contract address                         |
| `decimals` | Yes      | Token decimals (e.g., 6 for USDC, 18 for WETH) |
| `name`     | Yes      | Token name for EIP-712 domain                  |
| `version`  | No       | EIP-712 version (default: "1")                 |

**Note:** Custom chains and tokens are only supported for EVM (eip155) networks. Solana chains use a different implementation.

### Accept Multiple Payment Options

Allow clients to pay on any of several supported chains by using `config.accept()`:

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']

  # Register a custom chain not included in the built-in list
  config.register_chain(name: "optimism", chain_id: 10, standard: "eip155")
  config.register_token(
    chain: "optimism",
    symbol: "USDC",
    address: "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85",
    decimals: 6,
    name: "USD Coin",
    version: "2"
  )

  # Accept payments on multiple chains (built-in + custom)
  config.accept(chain: "base-sepolia", currency: "USDC")
  config.accept(chain: "arbitrum-sepolia", currency: "USDC")
  config.accept(chain: "optimism", currency: "USDC")
end
```

When `config.accept()` is used, the 402 response will include all accepted payment options:

```json
{
  "accepts": [
    { "network": "eip155:84532", "asset": "0x036CbD53842c5426634e7929541eC2318f3dCF7e", ... },
    { "network": "eip155:421614", "asset": "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d", ... }
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

## Protocol Versions

x402-rails supports both v1 and v2 of the x402 protocol. **v2 is the default**.

### Key Differences

| Feature         | v1 (Legacy)                   | v2 (Default)                     |
| --------------- | ----------------------------- | -------------------------------- |
| Network format  | Simple names (`base-sepolia`) | CAIP-2 (`eip155:84532`)          |
| Payment header  | `X-PAYMENT`                   | `PAYMENT-SIGNATURE`              |
| Response header | `X-PAYMENT-RESPONSE`          | `PAYMENT-RESPONSE`               |
| Requirements    | Body only                     | `PAYMENT-REQUIRED` header + body |
| Amount field    | `maxAmountRequired`           | `amount`                         |

### v2 (Default)

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']
  config.version = 2  # Default, can be omitted
end
```

v2 uses CAIP-2 network identifiers (`eip155:84532`) and the `PAYMENT-SIGNATURE` header. Payment requirements are sent in both the `PAYMENT-REQUIRED` header (base64-encoded) and the response body (JSON).

### v1 (Legacy)

```ruby
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']
  config.version = 1
end
```

v1 uses simple network names (`base-sepolia`) and the `X-PAYMENT` header. Payment requirements are sent only in the response body.

### Per-Endpoint Version

Override the version for specific endpoints:

```ruby
def premium_v2
  x402_paywall(amount: 0.001, version: 2)
  return if performed?
  render json: { data: "v2 endpoint" }
end

def legacy_v1
  x402_paywall(amount: 0.001, version: 1)
  return if performed?
  render json: { data: "v1 endpoint" }
end
```

## Bazaar Discovery

Facilitators with a discovery layer (PayAI, Coinbase CDP Bazaar) index your route into their public catalog when a payment carries the x402 Bazaar discovery extension. Declare it per action and the gem attaches it to every v2 402 for that action; paying clients echo it into their payment payload, and the gem forwards the echo to the facilitator on verify/settle — that's what creates the catalog entry.

> **Note:** Parameterized routes (e.g. `/weather/:city`) are cataloged per concrete URL — the gem does not emit the optional `routeTemplate` field.

### GET route (query params)

Omit `body_type` for GET/HEAD/DELETE — `input` describes query params:

```ruby
class WeatherController < ApplicationController
  x402_discovery only: :show,
                 input: { "city" => "San Francisco", "units" => "celsius" },
                 input_schema: {
                   "type" => "object",
                   "properties" => {
                     "city" => { "type" => "string", "description" => "City name" },
                     "units" => { "type" => "string", "enum" => ["celsius", "fahrenheit"] },
                   },
                   "required" => ["city"],
                 },
                 output: { example: { "weather" => "foggy", "temperature" => 15 } }

  def show
    x402_paywall(amount: 0.001)
    return if performed?
    render json: { weather: "foggy", temperature: 15 }
  end
end
```

### POST route (JSON body)

Pass `body_type: "json"` — `input` is now an example request body. Give every field a `description`: it's what agents read in the catalog to call you correctly.

```ruby
class SearchController < ApplicationController
  x402_discovery only: :create,
                 body_type: "json",
                 input: {
                   "query" => "solar panels",
                   "filters" => { "max_price" => 100 },
                 },
                 input_schema: {
                   "type" => "object",
                   "properties" => {
                     "query" => { "type" => "string", "description" => "Search terms" },
                     "filters" => {
                       "type" => "object",
                       "properties" => { "max_price" => { "type" => "number" } },
                     },
                   },
                   "required" => ["query"],
                 },
                 output: {
                   example: { "results" => [{ "title" => "…", "price" => 42 }] },
                   schema: { "properties" => { "results" => { "type" => "array" } } },
                 }

  def create
    x402_paywall(amount: 0.005)
    return if performed?
    render json: { results: search_results }
  end
end
```

### Multiple routes in one controller

Each action gets its own declaration; undeclared actions emit no extension:

```ruby
class ReportsController < ApplicationController
  x402_discovery only: :create, body_type: "json",
                 input: { "ticker" => "AAPL" },
                 input_schema: { "properties" => { "ticker" => { "type" => "string" } }, "required" => ["ticker"] },
                 output: { example: { "report_id" => "rep_123" } }

  x402_discovery only: :summary,
                 input: { "report_id" => "rep_123" },
                 input_schema: { "properties" => { "report_id" => { "type" => "string" } }, "required" => ["report_id"] },
                 output: { example: { "summary" => "…" } }
end
```

### Full control

Build the extension yourself (e.g. to share schemas with your validators), or attach per-call:

```ruby
x402_discovery only: :create, extensions: X402::DiscoveryExtension.declare(
  body_type: "json",
  input: MyApi::EXAMPLE_BODY,
  input_schema: MyApi::BODY_SCHEMA,
  output: { example: MyApi::EXAMPLE_RESPONSE },
)

# or, inside an action:
x402_paywall(amount: 0.005, extensions: my_extensions)
```

### Indexing rules

- The example `input` **must validate against `input_schema`** — facilitators silently skip routes whose extension fails validation. Keep example and schema in sync.
- `method` is stamped from the actual request at render time — omit it; a declared value is overwritten.
- `description:` on `x402_discovery` sets the 402's `resource.description` — the text catalogs display for the route. A description alone just names the route; declaring input/output metadata is what makes it discoverable.
- Catalogs are **per-facilitator** — an entry appears only in the catalog of the facilitator that settled the payment. To appear in both PayAI and CDP, settle at least one payment through each.
- Indexing is a side-effect of a real payment; there is no registration API.

Verify a listing:

```ruby
X402::FacilitatorClient.new.discovery_resources(type: "http")
# or against a specific facilitator:
X402::FacilitatorClient.new("https://facilitator.payai.network").discovery_resources
```

## Facilitators

Any x402 facilitator works via `X402_FACILITATOR_URL` / `config.facilitator`. Auth is applied automatically:

| Facilitator | URL | Auth |
| ----------- | --- | ---- |
| x402.org (default) | `https://www.x402.org/facilitator` | none |
| PayAI | `https://facilitator.payai.network` | none |
| Coinbase CDP | `https://api.cdp.coinbase.com/platform/v2/x402` | Bearer JWT, built in |

> **Note:** Not every facilitator settles every chain — check your facilitator's `/supported` endpoint. For example, Arbitrum One and Arbitrum Sepolia are supported by the Coinbase CDP facilitator, while the default x402.org facilitator covers testnets like Base Sepolia.

### Using Coinbase CDP

1. Create a project + API key at [cdp.coinbase.com](https://cdp.coinbase.com) (ECDSA and Ed25519 keys both work).
2. Set the env vars CDP's own SDKs use — the gem picks them up automatically:

```bash
X402_FACILITATOR_URL=https://api.cdp.coinbase.com/platform/v2/x402
CDP_API_KEY_ID=your-key-id
CDP_API_KEY_SECRET=your-key-secret
```

Or configure explicitly:

```ruby
X402.configure do |config|
  config.facilitator = "https://api.cdp.coinbase.com/platform/v2/x402"
  config.cdp_api_key_id = Rails.application.credentials.dig(:cdp, :api_key_id)
  config.cdp_api_key_secret = Rails.application.credentials.dig(:cdp, :api_key_secret)
end
```

Every verify/settle/supported/discovery request then carries a per-request, URI-bound Bearer JWT (2-minute expiry), matching `@coinbase/cdp-sdk`. Note: CDP's Bazaar discovery currently covers Base and Base Sepolia USDC.

## Environment Variables

Configure via environment variables:

```bash
# Required
X402_WALLET_ADDRESS=0xYourAddress

# Optional (with defaults)
X402_FACILITATOR_URL=https://www.x402.org/facilitator
X402_CHAIN=base-sepolia
X402_CURRENCY=USDC
X402_OPTIMISTIC=true  # "true" or "false"

# Coinbase CDP facilitator auth (only needed when X402_FACILITATOR_URL is CDP)
CDP_API_KEY_ID=
CDP_API_KEY_SECRET=

# Solana fee payer overrides (required when using a non-default facilitator)
# The default fee payer is for the Coinbase facilitator (x402.org).
# Each facilitator manages its own fee payer — check your facilitator's /supported endpoint.
X402_FEE_PAYER=                     # Global override for all Solana chains
X402_SOLANA_FEE_PAYER=              # Solana mainnet override
X402_SOLANA_DEVNET_FEE_PAYER=       # Solana devnet override

# Example: PayAI facilitator (https://facilitator.payai.network)
# X402_FACILITATOR_URL=https://facilitator.payai.network
# X402_SOLANA_FEE_PAYER=2wKupLR9q6wXYppw8Gr2NvWxKBUqm4PPJKkQfoxHDBg4
# X402_SOLANA_DEVNET_FEE_PAYER=2wKupLR9q6wXYppw8Gr2NvWxKBUqm4PPJKkQfoxHDBg4
```

Fee payer lookup priority:
1. `config.fee_payer` (programmatic, global)
2. Per-chain ENV variable (e.g., `X402_SOLANA_DEVNET_FEE_PAYER`)
3. `X402_FEE_PAYER` (ENV, global)
4. Built-in default from chain config

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
- [Step-by-Step Rails Integration Guide](https://www.quicknode.com/guides/infrastructure/x402-payment-integration-with-rails)


## License

MIT License. See [LICENSE.txt](LICENSE.txt).
