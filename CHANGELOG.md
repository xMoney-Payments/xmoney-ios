# Changelog

All notable changes to the xMoney iOS SDK are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `ApplePayButton.onFirstDraw` and `ApplePayButtonView.onFirstDraw` run once the PassKit button has painted, or after a short wait if it never does. They run again after an appearance change rebuilds the button, or when the button moves to a new window.
- `EmbeddedPayment.updateOrder { }`, `PaymentElement.updateOrder { }`, and `ApplePay.updateOrder { }` lock Pay while the closure creates the next order and until that order is bound. They return the bound `PaymentIntent` (`@discardableResult`), run the closure on the main actor, and cancel it when the calling task is cancelled.
- `EmbeddedEvent.updateFailed(PaymentError)`: binding a new order failed after an order was already bound.
- `EmbeddedPayment.boundIntent`, the order Pay charges. A custom host can skip re-binding an intent that is already bound.
- `PaymentError.paymentInProgress`, thrown when a different order is requested during a charge. Compare with `==`.
- A "Surface lifecycle contract" section in the README, shared with the Android SDK.

### Changed

- `EmbeddedPayment.prepare` and `EmbeddedPayment.updateOrder` no longer emit `.ready`. A mounted `PaymentElement` emits it once, after the surface first draws; later order updates do not emit it again. `isInteractionEnabled` still unlocks when the bind finishes.
- The newest merchant `prepare` / `updateOrder` call always wins, including when it passes the order that is already bound. It cancels any in-flight order creation or bind. A superseded call throws `CancellationError`. `PaymentElementView` re-asserting the bound intent is a no-op that cancels nothing.
- Order binding is two-phase: a superseded bind never changes the order that Pay charges.
- A later bind failure locks Pay on the stale order until a later update succeeds, and Element emits `.updateFailed`. A `createOrder` closure failure still keeps the previous order payable.
- `.ready` is not emitted on the Element failure state. A later successful retry emits it.
- The Element failure label is themed, follows Dynamic Type, and is localized. `.failed` for an initial bind is delivered once per failure streak, and SwiftUI re-renders no longer retry a failed bind.
- The loading coin has a localized accessibility label and is announced to VoiceOver.
- Payment Sheet emits `.ready` when the sheet has settled at its form height, instead of when the height animation starts.
- Calling `EmbeddedPayment.updateOrder(intent:)` without an `onEvent` closure keeps the existing event handler instead of replacing it.
- Card 3DS now runs in an `SFSafariViewController` instead of an in-app web view, and stays open until the payment result is known, including when the bank app takes over.
- Apple Pay authentication stays in the Apple Pay sheet.
- The SDK asks the shopper before opening a bank app from the challenge. Redirects to the App Store, enterprise app installs, Settings, and other system links are blocked while the challenge loads.

### Fixed

- Payment Element and Payment Sheet keep their loading cover in place until the card form is in a window with a real size and, when Apple Pay is offered, the PassKit button has committed its backing store plus one display interval. The wait is capped at two seconds.
- In the example app, a fast Pay tap after an amount change could charge the previous order before the new order was bound.
- On iOS 26, Apple Pay buttons are created with card art disabled. The default button paints that art after the rest of the sheet, which left an empty slot above the divider.
- The example Apple Pay sample and `MerchantReadyGate` stay on the loader until the order is bound and the button has drawn. The button is laid out under the cover so PassKit can paint before the gate opens.
- 3DS browser data now reports Safari's user agent, matching the browser that shows the challenge.
- Payment status checks no longer fail on network errors iOS reports after the app returns from the background. Only real client errors (4xx) stop the check early.
- Apple Pay in Payment Sheet and Element now closes the Apple Pay sheet before a 3DS challenge, instead of leaving the challenge hidden and reporting a cancel.
- The payment sheet stays above the keyboard and scrolls the focused field into view.
- An approval in the bank app could be reported as a failure when iOS dropped the status check while the app was in the background. The SDK now retries and checks the payment once more before reporting an error or timeout.
- Closing the challenge after switching to the bank app now waits for the bank's answer instead of reporting a cancel after a few seconds.
- The bank-app waiting screen could be swiped away, leaving the payment stuck with nothing on screen.
- The challenge could fail to appear when the app was already showing another screen, leaving the payment waiting until timeout.
- Payment Element initial bind failures now replace the loading cover with an SDK-authored failure state. A later bind failure throws and does not call the result handler.
- Payment Element could charge an order other than the one on screen when the shopper reverted the cart while an update was in flight.
- `.processing(false)` could be dropped when `PaymentElement.updateOrder { }` was rejected during a charge, leaving the form on “Processing…”.
- A superseded initial `prepare` no longer shows “Failed to load” or emits `.ready`; the newer bind renders the form.
- `PaymentElement.updateOrder { }` before the form exists now locks Pay and supports supersession.
- A Payment Element that is not in a window no longer waits two seconds; the reveal resumes when it enters a window. Order updates on an already revealed form no longer wait for a redraw.

### Breaking changes

- `.ready` is scoped to a mounted surface and is no longer an update-completion signal. It is not emitted on the failure state.
- `EmbeddedEvent` has a new case, `updateFailed`. Exhaustive `switch` statements must handle it.
- A later bind failure locks Pay on the stale order instead of leaving the previous order payable.
- A merchant call with the already-bound intent now supersedes an in-flight update instead of being ignored.
- The `createOrder` closures are `@MainActor` and the methods return `PaymentIntent`.

### Migration

- Keep Element and Apple Pay views mounted at their real size until `.ready`; a remount emits `.ready` again. Handle `.failed` for the initial failure state instead of waiting for `.ready`.
- Treat the async return as update completion and gate controls with `isInteractionEnabled`.
- Handle `CancellationError` when a newer update supersedes an older one, and keep order-creation endpoints idempotent.
- Handle `.updateFailed`: tell the shopper, then call `updateOrder` again. Pay stays locked until a bind succeeds.
- Replace `error.message == "Payment in progress"` checks with `error == .paymentInProgress`.
- Use the intent returned by `updateOrder { }` instead of capturing it from inside the closure.

## [1.0.1] - 2026-09-24

### Fixed

- The Apple Pay sheet could not be closed after a payment result (success or failure), including via its close button: the SDK released the PassKit delegate before `paymentAuthorizationControllerDidFinish` arrived. The handler now stays alive until PassKit has dismissed the sheet.

## [1.0.0] - 2026-09-08

### Changed

- First stable 1.0 release.

## [0.0.3] - 2026-09-02

### Added

- `EmbeddedPayment.updateStyle` / `updateWalletAppearance` (and the same on `PaymentElement`) restyle a mounted Element without remounting
- `ApplePay.availability()` and `isAvailable` / `isReady` to gate the wallet without presenting PassKit

### Changed

- `appearance.borderRadius` / `borderWidth` now apply to card fields and the methods container (omit-defaults 16 / 20); field chrome uses `componentBorder` / `error`.
- Checkout copy and default chrome colors match Android (`sheet.useOtherCard`, dark text `#F7F6F9`, field/container ink alphas).

### Fixed

- VoiceOver labels on condensed card fields, the sheet close button, and the 3DS close button (`sheet.cancel`).

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
