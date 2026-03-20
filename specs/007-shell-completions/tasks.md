# Tasks: Shell Completions

All tasks complete. Shipped 2026-03-14. Closed get-clear #4.

---

## Completion files

- [x] **T001** — Create `get-clear/completions/` directory
- [x] **T002** — `_reminders` — all commands with descriptions; dynamic list names for `list` arg; live titles for `show`/`change`/`done`/`remove`
- [x] **T003** — `_calendar` — all commands; dynamic subset names
- [x] **T004** — `_contacts` — all commands; dynamic group names for `list`/`export` args
- [x] **T005** — `_mail` — all commands
- [x] **T006** — `_sms` — all commands

---

## ANSI stripping

- [x] **T007** — Strip ANSI codes from dynamic completion output via sed pipeline before presenting to zsh

---

## PKG integration

- [x] **T008** — Bundle completion files to `/usr/local/share/zsh/site-functions/` in PKG installer (via `pkgbuild` payload)

---

## Curl installer integration

- [x] **T009** — Download completion files from GitHub release assets in `install.sh`
- [x] **T010** — Install to `~/.local/share/zsh/site-functions/`
- [x] **T011** — Patch `~/.zshrc`: add `fpath=(~/.local/share/zsh/site-functions $fpath)` before any `compinit` line

---

## Dotfiles integration

- [x] **T012** — Update `FPATH` in `~/.zsh/options.zsh` or equivalent to include `~/.local/share/zsh/site-functions` before Homebrew
- [x] **T013** — Personal install script creates `~/bin` symlinks to dev build artifacts — no more manual `cp` after `swift build`

---

## Closed issues

- [x] **get-clear #4** — shell completions for all five tools
- [x] **going-live Phase 3** — shell completions checked off
