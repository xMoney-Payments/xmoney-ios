# Changelog

All notable changes to the xMoney iOS SDK are documented here.

## [Unreleased]

## [0.0.1] - 2026-08-17

First public release (SPM + CocoaPods `XMoneyPaymentSheet`).

### Added

- Shared `PaymentSession` with injectable HTTP, one-shot consume policy, and serialized submit
- `ApplePay.register()` so Embedded can enable Apple Pay without a PaymentElement → ApplePay module dependency
- Linking `XMoneyApplePay` auto-installs Apple Pay (C/`+load`); `register()` stays public and idempotent
- SPM ships `PrivacyInfo.xcprivacy` on `XMoneyCore`
- Edit / Done saved-card management with inline Remove / Keep it confirm
- Module split mirroring Android: `XMoneyCore` → `XMoneyApplePay` → `XMoneyPaymentElement` → `XMoneyPaymentSheet`
- Embedded Payment Element: `EmbeddedPayment`, `PaymentElement`, SwiftUI `PaymentElementView`
- Standalone Apple Pay: `ApplePay.present`, `ApplePayButton`
- Cardholder verification (`CardHolderVerification`) with account-validation API
- `ThreeDSReconcile` soft-cancel grace (4s) matching Android/web
- Branded `XCoinFlipLoader` / `XCoinButtonMark` and 3DS dots + brand overlay
- Roobert fonts and xMoney mark assets for loaders / 3DS
- `PaymentError.applePay` and `PaymentError.cardHolderVerification`
- One-shot order consumption (`isOrderConsumed`) on Embedded and standalone Apple Pay
- Swift Package Manager products `XMoneyCore`, `XMoneyApplePay`, `XMoneyPaymentElement`, `XMoneyPaymentSheet`
- CocoaPods pod `XMoneyPaymentSheet` with `Core`, `ApplePay`, `PaymentElement`, `PaymentSheet` subspecs
- Contract tests driven by shared `test-vectors.json`
- UIKit and SwiftUI example apps
- Opt-in `OSLog`-based HTTP debug logging with sensitive key redaction
- English `Localizable.strings` resource bundle

### Changed

- Same-order `prepare` reuses the loaded engine (no empty session token)
- Payment Sheet keeps Pay locked until dismiss; pre-authorize Apple Pay cancel can retry
- Embedded cancel matches Apple Pay: pre-authorize dismiss does not consume the order
- 3DS WebView allows `https` and `about` only; return URL matches scheme + host + path prefix
- Apple Pay is shown only when wallet params include a merchant ID; params are cached
- Delete saved card refreshes the card list without reminting the session
- `XMoneyPaymentElement` no longer depends on `XMoneyApplePay`; `XMoneyCore` no longer links PassKit
- CVV fields stay visible as typed (Android / Stripe-class CVC)
- HTTP multipart rejects CR/LF/boundary injection; path IDs are percent-encoded
- DELETE saved-card requests fail closed on non-2xx (confirm stays open)
- Apple Pay fails closed when order amount or currency is missing (`0` amount still allowed)
- `PaymentSession.bind` commits engine/state only after `load()` succeeds; overlapping binds are generation-guarded
- Payment Sheet X / scrim / drag / `dismiss()` share one wait-or-cancel policy (never cancel an in-flight charge)
- Session-load coin is always xMoney `#7C4DFF` (not merchant `appearance.colors.primary`)
- Apple Pay params are awaited with the rest of bind (no 5s timeout that hid the button)
- 3DS UI lives in Core; standalone Apple Pay uses the same branded WebView
- `PaymentSession` is `@MainActor`; `Transaction.init(apiMap:)` is `package`
- 3DS challenge URLs must be `https` at parse time
- Payment Sheet is thin chrome hosting the shared Payment Element form
- Package platforms are iOS-only (removed unused macOS claim)

### Breaking

- Merchant terminal callbacks use `PaymentResult` (`complete` / `failed` / `canceled`) instead of `Result<Transaction, PaymentError>`. Cancel is no longer a `PaymentError`. Failures are always sanitized.
- Dropped the `XMoney` prefix on merchant types (Android + Stripe iOS parity). Modules stay branded: `import XMoneyPaymentSheet` → `PaymentSheet`.
- SPM package and CocoaPods pod `XMoneyCheckout` → `XMoneyPaymentSheet`. Product `XMoneyEmbedded` → `XMoneyPaymentElement`. Subspec `Embedded` → `PaymentElement`.
- `XMoneyCheckout` → `PaymentSheet`; `present(from:order:)` → `present(from:intent:)`.
- `XMoneyOrder` → `PaymentIntent`; `XMoneyConfiguration` → `PaymentConfig`; `XMoneyError` → `PaymentError`; `XMoneyTransaction` → `Transaction`.
- Nested config uses Android `*Config` names (`CardConfig`, `OptionsConfig`, `SubmitButtonType`, …).
- SwiftUI `.xmoneyPaymentSheet` → `.paymentSheet(isPresented:configuration:intent:…)`.
- `XMoneyEmbeddedPayment` / `XMoneyPaymentElement` / `XMoneyApplePay` → `EmbeddedPayment` / `PaymentElement` / `ApplePay`.
- `prepare(order:)` → `prepare(intent:)`.
- Removed `PaymentError.googlePay`. Engine, services, HTTP, and form views are no longer public.
