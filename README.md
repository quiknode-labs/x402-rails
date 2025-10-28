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

| Attribute | Required | Default | Description |
|-----------|----------|---------|-------------|
| `wallet_address` | **Yes** | - | Your Ethereum wallet address where payments will be received |
| `facilitator` | No | `"https://x402.org/facilitator"` | Facilitator service URL for payment verification and settlement |
| `chain` | No | `"base-sepolia"` | Blockchain network to use (`base-sepolia`, `base`, `avalanche-fuji`, `avalanche`) |
| `currency` | No | `"USDC"` | Payment token symbol (currently only USDC supported) |
| `optimistic` | No | `true` | Settlement mode (see Optimistic vs Non-Optimistic Mode below) |

### Per-Request Overrides

Override config for specific requests:

```ruby
x402_paywall(
  amount: 0.005,           # Required: payment amount in USD
  chain: "base",           # Optional: override chain
  currency: "USDC"         # Optional: override currency
)
```

### Optimistic vs Non-Optimistic Mode

The gem supports two settlement modes that affect response timing and user experience:

#### Optimistic Mode (Default: `true`)

**Flow:**
1. Verify payment signature (off-chain, ~100ms)
2. Process request and generate response
3. Send response to client (~1 second total)
4. Settle payment on blockchain in background (async)

**Characteristics:**
- ⚡ **Fast**: ~1 second response time
- 🎯 **Better UX**: Users get instant responses
- 💰 **Risk**: Small window where payment might fail to settle
- ✅ **Best for**: Most applications, especially user-facing APIs

**When to use:**
- User-facing APIs where speed matters
- Low-value transactions
- High-volume endpoints
- When you can handle occasional settlement failures gracefully

```ruby
X402.configure do |config|
  config.optimistic = true  # Default
end
```

#### Non-Optimistic Mode (`false`)

**Flow:**
1. Verify payment signature (off-chain, ~100ms)
2. Settle payment on blockchain (wait for transaction, ~1 second)
3. Process request and generate response
4. Send response to client (~2 seconds total)

**Characteristics:**
- 🛡️ **Secure**: Payment guaranteed before response
- 🐢 **Slower**: ~2 second response time
- 💎 **Zero risk**: No chance of unpaid responses
- ✅ **Best for**: High-value transactions, critical data

**When to use:**
- High-value content or services
- Critical or sensitive data
- When payment certainty is more important than speed
- Compliance or auditing requirements

```ruby
X402.configure do |config|
  config.optimistic = false
end
```

#### Mode Comparison

| Feature | Optimistic | Non-Optimistic |
|---------|-----------|----------------|
| Response Time | ~1 second | ~2 seconds |
| User Experience | Excellent | Good |
| Payment Certainty | High (async) | Guaranteed |
| Risk of Unpaid Response | Very low | Zero |
| Recommended For | General use | High-value content |

#### Handling Settlement Failures (Optimistic Mode)

In optimistic mode, settlement happens after the response is sent. If settlement fails:

1. **Logged automatically**: Check Rails logs for settlement errors
2. **User still got service**: Cannot be revoked
3. **Monitoring recommended**: Track failure rates
4. **Rare in practice**: Most failures are caught during verification

```ruby
# Add monitoring for settlement failures
class ApplicationController < ActionController::API
  after_action :log_settlement_status, if: -> { request.env['x402.payment'] }

  private

  def log_settlement_status
    settlement = request.env['x402.settlement_result']
    unless settlement&.success?
      # Alert your monitoring service
      Rails.logger.error("Settlement failed for #{request.env['x402.payment'][:payer]}")
    end
  end
end
```

## Payment Flow

The gem follows a secure payment flow that varies by mode:

### Optimistic Mode (Default)

1. **Verify**: Payment signature validated off-chain (~100ms)
2. **Process**: Controller action executes
3. **Respond**: Client receives response (~1s total)
4. **Settle**: Payment settled on blockchain asynchronously

### Non-Optimistic Mode

1. **Verify**: Payment signature validated off-chain (~100ms)
2. **Settle**: Payment settled on blockchain (~1s)
3. **Process**: Controller action executes
4. **Respond**: Client receives response (~2s total)

**Both modes ensure:**
- Users only pay for successful (2xx) responses
- Invalid payments are rejected before processing
- Settlement failures are logged and monitored

## Accessing Payment Info

After successful payment, access details via `request.env`:

```ruby
def show
  x402_paywall(amount: 0.001)

  payment = request.env['x402.payment']

  puts payment[:payer]        # => "0x..."
  puts payment[:amount]       # => "1000"
  puts payment[:network]      # => "base-sepolia"
  puts payment[:payload]      # => PaymentPayload object
  puts payment[:requirement]  # => PaymentRequirement object

  render json: { paid_by: payment[:payer] }
end
```

## Supported Networks

### Testnets

- `base-sepolia` (Chain ID: 84532)
- `avalanche-fuji` (Chain ID: 43113)

### Mainnets

- `base` (Chain ID: 8453) ✅ No fees!
- `avalanche` (Chain ID: 43114)

## Browser Support

When accessed from a browser, users see a beautiful paywall page:

```
┌─────────────────────────┐
│   💳 Payment Required   │
│                         │
│        $0.001           │
│                         │
│  Network: base-sepolia  │
│  Asset: USDC            │
└─────────────────────────┘
```

API clients receive JSON:

```json
{
  "x402Version": 1,
  "error": "Payment required to access this resource",
  "accepts": [{
    "scheme": "exact",
    "network": "base-sepolia",
    "maxAmountRequired": "1000",
    "asset": "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
    "payTo": "0xYourAddress",
    "resource": "https://api.example.com/weather"
  }]
}
```

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

All environment variables can be used in your initializer:

```ruby
X402.configure do |config|
  config.wallet_address = ENV.fetch('X402_WALLET_ADDRESS')
  config.facilitator = ENV.fetch('X402_FACILITATOR_URL', 'https://x402.org/facilitator')
  config.chain = ENV.fetch('X402_CHAIN', 'base-sepolia')
  config.currency = ENV.fetch('X402_CURRENCY', 'USDC')
  config.optimistic = ENV.fetch('X402_OPTIMISTIC', 'true') == 'true'
end
```

## Examples

### Weather API

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

### Premium Content API

```ruby
class ArticlesController < ApplicationController
  before_action :require_payment_for_premium, only: [:show]

  def require_payment_for_premium
    if @article.premium?
      x402_paywall(amount: 0.05, chain: "base")
    end
  end

  def show
    render json: @article
  end
end
```

### AI API with Dynamic Pricing

```ruby
class AiController < ApplicationController
  def generate
    tokens = params[:max_tokens].to_i
    price = (tokens / 1000.0) * 0.01  # $0.01 per 1000 tokens

    x402_paywall(amount: price)

    result = generate_ai_response(params[:prompt], tokens)
    render json: { result: result }
  end
end
```

### High-Value Content (Non-Optimistic Mode)

For premium content where payment certainty is critical:

```ruby
class PremiumReportsController < ApplicationController
  # Use non-optimistic mode for high-value content
  def initialize
    @original_optimistic = X402.configuration.optimistic
    super
  end

  before_action :use_non_optimistic_mode

  def download
    # $50 premium report - wait for settlement
    x402_paywall(amount: 50.00, chain: "base")  # Use mainnet for production

    report = generate_premium_report(params[:id])

    send_data report.to_pdf,
      filename: "premium_report_#{params[:id]}.pdf",
      type: 'application/pdf'
  end

  private

  def use_non_optimistic_mode
    # Temporarily disable optimistic mode for this controller
    X402.configuration.optimistic = false
  end

  after_action :restore_optimistic_mode

  def restore_optimistic_mode
    X402.configuration.optimistic = @original_optimistic
  end
end
```

Or use environment-based configuration:

```ruby
# config/initializers/x402.rb
X402.configure do |config|
  config.wallet_address = ENV['X402_WALLET_ADDRESS']
  config.chain = "base"  # Mainnet for production

  # Use non-optimistic mode for production high-value transactions
  config.optimistic = Rails.env.production? ? false : true
end
```

## Testing

### Testing with Mock Payments

In your test environment, you may want to disable payment requirements:

```ruby
# config/environments/test.rb
Rails.application.configure do
  # Mock x402 for tests
  config.after_initialize do
    X402.configure do |config|
      config.wallet_address = "0xTestAddress"
      config.chain = "base-sepolia"
    end
  end
end
```

Or create test helpers:

```ruby
# spec/support/x402_helpers.rb
module X402TestHelpers
  def with_x402_payment(amount:)
    # Mock payment header
    request.headers["X-PAYMENT"] = mock_payment_header(amount)
  end

  def mock_payment_header(amount)
    # Generate mock payment payload
  end
end
```

### Testing with Real Payments

For integration testing or manual API testing, you'll need to generate valid payment signatures.

#### Prerequisites

1. **Install Python x402 library:**

```bash
# In your project directory
python3 -m venv venv
source venv/bin/activate
pip install git+https://github.com/coinbase/x402.git#subdirectory=python/x402
```

2. **Get testnet USDC:**

For base-sepolia testing, get testnet ETH and USDC from the [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet).

#### Generating Payment Signatures

Use the x402 Python library to generate payment signatures:

```python
#!/usr/bin/env python3
"""Generate X-PAYMENT header for testing"""

import sys
import os
sys.path.insert(0, 'path/to/x402/python/x402/src')

from eth_account import Account
from x402.exact import prepare_payment_header, sign_payment_header
from x402.types import PaymentRequirements

# Your test wallet private key
PRIVATE_KEY = os.environ.get("X402_TEST_PRIVATE_KEY", "0x...")
PORT = os.environ.get("PORT", "3000")
PAY_TO = "0xYourServerWalletAddress"

account = Account.from_key(PRIVATE_KEY)

# Payment requirements (must match your server's 402 response)
requirements = PaymentRequirements(
    scheme="exact",
    network="base-sepolia",
    asset="0x036CbD53842c5426634e7929541eC2318f3dCF7e",  # USDC on base-sepolia
    pay_to=PAY_TO,
    max_amount_required="1000",  # 0.001 USDC in atomic units
    resource=f"http://localhost:{PORT}/api/weather/current",
    description="Payment required for /api/weather/current",
    max_timeout_seconds=600,
    mime_type="application/json",
    output_schema=None,
    extra={
        "name": "USDC",  # base-sepolia uses "USDC" not "USD Coin"
        "version": "2",
    },
)

# Generate unsigned payment header
unsigned_header = prepare_payment_header(account.address, 1, requirements)

# Convert nonce to hex string
nonce = unsigned_header["payload"]["authorization"]["nonce"]
unsigned_header["payload"]["authorization"]["nonce"] = nonce.hex()

# Sign the payment header
payment_header = sign_payment_header(account, requirements, unsigned_header)

print(f"X-PAYMENT: {payment_header}")
print(f"\nCurl command:")
print(f'curl -i -H "X-PAYMENT: {payment_header}" http://localhost:{PORT}/api/weather/current')
```

**Usage:**

```bash
# Generate payment for localhost:3000
python generate_payment.py

# Generate for different port
PORT=3001 python generate_payment.py

# Use custom wallet
X402_TEST_PRIVATE_KEY=0x... python generate_payment.py
```

#### Testing the Full Flow

1. **Start your Rails server:**

```bash
bin/rails server -p 3000
```

2. **Request without payment (get requirements):**

```bash
curl -i http://localhost:3000/api/weather/current
```

Expected: `402 Payment Required` with payment requirements

3. **Generate payment signature:**

```bash
python generate_payment.py
```

4. **Make request with payment:**

Copy the curl command from the script output and run it.

Expected: `200 OK` with data and `X-PAYMENT-RESPONSE` header containing blockchain transaction hash

#### Viewing Settlement on Blockchain

After successful payment, view the transaction:

- **Base Sepolia**: https://sepolia.basescan.org/tx/TRANSACTION_HASH
- **Base Mainnet**: https://basescan.org/tx/TRANSACTION_HASH

## How It Works

### Request Flow

1. **No payment header**: Returns HTTP 402 with payment requirements
2. **Payment header present**: Verifies EIP-712 signature via facilitator (off-chain, no gas)
3. **Invalid signature**: Returns 402 with error details
4. **Valid signature**:
   - **Optimistic mode**: Process → Respond → Settle (async)
   - **Non-optimistic mode**: Settle → Process → Respond (sync)
5. **Settlement**: Transaction submitted to blockchain (only for 2xx responses)
6. **Response**: Includes `X-PAYMENT-RESPONSE` header with transaction hash

### Under the Hood

- **EIP-712 signatures**: Cryptographically verify payment authorization
- **EIP-3009**: TransferWithAuthorization - no token approvals needed
- **Facilitator**: Verifies signatures and submits blockchain transactions
- **After-action callback**: Handles async settlement in optimistic mode
- **Atomic units**: All amounts in USDC's smallest unit (1 USDC = 1,000,000 atomic units)

## Architecture

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

### Basic Error Handling (Automatic)

The gem automatically handles payment errors by rendering 402 responses with error details:

```ruby
class ApiController < ApplicationController
  def show
    x402_paywall(amount: 0.001)
    # Invalid payments automatically return 402 with error message
    render json: @data
  end
end
```

### Application-Wide Error Handling (Recommended)

For consistent error handling across your API, use `rescue_from` in ApplicationController:

```ruby
class ApplicationController < ActionController::API
  # Handle payment-related errors gracefully
  rescue_from X402::InvalidPaymentError, with: :render_payment_error
  rescue_from X402::FacilitatorError, with: :render_facilitator_error
  rescue_from X402::ConfigurationError, with: :render_config_error

  private

  def render_payment_error(exception)
    render json: {
      error: "Payment Error",
      message: exception.message,
      type: "invalid_payment"
    }, status: :payment_required
  end

  def render_facilitator_error(exception)
    # Log facilitator errors for monitoring
    Rails.logger.error("[x402] Facilitator error: #{exception.message}")

    render json: {
      error: "Payment Service Unavailable",
      message: "Unable to process payment. Please try again.",
      type: "facilitator_error"
    }, status: :service_unavailable
  end

  def render_config_error(exception)
    # Configuration errors should be caught early
    Rails.logger.fatal("[x402] Configuration error: #{exception.message}")

    render json: {
      error: "Service Configuration Error",
      message: "Payment system not properly configured"
    }, status: :internal_server_error
  end
end
```

### Controller-Specific Error Handling

Override error handling for specific controllers:

```ruby
class PremiumController < ApplicationController
  rescue_from X402::InvalidPaymentError do |e|
    # Custom handling for premium endpoints
    render json: {
      error: "Premium Access Denied",
      message: "Valid payment required for premium content",
      details: e.message,
      pricing: { amount: "$0.01", currency: "USDC" }
    }, status: :payment_required
  end

  def show
    x402_paywall(amount: 0.01)
    render json: @premium_content
  end
end
```

### Monitoring and Alerting

Integrate with error tracking services:

```ruby
class ApplicationController < ActionController::API
  rescue_from X402::FacilitatorError do |exception|
    # Report to error tracking service
    Sentry.capture_exception(exception) if defined?(Sentry)

    # Log for monitoring
    Rails.logger.error({
      error: "x402_facilitator_error",
      message: exception.message,
      timestamp: Time.current,
      request_id: request.uuid
    }.to_json)

    render json: {
      error: "Payment service temporarily unavailable"
    }, status: :service_unavailable
  end
end
```

### Development vs Production Error Messages

Show detailed errors in development, generic in production:

```ruby
class ApplicationController < ActionController::API
  rescue_from X402::InvalidPaymentError do |exception|
    message = if Rails.env.production?
      "Invalid payment. Please check your payment details."
    else
      "Invalid payment: #{exception.message}"
    end

    render json: { error: message }, status: :payment_required
  end
end
```

## Security

- Payments validated via EIP-712 signatures
- Nonce prevents replay attacks
- Time windows limit authorization validity
- Facilitator verifies all parameters
- Settlement happens on-chain (immutable)

## Requirements

- Ruby 3.0+
- Rails 7.0+

## Development

After checking out the repo:

```bash
bin/setup
bundle exec rake spec
bin/console
```

## Contributing

Bug reports and pull requests welcome at https://github.com/yourusername/x402-rails

## Resources

- [x402 Protocol Docs](https://docs.cdp.coinbase.com/x402)
- [GitHub Repository](https://github.com/coinbase/x402)
- [Facilitator API](https://x402.org/facilitator)

## License

MIT License. See LICENSE.txt for details.
