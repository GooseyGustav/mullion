# Launch playbook

Mullion is distributed **outside the Mac App Store**, signed with a Developer ID,
notarized by Apple, and updated with Sparkle. Sales go through **Stripe directly**:
you are the merchant of record. Licenses are issued by a **self-hosted Go + SQLite
service** on the same VPS, with a small admin dashboard. The product page is part of
the existing `asifthatworks.com` site.

The complete commerce and hosting contract is [`COORDINATION.md`](COORDINATION.md);
the service implementation notes are in [`../server/README.md`](../server/README.md).
This document is the app-release order of operations. Each step assumes the previous
one.

| | |
|---|---|
| Bundle ID | `com.kyanhpham.mullion` |
| Team ID | `NZJ6XP9B66` |
| Signing (local) | `Apple Development: Ky Anh Pham (W99V9DN93Y)` |
| Signing (release) | `Developer ID Application: Ky Anh Pham (NZJ6XP9B66)` — exported |
| Minimum macOS | 14.0 |
| Product page | `https://asifthatworks.com/mullion` |
| Downloads | `https://dl.asifthatworks.com/mullion/` |
| License API | `https://api.asifthatworks.com` (frozen) |
| Website brief | `docs/WEBSITE.md` |
| Contract | `docs/COORDINATION.md` |

## 0. Where things stand

Done:

- app, glass panel, uniform grid, thumbnails, ⌘⇥ event tap, hover traffic lights
- bundle ID and name finalized, hardened runtime on
- `xcodegen` project builds and installs as `/Applications/Mullion.app`
- Developer ID Application certificate exported and test-signed
- release script, website brief, coordination contract
- license service foundation in `server/` (key format, `LIC1` signer, tests)

Missing before a paid release:

- [ ] custom app icon (the generic executable icon is not sellable)
- [ ] notarization credentials (`mullion-notary`) — blocked by Apple agreement 403 until accepted
- [ ] Accessibility + Screen Recording granted for `com.kyanhpham.mullion`
- [ ] Sparkle 2 integration + EdDSA keys
- [ ] trial + license UI, `LicenseManager`
- [ ] license service MVP deployed (`api.asifthatworks.com`)
- [ ] Stripe test/live products, prices, Payment Links
- [ ] version bumped to `1.0.0`
- [ ] website, legal pages, checkout
- [ ] one real purchase + refund + refresh-410 test

## 1. Locked decisions

These are expensive to change after people buy, because TCC grants and licenses are
keyed to them.

1. **Bundle ID**: `com.kyanhpham.mullion`. Do not change it.
2. **Price**: €14.99 one-time, 14-day trial, 3 seats, free 1.x updates (`major: 1`),
   paid 2.0. One-time is right for a utility in a category where AltTab is free.
3. **Commerce**: Stripe directly (merchant of record), one Stripe account for all
   products. Stripe Payment Links for checkout; the VPS is never in the purchase
   path. Stripe Tax calculates, but VAT/OSS registration and filing remain the
   owner's responsibility.
4. **Licensing**: self-hosted Go + SQLite service at `api.asifthatworks.com`.
   Keys `MULL-…`, signed `LIC1` envelopes, Ed25519 offline verification, random
   `install_id`, 30-day offline grace on network failure. No Polar, no Gumroad.
5. **URLs**: product page `https://asifthatworks.com/mullion`, artifacts on
   `dl.asifthatworks.com`, API on `api.asifthatworks.com`, dashboard on
   `admin.asifthatworks.com`. `mullion.app` is not owned — do not use it.

## 2. Certificates

You already have the paid Apple Developer Program and an **Apple Development**
certificate. That one only runs on your Mac. Distribution needs a **Developer ID
Application** certificate, which the same membership can issue.

1. Xcode ▸ Settings ▸ Accounts ▸ select team `NZJ6XP9B66` ▸ Manage Certificates.
2. **+** ▸ **Developer ID Application**. It is created and installed in the login
   keychain.
3. Verify:

```bash
security find-identity -v -p codesigning
# "Developer ID Application: Ky Anh Pham (NZJ6XP9B66)"
```

4. Export it as a `.p12` (Keychain Access ▸ right-click ▸ Export) and store the
   password in a password manager. You need it only if you release from another
   machine or CI, but losing it means re-issuing.

Keep the `Apple Development` identity in `project.yml` for day-to-day builds;
release commands override the identity on the command line. Never commit a `.p12`
or its password.

### Notarization credentials

Use an **app-specific password** (appleid.apple.com ▸ Sign-In and Security ▸
App-Specific Passwords), or an App Store Connect API key if you prefer. Store it
once in the keychain:

```bash
xcrun notarytool store-credentials "mullion-notary" \
  --apple-id "you@example.com" \
  --team-id "NZJ6XP9B66" \
  --password "abcd-efgh-ijkl-mnop"
```

`notarytool` reads it back with `--keychain-profile mullion-notary`. The profile is
per-machine; a CI runner needs its own copy.

## 3. Versioning

Two independent numbers:

- `MARKETING_VERSION` — what people see: `1.0.0` for the first paid release.
- `CURRENT_PROJECT_VERSION` — Sparkle's comparison key. **Must increase on every
  shipped build**, including betas. Never reuse or decrease it.

Set both in `project.yml` (or with `agvtool`). Suffix betas as `1.0.0-beta.2`
(marketing) while still incrementing the build number.

## 4. Release build

`xcodegen` is the source of truth; the `.xcodeproj` is generated and ignored.

```bash
xcodegen generate

xcodebuild archive \
  -project Mullion.xcodeproj \
  -scheme Mullion \
  -configuration Release \
  -archivePath build/Mullion.xcarchive \
  -destination "generic/platform=macOS" \
  DEVELOPMENT_TEAM=NZJ6XP9B66 \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"
```

Export with a Developer ID export options file (`scripts/ExportOptions.plist`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>NZJ6XP9B66</string>
  <key>destination</key><string>export</string>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath build/Mullion.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist scripts/ExportOptions.plist
```

Confirm the binary is universal (Intel + Apple silicon) unless you deliberately
ship arm64-only:

```bash
lipo -archs build/export/Mullion.app/Contents/MacOS/Mullion
# x86_64 arm64
```

## 5. Signing rules

Hardened runtime is already enabled. There is **no sandbox** and **no entitlement
file** — Mullion needs unrestricted Accessibility and ScreenCaptureKit access, and
that is exactly why the App Store is not an option.

Sign inside-out and never use `--deep`:

1. XPC services and helpers inside `Sparkle.framework`
2. `Sparkle.framework`
3. the app bundle

Sparkle ships its XPC services ad-hoc signed. When you embed it, re-sign each one
with your Developer ID **and** the hardened runtime, or notarization fails:

```bash
FW="build/export/Mullion.app/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign -f -s "Developer ID Application" -o runtime --timestamp \
  "$FW/XPCServices/Installer.xpc"
codesign -f -s "Developer ID Application" -o runtime --timestamp \
  --preserve-metadata=entitlements "$FW/XPCServices/Downloader.xpc"
codesign -f -s "Developer ID Application" -o runtime --timestamp "$FW/Autoupdate"
codesign -f -s "Developer ID Application" -o runtime --timestamp "$FW/Updater.app"
codesign -f -s "Developer ID Application" -o runtime --timestamp "$FW"
codesign -f -s "Developer ID Application" -o runtime --timestamp \
  "build/export/Mullion.app"
```

`scripts/release.sh` does this only if the framework is present, so it works before
and after Sparkle is added.

Verify:

```bash
codesign --verify --deep --strict --verbose=2 build/export/Mullion.app
codesign -d --entitlements :- build/export/Mullion.app   # empty / no get-task-allow
spctl -a -vvv -t exec build/export/Mullion.app           # rejected until notarized
```

## 6. Notarize and staple

Notarize the **app**, staple it, then build the DMG, sign and notarize the DMG.
Notarizing the DMG alone works, but stapling the app too means the app stays valid if
someone copies it out of the disk image.

```bash
ditto -c -k --keepParent build/export/Mullion.app build/Mullion.zip

xcrun notarytool submit build/Mullion.zip \
  --keychain-profile mullion-notary --wait
# status: Accepted

xcrun stapler staple build/export/Mullion.app
xcrun stapler validate build/export/Mullion.app
```

If it is rejected, `notarytool log <submission-id> --keychain-profile
mullion-notary` names the offending file. The usual causes are an unsigned nested
helper, a missing `--timestamp`, or hardened runtime not enabled.

### DMG

```bash
mkdir -p build/dmg
cp -R build/export/Mullion.app build/dmg/
ln -sfn /Applications build/dmg/Applications
hdiutil create -volname "Mullion 1.0.0" -srcfolder build/dmg \
  -ov -format UDZO build/Mullion-1.0.0.dmg

codesign --force --sign "Developer ID Application" --timestamp \
  build/Mullion-1.0.0.dmg

xcrun notarytool submit build/Mullion-1.0.0.dmg \
  --keychain-profile mullion-notary --wait
xcrun stapler staple build/Mullion-1.0.0.dmg
xcrun stapler validate build/Mullion-1.0.0.dmg

spctl -a -t open --context context:primary-signature -v build/Mullion-1.0.0.dmg
```

**Test on a clean Mac or a fresh user account.** On your own machine the notarization
ticket is already cached, so a broken build can still open. The test is: download from
the website over HTTPS, open, grant both permissions, use ⌘⇥, quit, relaunch.

## 7. Updates with Sparkle 2

Add the package in Xcode (File ▸ Add Package Dependencies ▸
`https://github.com/sparkle-project/Sparkle`, version 2.x). XcodeGen users can add
it to `project.yml` once and re-generate:

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.6.0"

targets:
  Mullion:
    dependencies:
      - package: Sparkle
```

Then either embed `Sparkle.framework` and add it to the app's Frameworks phase, or
call `SPUStandardUpdaterController` which is enough for this app. Add to
`Mullion/Resources/Info.plist`:

```xml
<key>SUFeedURL</key>
<string>https://dl.asifthatworks.com/mullion/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>REPLACE_WITH_PUBLIC_KEY</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>
```

### Keys

```bash
# Sparkle's bin/ directory, from the SPM checkout or the release tarball
./bin/generate_keys
```

The private key lives in your login keychain; the command prints the public key for
`SUPublicEDKey`. **Back up the private key.** If you lose it, existing installs will
reject every future update and users must download manually. Keep the backup offline,
not in the repo.

### Build the appcast

```bash
./bin/generate_appcast \
  --download-url-prefix "https://dl.asifthatworks.com/mullion/" \
  --link "https://asifthatworks.com/mullion" \
  -o appcast.xml dist/
```

`dist/` contains the signed DMGs and optional `Mullion-1.0.0.md` release notes.
Sparkle signs each enclosure with the private key and writes `sparkle:edSignature`
plus the file length. Upload `appcast.xml` and the DMG. Serve the appcast with
`Cache-Control: no-cache` (see `docs/WEBSITE.md`).

Rules that matter:

- `CURRENT_PROJECT_VERSION` must be greater than the installed build.
- The new DMG must be notarized and signed by the same team; Sparkle checks the code
  signature before installing.
- Never rewrite a published DMG. Publish a new version instead.
- Keep the old DMGs online for rollback and for people on old macOS.

### Agent-app caveat

Mullion is `LSUIElement`, so Sparkle's update window can open behind everything.
Temporarily switch the activation policy while the update UI is up:

```swift
NSApp.setActivationPolicy(.regular)
NSApp.activate(ignoringOtherApps: true)
updaterController.checkForUpdates(nil)
// back to .accessory when the update window closes
```

Verify the whole cycle with a real +1 build: install 1.0.0, publish 1.0.1, click
"Check for Updates…", let it replace the app, confirm the bundle ID and TCC grants
survive (they do, because the signing identity and bundle ID are unchanged).

## 8. Trial and licensing

There is no Mac App Store receipt. Licenses come from the self-hosted service at
`api.asifthatworks.com` (see `COORDINATION.md` §6 and `server/README.md`).

```swift
enum LicenseStatus: Equatable {
    case trial(daysLeft: Int)
    case licensed
    case expired
    case invalid
    case unreachable(lastChecked: Date)   // offline grace
}

protocol LicenseProviding {
    func activate(key: String, installID: String) async throws -> LicenseEnvelope
    func refresh(key: String, installID: String) async throws -> LicenseEnvelope
    func deactivate(key: String, installID: String) async throws
}
```

Behaviour:

- **14-day trial** from first launch. Store the date in Keychain and mirror it in
  Application Support; use the earlier one. If the clock moves back more than 24
  hours, keep the last known state.
- **Install identity**: `install_id` is a random 32-byte hex value generated once and
  stored in Keychain. No hardware UUID or serial number leaves the Mac.
- **Activation**: `POST /v1/activate` with the normalized key and `install_id`.
  Verify the `LIC1` envelope offline with the embedded Ed25519 public key. Store the
  envelope and key in Keychain. 3 seats.
- **Refresh**: revalidate lazily (at most once a day). One-time licenses may refresh
  opportunistically; subscriptions refresh to extend `expires_at`.
- **Offline**: if the network is down, honour the last valid envelope for up to
  **30 days**. Never block the switcher on the network.
- **Revocation**: a server `410 revoked|expired` means invalid now — show the license
  window at next launch, not mid-session. Do not delete user data.
- **Deactivation**: `POST /v1/deactivate` frees a seat.

### What not to build

- No account system, no password, no email verification inside the app.
- No card data, Stripe secrets, or license private keys in the app or on the
  website. Stripe Checkout is hosted; the server is the only Stripe integration.
- No phone-home heartbeat. No hardware fingerprinting.

A determined person can patch the check. Optimise for the paying customer: paste key,
unlock, never think about it again.

## 9. Stripe and license service

Stripe is the merchant of record. You are responsible for VAT/OSS registration and
filing; Stripe Tax calculates but does not file.

### Stripe

1. Confirm business details and Stripe Tax. Enable the Customer Portal.
2. Create test-mode products and prices:
   - **Mullion** (`product_id: mullion`, `plan: pro`, `prefix: MULL`): €14.99
     one-time, 3 seats, 14-day trial in the app.
   - **Fat Cat Pomodoro** (`product_id: fatcatpomodoro`, `prefix: FATC`): plan and
     price TBD (see `COORDINATION.md` §5). Do not create until confirmed.
3. Create one Payment Link per price with `client_reference_id=<product>:<plan>`,
   metadata `product_id`, `plan_id`, `seats`, `channel=direct`, success URL
   `https://asifthatworks.com/<product>/thanks?session_id={CHECKOUT_SESSION_ID}`.
4. Add the endpoint `https://api.asifthatworks.com/webhooks/stripe` and subscribe to
   `checkout.session.completed`, `invoice.paid`, `invoice.payment_failed`,
   `customer.subscription.updated`, `customer.subscription.deleted`,
   `charge.refunded`, `charge.dispute.created`.
5. Put the Payment Links in `web/links.json` (no secrets). Buy buttons are plain
   `<a>` links; the VPS is never in the purchase path.
6. Run a real test purchase → key email → activate → refund → refresh returns 410.

### License service

Implementation: `server/` (Go 1.27, pure-Go SQLite, single binary). Contract:
`COORDINATION.md`.

- Binds to `127.0.0.1:8080`; Caddy/nginx terminates TLS on `api.asifthatworks.com`
  and `admin.asifthatworks.com`.
- Stores only key hashes and AES-GCM ciphertexts, never plaintext keys or card data.
- Verifies `Stripe-Signature`; uses event IDs for idempotency.
- Sends license email via Resend (SPF/DKIM/DMARC on `asifthatworks.com`).
- Admin dashboard: basic auth + optional IP allowlist, never linked publicly.

Deploy target: the existing Hostinger VPS, in its own folder (e.g.
`/srv/mullion-license`), managed by systemd, secrets in `/etc/mullion/license.env`
mode 600. Do not hand-edit live web server config without a backup and rollback.

## 10. Website and VPS

Marketing is part of the existing `asifthatworks.com` site. Full setup lives in
[`WEBSITE.md`](WEBSITE.md) and [`COORDINATION.md`](COORDINATION.md).

- `https://asifthatworks.com/mullion` — product page, download, changelog, activate
- `https://asifthatworks.com/apps` — catalog
- `https://dl.asifthatworks.com/mullion/` — versioned DMGs, `latest.json`,
  `appcast.xml` (immutable DMGs, `no-cache` manifests)
- `https://api.asifthatworks.com` — license API and Stripe webhook
- `https://admin.asifthatworks.com` — dashboard

Static files, no card fields, no third-party scripts. The existing site server and
deploy pipeline own the marketing pages; the license service is a separate process.

## 11. Release checklist

```
[ ] version + build number bumped
[ ] app icon present at all required sizes
[ ] README and in-app About show the right version
[ ] xcodegen generate
[ ] Release archive builds clean
[ ] codesign --verify --deep --strict passes
[ ] notarization Accepted, app stapled, DMG stapled
[ ] spctl accepts the DMG on a clean account
[ ] TCC granted on clean account (Accessibility + Screen Recording), restart works
[ ] ⌘⇥ works, thumbnails appear, traffic lights close/minimize/zoom
[ ] trial timer starts, key activates, expired state shows buy link
[ ] test purchase → key email → activate → deactivate → refund → refresh 410
[ ] DMG and checksums on dl.asifthatworks.com, latest.json/appcast no-cache
[ ] website download and buy links point at this release
[ ] privacy, terms, refund, imprint pages live and reviewed
[ ] Sparkle private key backed up offline
[ ] old DMG kept available for rollback
```

## 12. Costs

| Item | Cost |
|---|---|
| Apple Developer Program | €99/year (already paid) |
| Existing domain / VPS | already paid |
| TLS | free (Let's Encrypt) |
| Stripe | ~1.5% + €0.25 EEA cards (+1.5% international, +0.5% Stripe Tax) |
| Email (Resend) | free tier, then small |
| Notarization | free |

You are the merchant of record: budget for VAT/OSS compliance. The real recurring
cost is support: TCC dialogs, restart, Gatekeeper, and license recovery.

## 13. Support answers to have ready

- **"Mullion can't control my Mac"** — Accessibility is off. System Settings ▸
  Privacy & Security ▸ Accessibility ▸ enable Mullion.
- **"Thumbnails are blank"** — Screen Recording is off, or the app was not restarted
  after granting it. Quit from the menu bar and reopen.
- **"It says damaged / unidentified developer"** — the download was corrupted or an
  old build. Re-download from the official URL; do not bypass Gatekeeper.
- **"⌘⇥ does nothing"** — another switcher or a keyboard remapper is swallowing it;
  check the menu bar item shows Accessibility granted.
- **"How do I uninstall?"** — quit, drag to Trash, optionally remove
  `~/Library/Logs/Mullion.log`; permissions disappear with the app.
- **"Where is my license key?"** — check the purchase email, or use
  `asifthatworks.com/mullion/activate` to resend. Support can recover or reissue from
  the admin dashboard.

## 14. Do not do

- Do not run `tccutil reset` on your own machine again; it wipes every app's grants.
- Do not change the bundle ID after the first sale.
- Do not ship an ad-hoc signed build; TCC grants break on every rebuild.
- Do not notarize with `--deep` signing or skip `--timestamp`.
- Do not rewrite a published DMG or reuse a build number.
- Do not put Stripe secret keys, license databases, or card data on the website.
- Do not move `api.asifthatworks.com` after apps ship; it is frozen. Use a 308
  redirect and an app update only as a last resort.
- Do not hand-edit the live VPS web server config without a backup and rollback.
