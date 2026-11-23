# Quickstart: verifying spec 018

## 0. Spike (gate — before any other task)
On primo (Developer ID identity is in the login keychain):
1. Build a throwaway `Spike.app` (`LSUIElement`, Reminders usage string, agent plist with `BundleProgram`/`MachServices`), sign it with Developer ID and the hardened runtime, and copy it to `/Applications`.
2. Run `Spike.app/Contents/MacOS/Spike register`, then from Terminal run the spike client, which asks the agent over XPC to call `requestFullAccessToReminders()`.
3. Expect: the prompt names **Spike**; `sudo launchctl procinfo <agent pid> | grep responsible` shows the app; Privacy & Security → Reminders lists Spike, not Terminal.
4. Repeat steps 2–3 from Tecolot on the work Mac (the #210 terminal). **This run is the go/no-go.**
5. Replace the bundle at the same path (same signature, bumped version) and confirm the grant and registration survive.
6. Repeat with `osascript` → Messages (Automation).

If step 3 or 4 fails, stop and bring the result back to Ken. The design rests on R1.

## 1. Local build
```bash
./scripts/test                      # all Lib tests, incl. wire round-trips
./scripts/build-app                 # .build/Get Clear.app, signed with the local Developer ID
```

## 2. Acceptance (per spec)
- **US1:** in a terminal with no usage strings, run `reminders lists`, `calendar today`, `contacts find a`, and `text send <self> message test`. Expect one prompt each, all naming Get Clear.
- **US2:** install the PKG over 1.3.5. Expect `which reminders` → `/usr/local/bin/reminders` (a symlink into the app), and stdout diffs clean against 1.3.5 for a fixed command set.
- **US3:** install vN, publish vN+1 to a test tag, run `get-clear update`. Expect no window, `--version` reporting N+1, and no new prompts. Then repeat with a tampered zip; expect it rejected and vN still working.
- **US4:** run the uninstaller. Expect `launchctl print gui/$UID/com.kenscott.get-clear.helper` → not found, and `which reminders` → nothing.
- **US5:** run `swift build` and the built binary from iTerm with no app installed. Expect today's behavior.
