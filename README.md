# x402-rails

Accept instant blockchain micropayments in Rails applications using the [x402 payment protocol](https://docs.cdp.coinbase.com/x402). Enable HTTP 402 Payment Required with USDC payments on Base and other networks.

## Features

- **1 line of code** to accept digital dollars (USDC)
- **No fees** on supported networks (Base)
- **~2 second** settlement times
- **$0.001 minimum** payment amounts
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
  config.wallet_address = "0xYourAddress"      # Required: recipient address
  config.facilitator = "https://x402.org/facilitator"  # Facilitator URL
  config.chain = "base-sepolia"                 # Network to use
  config.currency = "USDC"                      # Token symbol
end
```

### Per-Request Overrides

Override config for specific requests:

```ruby
x402_paywall(
  amount: 0.005,
  chain: "base",           # Override chain
  currency: "USDC"         # Override currency
)
```

## Payment Flow

The gem follows a secure payment flow:

1. **Verify**: Payment signature is validated (no blockchain transaction yet)
2. **Process**: Your controller action executes and renders the response
3. **Settle**: If response is successful (2xx status), payment is settled on-chain
4. **Response**: Client receives response with settlement confirmation header

This ensures users only pay for successful requests.

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
X402_WALLET_ADDRESS=0xYourAddress
X402_FACILITATOR_URL=https://x402.org/facilitator
X402_CHAIN=base-sepolia
X402_CURRENCY=USDC
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

1. **No payment**: Returns HTTP 402 with payment requirements
2. **Payment received**: Verifies signature via facilitator (no blockchain transaction yet)
3. **Valid payment**: Processes request and renders response
4. **Settlement**: If response is 2xx, settles payment on blockchain
5. **Invalid payment**: Returns 402 with error details

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
