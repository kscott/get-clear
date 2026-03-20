# Tasks: Signing, Notarization & Distribution

All tasks complete. Shipped 2026-03-14. PKG live at github.com/kscott/get-clear/releases.

---

## Certificate setup

- [x] **T001** — Generate CSR via openssl CLI for Developer ID Installer certificate
- [x] **T002** — Upload CSR to developer.apple.com; download and import resulting .cer
- [x] **T003** — Export .p12 with `-legacy` flag (3DES/RC2) for macOS security framework compatibility
- [x] **T004** — Back up Installer cert to Secure Documents disk image alongside Application cert
- [x] **T005** — Store in Keychain under `get-clear-signing` (installer-p12-base64, installer-p12-password)

---

## Repository infrastructure

- [x] **T006** — `VERSION` file — single source of version truth
- [x] **T007** — `scripts/bump-version X.Y.Z` — updates VERSION, commits, pushes, triggers CI
- [x] **T008** — `scripts/sync-secrets` — syncs Developer ID certs + notarytool credentials to all six repos
- [x] **T009** — Update `setup.md` with Installer cert creation steps

---

## PKG distribution pipeline

- [x] **T010** — `pkg/distribution.xml` — PKG installer UI: title, welcome, conclusion, rootVolumeOnly
- [x] **T011** — `pkg/resources/welcome.html` — introductory installer screen
- [x] **T012** — `pkg/resources/conclusion.html` — post-install next-steps screen
- [x] **T013** — `pkg/scripts/postinstall` — opens README in browser after install
- [x] **T014** — `.github/workflows/release.yml` in get-clear — downloads all five binaries from tool releases, runs `pkgbuild` + `productbuild`, signs, notarizes, staples, publishes PKG
- [x] **T015** — Remove stapler step from all five tool repos (stapling only works on PKG/DMG/bundle, not raw binaries)

---

## Curl installer

- [x] **T016** — `install.sh` — downloads five `{tool}-bin` release assets from GitHub, installs to `~/.local/bin`, patches `~/.zshrc` PATH if needed, prints next steps
- [x] **T017** — Idempotency: replace existing binaries without error; skip PATH patch if already present

---

## Uninstaller

- [x] **T018** — `scripts/uninstall` — removes binaries + PKG receipt; prompts for config/Keychain removal
- [x] **T019** — `--purge` flag — skips prompt, removes everything
- [x] **T020** — Bundle uninstaller in PKG at `/usr/local/share/get-clear/uninstall.sh`

---

## CI fixes and stabilization

- [x] **T021** — Fix legacy OpenSSL cipher compatibility (PKCS12 re-export with `-legacy`)
- [x] **T022** — Fix race condition: reminders-cli asset replaced mid-download; re-run after tool releases completed
- [x] **T023** — Fix existing release tag handling in CI (`e28849c`) — re-run scenarios don't fail
- [x] **T024** — Replace `softprops/action-gh-release` with `gh` CLI for release publication (`4bd6c6e`)
- [x] **T025** — Update `going-live.md`: Phase 0 fully checked off

---

## Closed issues / checklist items

- [x] **going-live Phase 0** — PKG is live, signed, notarized, stapled; curl installer live; uninstaller bundled
