# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-01-07

### Added
- **Protocol v2 support** - Now supports x402 protocol v2 with CAIP-2 network identifiers and updated headers
- **v2 `PAYMENT-REQUIRED` header** - v2 responses now include the `PAYMENT-REQUIRED` header with base64-encoded PaymentRequired schema per the x402 v2 HTTP transport spec
- **Multi-chain accept** - `config.accept(chain:, currency:)` allows accepting payments on multiple chains simultaneously
- **Per-endpoint version** - Override protocol version per endpoint with `x402_paywall(amount:, version:)`
- **Custom chain CAIP-2 lookup** - `from_caip2()` now supports reverse lookup for custom registered chains
- **Version strategy specs** - Added comprehensive tests for V1 and V2 version strategies

### Changed
- Default protocol version is now v2
- v2 responses use CAIP-2 format for network identifiers (e.g., `eip155:84532` instead of `base-sepolia`)
- v2 402 responses include full PaymentRequired in both header (base64) and body (JSON) for easier debugging
- v1 402 responses continue to use body-only (no header)

### Fixed
- PaymentPayload v2 format now includes `scheme` and `network` at top level
- PaymentRequirement includes all required facilitator fields (`maxAmountRequired`, `description`, `resource`, `mimeType`)

## [0.2.1] - Previous Release

- Initial stable release with v1 protocol support
- Custom chain and token registration
- Optimistic and non-optimistic settlement modes
