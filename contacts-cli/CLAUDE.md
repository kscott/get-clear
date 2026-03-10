# contacts-cli

Swift CLI tool for Apple Contacts via CNContactStore.

## Build & run

```bash
contacts setup   # build release binary and install to ~/bin
contacts test    # build and run test suite
```

## Project structure

- `Sources/ContactsLib/Matching.swift` — pure matching and formatting logic, no framework deps
- `Sources/ContactsCLI/main.swift` — CLI entry point, all Contacts/AppKit code
- `Tests/ContactsLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `contacts` — bash wrapper script, symlinked into `~/bin`

See [DEVELOPMENT.md](DEVELOPMENT.md) for coding conventions, interface design rules, and patterns to follow when adding features.

## Commands

```
contacts open
contacts lists
contacts list <group>
contacts export <group>
contacts search <query>
contacts show <name>
contacts add <name> [email E] [phone P] [note free text]
contacts add <name> to <group>
contacts change <name> [email E] [phone P] [note free text]
contacts rename <name> <new-name>
contacts remove <name>
contacts remove <name> from <group>
```

## Key decisions

- **Contacts framework over AppleScript** — faster, non-blocking, fully scriptable
- **ContactsLib separated from ContactsCLI** — allows unit testing without entitlements or permissions
- **Custom test runner instead of XCTest** — works with CLT only, no full Xcode needed
- **Keyword-based argument parsing** — natural language, no flags
- **Fuzzy name matching** — `matchContacts()` scores by quality: exact > prefix > substring > email > company > phone
- **`to`/`from` keywords** — disambiguate group membership from contact operations

## Optional fields (add/change)

Keywords in any order; `note` captures to end of string and must be last:

```
contacts add "Jane Doe" email jane@acme.com phone 555-1234 note met at conference
contacts add "Jane Doe" to "Acme Corp"
contacts change "Jane Doe" email jane.smith@acme.com
contacts rename "Jane Doe" "Jane Smith"
contacts change "Jane" note none   # clears the note
contacts change "Jane" email none  # removes all email addresses
contacts remove "Jane Doe" from "Acme Corp"
contacts remove "Jane Doe"
```

## Adding a new command

1. Add the case to the `switch cmd` block in `main.swift`
2. Add it to `usage()`
3. Add it to the command table in `README.md` and `CLAUDE.md`
4. If the command introduces new parsing logic, add it to `ContactsLib` with tests
