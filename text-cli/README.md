# text-cli

Send iMessages and SMS from the terminal. Fire and forget.

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
git clone https://github.com/kscott/text-cli.git ~/dev/text-cli
cd ~/dev/text-cli
swift build -c release
cp .build/release/text-bin /usr/local/bin/text
```

## Command reference

```
text send <contact> <message...>     # Send an iMessage or SMS
text open [contact]                  # Open Messages.app
```

### Examples

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
text open Alice     # opens directly to that conversation
```

## Contact resolution

1. Direct phone number (10 or 11 digits) — normalized to E.164 (+1XXXXXXXXXX)
2. Direct email address — used as-is for iMessage
3. Fuzzy name match in Contacts — first phone number, or email if no phone

## How it works

- **Send** — AppleScript via `osascript` to Messages.app (handles iMessage with SMS fallback via iPhone)
- **Contact lookup** — CNContactStore for name → phone/email resolution

## Project structure

```
text-cli/
├── Package.swift
├── Sources/
│   ├── TextLib/                        # Pure Swift — no framework deps, fully testable
│   │   └── PhoneNormalizer.swift       # Phone normalization, matching, and contact resolution
│   └── TextCLI/
│       └── main.swift                  # CLI entry point (Contacts + osascript)
└── Tests/
    └── TextLibTests/                   # Quick + Nimble test suite
        └── PhoneNormalizerSpec.swift
```

## Tests

```bash
swift test
```
