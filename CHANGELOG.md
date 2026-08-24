# Changelog

All notable changes to the xMoney iOS SDK are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.2] - 2026-08-24

### Breaking

- Removed `WalletButtonStyle` and `WalletAppearance.style`

### Added

- `EmbeddedPayment.confirm()` / `PaymentElement.confirm()` for a merchant-owned Pay button
- `EmbeddedPayment.updateOrder` / `PaymentElement.updateOrder` rebinds a new signed order in place
- `EmbeddedPayment.updateAppearance` / `updateLocale` (and the same on `PaymentElement`)
- `PaymentElement.onContentSizeChange` when the embedded form’s measured height changes
- `EmbeddedPayment.isInteractionEnabled` to gate a merchant CTA during `updateOrder` or an in-flight charge
- `ApplePay.updateOrder` stores the next payable intent; Pay stays locked until it returns
- `ApplePay.dismiss()` closes the PassKit sheet before authorize
- Bulgarian, Hungarian, and Polish checkout copy (`bg`, `hu`, `pl`; region tags like `pl-PL` work)

### Changed

- Default Pay button is a pill (`appearance.primaryButton.borderRadius` 9999)
- Default card validation is `onTouched`
- Payment Sheet always shows the SDK Pay button (`SubmitButtonConfig.visible` is Embedded-only)
- `options.locale` selects UI language by language prefix (`pl` and `pl-PL` use the same catalog) and drives Pay-button amount punctuation
- `updateOrder` keeps the mounted Element visible. Pay stays locked until `.ready`; gate a merchant CTA with `isInteractionEnabled`
- `EmbeddedEvent.processing` is an in-flight charge only — `updateOrder` does not emit it
- `ApplePay` is `@MainActor` (same as `PaymentSheet` / `EmbeddedPayment`)
- Saved cards label the issuer from `bankName`
- Example app is a single Xcode project (`Examples/Example`) with Sheet / Element / Apple Pay samples, store scenarios, and a playground

### Fixed

- SwiftUI `.paymentSheet` and `PaymentSheet.present(from:)` present from a controller that is in a window
- 8-digit appearance hex is AARRGGBB (same as Android)
- Cancelled HTTP (overlapping `updateOrder` / SwiftUI `.task` teardown) is not reported as a payment failure

## [0.0.1] - 2026-08-17

First public release (SPM + CocoaPods `XMoneyPaymentSheet`).

Payment Sheet, Payment Element, and Apple Pay. Products: `XMoneyCore`, `XMoneyApplePay`, `XMoneyPaymentElement`, `XMoneyPaymentSheet`.
