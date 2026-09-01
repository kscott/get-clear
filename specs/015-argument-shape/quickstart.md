# Quickstart — wiring a command to the shared parser

For the Phase 1 reminders work, and the template for Phase 2 (#192–195).

## 1. Define the shape

`<Tool>Lib/<Tool>CommandShapes.swift`:

```swift
import GetClearKit

enum ReminderCommandShapes {
    static let repeatKw = Keyword("repeat", aliases: ["repeats", "repeating", "repeated"])
    static let dueKw    = Keyword("due", aliases: ["date"])

    static let add = CommandShape(
        identifiers: [Identifier("title")],
        leading: .bareDate,
        keywords: [Keyword("list"), Keyword("priority"), Keyword("url"), repeatKw, dueKw],
        trailingTextKeyword: "note"
    )

    static let remove = CommandShape(
        identifiers: [Identifier("title")],
        keywords: [Keyword("list")]
    )

    static let list = CommandShape(
        identifiers: [Identifier("list", required: false)],
        keywords: [Keyword("by")]
    )

    static let find = CommandShape(
        identifiers: [Identifier("query")]
    )
    // rename: identifiers [Identifier("title"), Identifier("new title")], keywords [Keyword("list")]
}
```

## 2. Parse in the handler

```swift
public func handleRemove(args: [String], store: any ReminderStore) async throws -> String {
    let parsed: ParsedCommand
    do {
        parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.remove)
    } catch let e as ArgumentError {
        throw ReminderHandlerError(e.errorDescription ?? "invalid arguments")
    }

    let title = parsed.identifiers[0]
    let list  = try await resolvedList(named: parsed.values["list"], from: store)
    // ... unchanged from here
}
```

`args[0]` is the command name (`parseArgs` keeps it there); pass `args.dropFirst()` to `parseCommand`.

## 3. add / change — map to `ParsedOptions`

```swift
let parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.add)
let title  = parsed.identifiers[0]
let opts   = parseOptions(from: parsed)   // ParsedOptions { date, recurrence, priority, url, list, note }
// parseDate(opts.date), parseRecurrence(opts.recurrence), parsePriority(opts.priority) — all unchanged
```

## 4. list / find

```swift
// handleList
let filter = parsed.identifiers.first                       // nil → all lists
let order  = try sortOrder(from: parsed.values["by"])       // throws on an unknown value (was silent → .due)

// handleFind — query is a required identifier, so it is always present here
let query = parsed.identifiers[0]      // `reminders find` already threw missingIdentifier(name: "query")
```

## 5. Test the shape

`<Tool>LibTests/<Tool>CommandShapesSpec.swift`:

```swift
describe("the remove shape") {
    it("parses a quoted list keyword") {
        let p = try! parseCommand(["Pay rent", "list", "House Stuff"], shape: ReminderCommandShapes.remove)
        expect(p.identifiers) == ["Pay rent"]
        expect(p.values["list"]) == "House Stuff"
    }
    it("rejects a stray token where the name should have been quoted") {
        expect { try parseCommand(["Pay", "rent"], shape: ReminderCommandShapes.remove) }
            .to(throwError(ArgumentError.unexpectedTokens(["rent"])))
    }
}
```

## Verify

```bash
swift test 2>&1 | tail -20
swift build -c release 2>&1 | tail -10
swiftformat --lint . && swiftlint lint --quiet
```
