# Marky

A lightweight, native macOS markdown editor with three editing modes and a live file browser.

## Features

- **Three editing modes**, switchable instantly with Cmd+1/2/3:
  - **Markdown** — raw text with live syntax highlighting (headings, bold, italics, code, links, blockquotes, lists)
  - **Split** — raw markdown on the left, rendered preview on the right
  - **Preview** — true WYSIWYG editing directly in the rendered view
- **Sidebar file browser** with recursive folder view, live file-system watching, and sort options (last opened, last modified, name)
- **Tabbed editing** for multiple files at once
- **Native keyboard shortcuts** — Cmd+B, Cmd+I, Cmd+E, Cmd+K, Cmd+D for inline formatting in both raw and WYSIWYG modes
- **Auto-updates** via [Sparkle](https://sparkle-project.org) — check automatically or on demand from the Marky menu
- **Signed and notarized** by Apple — no Gatekeeper warnings

## Install

Download the latest `Marky.dmg` from the [Releases page](https://github.com/detherington/Marky/releases/latest), open it, and drag Marky to Applications.

Once installed, Marky checks for updates automatically (daily) and will prompt you when a new version is available. You can also check manually via **Marky → Check for Updates…**.

## Build from source

Requires macOS 14+ and Swift 5.10+.

```bash
git clone https://github.com/detherington/Marky.git
cd Marky
swift run Marky
```

To produce a signed+notarized DMG (requires a Developer ID certificate and notarization credentials in your keychain):

```bash
./scripts/build-app.sh
```

Pass `--skip-notarize` to skip notarization during development.

## Release process

To cut a new release (maintainer only):

1. Bump `VERSION` / `SHORT_VERSION` in `scripts/build-app.sh`
2. Add release notes: `docs/release-notes/<version>.html`
3. Build: `./scripts/build-app.sh`
4. Publish: `./scripts/release.sh <version>`

The release script signs the DMG with the EdDSA key, updates `docs/appcast.xml`, commits and pushes (GitHub Pages picks up the new appcast), and creates a GitHub Release with the DMG attached.

## License

MIT — see [LICENSE](LICENSE).
