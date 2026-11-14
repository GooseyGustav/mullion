# Website concept and build brief

> **Hosting revision, 13 Nov 2026.** The product page lives at
> `https://asifthatworks.com/mullion`, on the existing site. Downloads and appcasts
> live on `https://dl.asifthatworks.com/mullion/`. The shared license API is
> `https://api.asifthatworks.com`. Read the shared [coordination contract](https://github.com/GooseyGustav/asifthatworks-licensing/blob/main/docs/COORDINATION.md) before
> deploying; it is the interface contract. The copy, page structure, and visual
> direction below are unchanged.

> Hand this file to the remote agent. It is the complete brief for the Mullion
> marketing site. Nothing here requires an application server: the site is static
> files on a VPS, and checkout is an outbound link to Stripe.

Status: concept, pre-build. Copy is draft and can be edited; structure and technical
constraints are the parts to follow.

- Product: **Mullion**
- URL: **`https://asifthatworks.com/mullion`** (canonical product page)
- Repo: `github.com/GooseyGustav/mullion`
- Price: **€14.99 one-time**, 14-day trial, all 1.x updates included
- Audience: macOS power users who keep 15–40 windows open and want to see them
- Tone: quiet, technical, confident. No growth-hack copy, no exclamation marks,
  no "supercharge your workflow".

---

## 1. Positioning

**One sentence:** Mullion replaces ⌘⇥ with a glass panel of live window previews, so
you switch to the window you can see instead of guessing from an app icon.

**Three things the page must communicate in the first screen:**

1. It is a **window** switcher, not an app switcher.
2. It is **fast** and **idle when closed**.
3. It is a **one-time purchase**, not a subscription.

**What it is not:** a launcher, a window manager, a tiling tool, a Dock replacement,
or a subscription. Do not imply features that do not exist (search, Spaces, multiple
shortcuts, per-app rules) on the 1.0 site.

### Hero copy (draft)

```
Mullion

Every window. One keystroke.

A glass panel of live window previews replaces ⌘⇥ on macOS.
See the window, not just the app icon. Close, minimize, or zoom it
without leaving the switcher.

[Download for macOS]   [Buy — €14.99]

Free 14-day trial · macOS 14+ · Apple silicon & Intel · Notarized by Apple
```

Alternative headline, pick one:

- "⌘⇥, but you can see."
- "The window switcher you can see."
- "Stop guessing which window."

Subhead must mention "macOS" and "⌘⇥" because that is how people search.

---

## 2. Page structure

Mullion is a product page inside the existing `asifthatworks.com` site, not a new
domain. It reuses the site header, footer, and type, and adds:

```
/mullion              product page
/mullion/download     versioned DMG + checksum + system requirements
/mullion/changelog    release notes (plain HTML, one section per version)
/mullion/activate     activate, recover a key, deactivate a Mac
/mullion/thanks       post-checkout confirmation
/apps                 catalog of shipped apps
/privacy              privacy policy (global)
/terms                terms of sale (global)
/refunds              refund policy (global)
/imprint              Impressum (global, required in Germany/EU)
```

Navigation: keep the existing site nav and add a `Mullion` entry. Inside the product
page, use `Features` `Pricing` `FAQ` `Changelog` `Download` and one primary button,
**Buy €14.99**. When the visitor already owns Mullion, the menu shows `Download`.

No hamburger menu on desktop; on mobile collapse to a simple stacked menu.

### 2.1 Hero

- Left: headline, subhead, two CTAs, trust line.
- Right: looping 8–12 second screen recording of ⌘⇥ opening the glass panel,
  arrow keys moving selection, release to switch. Autoplay muted, loop, playsinline,
  poster frame for reduced-motion and slow connections.
- Background: the app's own glass aesthetic — a dark blurred desktop wallpaper with
  a soft blue/violet glow, not a stock photo.
- Below the fold edge: a thin strip of four facts:
  `0% idle CPU` · `~20 ms window snapshot` · `No account` · `No telemetry`.

### 2.2 "The switcher you can see"

Three short feature blocks, each with a still:

1. **Live previews, not icons.** "Every open window, captured when you open the
   switcher. Titles and app icons included."
2. **Built for the keyboard.** "Hold ⌘, tap ⇥, release. Arrow keys work. Esc
   cancels. ⌘W closes the selected window without leaving the panel."
3. **Window controls on hover.** "Hover a tile for close, minimize, and zoom —
   the same three actions as a real titlebar."

Each block: 40–60 words maximum, one screenshot, no icon soup.

### 2.3 "Fast because it does nothing when closed"

A technical credibility section. Short paragraph plus a small table or code-like
diagram:

- No background polling, no timers, no `SCStream`. Idle CPU is zero.
- Windows are read once per open (CoreGraphics + one batched Accessibility call per
  app).
- Thumbnails are captured only when missing or older than 3 seconds, in two waves.
- The cache is bounded; memory does not grow with uptime.

This section is for the reader who will otherwise ask "will this drain my battery?"
Answer it before they ask.

### 2.4 "Glass, not chrome"

One wide screenshot on a desktop, minimal copy:

> One behind-window blur for the whole panel. Dark translucent tiles. A single
> selected stroke. No borders around previews, no cropping, no drop shadows on every
> element. The desktop stays visible because the switcher is a layer, not a window.

Mention uniform 16:10 previews; windows are aspect-fit, never cropped.

### 2.5 Keyboard reference

A compact two-column table (also useful for SEO):

| Key | Action |
|---|---|
| ⌘⇥ | Open / next window |
| ⇧⌘⇥ | Previous window |
| ← → ↑ ↓ | Move selection |
| Return | Switch |
| Esc | Cancel |
| ⌘W | Close selected window |
| Release ⌘ | Switch |

### 2.6 Pricing

One card, no tiers, no "most popular" badge.

```
Mullion                                     €14.99
One-time purchase. Yours to keep.

✓ 14-day free trial, no card required
✓ All 1.x updates included
✓ License for your Macs (up to 3 activations)
✓ Offline activation, no account
✓ 14-day refund policy

[Buy Mullion]        [Start free trial]
```

Under the card: "VAT included where applicable. Checkout and invoices are handled by
Stripe. Card details never touch this site."

Mullion is merchant-of-record direct: the site links to a Stripe Payment Link, and
the license is issued by the shared service (`api.asifthatworks.com`, see the [coordination contract](https://github.com/GooseyGustav/asifthatworks-licensing/blob/main/docs/COORDINATION.md)). Do **not** add
a card form, Stripe.js, or a "lifetime deal" countdown.

### 2.7 FAQ

Accordion, plain `<details>` elements, crawlable:

- **Does it replace the macOS app switcher?** Yes. Mullion swallows ⌘⇥ while it
  runs; quit it and the system switcher returns.
- **Why isn't it on the Mac App Store?** It needs Accessibility and Screen
  Recording APIs that the App Store sandbox does not allow. It is signed with a
  Developer ID and notarized by Apple instead.
- **What permissions does it need?** Accessibility to read titles and raise/close
  windows; Screen Recording only for previews. Without Screen Recording it still
  works with icons.
- **Why did I have to restart after granting Screen Recording?** macOS requires it
  for that permission. The app tells you when a restart is needed.
- **Does it work on multiple displays?** It opens on the display with the pointer.
- **Does it phone home?** Only to validate a license key, and at most once a day.
  No analytics, no telemetry, no account.
- **How do updates work?** Signed updates through Sparkle, checked daily. You can
  turn them off.
- **What happens after the trial?** The switcher stops opening until you enter a
  key. Your settings and license stay on the Mac.
- **Refunds?** 14 days, no questions. Link `/refunds`.
- **Which macOS versions?** macOS 14 Sonoma or later, Intel and Apple silicon.

### 2.8 Footer

- Wordmark + one-line description
- `Mullion` · Download · Changelog · Activate
- Privacy · Terms · Refunds · Imprint
- `Mullion 1.0.0` and a `What's new` link
- Contact email, Impressum link
- Copyright line with the legal name

No social icons unless the accounts actually exist.

---

## 3. Visual direction

The site should look like the app, not like a SaaS landing page.

- **Palette:** near-black `#0B0D10`, glass `rgba(255,255,255,0.06)`, text
  `#F5F7FA`, muted `#9BA3AE`, one accent `#6FA8FF` (the selected-tile blue).
  Warm traffic-light colours only inside screenshots, never as site accents.
- **Type:** system stack (`-apple-system, BlinkMacSystemFont, "SF Pro Text"`).
  No webfonts: faster, private, and correct on macOS.
- **Surfaces:** one large rounded panel, 20–24 px radius, 1 px light border at 10–15%
  white, subtle inner sheen. Avoid glassmorphism everywhere; the hero may be glass,
  the rest of the page can be flat dark.
- **Motion:** 150–250 ms fades and small translates. Respect
  `prefers-reduced-motion`; the hero video must not autoplay for those users.
- **Screenshots:** real app, real windows, neutral desktop wallpaper. Do not mock up
  fake window contents. Capture at 2× and export WebP with PNG fallback.
- **No** stock photography, 3D blobs, "trusted by" logos, or gradient text.

### Assets the remote agent needs

The app repo will provide:

- `icon-1024.png` (app icon, transparent or rounded-square)
- `hero.mp4` + `hero.webm` (8–12 s, 1600×1000, muted, no audio track)
- `hero-poster.webp`
- `switcher.webp` (panel, 2×)
- `traffic-lights.webp` (hover controls close-up)
- `desktop.webp` (panel over a real desktop)
- `og-image.png` (1200×630, wordmark + panel photo)
- `favicon.svg`, `favicon-32.png`, `apple-touch-icon.png`

If an asset is missing, leave a labelled placeholder; do not invent UI.

---

## 4. Technical specification

### Constraints

- Static HTML/CSS/JS. No React, no build step required to deploy.
- No cookies, no third-party scripts, no Google Fonts, no CDNs, no analytics by
  default. If analytics are added, self-host Plausible/Umami and disclose it.
- No card data, no license database, no API keys in the repository.
- HTTPS only; HTTP redirects to HTTPS.
- Works without JavaScript. JS is allowed only for the mobile menu and
  download-OS hint.
- Lighthouse: performance ≥ 95, accessibility ≥ 95, best practices ≥ 95, SEO ≥ 95
  on desktop.

### Suggested file tree

```
web/
├── index.html
├── download.html
├── changelog.html
├── activate.html
├── privacy.html
├── terms.html
├── refunds.html
├── imprint.html
├── assets/
│   ├── style.css
│   ├── site.js
│   ├── icon-1024.png
│   ├── hero.mp4
│   ├── hero-poster.webp
│   ├── switcher.webp
│   ├── traffic-lights.webp
│   ├── desktop.webp
│   └── og-image.png
├── downloads/
│   ├── Mullion-1.0.0.dmg
│   └── Mullion-1.0.0.dmg.sha256
├── appcast.xml
├── robots.txt
└── sitemap.xml
```

The marketing tree (`web/mullion/`) is deployed as the `/mullion` path on the
existing `asifthatworks.com` site. Binaries, appcasts, and `latest.json` live on
`dl.asifthatworks.com`. See the [coordination contract](https://github.com/GooseyGustav/asifthatworks-licensing/blob/main/docs/COORDINATION.md) §2 and §6.4 for the exact URL map and cache headers.

### Download page

- Detect Apple silicon vs Intel only to recommend the right file; ship one universal
  DMG if possible, so there is nothing to choose.
- Show: version, build number, macOS requirement, architecture, file size, SHA-256.
- Button: `Download Mullion 1.0.0` →
  `https://dl.asifthatworks.com/mullion/Mullion-1.0.0.dmg`.
- Secondary: `Release notes` and `Verify the signature` (collapsible block with
  `spctl` / `codesign` commands).
- After the trial expires, the app links to `/mullion/activate`; the purchase
  receipt links to `/mullion/download`.

### Checkout links

- Buy buttons point directly at the Stripe Payment Link for the plan. Open in the
  same tab; no modal, no email capture form on our side, no card fields.
- `Start free trial` scrolls to the download section or goes to `/mullion/download`.
- Do not add third-party pixels. If campaign attribution is needed, use Stripe's
  built-in promotion codes, not a tracker.

### SEO and metadata

- `<title>Mullion — a visual ⌘⇥ window switcher for macOS</title>`
- Description: "Replace ⌘⇥ with live window previews. Fast, keyboard-first, and
  idle when closed. One-time purchase, free 14-day trial. macOS 14+."
- Canonical `https://asifthatworks.com/mullion`, Open Graph, Twitter card
  (`summary_large_image`), `og-image.png`.
- JSON-LD `SoftwareApplication`: name, operatingSystem `macOS 14+`,
  applicationCategory `UtilitiesApplication`, offers price `14.99`, priceCurrency
  `EUR`, `downloadUrl` on `dl.asifthatworks.com`.
- `robots.txt` allows the public pages; the DMGs live on `dl.asifthatworks.com` and
  are not listed in the sitemap.
- `sitemap.xml` lists the public pages.

### Accessibility

- Visible focus rings, logical tab order, skip link.
- Contrast 4.5:1 for body text; the muted grey must pass on `#0B0D10`.
- All screenshots/video have alt text or captions.
- FAQ uses native `<details>/<summary>`.
- Buttons are `<a>` when they navigate, `<button>` when they act.

### Privacy and legal pages

These are content requirements, not legal advice; the owner must review them.

- **Impressum:** legal name, postal address, email, responsible person, VAT ID if
  applicable. Required in Germany even for a one-person software site.
- **Privacy:** what the server logs (IP, user agent, timestamp, retention), that the
  site sets no cookies, that checkout is handled by Stripe, that the app validates
  licenses with `api.asifthatworks.com`, and the legal basis (GDPR Art. 6).
- **Terms:** license grant, number of activations, update policy, no warranty beyond
  law, governing law.
- **Refunds / withdrawal:** 14-day refund; EU right of withdrawal for digital
  content — the merchant of record collects the express consent and acknowledgment
  at checkout. State that clearly and link to the store's policy too.
- The merchant of record is responsible for VAT/sales tax; say so on the pricing
  card and in the terms.

### Legal entity placeholders

The remote agent must not invent these. Leave `[LEGAL NAME]`, `[STREET]`,
`[POSTAL CODE CITY]`, `[COUNTRY]`, `[EMAIL]`, `[VAT ID]` visible in the HTML until
the owner fills them in, and add a build-time checklist item so they cannot ship
unfilled.

---

## 5. Copy rules

- Sentence case, short paragraphs, no exclamation marks.
- Say "macOS", not "Mac OS" or "OSX".
- Say "window switcher", not "alt-tab replacement" in body copy (fine in a meta
  description for search).
- Never claim "the fastest" or "the best". Show measurements and let the reader
  decide.
- Every feature claim must map to shipped behaviour in the app.
- No fake testimonials, no invented user counts, no "as seen in" logos.

---

## 6. Hosting and deployment

The site is not standalone. It is part of the existing `asifthatworks.com` site, and
the shared services are separate hostnames on the same VPS. The exact hostnames,
URL map, ownership, cache headers, and security rules are in
[`asifthatworks-licensing/docs/COORDINATION.md`](https://github.com/GooseyGustav/asifthatworks-licensing/blob/main/docs/COORDINATION.md).

In short:

- `asifthatworks.com` keeps its current server and deploy pipeline; Mullion is added
  as `/mullion`, not as a new root site. The website agent owns this.
- `dl.asifthatworks.com` is a static root (`/var/www/dl`) for versioned DMGs,
  `latest.json`, and `appcast.xml`, served by the same Caddy/nginx with immutable
  caching for versioned files and `no-cache` for the manifests.
- `api.asifthatworks.com` and `admin.asifthatworks.com` reverse-proxy to the Go
  service on `127.0.0.1:8080`. The app agent owns these blocks.
- `portfolio.asifthatworks.com` is untouched.

Do not take over the root of `asifthatworks.com`, and do not change the live server
config without a backup and a rollback command. Once the existing stack is known,
this section will be replaced with the exact Caddy/nginx snippet and deploy commands.

## 7. Definition of done

The site is ready for the remote agent to hand back when:

- [ ] Landing page matches the structure above and renders at 360, 768, 1024, 1440 px
- [ ] All copy is final, with no lorem ipsum and no unfilled brackets except the
      legal entity block
- [ ] Real screenshots/video, correctly compressed, with poster and alt text
- [ ] Buy button opens a working test checkout in a new tab; no card fields on site
- [ ] Download button serves the current signed DMG with a correct SHA-256
- [ ] `/appcast.xml` is served with `Cache-Control: no-cache` and `application/xml`
- [ ] Version number in the footer matches the DMG
- [ ] Privacy, terms, refunds, and imprint pages exist and are linked from every page
- [ ] No third-party requests in the network panel (fonts, analytics, CDNs)
- [ ] Lighthouse scores meet the targets above
- [ ] `robots.txt` and `sitemap.xml` are valid
- [ ] Site works with JavaScript disabled
- [ ] HTTPS redirect, HSTS, and security headers verified with `curl -I`
- [ ] Owner has reviewed the legal pages and filled the entity details

## 8. Out of scope for v1

- Blog, changelog RSS, newsletter
- Customer accounts or a license dashboard on our domain
- Localized versions (German can come later; English first)
- A/B testing, cookie banners, retargeting
- Live chat widgets
- A theme switcher (the site is dark only)

## 9. Handoff notes for the remote agent

- The app repo is the source of truth for features and version numbers. Read
  `README.md`, `docs/ARCHITECTURE.md`, and `docs/LAUNCH.md` before writing copy.
- Do not change `appcast.xml` by hand; it is generated by Sparkle's
  `generate_appcast`. The site only serves it.
- Do not put the DMG in git. Upload it to the VPS `downloads/` directory; keep the
  previous version for rollback.
- Ask before adding any dependency, tracker, or hosted service.
- Deploy target and Caddy config are specified in the app repo's
  `docs/WEBSITE.md`.
- The site must remain usable if the VPS moves: relative links only, no hard-coded
  absolute paths except canonical/OG URLs.
