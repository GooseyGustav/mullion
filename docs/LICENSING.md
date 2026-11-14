# Licensing integration (Mullion)

Mullion uses the shared direct-licensing service. **Do not** implement a local or
product-specific license server.

## Sources of truth

- Service implementation: <https://github.com/GooseyGustav/asifthatworks-licensing>
- Contract (request/response shapes, envelope, flows): <https://github.com/GooseyGustav/asifthatworks-licensing/blob/main/docs/COORDINATION.md>
- Shared Swift package: <https://github.com/GooseyGustav/asifthatworks-licensekit> (`LicenseKit`)

## Endpoints

| Environment | Base URL | Service |
|---|---|---|
| Production (frozen) | `https://api.asifthatworks.com` | `127.0.0.1:8090` |
| Staging | `https://staging.api.asifthatworks.com` | `127.0.0.1:8091` (verified locally) |

- `POST /v1/activate`
- `POST /v1/refresh` (returns `410` on revoked/expired)
- `POST /v1/deactivate`
- `POST /v1/recover` (alias `/v1/resend`, always 202)
- `GET /v1/public-key?product=<id>`
- `GET /v1/session/{stripe_session_id}` (success-page lookup)
- `GET /healthz`

Use **staging** for sandbox keys and integration testing.

## Mullion product config

| Field | Value |
|---|---|
| `product` | `mullion` |
| Key prefix | `MULL` |
| Plan | `pro` (one-time, 3 seats, `major: 1`, 14-day trial in app) |
| `kid` | `mull-2026-01` |
| Public key (Ed25519, base64url) | `HLmuY4Pcli5XDVFTwZOe5II4ouW8bNIIZMPaU5dHaO0` |

Embed the public key in the app and verify `LIC1.<payload_b64url>.<signature_b64url>`
over the exact payload bytes. Refresh on `410` means revoked/expired now; network
failure allows 30-day offline grace only.

## Staging sandbox (verified)

- License key: `MULL-9LWFS-U9X3C-RJTN3-8Y37T`
- Seed session: `seed_mullion`, plan `pro`, 3 seats, active
- Verified on staging: `healthz`, `public-key`, session lookup, activate/refresh

**Caveats:** sandbox key is for staging only. Live Stripe test-mode end-to-end
(real test purchase → webhook issuance/email) still depends on the public staging
webhook being reachable and Stripe test products/prices/webhook configured.
Production `8090` service was not changed.

## App URLs

- Product page: <https://asifthatworks.com/mullion>
- Downloads/appcasts: <https://dl.asifthatworks.com/mullion/>
- Recovery page: <https://asifthatworks.com/mullion/activate>
