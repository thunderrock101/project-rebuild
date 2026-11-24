# PROJECT REBUILD

An iPhone-first, installable web app for daily habits, sleep, mood, recovery and
personal rewards. The static app is in `web/` and is ready for Cloudflare Pages.

## Deploy to Cloudflare Pages

The source repository is [thunderrock101/project-rebuild](https://github.com/thunderrock101/project-rebuild).

1. In Cloudflare, open **Workers & Pages → Create application → Get started → Drag and drop your files**.
2. Upload `PROJECT-REBUILD-Cloudflare-Pages-Upload.zip` from this repository.
3. Deploy. Cloudflare serves the files over HTTPS at the assigned `pages.dev` URL.

The ZIP has the web files at its root, as Pages expects. For automatic deploys
from Git instead, connect the repository, set build output directory to `web`,
and use `exit 0` as the build command. See [Cloudflare's static HTML guide](https://developers.cloudflare.com/pages/framework-guides/deploy-anything/).

## Install on iPhone

Open the Pages HTTPS URL in Safari → **Share → Add to Home Screen → Add**. The
app opens in its own full-screen window and caches its shell for offline use
after the first visit.

On first use, set an eight-character-or-longer password. This initializes the
encrypted local vault and an on-device key. The password is not requested again
on this device, including when the app opens from its Home Screen icon. The
password is required to restore an encrypted backup on another device. If it is
lost, backups cannot be decrypted.

## Privacy and storage

Cloudflare hosts only static files. Habits, journal entries, sleep and mood
records stay in this browser's IndexedDB and are encrypted with AES-256-GCM.
No personal records are sent to Cloudflare or another service. Encrypted JSON
backups can be exported from **Settings**. The app does not provide medical
diagnoses.

## Current features

- Dashboard, levels, XP and life-area progress
- Daily habit tracker, custom habits, recovery mode and planned rest
- Sleep sessions, including sessions crossing midnight
- Mood check-ins and private journal
- Personal reward store and credits
- Encrypted backup and restore
- Responsive iPhone navigation and offline shell caching

Analytics, finance, nutrition, fitness and projects remain future modules.

## White-box checks

Run from the repository root with Node.js:

```sh
node --check web/app.js
node --check web/core.js
node --check web/sw.js
node --test tests/whitebox.test.cjs
```

The `App/` directory is the earlier native SwiftUI experiment; Cloudflare Pages
uses only `web/`.
