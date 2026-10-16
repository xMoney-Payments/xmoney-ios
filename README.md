# xMoney Payments — iOS SDK

Native iOS SDK for [xMoney](https://xmoney.com) checkout. Three surfaces, one `PaymentConfig`, one `PaymentResult`.

| Module              | Product                | Use when                                                  |
| ------------------- | ---------------------- | --------------------------------------------------------- |
| **Payment Sheet**   | `XMoneyPaymentSheet`   | Drop-in bottom sheet. SDK owns the UI and the Pay button. |
| **Payment Element** | `XMoneyPaymentElement` | Card, saved cards, and Apple Pay **in your layout**.      |
| **Apple Pay**       | `XMoneyApplePay`       | Standalone wallet button or `present()`.                  |
| **Core**            | `XMoneyCore`           | Pulled in by the surfaces. Do not depend on it directly.  |

```
XMoneyPaymentSheet ──► XMoneyPaymentElement ──► XMoneyCore
                 └──► XMoneyApplePay ───────────┘
```

`XMoneyPaymentElement` does not pull in Apple Pay. Link `XMoneyApplePay` next to it if the embedded form should offer a wallet button, and call `ApplePay.register()` before `prepare`. Payment Sheet registers Apple Pay itself.

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15+ builds the SDK. CI tests with Xcode 26 only; older toolchains compile the pre-iOS 26 Apple Pay button path, which is not tested in CI.

## Installation

Latest release: **`1.1.0`**

### Swift Package Manager

```swift
.package(url: "https://github.com/xMoney-Payments/xmoney-ios.git", from: "1.1.0")
```

Link `XMoneyPaymentSheet` for the drop-in (includes Element + Apple Pay). Or pick surfaces: `XMoneyPaymentElement`, `XMoneyApplePay`.

### CocoaPods

```ruby
pod 'XMoneyPaymentSheet' # default subspec: PaymentSheet
# pod 'XMoneyPaymentSheet', :subspecs => ['PaymentElement']
# pod 'XMoneyPaymentSheet', :subspecs => ['ApplePay']
```

CocoaPods compiles every subspec into one module. Always `import XMoneyPaymentSheet`.

Put only a **publishable** `publicKey` (`pk_test_…` / `pk_live_…`) in the app. Create orders on **your server**. Never ship a secret API key.

## Checkout flow

1. Your backend creates an order and returns `payload` + `checksum`.
2. The app builds a `PaymentIntent` from those two values.
3. You present Sheet, mount Element, or show Apple Pay.
4. The SDK fetches the session token and collects payment. A card 3DS challenge stays open in an `SFSafariViewController` until polling sees a completed payment. The merchant return URL is not used. Apple Pay authentication stays in the Apple Pay sheet.
5. You handle `PaymentResult`. Session tokens are never passed by the merchant.

```swift
let intent = PaymentIntent(
    orderPayload: OrderPayload(payloadFromYourServer),
    orderChecksum: OrderChecksum(checksumFromYourServer)
)
```

## Payment result

Every surface delivers the same type:

```swift
switch result {
case .complete(let transaction): // paid
case .failed(let error):         // error.code / error.message
case .canceled:                  // user dismissed; no error payload
}
```

`failed` messages are SDK-authored. Do not display raw server bodies.

Interim events (`.ready`, `.processing`) are optional and do not replace the result callback.

## Surface lifecycle contract

The iOS and Android SDKs follow the same contract.

1. **Ready.** `.ready` fires once per mounted surface, when the form or wallet
   button first draws, or after the two-second fallback. A wallet that is known
   to be unavailable is a settled state, so `.ready` still fires. It never fires
   on a failure state; if a later retry replaces the failure state with a form,
   `.ready` fires then. Order updates never emit it. Remounting emits it again.
2. **Initial failure.** The surface shows a themed, localized failure state.
   `.failed` is delivered once per failure streak, and direct callers get the
   error thrown. SwiftUI re-renders do not retry a failed bind.
   A merchant loader that waits for Ready must also end on `.failed`. A failed
   first load shows the SDK failure state and emits no Ready. To retry, call
   `updateOrder` with a new or the same order, or remount the surface.
3. **Later bind failure.** If an order is already bound and binding a new one
   fails, Pay stays locked on the stale order (`isInteractionEnabled` is false)
   until a later update succeeds. Element emits `.updateFailed(error)`, and the
   error is thrown to direct callers. The result callback is not called.
   A declarative host that switches back to the bound intent clears the lock;
   a remount does not.
4. **`createOrder` failure.** If your closure throws, the previous order stays
   bound and payable. The error is thrown; no `.updateFailed` is emitted.
5. **Supersession.** The newest merchant call always wins, even when it passes
   the order that is already bound: it cancels any in-flight creation or bind.
   `PaymentElementView` re-asserting the bound intent is a no-op that cancels
   nothing. A superseded call throws `CancellationError`.
6. **During a charge.** The same intent is a no-op. A different intent throws
   `PaymentError.paymentInProgress` (compare with `==`). `PaymentElementView`
   keeps that intent and binds it after `.processing(false)`.
7. **`.processing`** events are never dropped because an update is pending.
8. **`updateOrder { createOrder() }`** locks Pay immediately, runs the closure on
   the main actor, cancels it when the calling task is cancelled, and returns
   the bound intent. Keep order-creation endpoints idempotent.
9. **Binding is two-phase.** A superseded bind never changes the order that Pay
   charges.
10. **Accessibility.** The loader has a localized "Loading" label and is
    announced. Covered form controls are hidden from VoiceOver.

## Surface behavior

| Surface | Ready | Initial failure | Later update failure | Same intent while paying |
| --- | --- | --- | --- | --- |
| Payment Element | After layout and, when offered, the PassKit button has painted, or after two seconds. Not on failure | Failure label and `.failed` (once per streak) | Throws, emits `.updateFailed`; Pay locked on the stale order | No-op |
| Payment Sheet | When the sheet has settled at its form height | `.failed` and the sheet closes | No `updateOrder` | No `updateOrder` |
| UIKit Apple Pay | `present` emits `.ready` after the wallet session binds. The button's own signal is `onFirstDraw` | `present` delivers `.failed` | Throws; `present` is a no-op on the stale order | No-op |

## Order lifecycle

Order checksums are **one-shot**. After a consumed result the bound order cannot be charged again.

| Outcome                                           | Consumes order? | What you do                                  |
| ------------------------------------------------- | --------------- | -------------------------------------------- |
| `.complete`                                       | Yes             | New `PaymentIntent` for another payment      |
| `.failed`                                         | Yes             | New `PaymentIntent`                          |
| `.canceled` **after** pay / 3DS started           | Yes             | New `PaymentIntent`                          |
| Sheet closed **before** pay (header, drag, scrim) | No              | Present the **same** intent again            |
| Apple Pay dismissed **before** authorization      | No              | Present / tap again with the **same** intent |

Embedded and standalone Apple Pay stay mounted after a consumed result; Pay / wallet disable (`isOrderConsumed`). Unmount them, or `prepare` / `present` with a **new** intent.

Payment Sheet dismisses on terminal results (including post-submit cancel). Present again with a new intent.

Use `PaymentSheetEvent.processing` (or `isOrderConsumed` on Element / Apple Pay) to tell pre-pay cancel apart from post-submit cancel.

## Payment Sheet

SDK owns the full checkout UI, including the Pay button (`SubmitButtonConfig.visible` is ignored).

**UIKit**

```swift
import XMoneyPaymentSheet

let sheet = PaymentSheet(
    configuration: PaymentConfig(
        publicKey: "pk_test_…",
        paymentMethods: .init(applePay: .init(enabled: true)),
        card: .init(savedCards: .init(enabled: true))
    )
)

sheet.present(from: self, intent: intent) { result in
    // PaymentResult
}

sheet.dismiss() // optional; idle close still cancels
```

**SwiftUI**

```swift
Button("Pay") { showSheet = true }
    .paymentSheet(
        isPresented: $showSheet,
        configuration: configuration,
        intent: intent
    ) { result in
        // PaymentResult
    }
```

While idle, the sheet can be dragged closed. Drag, X, and scrim lock while a charge is in flight. `dismiss()` waits for an in-flight charge; idle close still cancels.

Copy-paste sample: [`PaymentSheetSampleView.swift`](Examples/Example/Samples/PaymentSheetSampleView.swift)

## Payment Element

Same form as the sheet, without the bottom-sheet chrome. Mount it in your layout. Embedded does not add outer content padding or a page fill — the host background shows through; supply your own page spacing.

```swift
import XMoneyPaymentElement
import XMoneyApplePay // required for wallet in Embedded

ApplePay.register()

let embedded = EmbeddedPayment(configuration: configuration) { result in
    // PaymentResult
}

let element = PaymentElement(payment: embedded)
view.addSubview(element)
// Merchant owns page spacing, e.g. 20pt horizontal insets.
try await element.prepare(intent: intent)
```

After `.complete` / `.failed` / post-submit `.canceled`, hide the element (or prepare a new intent). Pre-pay cancel does not consume — keep it mounted.

SwiftUI: `PaymentElementView(payment:intent:onEvent:)`.

### Update the order

`EmbeddedPayment.updateOrder` rebinds a new signed `PaymentIntent` on the mounted Element. Pay, `confirm()`, and Apple Pay are no-ops until it returns (`isInteractionEnabled` is false). A newer `updateOrder` cancels the in-flight one. The Pay button keeps its current title; it does not show “Processing...”. If the bind fails, Pay stays locked on the stale order and the Element emits `.updateFailed`; call `updateOrder` again to recover.

```swift
try await embedded.updateOrder(intent: next)
```

When the shopper changes the cart, pass the server call instead. Pay is locked immediately, including while your server creates the order, so a fast tap cannot charge the previous order. The closure runs on the main actor and returns the bound intent; pass it to your host. If the closure throws, the previous order stays bound and payable:

```swift
let bound = try await embedded.updateOrder {
    let (payload, checksum) = try await backend.createOrder(cart)
    return PaymentIntent(
        orderPayload: OrderPayload(payload),
        orderChecksum: OrderChecksum(checksum)
    )
}
```

`PaymentElement` / `PaymentElementView` call `updateOrder` when `intent` changes. Keep the surface mounted; do not set the intent to `nil` or swap the form for a loader. Keep merchant loading until `.ready` or a `.failed` result; a failed first load shows the SDK failure label and emits no `.ready`. Do not bring the loader back when you retry: a repeat failure in the same streak does not deliver `.failed` again. `.ready` fires once, after the form has laid out and, when Apple Pay is offered, the wallet button has drawn. Until then, Payment Element covers partial paint with `CheckoutTheme.background`. A later `updateOrder` does not emit it again. Gate a merchant-owned Pay button with `embedded.isInteractionEnabled`.

Copy-paste sample: [`UpdateOrderSampleView.swift`](Examples/Example/Advanced/UpdateOrderSampleView.swift)

### Live appearance

Keep `EmbeddedPayment` across appearance changes. Call `updateAppearance` / `updateStyle` / `updateLocale` / `updateWalletAppearance` instead of recreating `PaymentConfig`:

```swift
embedded.updateAppearance(appearance)
embedded.updateStyle(style)
embedded.updateWalletAppearance(wallet)
embedded.updateLocale(locale)
```

`PaymentElement` / `PaymentElementView` apply those updates to the mounted form. Payment Sheet snapshots config at `present()` — pass appearance on `PaymentConfig` and present again to replace an idle sheet.

### Merchant-owned Pay button

Embedded only. Hide the SDK button and call `confirm()` after `.ready`. End your loader on `.failed` too:

```swift
let configuration = PaymentConfig(
    publicKey: "pk_test_…",
    card: .init(submitButton: .init(visible: false))
)

let embedded = EmbeddedPayment(configuration: configuration) { result in
    // First-load failure: show the SDK failure label.
    if case .failed = result { ready = true }
}

let element = PaymentElement(payment: embedded) { event in
    if case .ready = event { ready = true }
}

// Your CTA:
embedded.confirm() // or element.confirm()
```

`confirm()` submits the currently selected method (new card or saved card). Apple Pay still uses the wallet button. `isInteractionEnabled` is false during `updateOrder` and while a charge is in flight. `EmbeddedEvent.processing` is the in-flight charge only.

Copy-paste sample: [`EmbeddedPaymentSampleView.swift`](Examples/Example/Samples/EmbeddedPaymentSampleView.swift) · Merchant CTA: [`MerchantPayButtonSampleView.swift`](Examples/Example/Advanced/MerchantPayButtonSampleView.swift) · Update order: [`UpdateOrderSampleView.swift`](Examples/Example/Advanced/UpdateOrderSampleView.swift)

## Apple Pay

**UIKit**

```swift
import XMoneyApplePay

let applePay = ApplePay(configuration: configuration) { result in
    // PaymentResult
}

let flags = try await applePay.availability(intent: intent)
if flags.isAvailable && flags.isReady {
    applePay.present(from: self, intent: intent)
}

applePay.dismiss() // closes PassKit before authorize; no-op during token submit / 3DS

let button = ApplePayButton()
button.onTap = { applePay.present(from: self, intent: intent) }
button.onFirstDraw = { /* PassKit mark is on screen */ }
```

`onFirstDraw` also exists on `ApplePayButtonView`. It runs once the button has painted (or after a short wait if it never does), and again after an appearance change rebuilds the button or the button moves to a new window. Keep your own loader up until the first call.

**SwiftUI**

```swift
ApplePayButtonView {
    applePay.present(from: presenter, intent: intent)
}
```

After `availability` or `updateOrder`, gate your own chrome with the same flags:

```swift
applePay.isAvailable  // site / config allows Apple Pay
applePay.isReady      // PassKit can make payments on this device
applePay.isInteractionEnabled  // false during updateOrder, while paying, and on a stale order
applePay.isOrderConsumed
```

When the cart changes, call `applePay.updateOrder { try await backend.createOrder(cart) }`. From that call until the new order is bound, `present` is a no-op. `ApplePay` is not observable, so the wallet button does not grey out on its own: read `isInteractionEnabled` when you render, and again after `updateOrder` returns.

Pre-auth dismiss delivers `.canceled` and does **not** consume. Present or tap again with the same intent.

### Setup

1. Enable Apple Pay: `paymentMethods: .init(applePay: .init(enabled: true))`.
2. Link `XMoneyApplePay` (Payment Sheet already does). For Embedded, call `ApplePay.register()` before `prepare`.
3. Create a Merchant ID in [Apple Developer](https://developer.apple.com/account/resources/identifiers/list/merchant).
4. In Xcode: app target → **Signing & Capabilities** → **Apple Pay** → add that Merchant ID.
5. The Merchant ID must match `merchantId` from xMoney wallet params. xMoney stores the Payment Processing certificate.
6. Test on a **physical device** with a card in Wallet.

Copy-paste sample: [`ApplePaySampleView.swift`](Examples/Example/Samples/ApplePaySampleView.swift)

## Configuration

```swift
PaymentConfig(
    publicKey: "pk_test_…",
    paymentMethods: .init(
        applePay: .init(
            enabled: true,
            appearance: .init(color: .black, radius: 12, type: .pay)
        )
    ),
    card: .init(
        savedCards: .init(enabled: true, optInVisible: true),
        validationMode: .onTouched,
        inputs: .init(grouping: .condensed),
        submitButton: .init(
            visible: true,  // Embedded only
            type: .pay      // book, buy, checkout, donate, …
        )
    ),
    options: .init(
        locale: "en-US",    // UI language + pay-button amount punctuation
        style: .automatic,
        appearance: .init(
            borderRadius: 12,  // card fields + methods container
            primaryButton: .init(borderRadius: 12)
        )
    )
)
```

**Card validation** (`card.validationMode`, default `onTouched`):

| Mode        | When errors show                                                     |
| ----------- | -------------------------------------------------------------------- |
| `onTouched` | None while first typing; on blur; then live. After Pay, always live. |
| `onChange`  | Live from the first keystroke                                        |
| `onBlur`    | On blur; frozen until the next blur (live after Pay)                 |
| `onSubmit`  | On Pay (then live)                                                   |

Pay uses current field validity. Cardholder name is always collected.

**Appearance** — pass `colorsLight` / `colorsDark` so the form matches your chrome. Card fields (condensed box and spaced inputs) use `appearance.borderRadius` (default 16 pt), `appearance.borderWidth`, and `colors.componentBorder`. The methods container shares the radius (omit-default 20 pt). Pay button radius comes from `appearance.primaryButton.borderRadius` (default a pill, `9999`). Pass `12` for a squircle. On a mounted Element, call `updateAppearance` / `updateStyle` / `updateWalletAppearance`. See [`exampleAppearance()`](Examples/Example/SampleHelpers.swift) for a copy-paste palette.

**Locale** — `options.locale` sets UI copy and pay-button amount punctuation. Supported languages: `en`, `el`, `ro`, `bg`, `hu`, `pl`. Region tags (`en-US`, `pl-PL`) work; unknown languages fall back to English.

## Card holder verification

Optional pre-pay name check. Requires the site to have name-check validation enabled.

```swift
card: .init(
    cardHolderVerification: CardHolderVerification(
        name: CardHolderName(firstName: "John", lastName: "Doe"),
        onCardHolderVerification: { result in
            result.status == .matched
        }
    )
)
```

Return `true` to continue pay, `false` to block. Sample: [`CardHolderVerificationSampleView.swift`](Examples/Example/Advanced/CardHolderVerificationSampleView.swift)

## Public API

Use only these merchant-facing types:

| Surface         | Types                                                                                                                                                                              |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Config / models | `PaymentConfig` and nested options, `PaymentIntent` / `OrderCredentials` / `OrderPayload` / `OrderChecksum`, `PaymentResult`, `PaymentError`, `Transaction`                        |
| Payment Sheet   | `PaymentSheet`, `.paymentSheet`, `PaymentSheetEvent`                                                                                                                               |
| Payment Element | `PaymentElement`, `PaymentElementView`, `EmbeddedPayment` (`updateOrder`, `confirm`, `updateAppearance`, `updateStyle`, `updateLocale`, `updateWalletAppearance`), `EmbeddedEvent` |
| Apple Pay       | `ApplePay` (`availability`, `present`, `updateOrder`, `dismiss`), `ApplePayAvailability`, `ApplePayButton`, `ApplePayButtonView`, `ApplePayEvent`                                  |

Everything else (HTTP, services, 3DS host, form views, theme helpers) is library-internal.

## Example app

In-repo demo: copy-paste Integrations (Sheet / Element / Apple Pay, UIKit and SwiftUI), Lumen / Hearth / Pulse stores, merchant CTA / `updateOrder` / name-check, and an internal playground. See [`Examples/README.md`](Examples/README.md) for the launcher map, secrets, and consumption notes.

```bash
cp Examples/Secrets.xcconfig.example Examples/Secrets.xcconfig
# PUBLIC_KEY, API_KEY, API_HOST, CURRENCY, DESCRIPTION
```

Open **`Examples/Example.xcodeproj`** and run **Example**. Start with **Payment Sheet**, **Embedded Payment Element**, then **Apple Pay**.

The example talks to a demo backend with `API_KEY` in the app. **Do not ship that pattern.** Production apps hold only `publicKey`; your server returns `payload` + `checksum`.

## Testing

```bash
scripts/xcode-ios-test.sh
```

Contract tests read `Tests/XMoneyCoreTests/test-vectors.json`.

## Support

- Releases: [CHANGELOG.md](CHANGELOG.md)
- Security: [SECURITY.md](SECURITY.md) — report vulnerabilities to **it-support@xmoney.com**, not a public issue
- License: [MIT](LICENSE)
