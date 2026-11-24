# PROJECT REBUILD

This repository includes a native SwiftUI experiment under `App/` and a
Cloudflare Pages ready, installable web app under `web/`. The web app is the
recommended iPhone path: host it on HTTPS, open it in Safari, then use **Share →
Add to Home Screen**. It works offline after its first load and stores personal
records encrypted in the browser.

## Host the web app on Cloudflare Pages

The GitHub repository is `thunderrock101/project-rebuild`.

1. In Cloudflare, open **Workers & Pages → Create application → Pages → Import
   an existing Git repository** and select this repository.
2. Configure the production branch as `main`, build command as `exit 0`, and
   build output directory as `web`.
3. Deploy. Cloudflare gives the site an HTTPS `*.pages.dev` address and can
   deploy future pushes automatically.
4. On iPhone, open that address in Safari, tap **Share → Add to Home Screen →
   Add**, then launch it from the new Home Screen icon.

The app code is static. Cloudflare serves the shell files, while habits, sleep,
mood, journal, XP and rewards remain in local IndexedDB. The app does not upload
those records. A password is used with PBKDF2-SHA256 to derive an AES-256-GCM
encryption key; the password and key are not persisted. Exported backups are
encrypted too. Losing the password means the local data and backups cannot be
decrypted, so keep the password safe.

The web MVP includes the dashboard, default daily habits, custom habit add,
one-time XP awards, recovery mode, sleep sessions, mood/journal check-ins,
reward credits, encrypted backup/restore, and offline shell caching. Analytics,
finance, nutrition, fitness, projects and expanded achievement management are
future modules. It does not provide medical diagnoses.

## Native iOS template

The `App/` directory retains the SwiftUI version and loopback control API. Its
build workflow runs on GitHub Actions; the browser app can be deployed
independently from `web/` using the Pages configuration above.

The remaining sections document the underlying build and sideload workflow.

A starting point an AI agent can use to build, ship and drive a **native iOS app (Swift + optional Rust)** on a real iPhone, **without a Mac and without a paid Apple Developer account**. Built from a working setup (LoopLab) on iPhone 17 Pro Max / iOS 27, October 2026.

Hand this repo to an agent together with your app idea. The agent does everything it can by script; the few things only a human can do are listed in [HUMAN-STEPS.md](HUMAN-STEPS.md), and the agent should ask for them one at a time, at the moment they're needed.

## How it works
```
agent edits code ──git push──▶ GitHub Actions (macOS, Xcode 27) ──▶ unsigned .ipa as a GitHub release
                                                                            │
                     iPhone: SideStore (free Apple ID) re-signs + installs ◀┘   (one tap: "Update")
                                                                            │
agent ◀── JSON over 127.0.0.1 (loopback) ── app's control server ◀──────────┘   (agent drives/measures the app)
```
- **Build**: `project.yml` (XcodeGen) → `xcodebuild archive CODE_SIGNING_ALLOWED=NO` on the free `xcode-27` runner (public repos: free minutes). Releases publish the `.ipa` plus a SideStore source JSON at a stable URL.
- **Install/update**: SideStore source URL `https://github.com/<owner>/<repo>/releases/latest/download/sidestore-source.json`. After the first install, every update is one tap.
- **Drive**: the app starts an HTTP JSON server bound to `127.0.0.1` only, protected by a token shown in-app. An agent with a terminal on the same phone (e.g. iSH via Minis) calls it with `curl`; see `tools/appctl`.
- **Rust (optional)**: `rust/` builds a static library for `aarch64-apple-ios` in CI and links it; Swift calls it through a C header. Remove the folder if you don't need it.

## Files
| path | purpose |
|---|---|
| `project.yml` | XcodeGen spec: app target, entitlements, SwiftPM deps, URL scheme |
| `App/` | SwiftUI app: `ControlServer.swift` (loopback JSON API), `DeviceProbe.swift` (hardware + granted entitlements), `App.swift` |
| `rust/` | optional Rust crate → `libcore.a` + `core.h` |
| `.github/workflows/build.yml` | build, package, release, SideStore source |
| `tools/ci` | wait for a CI run, print the failing step and error lines |
| `tools/appctl` | call the app's control API from a phone terminal |
| `HUMAN-STEPS.md` | the user's one-time setup, in order |
| `AGENTS.md` | rules for the agent: loop, pitfalls, verification |

## Limits of the free path (verified Oct 2026)
- Free Apple ID: **3 sideloaded apps at once, 7-day signature** (SideStore refreshes automatically), ~10 new App IDs per week.
- Not available to free teams: push notifications, app groups across teams, iCloud, Sign in with Apple, associated domains. Don't add those entitlements.
- **`increased-memory-limit`** (≈6 GB vs ≈3.3 GB usable on 12 GB iPhones) *is* granted to free teams by Apple, but SideStore currently strips it (SideStore issue #1616, fix PR SideSign#4). Workarounds: AltStore 2.3, or the GetMoreRam app. The template's `DeviceProbe` reports whether it was actually granted — check `GET /device`.
- No JIT at runtime. Metal shaders compiled at runtime (`makeLibrary(source:)`) are fine.
