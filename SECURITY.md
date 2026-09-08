# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.0.x   | Yes       |

## Reporting a vulnerability

Do **not** open a public GitHub issue for security vulnerabilities.

Email **it-team@xmoney.com** with:

- a clear description of the issue
- steps to reproduce
- impact (what an attacker could do)

Expect an initial response within **5 business days**. We will coordinate a fix and disclosure.

## Scope

This policy covers the published SDK modules in this repo: `XMoneyCore`, `XMoneyApplePay`, `XMoneyPaymentElement`, and `XMoneyPaymentSheet`.

Issues in merchant apps, backends, or non-SDK xMoney products are out of scope here — contact your xMoney account team.

## Hard rules for integrators

- Put only the publishable `publicKey` (`pk_test_…` / `pk_live_…`) in the iOS app.
- Keep secret / private API keys on your server. Create orders server-side.
- Never commit live keys, order payloads with secrets, or card data to source control.
- Use sandbox keys during development.
- Do not log PAN or CVV. The SDK does not; report any suspected leakage of card data immediately.

## Card data (reality)

Native card entry collects PAN + CVV in memory and sends them over HTTPS to xMoney’s PCI DSS Level 1 backends (`secure*.xmoney.com` for payment; `api-*-next.xmoney.com` for optional account validation).

## TLS / certificate pinning

All SDK network calls use HTTPS to hardcoded xMoney hosts only (no cleartext, no merchant-supplied base URLs).

Certificate pinning is **not** implemented in the SDK. For v1.0.x we **accept** the residual risk that a compromised device trust store could enable MITM. Revisit pinning if the threat model or merchant compliance requirements change.
