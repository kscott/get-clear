# Development conventions

Patterns and decisions established for this project. Follow these when adding or changing anything.

## Architecture: what goes where

The project has two targets — keep them strictly separated.

**`ContactsLib`** — pure Swift, no framework dependencies
- All matching logic: name, email, phone, company scoring
- All formatting: `addressField`, `exportAddresses`, label cleaning
- Anything that can be expressed as `ContactRecord → String` or `[String] → [ContactRecord]`
- If it doesn't need the Contacts framework, it goes here

**`ContactsCLI/main.swift`** — Contacts and AppKit only
- Argument parsing and command dispatch
- CNContactStore calls (fetch, save, update)
- Thin conversion between CNContact and ContactRecord
- `NSWorkspace` for launching apps

The rule: if you find yourself wanting to test something that lives in `main.swift`, that's a sign it should be moved to `ContactsLib`.

## Interface design: no flags

The tool uses positional arguments and natural language keywords — not flags.

**Correct:**
```
contacts add "Jane Doe" email jane@acme.com phone 555-1234
contacts add "Jane Doe" to "Acme Corp"
contacts change "Jane" note met at the conference last week
contacts rename "Jane Doe" "Jane Smith"
contacts remove "Jane Doe" from "Acme Corp"
contacts remove "Jane Doe"
```

**Avoid:**
```
contacts add "Jane Doe" --email jane@acme.com   # don't do this
```

There are no flags. `rename` is a dedicated command for changing a contact's name
(identity). `change` modifies attributes. `to`/`from` keywords disambiguate group
membership from contact-level operations.

## Argument parsing conventions

- **Name** is always `args[1]` — required, user should quote it for names with spaces
- **Keywords** `email`, `phone`, `note` can appear in any order within the remaining args
- **Note** captures to end of string — extract first, then parse remaining for email/phone
- **`none` as value** in change — clears the field: `email none`, `phone none`, `note none`
- **`to <group>`** after name in add — signals group membership, not contact creation
- **`from <group>`** after name in remove — signals group membership removal, not contact deletion

## Natural language over syntax

Prefer recognising natural words over inventing syntax.

- `note` captures to end of string — no escaping needed; free text just works
- Contact matching is case-insensitive and fuzzy — partial names, email fragments, phone digits all work
- Search scores by quality so the best match wins

## Matching priority

`matchContacts()` scores candidates:

| Score | Condition |
|-------|-----------|
| 0 | Exact name match |
| 1 | Name starts with query |
| 2 | Name contains query |
| 3 | Any email contains query |
| 4 | Exact company match |
| 5 | Company contains query |
| 6 | Phone digits contain query digits |

Lower score wins. Unmatched contacts are excluded.

## Testing

- All test-worthy logic lives in `ContactsLib` so it can be tested without Contacts permissions
- Tests live in `Tests/ContactsLibTests/main.swift` — a custom runner, no XCTest or Xcode required
- Run with `contacts test`
- New matching or formatting behaviour → new test suite. Cover: typical inputs, edge cases, nil/empty inputs
- Test descriptions should read as plain English sentences (they appear verbatim in output)

## Output conventions

Commands confirm what they did. Format:

| Command | Output |
|---------|--------|
| `add` | `Added: <name>[ · email <e>][ · phone <p>][ · + note]` |
| `add to group` | `Added <name> to <group>` |
| `change` | `Updated "<name>": <change>, <change>` |
| `rename` | `Renamed: "<old>" → "<new>"` |
| `remove` | `Removed: <name>` |
| `remove from group` | `Removed <name> from <group>` |
| `show` | Multi-line card: name, Company, Email, Phone, Note |
| `search` | `  Name <email> — Company` per result |
| `list` | `  Name <email>` per member |
| `export` | Single paste-ready `Name <email>, Name <email>` string |

Errors go to stderr via `fail()`, which exits non-zero. No silent failures.

## Adding a new command

1. Add the case to the `switch cmd` block in `main.swift`
2. Add it to `usage()`
3. Add it to the command table in `README.md` and `CLAUDE.md`
4. If the command introduces new parsing logic, add it to `ContactsLib` with tests
