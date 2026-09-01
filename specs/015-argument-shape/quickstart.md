# Quickstart — wiring a command to the shared parser

For the Phase 1 reminders work, and the template for Phase 2 (#192–195).

## 1. Define the shape

In `<Tool>Lib/<Tool>CommandShapes.swift`:

```swift
import GetClearKit

enum ReminderCommandShapes {
    static let repeatKw = Keyword("repeat", aliases: ["repeats", "repeating", "repeated"])
    static let dueKw    = Keyword("due", aliases: ["date"])

    static let add = CommandShape(
        identifiers: ["title"],
        acceptsBareDate: true,
        keywords: [Keyword("list"), Keyword("priority"), Keyword("url"), repeatKw, dueKw],
        trailingTextKeyword: "note"
    )

    static let remove = CommandShape(
        identifiers: ["title"],
        keywords: [Keyword("list")]
    )
    // rename: identifiers ["title", "new title"], keywords [Keyword("list")]
    // change: same as add
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

## 3. For add / change: map to `ParsedOptions`

```swift
let parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.add)
let title  = parsed.identifiers[0]
let opts   = parseOptions(from: parsed)   // ParsedOptions { date, recurrence, priority, url, list, note }
// ... parseDate(opts.date), parseRecurrence(opts.recurrence), etc. — all unchanged
```

## 4. Test the shape

`<Tool>Lib Tests/<Tool>CommandShapesSpec.swift`:

```swift
describe("the remove shape") {
    it("parses a quoted list keyword") {
        let p = try! parseCommand(["remove", "Pay rent", "list", "House Stuff"].dropFirst().map(String.init),
                                  shape: ReminderCommandShapes.remove)
        expect(p.identifiers) == ["Pay rent"]
        expect(p.values["list"]) == "House Stuff"
    }
    it("rejects a bare word where list is required") {
        expect { try parseCommand(["Pay rent", "House", "Stuff"], shape: ReminderCommandShapes.remove) }
            .to(throwError(ArgumentError.unexpectedTokens(["House", "Stuff"])))
    }
}
```

## Verify

```bash
swift test 2>&1 | tail -20
swift build -c release 2>&1 | tail -10
swiftformat --lint . && swiftlint lint --quiet
```
