# Licensing integration (Mullion)

Mullion uses the shared direct-licensing service. **Do not** implement a local or
product-specific license server.

## Sources of truth

- Service implementation: <https://github.com/GooseyGustav/asifthatworks-licensing>
- Contract (request/response shapes, envelope, flows): <https://github.com/GooseyGustav/asifthatworks-licensing/blob/main/docs/COORDINATION.md>
- Shared Swift package: <https://github.com/GooseyGustav/asifthatworks-licensekit> (`LicenseKit`)

## Endpoints

| Environment | Base URL | Service | Notes |
|---|---|---|---|
| Production (frozen) | `https://api.asifthatworks.com` | `127.0.0.1:8090` | **Mullion 1.0.0 direct-download builds use production** (`POST /v1/activate|refresh|deactivate`, `license_key`, `install_id`, `app_version`, `os_version`). Confirm real service cutover before distributing. |
| Staging | `https://staging.api.asifthatworks.com` | `127.0.0.1:8091` | **Live** — use for integration/sandbox testing and activation verification with test keys. |

- `POST /v1/activate`
- `POST /v1/refresh` (returns `410` on revoked/expired)
- `POST /v1/deactivate`
- `POST /v1/recover` (alias `/v1/resend`)
- `GET /v1/public-key?product=<id>`
- `GET /v1/session/{stripe_session_id}` (success-page lookup)
- `GET /healthz`
- `POST /webhooks/stripe`

Envelope: `LIC1.<payload_b64url>.<signature_b64url>` (Ed25519 over the exact payload
bytes). Verify with the product public key. 30-day offline grace on network failure.

**Activate request**
```json
{
  "license_key": "MULL-XXXXX-XXXXX-XXXXX-XXXXX",
  "install_id": "<random 64 hex stored in Keychain>",
  "device_name": "optional",
  "os_version": "15.1",
  "app_version": "0.2.0"
}
```

**Activate response**
```json
{
  "token": "LIC1....",
  "license": {
    "id": "lic_...",
    "product": "mullion",
    "plan": "pro",
    "status": "active",
    "seats": 3,
    "activations": 1,
    "major": 1,
    "expires_at": null,
    "issued_at": "2026-11-13T20:11:10Z"
  },
  "billing_url": null
}
```

## Mullion product config

| Field | Value |
|---|---|
| `product_id` | `mullion` |
| Key prefix | `MULL` |
| Bundle ID | `com.kyanhpham.mullion` |
| URL scheme | `mullion://` |
| Trial | 14 days |
| Plan | `pro` (one-time, €11.11, 3 seats, `major: 1`) |
| `kid` | `mull-2026-01` |
| Public key (Ed25519, base64url) | `HLmuY4Pcli5XDVFTwZOe5II4ouW8bNIIZMPaU5dHaO0` |

Embed the public key in the app and verify `LIC1.<payload_b64url>.<signature_b64url>`
over the exact payload bytes. Refresh on `410` means revoked/expired now; network
failure allows 30-day offline grace only.

## Staging sandbox (verified)

- License key (staging only): `MULL-9LWFS-U9X3C-RJTN3-8Y37T`
- Seed session: `seed_mullion`, plan `pro`, 3 seats, active
- Verified on staging: `healthz`, `public-key`, session lookup, activate/refresh

**Do not ship sandbox keys in a real build.** Test activation, refresh, deactivate,
wrong product, wrong key, seat limit, revoked `410`, and offline grace.

**Caveats:** Production `8090` is still a placeholder (DNS/TLS live). Live Stripe
test-mode end-to-end (real test purchase → webhook issuance/email) depends on the
test webhook pointing at `https://staging.api.asifthatworks.com/webhooks/stripe`
(or production once live) and Stripe test products/prices/webhook being configured;
sandbox keys work without it.

## App URLs

- Product page: <https://asifthatworks.com/mullion>
- Downloads/appcasts: <https://dl.asifthatworks.com/mullion/>
- Recovery page: <https://asifthatworks.com/mullion/activate>
