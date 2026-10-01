# Production DeePay Trusted Callback Policy

Date: 2026-08-13

Status: enabled by owner authorization because DeePay cannot add an HMAC or
callback token to its existing third-party notification contract.

## Compensating Controls

- The dedicated callback ingress allows only `159.65.135.215/32`, the source
  observed for the production DeePay callback on 2026-08-13.
- The application independently requires the same source IP from the
  ingress-overwritten `X-Forwarded-For` header.
- A callback can settle only a DeePay bill whose transaction reference was
  already returned by the successful bill API response.
- The provider transaction ID, `reference1`, and `reference2` must match the
  stored bill attempt. Optional reference, amount, currency, and status fields
  are rejected when present with conflicting values.
- A callback cannot bind an unknown transaction reference, revive a confirmed
  cancellation, or post the same wallet credit more than once.

## Operations

The trusted source is configured in both locations and must remain identical:

```text
deploy/digitalocean/deepay-webhook-ingress.yaml
DEEPAY_KBANK_CALLBACK_TRUSTED_IPS in deploy/digitalocean/configmap.yaml
```

If DeePay rotates its callback address, verify the new address from provider
evidence before changing either allowlist. Do not add broad DigitalOcean CIDR
ranges. A cryptographically authenticated callback or provider inquiry API
should replace this policy if DeePay makes one available.
