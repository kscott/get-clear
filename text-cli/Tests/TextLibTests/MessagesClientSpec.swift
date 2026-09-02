// MessagesClientSpec.swift
//
// Tests for TextLib MessagesClient — AppleScript escaping and script generation.

import Foundation
import Testing
import TextLib

@Suite("appleScriptLiteral")
struct AppleScriptLiteralTests {
    @Suite("plain strings with no double quotes")
    struct PlainStrings {
        @Test("wraps the string in double quotes")
        func wrapsInDoubleQuotes() {
            #expect(appleScriptLiteral("hello") == "\"hello\"")
        }

        @Test("handles an empty string")
        func handlesEmptyString() {
            #expect(appleScriptLiteral("") == "\"\"")
        }

        @Test("preserves spaces")
        func preservesSpaces() {
            #expect(appleScriptLiteral("hello world") == "\"hello world\"")
        }

        @Test("preserves single quotes")
        func preservesSingleQuotes() {
            #expect(appleScriptLiteral("it's fine") == "\"it's fine\"")
        }

        @Test("preserves backslashes")
        func preservesBackslashes() {
            #expect(appleScriptLiteral("a\\b") == "\"a\\b\"")
        }

        @Test("preserves newlines")
        func preservesNewlines() {
            #expect(appleScriptLiteral("line1\nline2") == "\"line1\nline2\"")
        }

        @Test("preserves tabs")
        func preservesTabs() {
            #expect(appleScriptLiteral("col1\tcol2") == "\"col1\tcol2\"")
        }
    }

    @Suite("strings containing double quotes")
    struct StringsWithDoubleQuotes {
        @Test("splits on double quote and joins with & quote &")
        func splitsAndJoins() {
            #expect(appleScriptLiteral("say \"hi\"") == "\"say \" & quote & \"hi\" & quote & \"\"")
        }

        @Test("handles a string that is only a double quote")
        func onlyADoubleQuote() {
            #expect(appleScriptLiteral("\"") == "\"\" & quote & \"\"")
        }

        @Test("handles a string that starts with a double quote")
        func startsWithDoubleQuote() {
            #expect(appleScriptLiteral("\"hello") == "\"\" & quote & \"hello\"")
        }

        @Test("handles a string that ends with a double quote")
        func endsWithDoubleQuote() {
            #expect(appleScriptLiteral("hello\"") == "\"hello\" & quote & \"\"")
        }

        @Test("handles multiple consecutive double quotes")
        func multipleConsecutive() {
            #expect(appleScriptLiteral("\"\"") == "\"\" & quote & \"\" & quote & \"\"")
        }

        @Test("handles multiple separated double quotes")
        func multipleSeparated() {
            #expect(appleScriptLiteral("a\"b\"c") == "\"a\" & quote & \"b\" & quote & \"c\"")
        }
    }

    @Suite("injection-relevant inputs")
    struct InjectionRelevantInputs {
        @Test("does not allow AppleScript keywords to break out of the literal")
        func noBreakout() {
            // A crafted message with a double quote cannot escape into AppleScript syntax
            let result = appleScriptLiteral("\" & do shell script \"rm -rf /\"")
            // Must not contain unquoted AppleScript command text
            #expect(result.hasPrefix("\"\""))
            #expect(result.contains("& quote &"))
        }

        @Test("handles a message with only AppleScript-significant characters")
        func onlySignificantCharacters() {
            // Backslash, newline, and single quotes are safe inside AppleScript strings
            let result = appleScriptLiteral("\\ \n '")
            #expect(result == "\"\\ \n '\"")
        }
    }
}

@Suite("buildScript")
struct BuildScriptTests {
    @Test("produces a tell-send-end tell structure")
    func tellSendEndTellStructure() {
        let script = buildScript(recipient: "+15551234567", message: "hello")
        #expect(script.contains("tell application \"Messages\""))
        #expect(script.contains("end tell"))
    }

    @Test("includes the escaped message")
    func includesEscapedMessage() {
        let script = buildScript(recipient: "+15551234567", message: "hello")
        #expect(script.contains("\"hello\""))
    }

    @Test("includes the escaped recipient")
    func includesEscapedRecipient() {
        let script = buildScript(recipient: "+15551234567", message: "hello")
        #expect(script.contains("\"+15551234567\""))
    }

    @Test("uses send ... to buddy syntax")
    func usesSendToBuddySyntax() {
        let script = buildScript(recipient: "+15551234567", message: "hello")
        #expect(script.contains("send"))
        #expect(script.contains("to buddy"))
    }

    @Test("escapes double quotes in the message")
    func escapesDoubleQuotesInMessage() {
        let script = buildScript(recipient: "a@b.com", message: "say \"hi\"")
        #expect(script.contains("& quote &"))
        #expect(!script.contains("say \"hi\""))
    }

    @Test("escapes double quotes in the recipient")
    func escapesDoubleQuotesInRecipient() {
        // Unusual but safe — the function escapes both arguments
        let script = buildScript(recipient: "weird\"addr", message: "hi")
        #expect(script.contains("& quote &"))
    }
}
