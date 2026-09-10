# Feature Specification: Reminder Location Alarms

**Feature Branch**: `017-location-alarms`
**Created**: 2026-09-09
**Status**: Draft
**Input**: User description: "Location alarms for reminders — remind me when I arrive at or leave a place. Today a reminder can only fire on a date and time. This feature adds a place-based alarm: `reminders add \"Pick up milk\" arriving \"Whole Foods\"` and `reminders add \"Water plants\" leaving \"Home\"`. It is a change-able attribute like priority or repeat. The keyword is `arriving`/`leaving` itself — there is no `location` keyword, since the direction word already says it is a place. A reminder carries at most one location alarm. A named place is resolved to a real coordinate: Home/Work/School resolve from the person's own contact card first, anything else is looked up as an address, and resolution follows the suite's existing multi-match discipline. The location alarm must be visible in `show`. Tracked as issue #191."

---

## Background

A reminder in Get Clear can only be scheduled against a clock: a due date, optionally with a time, optionally repeating. But a large share of the things a person actually wants to be reminded of are not time-bound at all — they are place-bound. "Pick up milk" is not due Friday; it is due the next time you are at a grocery store. "Take out the recycling" is not due at 8am; it is due when you leave the house.

Apple's Reminders app has supported this for years, and the underlying capability is available to Get Clear through the same public system interfaces the tool already uses. What is missing is the vocabulary and the plumbing to reach it.

This feature adds one new attribute to a reminder — a **location alarm**: a place, plus a direction (arriving there, or leaving there). It behaves like every other reminder attribute: you can set it when you add a reminder, change it later, clear it, and read it back with `show`.

**Two things make this more than a field assignment.**

First, **a place name is not a place.** The system needs a coordinate to build a geofence around. "Whole Foods" is a phrase; it has to be resolved to somewhere on a map. That resolution can fail, and it can succeed in more than one way — there are four Whole Foods within a few miles of most people. Resolution is therefore the substance of this feature, and it must obey the suite's existing discipline: never guess, never silently pick the first candidate.

Second, **some places are personal.** "Home", "Work", and "School" are not addresses anyone can look up — they are addresses the person has already recorded on their own contact card. Get Clear already has a shared contact layer, so those places resolve from the person's own record before any general address lookup is attempted.

**Sequencing.** This feature lands after spec 015 (the suite argument-shape rule), because it adds vocabulary onto that rule rather than inventing its own. It is deliberately **independent of spec 014** (private Reminders metadata): location alarms need no consent gate, no private capability, and no elevated file access, and must not be scheduled behind or folded into that work.

---

## User Scenarios & Testing *(mandatory)*

The actors are the **person** typing commands at a terminal and **Claude** constructing command lines on the person's behalf. Both must be served: the vocabulary has to read naturally when typed cold from a reference card, and Claude has to produce lines that would look normal if the person had typed them.

### User Story 1 — Remind me when I get there (Priority: P1)

A person attaches a place to a reminder at the moment they create it. They name the place the way they would say it out loud, and the reminder fires when they arrive.

**Why this priority**: This is the feature. Everything else is refinement of it. A person who can only ever set an arrival alarm at creation time already has the whole value.

**Independent Test**: Run `reminders add "Pick up milk" arriving "Whole Foods"`. The reminder is created, the tool reports the place it resolved to, and `show` reads the alarm back.

**Acceptance Scenarios**:

1. **Given** a place name that resolves to exactly one address, **When** the person runs `reminders add "Pick up milk" arriving "Whole Foods"`, **Then** the reminder is created with an arrival alarm at that place and the output names the resolved address.
2. **Given** the same command, **When** the person afterwards runs `reminders show "Pick up milk"`, **Then** the output shows the place and the direction alongside the reminder's other attributes.
3. **Given** a reminder with both a due date and a location alarm (`reminders add "Pick up milk" friday arriving "Whole Foods"`), **When** it is created, **Then** both are set and both are shown — the two are independent, and neither replaces the other.
4. **Given** any command that sets a location alarm, **When** it succeeds, **Then** the output states once that the alarm fires only on a device where Reminders itself has been granted location access.

---

### User Story 2 — Remind me when I leave (Priority: P1)

The same attribute in the other direction. The person says `leaving` instead of `arriving` and the reminder fires on departure rather than arrival.

**Why this priority**: Departure is not a lesser case — "grab the dry cleaning ticket before you leave the house" is as common as the arrival case, and the two share one implementation entirely. Shipping one without the other would be arbitrary.

**Independent Test**: Run `reminders add "Water plants" leaving "Home"` and confirm via `show` that the direction reads as departure, not arrival.

**Acceptance Scenarios**:

1. **Given** a resolvable place, **When** the person runs `reminders add "Water plants" leaving "Home"`, **Then** the reminder is created with a departure alarm at that place.
2. **Given** a reminder with an arrival alarm, **When** the person runs `reminders change "Water plants" leaving "Home"`, **Then** the departure alarm replaces the arrival alarm — the reminder still has exactly one location alarm.

---

### User Story 3 — Personal places resolve to my addresses (Priority: P1)

"Home", "Work", and "School" mean the person's own home, work, and school. They resolve from the addresses already recorded on the person's own contact card, without the person having to type a street address.

**Why this priority**: These are the highest-frequency places by a wide margin, and they are exactly the ones a general address lookup handles worst — "Home" as a search phrase is meaningless. Without this, the most common case is also the most awkward one.

**Independent Test**: With a home address labelled on the person's own contact card, run `reminders add "Water plants" leaving "Home"` and confirm the output names that street address, not some unrelated business called Home.

**Acceptance Scenarios**:

1. **Given** the person's own contact card carries a labelled home address, **When** they use `Home` as the place, **Then** the alarm is set at that address and the output names it.
2. **Given** the person's own contact card carries a labelled work address, **When** they use `Work` as the place, **Then** the alarm is set at that address.
3. **Given** the person's own contact card exists but carries no address under the requested label, **When** they use that personal place name, **Then** the tool fails with a message naming the label it looked for, sets no alarm, and does **not** fall through to a general address lookup.
4. **Given** any place name that is not one of the personal place names, **When** it is used, **Then** the tool goes straight to the general address lookup without consulting the contact card.

---

### User Story 4 — An ambiguous place is never guessed (Priority: P1)

When a place name matches more than one real address, the tool shows the candidates and stops. It does not pick one. When it matches none, the tool fails and creates nothing.

**Why this priority**: This is the constitution's "no silent failures" applied to the one genuinely fuzzy input in the feature. Silently geofencing the wrong Whole Foods produces a reminder that never fires and gives no clue why — the worst possible outcome, because it looks like success.

**Independent Test**: Use a place name with several nearby matches. Confirm the candidates are listed, nothing is created or modified, and the exit status is non-zero.

**Acceptance Scenarios**:

1. **Given** a place name matching several addresses, **When** the person runs `reminders add "Pick up milk" arriving "Whole Foods"`, **Then** the tool lists the candidate addresses, creates no reminder, and exits non-zero.
2. **Given** the same situation on an existing reminder, **When** the person runs `reminders change "Pick up milk" arriving "Whole Foods"`, **Then** the candidates are listed and the reminder is left exactly as it was — no partial change is applied.
3. **Given** the listed candidates, **When** the person re-runs the command with a more specific place string, **Then** it resolves to one address and the alarm is set.
4. **Given** a place name matching no address at all, **When** the person uses it, **Then** the tool fails with a message naming the unresolvable place and makes no change.
5. **Given** a command that also carries other changes (`reminders change "Pick up milk" priority high arriving "Whole Foods"`), **When** the place fails to resolve, **Then** *no* part of the command is applied — the priority change does not land either.

---

### User Story 5 — Clearing and retargeting (Priority: P2)

A location alarm can be removed as easily as it was set, and pointed at a different place without being removed first.

**Why this priority**: The constitution requires that anything which can be added can be removed in the same tool — a mistake Claude makes must be undoable by Claude. Retargeting is the natural companion.

**Independent Test**: Set an alarm, retarget it to a different place, then clear it — confirming with `show` at each step.

**Acceptance Scenarios**:

1. **Given** a reminder with an arrival alarm at one place, **When** the person runs `reminders change "Pick up milk" arriving "Trader Joe's"`, **Then** the alarm points at the new place and the old one is gone.
2. **Given** a reminder with a location alarm in either direction, **When** the person runs `reminders change "Pick up milk" arriving none`, **Then** the location alarm is removed.
3. **Given** a reminder with an *arrival* alarm, **When** the person runs `reminders change "Pick up milk" leaving none`, **Then** the alarm is still removed — either direction's `none` clears the one alarm the reminder has.
4. **Given** a reminder with no location alarm, **When** the person clears one anyway, **Then** the command reports that there was nothing to change rather than claiming a change it did not make.

---

### User Story 6 — It reads the way I would say it (Priority: P2)

The person types the conjugation that comes naturally and includes the small connecting words English wants, and it all parses the same.

**Why this priority**: This is the suite's conversational-design principle. The cost of accepting the variants is small and fixed; the cost of rejecting them is a person being told their perfectly clear English is a syntax error.

**Independent Test**: Issue the same logical command six ways — `arrive`, `arriving`, `arrives`, with and without `at`/`when` — and confirm all six produce the identical result.

**Acceptance Scenarios**:

1. **Given** any of `arrive`, `arriving`, or `arrives`, **When** used as the keyword, **Then** all three set an arrival alarm identically.
2. **Given** any of `leave`, `leaving`, or `leaves`, **When** used as the keyword, **Then** all three set a departure alarm identically.
3. **Given** the filler words `at`, `from`, or `when`, **When** the person writes `reminders add "Pick up milk" when arriving at "Whole Foods"`, **Then** it parses identically to `arriving "Whole Foods"`.
4. **Given** the keyword written with no value at all (`reminders change "Pick up milk" leaving`), **When** the command runs, **Then** it fails naming the missing value — there is no valueless form that flips direction while keeping the place.

---

### Edge Cases

- **A place name that is also a filler word or the literal word `none`.** A person who genuinely wants a place called "none" is indistinguishable from one clearing the alarm; `none` is reserved for clearing, consistent with every other clearable attribute in the suite.
- **Both directions in one command** (`arriving "A" leaving "B"`). A reminder has one location alarm; naming two directions at once is an error, not a last-one-wins.
- **The same direction twice** (`arriving "A" arriving "B"`). A duplicate keyword, already an error under the suite argument-shape rule.
- **No contact card for the person at all.** Personal place names fail with a message saying no personal card was found, and name the label that was wanted. The tool never silently substitutes an unrelated address.
- **A place that resolves, but to somewhere absurdly far away.** The tool reports the resolved address in its output precisely so this is visible immediately rather than discovered weeks later when the reminder never fires.
- **The person has not granted Reminders location access on any device.** The alarm is still recorded correctly; it simply will not fire until they do. The tool says so rather than letting silence imply success.
- **A reminder that already has a time-based alarm.** Untouched. Location alarms and date alarms coexist.
- **Clearing on a reminder that has no location alarm.** Reported as nothing to change, not as a successful removal.

---

## Requirements *(mandatory)*

### Functional Requirements — Vocabulary

- **FR-001**: `arriving` and `leaving` MUST be keywords on `reminders add` and `reminders change`, each taking exactly one value: the place, quoted if it contains a space.
- **FR-002**: The conjugations `arrive` / `arriving` / `arrives` and `leave` / `leaving` / `leaves` MUST all be accepted and MUST behave identically within their direction.
- **FR-003**: The optional filler words `at`, `from`, and `when` MUST be accepted around the keyword without changing the meaning of the command.
- **FR-004**: There MUST NOT be a `location` keyword. The direction word is the keyword.
- **FR-005**: A location keyword given with no value MUST fail naming the missing value, consistent with every other keyword in the suite.
- **FR-006**: Naming both directions in a single command MUST fail naming the conflict, and MUST NOT apply either.

### Functional Requirements — The attribute

- **FR-007**: A reminder MUST carry at most one location alarm. The direction is a property of that alarm, not a second field.
- **FR-008**: Setting a location alarm on a reminder that already has one MUST replace it, in place, with no accumulation.
- **FR-009**: `arriving none` and `leaving none` MUST each clear the reminder's location alarm regardless of the direction it currently holds.
- **FR-010**: Clearing a location alarm on a reminder that has none MUST report that there was nothing to change, not a successful removal.
- **FR-011**: A location alarm MUST be independent of the reminder's due date, recurrence, priority, and notes — setting one MUST NOT alter or clear any other attribute.

### Functional Requirements — Place resolution

- **FR-012**: A place named `Home`, `Work`, or `School` MUST first be resolved from the addresses recorded on the person's own contact card, matched by that label.
- **FR-013**: A place name that is not one of the personal place names MUST be resolved by general address lookup, without consulting the contact card.
- **FR-014**: A personal place name with no matching labelled address on the person's own card MUST fail, naming the label it looked for, and MUST NOT fall through to general address lookup. Looking `Home` up as a business name risks silently geofencing an unrelated place, which is exactly the failure this feature is built to avoid.
- **FR-015**: When resolution yields exactly one address, the tool MUST use it and MUST name the resolved address in its output so the person can confirm it picked the right place.
- **FR-016**: When resolution yields several candidate addresses, the tool MUST list them, MUST make no change of any kind, and MUST exit non-zero.
- **FR-017**: When resolution yields no address, the tool MUST fail with a message naming the place that could not be resolved, and MUST make no change.
- **FR-018**: A failed or ambiguous place resolution MUST abort the entire command. Other changes named in the same command MUST NOT be applied.
- **FR-019**: A resolved place MUST be given a default proximity radius; the person does not specify one.
- **FR-020**: Place resolution MUST NOT require the tool itself to hold the operating system's location-services permission — it resolves names to addresses, it does not read the person's position.

### Functional Requirements — Output

- **FR-021**: `reminders show` MUST display a reminder's location alarm — both the place and the direction — alongside its other attributes.
- **FR-022**: The **first** time a location alarm is set, the tool MUST state, as a single line, that the alarm fires only on a device where Reminders itself has been granted location access.
- **FR-023**: Having shown that notice once, the tool MUST record the fact in `~/.config/get-clear/config.toml` and MUST NOT show it again. Clearing or editing that value MUST bring the notice back — the config file stays the source of truth, consistent with how the constitution already treats it.
- **FR-024**: Output MUST observe the suite's three-level colour hierarchy: the place is supporting metadata, not a primary identifier.
- **FR-025**: Every failure in this feature MUST go to stderr and exit non-zero, per the constitution.

### Functional Requirements — Scope

- **FR-026**: This feature MUST NOT depend on, or be gated behind, the consent-gated private-metadata capability (spec 014). It requires no consent prompt and no elevated access.
- **FR-027**: The vocabulary MUST conform to the suite argument-shape rule established in spec 015 — one identifier first, every other value introduced by a keyword taking a single quoted token, order-independent.
- **FR-028**: No new command-line flag may be introduced. The suite's only flags remain `--help` / `-h` and `--version` / `-v`.
- **FR-029**: The proximity radius MUST NOT be settable from the command line in this feature. No new keyword is introduced for it.

### Key Entities

- **Location alarm**: The new reminder attribute. A place and a direction (arrival or departure), plus the proximity radius around that place. A reminder has zero or one.
- **Place**: What the person types — a phrase, not a coordinate. Either a personal place name (Home, Work, School) or an arbitrary name or address.
- **Resolved address**: The outcome of looking a place up: a concrete street address and the coordinate it sits at. Resolution produces none, one, or several of these, and only the "one" case proceeds.
- **Direction**: Arrival or departure. A property of the location alarm, never stored or set independently of it.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person can attach a place to a reminder in a single command, without first looking up an address, for the three personal places and for any named business.
- **SC-002**: 100% of ambiguous place names produce a visible candidate list and zero changes — no command silently selects a candidate.
- **SC-003**: After any successful location-alarm command, the person can read back both the place and the direction from `show` alone, without opening the Reminders app.
- **SC-004**: Every command that sets a location alarm reports the address it actually resolved to, so a wrong place is caught at the moment it is set rather than when the alarm fails to fire.
- **SC-005**: A person given only the six conjugations and the three filler words can write a working command on the first attempt, with no per-command syntax to memorise.
- **SC-006**: A failed place resolution leaves the reminder byte-for-byte unchanged, including when other attribute changes were named in the same command.

---

## Decisions locked (with Ken, on issue #191)

1. **The keyword is the direction word.** No `location` keyword — it would be redundant next to `arriving`/`leaving`.
2. **One location alarm per reminder.** The direction is a property of that alarm, not two independent fields. Either direction's `none` clears it.
3. **No bare direction-flip form.** `change "X" leaving` (keep the place, flip the direction) does not exist, because every keyword in the suite takes a value. Restating the place is cheap and unambiguous; that is the trade.
4. **Personal places come from the person's own contact card**, not from a config file and not from a hardcoded list.
5. **Public capability, not private.** Location alarms are independent of spec 014 and must not wait on it.
6. **`show` displays it.** A person must be able to read back what they set.

### Answered 2026-09-09

7. **A missing personal address is a hard error, not a fallthrough.** If `Home` is not labelled on the person's own card, the tool fails naming the label it wanted. It does not try `Home` as a business name — resolving a personal place to an unrelated address is worse than refusing.
8. **The permission notice is shown once and remembered** in `~/.config/get-clear/config.toml`, rather than printing on every command or being relegated to the help text.
9. **A failed place resolution aborts the whole command.** Other changes named in the same line do not land. The command either fully happened or fully didn't.
10. **The radius stays fixed at the default.** No keyword, no configuration, revisit as its own feature only if it proves annoying in use.

---

## Assumptions

- **Default radius, fixed for now.** A proximity radius of roughly 100 metres is applied to every resolved place, with no vocabulary to change it — the platform's own geofencing floor makes anything tighter unreliable. Confirmed with Ken 2026-09-09: ship it fixed, and if it ever chafes, a per-place radius becomes its own small feature with its own keyword rather than being guessed at now.
- **The personal place names are exactly Home, Work, and School.** These are the labels the contact card itself uses. Matching is case-insensitive.
- **The permission notice is shown once, then remembered.** It prints the first time a location alarm is set and is suppressed thereafter via a flag in `~/.config/get-clear/config.toml` — the file the constitution already designates for per-person settings. This is the first use of that file for something other than telemetry consent, so the plan should confirm its shape and extend it rather than inventing a second settings mechanism.
- **Ambiguity is resolved by re-running with a more specific place string**, matching the suite's existing multi-match pattern (spec 009): list the candidates, change nothing, exit. There is no interactive prompt and no numbered selection — the suite's commands are non-interactive outside `setup`.
- **Address lookup happens over the network.** A place cannot be resolved offline; that failure surfaces as a resolution failure with a message saying so.
- **The alarm's behaviour once set is the operating system's.** Whether and when it fires depends on the person's devices and their Reminders location permission. This feature is responsible for recording the alarm correctly and saying what is required for it to fire — not for the firing itself.

---

## Out of Scope

- **Setting a custom radius per place.** Default only. Separate feature if ever wanted.
- **Showing location alarms in `list` or `find` output.** `show` is the read-back surface for reminder attributes; the list views stay compact.
- **Location alarms on calendar events.** Different tool, different model, not asked for.
- **Reading the person's current position** for anything — "remind me here", "what's near me". The tool resolves names to addresses; it never asks where the person is.
- **Multiple location alarms on one reminder.** One is the model, deliberately.
- **A `places` command** to list or manage saved places. Places are resolved per command, not stored by the tool.
- **Granting the Reminders location permission.** That is the operating system's to grant on each device; the tool states the requirement and stops there.
