# contacts-cli

Fast CLI for Apple Contacts via CNContactStore. Search, show, export, and manage contacts directly from the terminal.

## Installation

```bash
git clone https://github.com/kscott/contacts-cli ~/dev/contacts-cli
~/dev/contacts-cli/contacts setup
```

This builds the release binary, installs it to `~/bin/contacts-bin`, and symlinks `~/bin/contacts` to the wrapper script.

Requires macOS 14+.

## Commands

```
contacts open                       # Open the Contacts app
contacts lists                      # Show all contact groups
contacts list <group>               # Everyone in a group
contacts export <group>             # Paste-ready "Name <email>, ..." string
contacts search <query>             # Search name, email, phone, company
contacts show <name>                # Full contact card
contacts add <name> [email E] [phone P] [note free text]
contacts add <name> to <group>
contacts change <name> [email E] [phone P] [note free text]
contacts rename <name> <new-name>
contacts remove <name>
contacts remove <name> from <group>
```

## Examples

```bash
# Search
contacts search alice
contacts search "@acme.com"
contacts search "555-1234"

# Show a full contact card
contacts show "Alice Smith"

# Export a group for pasting into To/Cc
contacts export "Board Members"

# Add
contacts add "Jane Doe" email jane@acme.com phone 555-1234 note met at conference
contacts add "Jane Doe" to "Acme"

# Change — only specified fields are updated
contacts change "Jane Doe" email jane.smith@acme.com
contacts change "Jane" note now at new company
contacts change "Jane" phone none    # removes phone
contacts change "Jane" email none    # removes all email

# Rename (changes identity)
contacts rename "Jane Doe" "Jane Smith"

# Remove
contacts remove "Jane Doe"
contacts remove "Jane Doe" from "Acme"
```

## Build & test

```bash
contacts setup   # build release binary and install to ~/bin
contacts test    # build and run test suite
```

Or directly via SPM:

```bash
swift build -c release
swift test
```

## Project structure

- `Sources/ContactsLib/Matching.swift` — pure matching and formatting logic, no framework deps
- `Sources/ContactsCLI/main.swift` — CLI entry point, all Contacts/AppKit code
- `Tests/ContactsLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `contacts` — bash wrapper script, symlinked into `~/bin`

## Key decisions

- **Contacts framework over AppleScript** — faster, non-blocking, fully scriptable
- **ContactsLib separated from ContactsCLI** — allows unit testing without entitlements or permissions
- **Custom test runner instead of XCTest** — works with CLT only, no full Xcode needed
- **Keyword-based argument parsing** — natural language, no flags
- **Fuzzy matching** — partial names, email fragments, phone digits all work
- **`to`/`from` keywords** disambiguate group membership: `add X to <group>`, `remove X from <group>`

## Known limitations

- Write operations require Full Contacts access (not just read)
- Phone numbers are stored with a single "main" label; multi-number contacts show the first
