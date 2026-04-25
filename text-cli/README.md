# text-cli

Send iMessages and SMS from the terminal. Fire and forget.

Part of the [Get Clear](https://github.com/kscott/get-clear) suite.

---

## Commands

```
text send <contact> <message...>     # Send an iMessage or SMS
text open                            # Open Messages.app
```

## Examples

```bash
# Send by contact name
text send Alice Hey, are you free tonight?
text send "Alice Smith" Dinner at 7?

# Send to a phone number directly
text send 555-867-5309 On my way

# Send to an email address (iMessage)
text send alice@example.com Can you call me?

# Open Messages.app
text open
```

## Contact resolution

1. Direct phone number (10 or 11 digits) — normalized to E.164 (+1XXXXXXXXXX)
2. Direct email address — used as-is for iMessage
3. Name match in Contacts — first phone number, or email if no phone

## How it works

- **Send** — AppleScript via `osascript` to Messages.app (handles iMessage with SMS fallback via iPhone)
- **Contact lookup** — Contacts framework; prompts for access on first send
