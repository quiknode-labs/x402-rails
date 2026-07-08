# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0] - Unreleased

### Added
- **`x402_payment_required!`** - Builds the 402 PaymentRequired document (declared description and discovery extension included), stamps the requirement header and `Cache-Control: no-store`, and returns the document — for controllers that render a custom 402 body around the standard header

## [1.2.0] - 2026-07-08

### Added
- **Bazaar discovery** - `x402_discovery` controller macro declares discovery metadata per action; the extension is attached to every v2 402 the gem renders, echoed by paying clients, and indexed by facilitator catalogs (PayAI, Coinbase CDP Bazaar)
- **`X402::DiscoveryExtension.declare`** - Builds the `extensions.bazaar` wire shape, matching `@x402/extensions` `declareDiscoveryExtension` (query and body forms)
- **Coinbase CDP facilitator auth** - Requests to `api.cdp.coinbase.com` carry the required Bearer JWT (ES256 and Ed25519 keys, no new dependencies). Credentials via `CDP_API_KEY_ID` / `CDP_API_KEY_SECRET` or `config.cdp_api_key_id` / `config.cdp_api_key_secret`
- **`FacilitatorClient#discovery_resources`** - Query a facilitator's discovery catalog
- **`x402_payment_header` / `x402_payment_attempted?`** - Controller helpers for the version-appropriate payment header, for conditional paywall flows and idempotency fingerprints
- `x402_discovery(description:)` sets the 402 `resource.description` facilitator catalogs display; `x402_paywall(extensions:)` attaches a prebuilt extensions hash directly

### Changed
- 402 responses set `Cache-Control: no-store`
- Facilitator request/response bodies and settlement diagnostics log at `debug`; settlement outcomes stay at `info`/`error`

### Fixed
- **v2 PaymentPayload dropped client-echoed `extensions`** - `to_h` hardcoded `extensions: {}`, so the discovery extension never reached the facilitator on verify/settle and routes could not be indexed. Client extensions are now forwarded untouched
- Settlement failures returning HTTP 400 from the facilitator no longer raise out of the settlement hook; they are logged and handled like other settlement errors
- `rails generate x402:install` - the install generator was not discoverable (it lived outside Rails' generator load path)

With no discovery declared and a non-CDP facilitator, the only wire change from 1.1.0 is the 402 `Cache-Control` header.

## [1.0.0] - 2026-01-07

### Added
- **Protocol v2 support** - Full x402 protocol v2 compliance with CAIP-2 network identifiers and updated headers
- **v2 `PAYMENT-REQUIRED` header** - 402 responses include base64-encoded PaymentRequired in header per v2 HTTP transport spec
- **v2 PaymentPayload format** - `scheme` and `network` nested inside `accepted` object per v2 spec
- **v2 PaymentRequired format** - `resource` info at top level, `amount` field (not `maxAmountRequired`), `extensions` object
- **Multi-chain accept** - `config.accept(chain:, currency:)` allows accepting payments on multiple chains simultaneously
- **Per-endpoint version override** - `x402_paywall(amount:, version:)` to use v1 or v2 per endpoint
- **Custom chain registration** - `config.register_chain(name:, chain_id:, standard:)` for custom EVM chains
- **Custom token registration** - `config.register_token(chain:, symbol:, address:, decimals:, name:)` for custom tokens
- **CAIP-2 support** - `to_caip2()` and `from_caip2()` for network identifier conversion
- **Per-chain fee payer** - Configure via `X402_SOLANA_DEVNET_FEE_PAYER`, `X402_SOLANA_FEE_PAYER` env vars
- **Dynamic HTML paywall** - Detects decimals and asset symbol from chain configuration

### Changed
- Default protocol version is now v2
- v2 responses use CAIP-2 network format (e.g., `eip155:84532` instead of `base-sepolia`)
- v2 402 responses include full PaymentRequired in both header and body for debugging
- v1 requirements include `resource`, `description`, `mimeType` in each accept; v2 places these at top level

## [0.2.1] - Previous Release

- Initial stable release with v1 protocol support
- Custom chain and token registration
- Optimistic and non-optimistic settlement modes
