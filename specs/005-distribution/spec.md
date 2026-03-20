# Feature Specification: Signing, Notarization & Distribution

**Feature Branch**: `main` (multiple commits, 2026-03-14)
**Created**: 2026-03-14
**Status**: Shipped (Phase 0 complete 2026-03-14; PKG live at github.com/kscott/get-clear/releases; curl installer live)
**Input**: Five tools were built and tested locally but had no distribution story. Sharing required copying binaries manually. macOS Gatekeeper would quarantine unsigned binaries from the internet. A real distribution pipeline required: Developer ID signing, notarization, a PKG installer, a curl installer, and an uninstaller.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Install via PKG (Priority: P1)

A macOS user downloads `get-clear.pkg` from the GitHub releases page and double-clicks it. macOS opens the installer without a Gatekeeper warning — the package is signed and notarized. After clicking through the installer steps (welcome, conclusion), all five tools are installed to `/usr/local/bin`. The user opens a new terminal and the commands work immediately.

**Why this priority**: The PKG is the zero-configuration path. It handles PATH, permissions, and the macOS trust chain without user intervention. It is the recommended install path for anyone who doesn't use the curl installer.

**Independent Test**: Download `get-clear.pkg` from the latest release. Run `spctl --assess --type install get-clear.pkg` — it should print "accepted." Install it and run `reminders --version` in a new terminal.

**Acceptance Scenarios**:

1. **Given** `get-clear.pkg` from a GitHub release, **When** `spctl --assess --type install` runs, **Then** the result is "accepted" — signed and notarized by Apple.
2. **Given** the PKG installer runs to completion, **When** the user opens a new terminal, **Then** all five tools are on PATH at `/usr/local/bin`.
3. **Given** the welcome and conclusion HTML pages are configured, **When** the installer runs, **Then** the user sees introductory text on the first screen and next-step instructions on the final screen.
4. **Given** a new version is released, **When** the user runs the PKG for the new version, **Then** the existing binaries are replaced — no manual cleanup required.

---

### User Story 2 — Install via curl (Priority: P1)

A developer runs `curl -fsSL .../install.sh | bash`. The script downloads each tool's binary release asset from GitHub, installs it to `~/.local/bin`, patches `~/.zshrc` to add `~/.local/bin` to PATH if needed, and prints a "what's next" summary. No Homebrew, no Xcode, no build step required.

**Why this priority**: The curl installer reaches users who don't want or need a GUI installer. It's the path used when setting up a new machine via a script or dotfiles install. It also serves as the auto-update mechanism when `get-clear update` is run.

**Independent Test**: Run the install script on a machine that doesn't have the tools. Verify all five binaries appear in `~/.local/bin`, that `~/.zshrc` was patched, and that each tool responds to `--version`.

**Acceptance Scenarios**:

1. **Given** a fresh machine with no Get Clear tools, **When** the curl installer runs, **Then** all five tools are installed to `~/.local/bin` and respond to `--version`.
2. **Given** `~/.local/bin` is not in PATH, **When** the installer runs, **Then** it appends `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc`.
3. **Given** `~/.local/bin` is already in PATH, **When** the installer runs, **Then** it does not duplicate the PATH entry.
4. **Given** existing binaries in `~/.local/bin`, **When** the installer runs, **Then** it replaces them with the latest versions — idempotent.

---

### User Story 3 — Uninstall cleanly (Priority: P2)

The user runs the uninstaller (`/usr/local/share/get-clear/uninstall.sh` after PKG install, or by downloading `scripts/uninstall` from the repo). The script removes the five binaries and the PKG receipt. It prompts whether to also remove config files and Keychain credentials. `--purge` skips the prompt and removes everything.

**Why this priority**: A tool that can't be removed cleanly isn't ready for wide distribution. The uninstaller must handle the full trust chain — binary, receipt, config, and credentials — without leaving artifacts.

**Independent Test**: Install via PKG, then run the uninstaller. Verify: binaries are gone from `/usr/local/bin`, the receipt is gone (`pkgutil --pkgs | grep get-clear` returns nothing), and config files are removed after confirming the prompt.

**Acceptance Scenarios**:

1. **Given** a PKG installation, **When** the uninstaller runs, **Then** all five binaries and the PKG receipt are removed.
2. **Given** the user confirms the prompt, **When** the uninstaller runs, **Then** `~/.config/<tool>/` directories and Keychain credentials are also removed.
3. **Given** `--purge` flag, **When** the uninstaller runs, **Then** everything is removed without prompting.
4. **Given** a partially installed state (e.g., some tools missing), **When** the uninstaller runs, **Then** it does not fail — missing binaries are silently skipped.

---

### User Story 4 — CI builds, signs, and publishes automatically (Priority: P1)

A maintainer pushes a version tag (e.g., `v1.1.0`). The get-clear CI workflow triggers, downloads the five signed binaries from their respective GitHub releases, assembles a PKG, signs it with the Developer ID Installer certificate, submits it for notarization, staples the notarization ticket, and publishes `get-clear.pkg` to the GitHub release. No manual steps.

**Why this priority**: Manual signing and notarization are error-prone and slow. The CI pipeline is the release mechanism. If it breaks, shipping stops. It must be fully automated and auditable.

**Independent Test**: Push a version tag and watch the CI workflow. Verify: the notarization step completes (no "Invalid" result), the PKG is stapled, and the release asset appears on the releases page.

**Acceptance Scenarios**:

1. **Given** a version tag push, **When** CI runs, **Then** the PKG is built, signed, notarized, stapled, and published without manual intervention.
2. **Given** a failing test in any component, **When** CI runs, **Then** the PKG is not published — tests are a required check.
3. **Given** the Developer ID Installer cert in GitHub Secrets, **When** CI imports it, **Then** it imports successfully into the macOS Keychain using the legacy-compatible PKCS12 format.
4. **Given** a release tag that already exists (re-run scenario), **When** CI runs, **Then** the workflow handles the existing tag gracefully without failing.

---

### Edge Cases

**Stapling does not work on raw binaries**
`xcrun stapler staple` only works on app bundles, PKGs, and DMGs — not raw CLI binaries. The five individual tool CIs originally included a stapler step that always failed. This was removed from all five tool repos once diagnosed. The get-clear PKG CI staples the PKG itself, which works correctly.

**Legacy-compatible PKCS12 format**
Apple's notarytool and the macOS `security` framework require certificates exported in a specific PKCS12 format. Modern OpenSSL exports use AES-256 encryption for the private key, which the macOS security framework rejects. The fix: export with `-legacy` flag to use 3DES/RC2, which the framework accepts. The `.p12` file in Secrets was exported this way.

**`/usr/local/bin` vs `~/.local/bin`**
The PKG installs to `/usr/local/bin` (system-wide, requires admin, in default PATH). The curl installer installs to `~/.local/bin` (user-only, no admin required). Both are correct for their contexts. `/usr/local/bin` was chosen for PKG because PKG installers run as root anyway; Homebrew's `/opt/homebrew` is package-manager-specific and not applicable here.

**Race condition in multi-repo CI**
On the initial release run, a race condition caused one tool's binary release asset to be replaced mid-download by the PKG CI. Fixed by ensuring tool release CI completes before the PKG CI downloads assets — enforced by release tag timing and the PKG CI waiting for all five to be present.

**Developer ID Installer vs Application cert**
Two separate certificates are used: Developer ID Application (used by individual tool binaries, from signing infrastructure pre-existing before this work) and Developer ID Installer (used to sign the PKG). The Installer cert required a separate CSR and Apple approval. It was backed up alongside the Application cert in a Secure Documents disk image.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The get-clear PKG MUST be signed with a Developer ID Installer certificate before notarization submission.
- **FR-002**: The PKG MUST be notarized by Apple and the notarization ticket MUST be stapled to the PKG before publication.
- **FR-003**: CI MUST use `xcrun notarytool` (not `altool`) for notarization. Credentials MUST be stored in GitHub Secrets, not hardcoded.
- **FR-004**: The PKG CI workflow MUST NOT include a stapler step for individual tool binaries — only the PKG itself is stapled.
- **FR-005**: `install.sh` MUST download binaries from GitHub Releases (not the repo tree), install to `~/.local/bin`, and patch `~/.zshrc` PATH if needed.
- **FR-006**: `install.sh` MUST be idempotent — safe to run multiple times, replaces existing binaries without error.
- **FR-007**: `scripts/uninstall` MUST remove binaries and the PKG receipt by default. It MUST prompt before removing config files and Keychain credentials. `--purge` MUST skip the prompt.
- **FR-008**: The uninstaller MUST be bundled in the PKG at `/usr/local/share/get-clear/uninstall.sh` so PKG users can find it after installation.
- **FR-009**: `scripts/bump-version X.Y.Z` MUST update the `VERSION` file, commit, and push. CI MUST trigger on the resulting tag.
- **FR-010**: The PKG installer MUST include a welcome page and a conclusion page (HTML) explaining what was installed and what to do next.
- **FR-011**: The PKG MUST install to `/usr/local/bin` as the default system-wide PATH location.
- **FR-012**: PKCS12 certificate exports MUST use legacy-compatible format (3DES/RC2, via `-legacy` flag) for macOS `security` framework compatibility.

### Key Entities

- **`get-clear.pkg`**: Signed, notarized, stapled macOS installer. Installs all five binaries to `/usr/local/bin` plus the uninstaller to `/usr/local/share/get-clear/`.
- **`install.sh`**: Curl-safe bash installer. Downloads release assets, installs to `~/.local/bin`, patches PATH.
- **`scripts/uninstall`**: Removes binaries, receipt, and optionally config/credentials.
- **`scripts/bump-version`**: Bumps `VERSION`, commits, pushes — triggers CI release.
- **`scripts/sync-secrets`**: Syncs Developer ID certs and notarytool credentials to all six GitHub repos.
- **`pkg/distribution.xml`**: PKG installer UI configuration (title, welcome, conclusion, install options).
- **`pkg/resources/welcome.html`** / **`pkg/resources/conclusion.html`**: Installer screen content.
- **`pkg/scripts/postinstall`**: Post-install script (opens README in browser).
- **`VERSION`**: Single source of version truth, read by bump-version and CI.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `spctl --assess --type install get-clear.pkg` prints "accepted" — Gatekeeper passes.
- **SC-002**: `pkgutil --check-signature get-clear.pkg` shows Developer ID Installer identity.
- **SC-003**: All five tools respond to `--version` immediately after PKG install in a new terminal.
- **SC-004**: The curl installer is idempotent — running it twice produces no errors and the same binaries are present.
- **SC-005**: The uninstaller removes all traces: binaries, receipt (`pkgutil --pkgs | grep get-clear` empty), and config/credentials when confirmed.
- **SC-006**: A new version tag triggers full CI → PKG → notarized release without manual steps.

## Design Notes

**PKG vs DMG vs curl-only.** A PKG was chosen over a DMG because PKGs handle PATH, permissions, and post-install scripts natively — DMGs require the user to drag-to-install and don't have a postinstall hook. The curl installer exists alongside the PKG for users who want a no-GUI path or for automated machine setup. Both are supported; neither is deprecated in favor of the other.

**Homebrew is not the target.** A Homebrew formula was considered but deprioritized. Homebrew requires a formula in a tap or the core registry, introduces a review process, and adds complexity for what is currently a personal tool. The PKG + curl model is faster to ship and easier to control. Homebrew is a future option if the suite reaches public adoption.

**`sync-secrets` is the certificate management tool.** Rather than managing secrets across six repos manually, `sync-secrets` syncs the Developer ID Application cert, Developer ID Installer cert, and notarytool credentials to all repos in one command. This is the canonical way to rotate credentials.

**Semantic versioning from `VERSION`.** A single `VERSION` file at the repo root is the source of truth. `bump-version X.Y.Z` updates it, commits, tags, and pushes. CI reads the tag. Individual tool repos have their own versioning; the get-clear umbrella version tracks the suite release.

## Assumptions

- The Developer ID Application certificates for the five individual tools are managed separately in their respective repos. This spec covers only the Developer ID Installer cert and PKG distribution.
- `notarytool` (not `altool`) is used for notarization — Apple retired `altool` support.
- Notarization requires an Apple Developer account with the App Store Connect API key or Apple ID credentials in Secrets.
- `/usr/local/bin` is in the default macOS PATH. This assumption holds for all macOS versions since Monterey. If Apple changes this, the PKG postinstall script would need to patch PATH.
