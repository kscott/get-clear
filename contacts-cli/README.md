# contacts-cli

Fast CLI for Apple Contacts via CNContactStore. Search, show, export, create, and edit contacts directly from the terminal.

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
contacts create <name> [company] [email E] [phone P] [note free text]
contacts edit <name> [email E] [phone P] [--name "New Name"] [note free text]
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

# Create
contacts create "Jane Doe" Acme email jane@acme.com phone 555-1234 note met at conference

# Edit — only specified fields are updated
contacts edit "Jane Doe" --name "Jane Smith"
contacts edit "Jane" email jane.smith@acme.com
contacts edit "Jane" note now at new company
contacts edit "Jane" phone none    # removes phone
contacts edit "Jane" email none    # removes all email
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
- **Keyword-based argument parsing** — natural language, no flags (except `--name` in edit)
- **Fuzzy matching** — partial names, email fragments, phone digits all work

## Known limitations

- Write operations (create/edit) require Full Contacts access (not just read)
- Phone numbers are stored with a single "main" label; multi-number contacts show the first
- Contact groups (lists) are read-only — group membership cannot be modified via CNContactStore without additional entitlements
