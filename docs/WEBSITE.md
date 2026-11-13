# Website concept and build brief

> Hand this file to the remote agent. It is the complete brief for the Mullion
> marketing site. Nothing here requires an application server: the site is static
> files on a VPS, and checkout is an outbound link to a merchant of record.

Status: concept, pre-build. Copy is draft and can be edited; structure and technical
constraints are the parts to follow.

- Product: **Mullion**
- Domain: **mullion.app** (placeholder until purchased)
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

Single long page plus four legal/utility pages. No blog at launch.

```
/                     landing page
/download             versioned DMG + checksum + system requirements
/changelog            release notes (plain HTML, one section per version)
/activate             how to enter a license key, find your key, deactivate
/privacy              privacy policy
/terms                terms of sale
/refunds              refund policy
/imprint              Impressum (required in Germany/EU)
/support              optional: short FAQ + email link (can be an anchor on /)
```

Navigation (top right): `Features` `Pricing` `FAQ` `Changelog` `Download`.
A single primary button: **Buy €14.99**. When the visitor already owns Mullion,
the menu shows `Download`.

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
Polar. Card details never touch this site."

If Gumroad is used instead, replace "Polar" with "Gumroad" and keep the rest.

Do **not** invent a subscription toggle, team plan, or "lifetime deal" countdown.

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
- Download · Changelog · Support
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

Deployed root on the VPS: `/var/www/mullion/` (see §6 for Caddy, DNS, TLS, and
deployment commands).

### Download page

- Detect Apple silicon vs Intel only to recommend the right file; ship one universal
  DMG if possible, so there is nothing to choose.
- Show: version, build number, macOS requirement, architecture, file size, SHA-256.
- Button: `Download Mullion 1.0.0` → `/downloads/Mullion-1.0.0.dmg`.
- Secondary: `Release notes` and `Verify the signature` (collapsible block with
  `spctl` / `codesign` commands).
- After the trial expires, the app links to `/activate`; the purchase receipt links
  to `/download`.

### Checkout links

- Buy buttons point directly at the hosted checkout (Polar product link, or Gumroad
  overlay). Open in the same tab; no modal, no email capture form on our side.
- `Start free trial` scrolls to the download section or goes to `/download`.
- Add `?utm_source=website&utm_medium=buy` only if the store supports it; do not add
  third-party pixels.

### SEO and metadata

- `<title>Mullion — a visual ⌘⇥ window switcher for macOS</title>`
- Description: "Replace ⌘⇥ with live window previews. Fast, keyboard-first, and
  idle when closed. One-time purchase, free 14-day trial. macOS 14+."
- Canonical, Open Graph, Twitter card (`summary_large_image`), `og-image.png`.
- JSON-LD `SoftwareApplication`: name, operatingSystem `macOS 14+`,
  applicationCategory `UtilitiesApplication`, offers price `14.99`, priceCurrency
  `EUR`, `downloadUrl`.
- `robots.txt` allows everything except `/downloads/*.dmg` if you prefer not to
  index binaries.
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
  site sets no cookies, that checkout is handled by the merchant of record, that the
  app validates licenses with Polar/Gumroad, and the legal basis (GDPR Art. 6).
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

A €5/month VPS is enough. The site is static, so there is no runtime to keep alive,
no database, and no application server to patch.

### Server

- Ubuntu 24.04 LTS, 1 vCPU, 1 GB RAM, 20 GB disk (Hetzner CX22, Vultr, or similar)
- IPv4 + IPv6
- DNS: `A @ → <IPv4>`, `AAAA @ → <IPv6>`, `CNAME www → @`

### First-time setup

```bash
# as root, once
adduser deploy
usermod -aG sudo deploy
rsync --archive --chown=deploy:deploy ~/.ssh/authorized_keys /home/deploy/.ssh/
```

Harden SSH in `/etc/ssh/sshd_config.d/99-mullion.conf`:

```
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
```

```bash
systemctl restart ssh
apt update && apt upgrade -y
apt install -y ufw unattended-upgrades
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
dpkg-reconfigure -plow unattended-upgrades
```

Install Caddy from the official repository, then:

```bash
mkdir -p /var/www/mullion/downloads
chown -R deploy:deploy /var/www/mullion
```

### `/etc/caddy/Caddyfile`

```caddyfile
mullion.app {
    root * /var/www/mullion
    encode zstd gzip

    @appcast path /appcast.xml
    header @appcast Cache-Control "no-cache"

    @dmg path /downloads/*.dmg
    header @dmg Content-Type "application/x-apple-diskimage"
    header @dmg Cache-Control "public, max-age=31536000, immutable"

    @sha path /downloads/*.sha256
    header @sha Cache-Control "no-cache"

    @assets path /assets/*
    header @assets Cache-Control "public, max-age=604800"

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        Content-Security-Policy "default-src 'self'; img-src 'self' data:; media-src 'self'; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'self'"
    }

    file_server
}

www.mullion.app {
    redir https://mullion.app{uri} permanent
}
```

`caddy reload --config /etc/caddy/Caddyfile` after edits. TLS certificates are
provisioned automatically; port 80 must stay open for the ACME challenge.

The CSP assumes external CSS/JS only. If the remote agent inlines styles, the policy
must be widened — prefer fixing the markup over weakening the policy.

### Deploy

```bash
rsync -avz --delete --exclude 'downloads/' web/ deploy@mullion.app:/var/www/mullion/
rsync -avz dist/Mullion-1.0.0.dmg dist/Mullion-1.0.0.dmg.sha256 \
  deploy@mullion.app:/var/www/mullion/downloads/
```

- `--delete --exclude downloads/` keeps old DMGs available for rollback.
- Generate the checksum with `shasum -a 256 dist/Mullion-1.0.0.dmg`.
- Never edit files directly on the server; the repo is the source of truth and the
  VPS is a deploy target.
- Do not put the DMG in git. Upload it separately.

### Smoke test after every deploy

```bash
curl -I https://mullion.app/
curl -I https://mullion.app/appcast.xml            # 200, application/xml, no-cache
curl -I https://mullion.app/downloads/Mullion-1.0.0.dmg
curl -s https://mullion.app/downloads/Mullion-1.0.0.dmg | shasum -a 256
curl -sI http://mullion.app/ | head -1             # 308 to https
curl -s https://mullion.app/robots.txt
```

### Backups and monitoring

- The site and appcast are in git; the only server-side originals are the DMGs.
  Keep a copy of `dist/` locally and in object storage.
- Weekly `restic`/`borg` backup of `/var/www/mullion` if you keep anything there that
  is not reproducible.
- External uptime check (BetterStack free tier, Uptime Kuma, or a cron `curl` from
  another machine) on `/` and `/appcast.xml`.
- Email: use a hosted provider (Fastmail, Migadu, Zoho) for `support@mullion.app`.
  Do not run a mail server on the VPS.

### Cloudflare (optional)

Only add it after the origin works. Keep TLS mode **Full (strict)**, cache `/assets/*`
and downloads, and bypass cache for `/appcast.xml` and `/download` so customers are
never served a stale version. If Cloudflare's caching causes confusion, turn it off;
the origin is already fast for static files.

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
