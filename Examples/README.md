# xMoney iOS example app

In-repo demo for the SDK. One Xcode app, a launcher, copy-paste samples, three merchant scenarios, and an internal playground.

Sun/moon toggle for **light / dark** (saved across Integrations, Advanced, and Playground). Scenario stores hide it and use their own accent. Samples pass a matching `AppearanceConfig` (`colorsLight` / `colorsDark`) so the SDK form sits on the merchant page instead of the library defaults.

## Run

```bash
cp Examples/Secrets.xcconfig.example Examples/Secrets.xcconfig
# Fill PUBLIC_KEY, API_KEY, API_HOST, CURRENCY, DESCRIPTION
# Use a hostname only (demo.xmoney.com). Do not write https:// — xcconfig treats // as a comment.
# Optional: MERCHANT_IDENTIFIER for Apple Pay
```

Open **`Examples/Example.xcodeproj`** in Xcode and run **Example**. The app links the local Swift package at the repo root (`XMoneyPaymentSheet`, `XMoneyPaymentElement`, `XMoneyApplePay`). Leave `DEVELOPMENT_TEAM` empty and pick your team in Signing.

Apple Pay only authorizes on a **physical device**. Add the Merchant ID under Signing & Capabilities; it must match xMoney wallet params. Simulator shows a banner instead of a working PassKit sheet.

## Launcher

| Section | Screen | What it is |
|---|---|---|
| Integrations | Payment Sheet | Drop-in sheet — copy this first. UIKit / SwiftUI toggle. |
| Integrations | Embedded Payment Element | Form in your layout. Call `ApplePay.register()` before `prepare`. |
| Integrations | Apple Pay | Standalone wallet button. UIKit `present(from:)` needs a presenter VC. |
| Example app | Lumen shop | Lifestyle catalog → cart → Payment Sheet |
| Example app | Hearth Café | Café menu → cart → Embedded Element |
| Example app | Pulse Studio | Memberships → cart → Embedded Element |
| Advanced | Merchant Pay button | Embedded form, your CTA via `confirm()` |
| Advanced | Update order | `updateOrder` a new `PaymentIntent` on a mounted Element |
| Advanced | Card holder verification | Pre-pay name check |
| Internal | Playground | Every option, for SDK development |

Integrations and name-check include a **Test cards** sheet with the four xMoney simulator PANs (copy PAN / expiry / CVV / 3DS, success and fail). Playground **Appearance** is the live `AppearanceConfig` editor — presets plus colors, radii, Pay button, and font. Integration samples stay on `exampleAppearance()` so copy-paste still matches merchant chrome.

## Backend warning

[`DemoCheckoutBackend`](Example/Backend/DemoCheckoutBackend.swift) sends `API_KEY` to the public demo server so this app can create orders without a merchant backend.

**Do not copy that into production.** The iOS app should hold only `publicKey`. Your server creates the order and returns `payload` + `checksum`. The samples build `PaymentIntent` from those two values.

## Copy-paste notes

- Integrations samples **inline** `PaymentConfig` (`publicKey`, Apple Pay, saved cards, optional `options.appearance`). Do not copy `defaultPaymentConfig()` — that helper is for the stores and playground.
- After `complete`, `failed`, or post-submit `canceled`, the order checksum is **consumed**. Create a new intent before paying again.
- Closing Payment Sheet **before** pay does not consume; present the same intent (**Continue**).
- Embedded / Apple Pay: keep merchant loading until `.ready`. Branch on `isOrderConsumed` after that. Pre-auth Apple Pay dismiss delivers `canceled` and does not consume — present or tap again with the same intent.
- Payment Sheet: keep the merchant Pay button loading until `.ready`. Samples use `PaymentSheetEvent.processing` to tell pre-pay cancel apart from post-submit cancel.
- After a consumed result, samples hide the payment UI and show **New payment**.
- To change the amount on a mounted Element, `updateOrder` with a new `PaymentIntent`. Do **not** set the intent to `nil` or hide the form. Hearth, Pulse, and Update order do this; `PaymentElementHost` calls `updateOrder` when the payload/checksum changes. Pay stays locked (`isInteractionEnabled`) with its current title — `Processing` is an in-flight charge only. The form stays on screen. Playground Sheet mints a new intent when the amount stepper changes so Pay matches.
- Call `updateAppearance` / `updateLocale` when you restyle a live Element. Playground Appearance writes `AppearanceConfig` and the live Element picks it up. There is no public `updateStyle` / `updateWalletAppearance` — remount the controller when style or wallet appearance changes.
- [`exampleAppearance()`](Example/SampleHelpers.swift) is the appearance copy-paste — restyle Sheet / Element / Apple Pay to match your chrome.
- Cart amounts are **minor units** (`Int64` cents). The demo backend converts to a decimal only at the HTTP boundary.
- Do not put `PaymentElementView` in an unbounded `ScrollView` on iOS 15 (`sizeThatFits` is iOS 16+). Give it a `minHeight` or host `PaymentElement` in Auto Layout (see [`PaymentElementHost`](Example/UI/PaymentElementHost.swift)).
- Do not present Payment Sheet from inside a SwiftUI `.sheet`. This app pushes full-screen destinations.
