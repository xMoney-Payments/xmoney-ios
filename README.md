# xMoney iOS SDK

Native payments SDK for iOS apps integrating with [xMoney](https://xmoney.com). Accept card payments and Apple Pay with a Stripe PaymentSheet-style experience.

Types are unprefixed (`PaymentSheet`, `PaymentConfig`, `PaymentIntent`), matching Android. Modules keep the `XMoney` brand, matching Stripe iOS (`import StripePaymentSheet` → `PaymentSheet`). Apps that also import Stripe disambiguate as `XMoneyPaymentSheet.PaymentSheet`.

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/xMoney-Payments/xmoney-ios.git", from: "0.0.1")
```

Link the product you need:

| Product | Use when |
|---------|----------|
| `XMoneyCore` | Models and configuration |
| `XMoneyApplePay` | Standalone Apple Pay button / present API |
| `XMoneyPaymentElement` | Merchant-hosted Payment Element in your layout |
| `XMoneyPaymentSheet` | Drop-in bottom sheet (hosts the Payment Element) |

```
XMoneyPaymentSheet ──► XMoneyPaymentElement ──► XMoneyCore
                 └──► XMoneyApplePay ───────────┘
```

Card-only Element does not link Apple Pay. For Apple Pay inside the Element, also link `XMoneyApplePay` and call `ApplePay.register()` before `prepare` (Payment Sheet registers automatically).

### CocoaPods

```ruby
pod 'XMoneyPaymentSheet', :subspecs => ['PaymentSheet']
```

| Subspec | Use when |
|---------|----------|
| `Core` | Models and configuration |
| `ApplePay` | Standalone Apple Pay button / present API |
| `PaymentElement` | Merchant-hosted Payment Element in your layout |
| `PaymentSheet` | Drop-in bottom sheet (default; hosts the Payment Element) |

Always `import XMoneyPaymentSheet`. CocoaPods compiles every subspec into that one module — there is no `XMoneyApplePay` or `XMoneyPaymentElement` module. Samples below use SPM product names; on CocoaPods, use `import XMoneyPaymentSheet` instead.

## Quick start — Payment Sheet (UIKit)

```swift
import XMoneyPaymentSheet

let configuration = PaymentConfig(
    publicKey: "pk_test_…",
    paymentMethods: .init(applePay: .init(enabled: true))
)

let intent = PaymentIntent(
    orderPayload: OrderPayload(orderPayloadFromBackend),
    orderChecksum: OrderChecksum(orderChecksumFromBackend)
)

let paymentSheet = PaymentSheet(configuration: configuration)
paymentSheet.present(from: self, intent: intent) { result in
    switch result {
    case .complete(let transaction):
        print("Paid:", transaction.id ?? "")
    case .failed(let error):
        print("Failed:", error.code, error.message)
    case .canceled:
        print("Canceled") // no error payload
    }
}
```

## Quick start — SwiftUI

```swift
import SwiftUI
import XMoneyPaymentSheet

struct CheckoutView: View {
    @State private var showSheet = false

    var body: some View {
        Button("Pay") { showSheet = true }
            .paymentSheet(
                isPresented: $showSheet,
                configuration: configuration,
                intent: intent
            ) { result in
                // handle result
            }
    }
}
```

If the app also imports Stripe’s PaymentSheet, use the module-qualified type `XMoneyPaymentSheet.PaymentSheet`. SwiftUI also exports StoreKit’s `Transaction`; qualify ours as `XMoneyCore.Transaction` (SPM) or `XMoneyPaymentSheet.Transaction` (CocoaPods) when the type is written explicitly.

## Standalone Apple Pay

CocoaPods: `import XMoneyPaymentSheet` instead of `XMoneyApplePay`.

```swift
import XMoneyApplePay

let applePay = ApplePay(configuration: configuration) { result in
    // handle result
}
applePay.present(from: self, intent: intent)

// Or embed a button:
let button = ApplePayButton()
button.onTap = { applePay.present(from: self, intent: intent) }
```

## Embedded Payment Element

Same methods as the sheet (Apple Pay, saved cards, new card), hosted in your layout:

CocoaPods: `import XMoneyPaymentSheet` instead of `XMoneyPaymentElement` / `XMoneyApplePay`.

```swift
import XMoneyPaymentElement
import XMoneyApplePay // if you want Apple Pay in the Element

ApplePay.register() // required for Element + Apple Pay; Payment Sheet does this itself

let embedded = EmbeddedPayment(configuration: configuration) { result in
    // handle result
}

let element = PaymentElement(payment: embedded)
view.addSubview(element)
// …
try await element.prepare(intent: intent)
```

SwiftUI: `PaymentElementView(payment:intent:onEvent:)`.

## Card holder verification

Optional pre-payment name check (requires site `nameCheckValidationEnabled`):

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

## After payment (Embedded / standalone Apple Pay)

Order checksums are **one-shot**. After `complete`, `failed`, or post-submit `canceled` (including 3DS abandon after pay):

- The SDK marks the session consumed (`isOrderConsumed`) and disables Pay / Apple Pay.
- The element stays mounted until you unmount it or navigate away.
- Call `prepare` / `present` with a **new** `PaymentIntent` to accept another payment.
- Closing Payment Sheet **before** pay (header cancel) does not hit the API; present again with the same intent if you still need it. After pay starts, abandon/cancel requires a new order.

Payment Sheet dismisses on terminal results; present again with a new intent for another checkout.

## Modules

```
XMoneyCore
├── PaymentConfig, PaymentIntent, OrderPayload, OrderChecksum, PaymentResult, PaymentError, Transaction
└── Engine, PaymentSession, networking, validators (package / internal)

XMoneyApplePay
├── ApplePay / ApplePayButton / ApplePayEvent
└── Wallet orchestration

XMoneyPaymentElement
├── EmbeddedPayment / PaymentElement / EmbeddedEvent
└── Shared payment form, theme, 3DS UI

XMoneyPaymentSheet
├── PaymentSheet / PaymentSheetEvent
├── SwiftUI `.paymentSheet`
└── Hosts the Payment Element form
```

## Examples

Sample apps live under `Examples/`:

- `UIKitExample` — UIKit payment sheet
- `SwiftUIExample` — SwiftUI `.paymentSheet` modifier

Open either folder in Xcode via **File → Open** and select `Package.swift`.

## Apple Pay setup

1. Enable Apple Pay in configuration: `paymentMethods: .init(applePay: .init(enabled: true))`
2. Link SPM product `XMoneyApplePay` or CocoaPods subspec `ApplePay` (Payment Sheet already does). For Embedded, call `ApplePay.register()` before `prepare`.
3. Create a **Merchant ID** in [Apple Developer](https://developer.apple.com/account/resources/identifiers/list/merchant).
4. In Xcode: app target → **Signing & Capabilities** → **Apple Pay** → add that Merchant ID.
5. Merchant ID must match `merchantId` from `GET /api/v1/digital-wallet/applePay/params`.
6. xMoney stores the Payment Processing certificate on the backend.
7. Test on a **physical device** with a card in Wallet.

## Testing

```bash
scripts/xcode-ios-test.sh
```

Contract tests consume `Tests/XMoneyCoreTests/test-vectors.json`, shared with the Android SDK.

## Privacy

The SDK ships `PrivacyInfo.xcprivacy` (SPM resource on `XMoneyCore`, CocoaPods resource bundle). It does not perform tracking. Device language, screen size, timezone, and a synthetic user-agent are sent with payment requests as 3DS browser fingerprint fields.

## License

MIT — see LICENSE.
