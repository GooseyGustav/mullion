# Release contract — asifthatworks.com, Mullion, Fat Cat Pomodoro

> Read this before changing the website, the license service, or either app.
> If a decision here is wrong, change this file in a PR. Do not diverge silently.

Status: v1, 13 Nov 2026.

This supersedes the hosting and hostname sections of `docs/WEBSITE.md`. The copy,
page structure, and visual direction in that file are still valid; the domain,
paths, and deployment model are revised here.

## 0. Decisions locked

| Decision | Value |
|---|---|
| Studio / catalog host | `asifthatworks.com` (already live) |
| Mullion page | `asifthatworks.com/mullion` (canonical) |
| Catalog | `asifthatworks.com/apps` |
| Fat Cat page | `asifthatworks.com/fatcatpomodoro` (already live) |
| Shared license API | `api.asifthatworks.com` |
| Downloads and appcasts | `dl.asifthatworks.com` |
| Admin dashboard | `admin.asifthatworks.com` |
| Checkout | Stripe Payment Links (not server-created Checkout) |
| Second app | Fat Cat Pomodoro |
| Own product domains | deferred; `dl.` makes moving safe later |
| Portfolio | `portfolio.asifthatworks.com`, untouched |

## 1. Where we are

| Thing | State |
|---|---|
| Main site | live at `https://asifthatworks.com` |
| Fat Cat page | live at `https://asifthatworks.com/fatcatpomodoro` |
| Mullion repo | `github.com/GooseyGustav/mullion`, `main` at `b7fa765` |
| Mullion app | builds; waiting for TCC grants and the Apple notary agreement |
| License service | `server/` started; only `internal/license/key.go` exists |
| Website output | not in this repo; `web/` does not exist on `main` |
| Fat Cat source | separate project folder `IslandBar` |

The repo is the only shared state between the website agent and the app/licensing
agent. Push early, even a skeleton. Neither agent edits the other's directories.

## 2. Topology

```
asifthatworks.com            catalog, Mullion page, Fat Cat page, legal
www.asifthatworks.com        301 → apex
dl.asifthatworks.com         DMGs, appcasts, latest.json (static, immutable)
api.asifthatworks.com        license API, Stripe webhook, portal (Go on 127.0.0.1:8080)
admin.asifthatworks.com      dashboard (same Go binary, basic auth + allowlist)
portfolio.asifthatworks.com  existing portfolio, untouched
```

Why this shape:

- `api.` is product-neutral and **frozen**. Binaries embed it; it must never move.
  `licenses.asifthatworks.com` may 301 to it during transition, but the app uses
  `api.` only.
- `dl.` is separate from marketing, so the Mullion page can move or be redesigned
  without breaking shipped appcasts or download URLs.
- `mullion.app` is **not ours** — ignore it. Mullion lives at
  `asifthatworks.com/mullion`. If a product domain is purchased later, it is a 301
  and the artifacts stay on `dl.`.
- Fat Cat stays at `asifthatworks.com/fatcatpomodoro`; the catalog links to both.
- One VPS, one Caddy/nginx, one Go process, one SQLite database, one dashboard for
  every product. A new app is a product row, a price, a Payment Link, a page, and a
  build.

### URL map

| URL | What |
|---|---|
| `https://asifthatworks.com/mullion` | Mullion product page |
| `https://asifthatworks.com/mullion/download` | version, checksum, requirements, download button |
| `https://asifthatworks.com/mullion/changelog` | release notes |
| `https://asifthatworks.com/mullion/activate` | activate, recover a key, deactivate a Mac |
| `https://asifthatworks.com/mullion/thanks` | post-checkout confirmation ("check your email") |
| `https://asifthatworks.com/apps` | catalog of shipped apps |
| `https://asifthatworks.com/fatcatpomodoro` | existing page, updated with pricing and App Store button |
| `https://asifthatworks.com/privacy` `/terms` `/refunds` `/imprint` | global legal, one entity; linked from every product page |

Optional later: `mullion.asifthatworks.com` or a purchased product domain, served
from the same static root or redirected with a 301. If added, `api.` and `dl.` do
not move.

## 3. Checkout — Payment Links, not server-created Checkout

One Stripe Payment Link per price. The static page links to it. No Stripe.js, no
card form, no server in the purchase path.

Why:

- If the VPS or license service is down, Stripe still takes the payment and retries
  the webhook for up to 3 days. With server-created Checkout, a down VPS means no
  sales.
- Card data never touches the site, so the CSP stays tight.
- Coupons, tax, Apple Pay, SEPA, and local payment methods come from Stripe.
- Multi-product is just multiple links, not multiple checkout implementations.
- The webhook must exist anyway to issue keys, so this adds no server code.

Server-created Checkout is **not unsafe** — the card form is still Stripe-hosted.
It simply puts the VPS in the critical path and buys nothing at this scale.

The server still owns:

- the webhook (signature verification, idempotency, fulfilment)
- `/portal?t=` → Stripe Customer Portal for subscriptions
- activation, refresh, deactivation, recovery

Payment Link settings, exactly:

- `client_reference_id` = `<product_id>:<plan_id>` (e.g. `mullion:pro`)
- metadata: `product_id`, `plan_id`, `seats`, `channel=direct`
- success URL: `https://asifthatworks.com/<product>/thanks?session_id={CHECKOUT_SESSION_ID}`
- cancel URL: the product page
- collect name + email, Stripe Tax on, promotion codes on, receipts on

The webhook resolves the plan in this order: `client_reference_id`, metadata, then
`price_id` in the `prices` table. Renewal invoices resolve by
`subscription.items[0].price.id`, because `client_reference_id` is not carried on
renewals.

## 4. Ownership

| Surface | Owner | Where |
|---|---|---|
| asifthatworks.com, `/mullion`, `/apps`, legal copy | website agent | existing site repo and pipeline |
| `docs/WEBSITE.md` copy and design brief | website agent | this repo |
| `server/`, `deploy/`, Caddy blocks for new hosts | app agent | this repo |
| Mullion app | app agent | this repo |
| Fat Cat app | app agent, with owner | `IslandBar` |
| Stripe products, prices, Payment Links | app agent creates, owner approves | Stripe dashboard |
| DNS, VPS, email DNS records | owner | provider panels |
| Legal entity details, tax decisions | owner | — |

Rules:

- The website agent does not edit `server/`, `Mullion/`, or `IslandBar/`.
- The app agent does not rewrite the existing homepage or the Fat Cat page without
  review.
- No one edits the live Caddy/nginx config without a backup and a rollback command.

## 5. Product registry

| Product ID | Name | Key prefix | Plans | Seats | Trial |
|---|---|---|---|---|---|
| `mullion` | Mullion | `MULL` | `pro` one-time | 3 | 14 days |
| `fatcatpomodoro` | Fat Cat Pomodoro | `FATC` | `pro` one-time *(recommended)* or `monthly`/`yearly` | 3 | none with a free tier, or 7 days |

Product IDs are lowercase and **stable forever**. They appear in keys, envelopes,
URLs, Stripe metadata, and the database. Never rename one.

Prices are set in Stripe and copied into `web/links.json`; they are not hardcoded
in the server.

**Open decision — Fat Cat.** The Fat Cat agent proposes €9.99 one-time Pro with a
free tier of 3 sessions/day and no trial. The owner's earlier direction was a 7-day
trial then premium, with a direct subscription. Both work in this schema, but the
Stripe product, the app's feature gate, and the envelope fields differ:

- **One-time Pro (recommended):** `plan: pro`, `expires_at: null`, `major: 1`.
  The app enforces 3 free sessions/day and unlocks unlimited sessions with Pro.
  The App Store build uses a non-consumable IAP, which is simpler than an
  auto-renewable subscription at this price.
- **Subscription:** `plan: monthly|yearly`, `expires_at` = period end + 3 days,
  refresh daily, portal link in email and app. The App Store build uses an
  auto-renewable subscription with a 7-day introductory offer.

Do not create Fat Cat prices or Payment Links until the owner confirms. The
mechanism is unaffected either way.

The App Store build of Fat Cat uses StoreKit and does **not** call this service. The
direct build uses the license service. They are separate products with separate
bundle IDs; there is no automatic cross-channel entitlement.

## 6. Frozen interfaces

### 6.1 License key

```
PREFIX-XXXXX-XXXXX-XXXXX-XXXXX
```

- Alphabet: `23456789ABCDEFGHJKLMNPQRSTUVWXYZ` (no `0`, `O`, `1`, `I`).
- 20 random characters = 100 bits.
- Case-insensitive; dashes and spaces are ignored on input.
- Prefixes: `MULL`, `FATC`.
- The server stores only the SHA-256 of the normalized key, plus an AES-GCM
  ciphertext so the dashboard can resend or recover a key. Plaintext is never
  logged.
- `server/internal/license/key.go` implements this.

The app must normalize before hashing and before sending, so a key typed with
lowercase or spaces works.

### 6.2 Signed envelope

```
LIC1.<payload_b64url>.<signature_b64url>
```

- Every product uses `LIC1`; the `product` claim identifies the app, so one verifier
  works for all of them.
- The signature is Ed25519 over the exact ASCII `<payload_b64url>` bytes.
- Base64url without padding.
- The app embeds the public key; `GET /v1/public-key` is for diagnostics and
  rotation, not trust.
- `server/internal/license/signer.go` implements signing and verification.

Payload:

```json
{
  "v": 1,
  "kid": "2026-11",
  "license_id": "lic_01J...",
  "product": "mullion",
  "plan": "pro",
  "status": "active",
  "seats": 3,
  "major": 1,
  "issued_at": "2026-11-13T12:00:00Z",
  "expires_at": null,
  "install_id": "<random 64 hex>",
  "key_hint": "7KQ2M"
}
```

- `major` is the highest app major the license can run. `1` means free 1.x updates,
  paid 2.0. A version cap is unambiguous; a date-based `updates_until` creates
  "bought on the last day" edge cases. Add `updates_until` later only if the business
  actually wants time-boxed updates; apps ignore unknown fields.
- `expires_at` is `null` for one-time licenses. For subscriptions it is the current
  period end + 3 days (billing grace).
- `status` is `active`, `revoked`, or `expired`. The app treats anything other than
  `active` as unlicensed.
- `install_id` is a random 32-byte hex value generated by the app on first launch and
  stored in Keychain. No hardware UUID or serial number leaves the Mac. A reinstall
  that loses Keychain consumes a seat; deactivation frees it. This is a speed bump,
  not DRM.
- `kid` selects the public key. Keep old public keys in the app when rotating.

### 6.3 API

Base: `https://api.asifthatworks.com`. Frozen. Never move it; if it must move,
keep a 308 redirect and ship an app update first.

| Method | Path | Caller | Notes |
|---|---|---|---|
| POST | `/v1/activate` | app | seat check, returns envelope |
| POST | `/v1/refresh` | app | re-issue, returns envelope or 410 |
| POST | `/v1/deactivate` | app | frees a seat, idempotent |
| POST | `/v1/recover` | website | email my keys; always 202; alias `/v1/resend` |
| GET | `/v1/public-key` | diagnostics | `kid`, algorithm, base64url key |
| GET | `/healthz` | monitor | `{ok, version}` |
| POST | `/webhooks/stripe` | Stripe | signature required; alias `/v1/webhook/stripe` |
| GET | `/portal?t=` | browser | 302 to Stripe Customer Portal |
| GET | `/admin*` | owner | basic auth + optional IP allowlist |

Activate request:

```json
{
  "license_key": "MULL-7KQ2M-XXXXX-XXXXX-XXXXX",
  "install_id": "<random 64 hex>",
  "device_name": "Ky's MacBook Pro",
  "os_version": "15.1",
  "app_version": "1.0.0"
}
```

Activate / refresh response:

```json
{
  "token": "LIC1....",
  "license": {
    "id": "lic_01J...",
    "product": "mullion",
    "plan": "pro",
    "status": "active",
    "seats": 3,
    "activations": 1,
    "major": 1,
    "expires_at": null,
    "issued_at": "2026-11-13T12:00:00Z"
  },
  "billing_url": null
}
```

`billing_url` is a signed, expiring URL to `/portal?t=` for subscriptions; `null`
for one-time licenses.

Error shape:

```json
{"error": "seat_limit", "message": "This license is active on 3 Macs."}
```

| Status | `error` | Meaning |
|---|---|---|
| 400 | `invalid_request` | malformed body or missing field |
| 404 | `unknown_key` | no license for that key |
| 409 | `seat_limit` | all seats used; includes `activations`, `seats` |
| 410 | `revoked` / `expired` | license no longer valid |
| 429 | `rate_limited` | back off and retry later |
| 500 | `internal` | retry with backoff; never show the raw body |

Rules:

- Never log a full key, email, or install id. Log license ids and key hints only.
- Activation is transactional: an existing install id is a touch; a new one respects
  the seat count.
- Refresh is cheap and idempotent.
- `410` is a state, not a crash: the app shows the license window and leaves any
  open switcher session alone.
- The app sends `Accept: application/json` and a `User-Agent` with product/version
  for diagnostics. No API key beyond the license key and install id.

### 6.4 Artifacts and `latest.json`

```
https://dl.asifthatworks.com/<product>/<Version>.dmg
https://dl.asifthatworks.com/<product>/latest.json
https://dl.asifthatworks.com/<product>/appcast.xml
```

`latest.json`:

```json
{
  "product": "mullion",
  "name": "Mullion",
  "version": "1.0.0",
  "build": 1,
  "released_at": "2026-12-01T10:00:00Z",
  "min_macos": "14.0",
  "arch": "universal",
  "url": "https://dl.asifthatworks.com/mullion/Mullion-1.0.0.dmg",
  "sha256": "…",
  "size_bytes": 0,
  "notes_url": "https://asifthatworks.com/mullion/changelog#1-0-0",
  "appcast_url": "https://dl.asifthatworks.com/mullion/appcast.xml"
}
```

Cache headers:

- Versioned DMG: `public, max-age=31536000, immutable`
- `latest.json` and `appcast.xml`: `no-cache`
- `Access-Control-Allow-Origin: *` on `latest.json` so the marketing page can read
  it cross-origin. No credentials, no private data.

The download page must have a static link and checksum as a fallback. JavaScript
only upgrades the values by fetching `latest.json`.

### 6.5 Links file

`web/links.json` is the single source of truth for public purchase and store URLs.
It contains no secrets. The website copies these URLs into the HTML; a check script
can grep for drift.

```json
{
  "mullion": {
    "buy": { "pro": "https://buy.stripe.com/test_..." },
    "download_manifest": "https://dl.asifthatworks.com/mullion/latest.json"
  },
  "fatcatpomodoro": {
    "buy": { "monthly": "https://buy.stripe.com/test_...", "yearly": "https://buy.stripe.com/test_..." },
    "app_store": "https://apps.apple.com/app/id...",
    "download_manifest": "https://dl.asifthatworks.com/fatcatpomodoro/latest.json"
  }
}
```

Test links are used on staging; live links on production. The same file shape, two
values. Never commit `sk_` keys.

### 6.6 CORS

Only `POST /v1/recover` is called from a browser. Allowlist:

- `https://asifthatworks.com`
- `https://www.asifthatworks.com`
- `http://localhost:8080` (development only, not in production)

Allowed: `POST, OPTIONS`, `Content-Type: application/json`, `max-age=600`, no
credentials. Every other endpoint is app-only and sends no CORS headers.

`dl.asifthatworks.com` sends `Access-Control-Allow-Origin: *` for `latest.json` and
`appcast.xml` only.

### 6.7 Email

- From: `Mullion <licenses@asifthatworks.com>` and
  `Fat Cat Pomodoro <licenses@asifthatworks.com>`.
- Reply-To: `support@asifthatworks.com`.
- Provider: Resend, with SPF, DKIM, and DMARC on `asifthatworks.com`.
- Do not overwrite an existing SPF record; merge the include.
- Templates: license key, download/activate links, portal link (subscriptions),
  refund confirmation. Plain text and simple HTML, no tracking pixels.
- If email fails, the webhook records the error and the admin can resend. The
  purchase is never rolled back because an email bounced.

## 7. Flows

**One-time purchase.** Buy link → Stripe Checkout → `checkout.session.completed`
→ customer + order + license → key emailed → admin shows the order. The key has no
expiry and 3 seats.

**Subscription purchase.** Same, plus a subscription row and a license whose
`expires_at` is the period end + 3 days. The email includes a portal link.

**Renewal.** `invoice.paid` extends `expires_at`. `invoice.payment_failed` leaves
the license valid until the existing expiry, then it lapses.

**Cancellation.** `customer.subscription.updated` with `cancel_at_period_end` does
not revoke immediately. `customer.subscription.deleted` revokes at period end.

**Refund / chargeback.** `charge.refunded` or `charge.dispute.created` revokes
immediately. The app finds out on the next refresh; offline copies survive until
then by design.

**Activation.** App normalizes the key, generates/loads its random `install_id`,
POSTs `/v1/activate`, verifies the envelope with the embedded public key, and stores
the envelope and install id in Keychain. Seat limit returns 409 with the current
count.

**Refresh.** Subscriptions refresh at launch and at most once a day. One-time
licenses may refresh opportunistically; they do not need to. Network failure keeps
the last valid envelope and allows up to **30 days** of offline grace. A server
`410` means revoked or expired now: the app moves to the license window immediately
and leaves any open switcher session alone. Grace is for unreachable servers, not
for revoked licenses.

**Recovery.** `https://asifthatworks.com/mullion/activate` posts an email to
`/v1/recover`. The endpoint always returns 202, whether or not the address exists.
If the key ciphertext is unreadable (secret rotated), the server reissues a key and
revokes the old one.

**Trial.** Local only, no server. The start is the earlier of Keychain and
Application Support. 14 days for Mullion. Fat Cat's trial depends on the open
pricing decision: no trial with a free tier, or 7 days with a subscription. A clock
rollback larger than 24 hours keeps the last known state rather than extending the
trial. Gate at launch and in the license window only; never in the capture or
inventory paths.

**App Store.** Fat Cat on the Mac App Store uses StoreKit, Apple's 7-day
introductory offer, and Restore Purchases. No license code is compiled into that
build, and it contains no link to direct purchase.

## 8. Questions for the website agent

Answer these in a PR comment on this file, or edit the defaults in place.

1. **Integration.** The Mullion page is `/mullion` on the existing site, reusing
   its header, footer, and type. It is not a replacement homepage. Agree?
2. **Repo and access.** Which repo/pipeline owns `asifthatworks.com`? Do you have
   write access, or do you deliver a patch/PR? Where should `web/links.json` live?
3. **Checkout.** Buy buttons are plain `<a href="…">` to the Payment Links in
   `web/links.json`, same tab, no Stripe.js, no card fields, works without
   JavaScript. Agree?
4. **Download page.** Static fallback link + checksum; JavaScript only upgrades
   version/size/SHA from `latest.json`. Never hardcode a version in two places.
   Agree?
5. **Recovery form.** `/mullion/activate` posts JSON to
   `https://api.asifthatworks.com/v1/recover` with `fetch`, shows a generic success
   message, and has a `<noscript>` mailto fallback. Agree?
6. **Legal.** Reuse global `/privacy`, `/terms`, `/refunds`, `/imprint`; never
   invent entity details; placeholders must fail a pre-deploy check. Agree?
7. **Assets.** List what you need and in what format (icon, hero video, stills,
   OG image). Use labelled placeholders until I can capture real windows. Do not
   mock up fake UI. Agree?
8. **Privacy.** No analytics, cookies, webfonts, CDNs, or third-party scripts in
   v1. CSP stays `'self'` plus `connect-src https://api.asifthatworks.com` on the
   activate page. Agree?
9. **Version display.** Footer version comes from `latest.json`; no invented
   release dates. Agree?
10. **Staging.** Preview at `staging.asifthatworks.com` or a path behind basic auth
    with `noindex`, using test Payment Links. Agree?
11. **Changelog.** Plain HTML, one section per version, newest first, no RSS. Agree?
12. **Scope.** No blog, customer accounts, license dashboard, live chat, or theme
    switcher in v1. Agree?

## 9. Questions for the owner (blocking)

These determine how the service is deployed. Answer what you can; the rest can wait
until the service is testable locally.

1. **Existing site.** What serves `asifthatworks.com` — Caddy, nginx, Apache, a
   panel (Coolify/Dokploy/Ploi), or a platform? Where is its source, and how is it
   deployed? Can I get SSH or a deploy key?
2. **DNS.** Which provider? Can we add `api`, `dl`, and `admin` A/AAAA records? Is
   Cloudflare proxying on? What MX/SPF/DKIM records already exist for
   `asifthatworks.com`?
3. **VPS.** Provider, OS, CPU/RAM, firewall. Is Go/systemd allowed? Is
   `127.0.0.1:8080` free?
4. **Fat Cat source.** Where is `IslandBar` (path, git remote), what are its bundle
   IDs, and do you want the shared `LicenseManager` integrated there?
5. **Stripe.** Live account ready; may I create test products, prices, and Payment
   Links? Is Stripe Tax configured, and are business details complete?
6. **Domains.** `mullion.app` is **not ours** — the other agent's note was wrong;
   ignore it. We use `asifthatworks.com/mullion`. Do you own `fatcatpomodoro.com`?
   If not, Fat Cat stays at `/fatcatpomodoro`. Confirm DNS access for `api`, `dl`,
   and `admin` subdomains.
7. **Legal and tax.** Reuse the existing Impressum/privacy/terms, or product-specific
   pages? VAT ID? Who files OSS? (Stripe Tax calculates; it does not file.)
8. **Fat Cat pricing.** This is the one unresolved business decision: €9.99 one-time
   Pro with 3 free sessions/day (the Fat Cat agent's proposal), or a 7-day trial then
   a direct subscription (your earlier direction). Pick one before we create Stripe
   products. The one-time model is simpler and fits the price; a subscription needs a
   monthly/yearly number and more support.

## 10. Build order

| Milestone | Work | Done when |
|---|---|---|
| M0 | This contract, infra discovery, DNS/domain decisions | both agents agree on §6 |
| M1 | License service: schema, keys, signer, API, webhook, email, admin, tests | `go test ./...` passes; local activate/refresh/deactivate with a manual key |
| M2 | Stripe test products, prices, Payment Links, `web/links.json` | a test purchase creates an order and emails a key |
| M3 | Mullion page at `asifthatworks.com/mullion`; `/apps` catalog; staging behind basic auth | product page, download, activate, changelog render |
| M4 | Mullion `LicenseManager`, trial, activation window, offline verify | clean macOS account: trial → buy → activate → refresh → deactivate |
| M5 | Production deploy: DNS, Caddy/nginx, systemd, live Stripe, backups, monitor | live purchase → key → activate on a clean Mac |
| M6 | Fat Cat direct build + license integration; App Store build unchanged | direct Pro or subscription activates; StoreKit build still restores |
| M7 | Catalog polish, launch notes, changelog | `docs/LAUNCH.md` checklist complete |

M1 can proceed now: the service is hostname-agnostic and runs on a laptop.
M5 is the first step that needs the VPS facts in §9.

## 11. Non-goals for v1

- Customer accounts or a self-service license dashboard on the public site
- Cross-channel entitlement between App Store and direct
- Card data, Stripe secret keys, or license private keys anywhere near the website
- A separate server or database per product
- Analytics, cookies, retargeting, live chat
- A custom checkout or card form
- Auto-renewing the App Store subscription outside StoreKit

## 12. Definition of done for the shared mechanism

- [ ] Test-mode purchase → key email → activate on a clean Mac → refresh →
      deactivate → refund → refresh returns 410
- [ ] Live purchase → same, with a real card and a real receipt
- [ ] A second product can be added with only a product row, a price, a link, and a
      page — no server code
- [ ] Site works with JavaScript disabled
- [ ] No secrets in git; `.env.example` only
- [ ] `latest.json` and `appcast.xml` are `no-cache`; DMGs are immutable
- [ ] HSTS, CSP, and `X-Content-Type-Options` verified with `curl -I`
- [ ] Admin is unlinked, basic-auth protected, and optionally IP-limited
- [ ] SQLite backup runs nightly and a restore has been tested
- [ ] Legal pages reviewed by the owner, with no unfilled placeholders
- [ ] Stripe webhook retries and duplicate events are idempotent
