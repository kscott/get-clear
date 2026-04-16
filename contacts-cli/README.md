# contacts-cli

A command-line tool that lets Claude search, manage, and export your Apple Contacts — just by asking.

Part of the [Get Clear](https://github.com/kscott/get-clear) suite.

## Setup

### Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Mac (arm64) for the pre-built binary; Intel Macs must build from source

### Install

Install the full Get Clear suite via the PKG installer — download from the [latest release](https://github.com/kscott/get-clear/releases/latest) and run it.

This installs all five tools to `/usr/local/bin`. Make sure that's in your `$PATH`:

```bash
export PATH="/usr/local/bin:$PATH"   # add to ~/.zshrc
```

On first run, macOS will prompt you to grant Contacts access.

### Build from source

```bash
xcode-select --install   # if not already installed
git clone https://github.com/kscott/contacts-cli.git ~/dev/contacts-cli
cd ~/dev/contacts-cli
swift build -c release
cp .build/release/contacts-bin /usr/local/bin/contacts
```

## Command reference

```
contacts open                           # Open the Contacts app
contacts lists                          # Show all contact groups
contacts list <group>                   # Everyone in a group
contacts export <group>                 # Paste-ready "Name <email>, ..." string
contacts find <query>                   # Find by name, email, phone, or company
contacts show <name>                    # Full contact card
contacts add <name> [email E] [phone P] [note text]
contacts add <name> to <group>
contacts change <name> [email E] [phone P] [note text]
contacts rename <name> <new-name>
contacts remove <name>
contacts remove <name> from <group>
```

### Examples

```bash
contacts find alice
contacts find "@acme.com"
contacts find "555-1234"
contacts show "Alice Smith"
contacts export "Board Members"

contacts add "Jane Doe" email jane@acme.com phone 555-1234 note met at conference
contacts add "Jane Doe" to "Acme"

contacts change "Jane Doe" email jane.smith@acme.com
contacts change "Jane" phone none    # removes phone
contacts change "Jane" email none    # removes all email

contacts rename "Jane Doe" "Jane Smith"
contacts remove "Jane Doe"
contacts remove "Jane Doe" from "Acme"
```

## Known limitations

- Write operations require Full Contacts access (not just read)
- `change` and `remove` require an exact (case-insensitive) name match; use `find` first if unsure

## Project structure

```
contacts-cli/
├── Package.swift
├── Sources/
│   ├── ContactsLib/                    # Pure Swift — no framework deps, fully testable
│   │   └── Matching.swift              # Contact search, formatting, and export logic
│   └── ContactsCLI/
│       └── main.swift                  # CLI entry point (Contacts + AppKit)
└── Tests/
    └── ContactsLibTests/               # Quick + Nimble test suite
        └── MatchingSpec.swift
```

## Tests

```bash
swift test
```
