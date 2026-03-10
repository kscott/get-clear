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
contacts create "Jane Doe" Acme email jane@acme.com phone 555-1234
contacts edit "Jane" note met at the conference last week
```

**Avoid:**
```
contacts create "Jane Doe" --company Acme --email jane@acme.com   # don't do this
```

The one exception is `--name` in the `edit` command. It's necessary because there's no unambiguous way to distinguish the existing name (used to find the contact) from a new name (what to rename it to) positionally.

## Argument parsing conventions

- **Name** is always `args[1]` — required, user should quote it for names with spaces
- **Keywords** `email`, `phone`, `note` can appear in any order within the remaining args
- **Note** captures to end of string — extract first, then parse remaining for email/phone
- **company** for create — positional; any remaining text not matched by email/phone/note keywords
- **`none` as value** in edit — clears the field: `email none`, `phone none`, `note none`

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
| `create` | `Created: <name> · email <e> · phone <p> · <company> · + note` |
| `edit` | `Updated "<name>": <change>, <change>` |
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
