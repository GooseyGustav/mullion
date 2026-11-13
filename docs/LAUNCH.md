# Launch playbook

Mullion is distributed **outside the Mac App Store**, signed with a Developer ID,
notarized by Apple, and updated with Sparkle. Sales go through a merchant of record
(Polar by default, Gumroad as the low-effort fallback), and the website is a static
site on your own VPS.

This document is the order of operations. Each step assumes the previous one.

| | |
|---|---|
| Bundle ID | `com.kyanhpham.mullion` |
| Team ID | `NZJ6XP9B66` |
| Signing (local) | `Apple Development: Ky Anh Pham (W99V9DN93Y)` |
| Signing (release) | `Developer ID Application: …` — **not created yet** |
| Minimum macOS | 14.0 |
| Website | `docs/WEBSITE.md` |

## 0. Where things stand

Done:

- app, glass panel, uniform grid, thumbnails, ⌘⇥ event tap, window close
- bundle ID and name finalized, hardened runtime on
- `xcodegen` project builds and installs as `/Applications/Mullion.app`

Missing before a paid release:

- [ ] custom app icon (the generic executable icon is not sellable)
- [ ] Developer ID Application certificate
- [ ] notarization credentials
- [ ] Sparkle 2 integration + EdDSA keys
- [ ] trial + license UI, `LicenseService`
- [ ] version bumped to `1.0.0`
- [ ] website, legal pages, checkout
- [ ] one real purchase + refund test

## 1. Lock these decisions first

These are expensive to change after people buy, because TCC grants and licenses are
keyed to them.

1. **Bundle ID**: `com.kyanhpham.mullion`. Do not change it now.
2. **Price**: €14.99 / $14.99 one-time, all 1.x updates included, 14-day trial.
   One-time is right for a utility in a category where AltTab is free. Bundling a
   year of updates is a defensible middle ground, but keep v1 simple: one price,
   lifetime license. Raise it later for new buyers if the app earns it.
3. **Store**: Polar (≈5% + 50¢, merchant of record, license keys) or Gumroad
   (10% + 50¢ + card processing ≈ 17–20% effective, simplest license API). Both
   handle VAT and refunds. Pick before writing `LicenseService`; the interface is
   the same, the request body is not.
4. **Domain**: e.g. `mullion.app`. Buy it before you announce anything.

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
<string>https://mullion.app/appcast.xml</string>
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
  --download-url-prefix "https://mullion.app/downloads/" \
  --link "https://mullion.app" \
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

The store sells a key; the app decides what a key is worth. Keep the store behind a
protocol so switching from Gumroad to Polar is a small change:

```swift
enum LicenseStatus: Equatable {
    case trial(daysLeft: Int)
    case licensed
    case expired
    case invalid
    case unreachable(lastChecked: Date)   // offline grace
}

protocol LicenseService {
    func activate(key: String) async throws -> LicenseStatus
    func refresh() async -> LicenseStatus
}
```

Behaviour:

- **14-day trial** from first launch. Store the date in the Keychain and mirror it in
  Application Support; check both and use the earlier one. This is not DRM, just a
  speed bump for honest users.
- **Activation**: one POST, store the key in the Keychain and a `verifiedAt` date.
  Cache `licensed` with a 30-day offline grace; re-validate in the background at most
  once a day. Never block the switcher on the network.
- **Refund / chargeback**: the next successful refresh flips to `invalid`. Do not
  delete the user's data or nag mid-session; show the license window at next launch.
- **Clock rollback**: if the system clock is earlier than the last check, keep the
  last known status and ignore the trial counter for that launch.
- **Failure**: if the network is down, honour the grace period. An app that stops
  working on a plane is worse than a pirated copy.

### Polar

Validate with the key and your organization ID. The response has `status`
(`granted`), `expires_at`, and usage counters. Activation IDs are optional unless
you want per-machine limits; for a one-time desktop license, one key per purchase
with `limit_activations` set to 3 and no activation tracking is enough.

```
POST https://api.polar.sh/v1/customer-portal/license-keys/validate
Content-Type: application/json

{ "key": "…", "organization_id": "…", "conditions": { "major_version": 1 } }
```

### Gumroad

One POST, form-encoded:

```
POST https://api.gumroad.com/v2/licenses/verify
product_id=…&license_key=…
```

Check `success`, then reject when `purchase.refunded` or
`purchase.chargebacked` is true. `uses` is informational.

### What not to build

- No account system, no password, no email verification inside the app.
- No card data anywhere near the app or your VPS. The hosted checkout owns that.
- No phone-home heartbeat. Activate once, re-validate lazily.

A determined person can patch the check. That is true of every Mac utility. Optimise
for the paying customer: paste key, unlock, never think about it again.

## 9. Store setup

### Polar (recommended)

1. Create the organization, complete payout and tax details.
2. Product: **Mullion**, one-time, €14.99, digital download.
3. Enable **license keys** as a benefit; set activation limit 3.
4. Attach the DMG as the download, or just link the website download (simpler: one
   download URL to update).
5. Copy the checkout link into the site's Buy button.
6. Enable the customer portal (receipts, refunds, key retrieval).
7. Set the refund policy to match your website (e.g. 14 days, no questions).

### Gumroad (fastest)

1. Product: digital, one-time price, "Generate a unique license key per sale" on.
2. Copy the product ID (not the permalink) for the verify call.
3. Use the Gumroad checkout overlay or link out. Direct sales are 10% + 50¢; sales
   through Discover are 30%, so link directly.
4. Turn on the receipt/refund settings and test a real purchase.

### Before you announce

Buy your own product with a real card, receive the key, activate on a clean account,
request a refund, confirm the key stops validating. That single loop catches most
launch-day support tickets.

## 10. Website and VPS

Full setup lives in [`WEBSITE.md`](WEBSITE.md). The short version: Caddy serving a
static directory, the versioned DMG, `appcast.xml`, and the legal pages; checkout is
an outbound link to Polar or Gumroad. No application server and no database.

## 11. Release checklist

```
[ ] version + build number bumped
[ ] app icon present at all required sizes
[ ] README and in-app About show the right version
[ ] xcodegen generate
[ ] Release archive builds clean, no warnings that matter
[ ] lipo shows expected architectures
[ ] codesign --verify --deep --strict passes
[ ] notarization Accepted, app stapled, DMG stapled
[ ] spctl accepts the DMG on a clean account
[ ] first-run flow grants Accessibility + Screen Recording, restart works
[ ] ⌘⇥ works on a fresh user, thumbnails appear, × and ⌘W close
[ ] trial timer starts, key activates, expired state shows the buy link
[ ] website download URL points at this DMG
[ ] appcast.xml published, one older install updates to this build
[ ] privacy, terms, refund, imprint pages live
[ ] checkout test purchase + refund done
[ ] backup of Sparkle private key, notarization profile documented
[ ] old version kept available for rollback
```

## 12. Costs

| Item | Cost |
|---|---|
| Apple Developer Program | €99/year (already paid) |
| Domain | ~€10–15/year |
| VPS | ~€5/month (1 vCPU, 1 GB is plenty for static files) |
| TLS | free (Let's Encrypt via Caddy) |
| Store | ~5% + 50¢ (Polar) or ~17–20% (Gumroad) |
| Notarization | free |

The real recurring cost is support: two TCC dialogs, a restart, and Gatekeeper
questions. Put those answers on the website and in the app's first-run text.

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

## 14. Do not do

- Do not run `tccutil reset` on your own machine again; it wipes every app's grants.
- Do not change the bundle ID after the first sale.
- Do not ship an ad-hoc signed build; TCC grants break on every rebuild.
- Do not notarize with `--deep` signing or skip `--timestamp`.
- Do not rewrite a published DMG or reuse a build number.
- Do not put Stripe secret keys, license databases, or card data on the VPS.
