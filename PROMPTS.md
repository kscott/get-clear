# Prompts — Keeping Claude on Track

Use these when something feels off. Direct statements work better than questions.

---

**Logic in main.swift that shouldn't be there**
> "That logic belongs in the Lib, not main.swift. Stop, design the interface, and put it in the right place."

**Feature work starting without a spec**
> "Run SpecKit before writing any code. We haven't specced this."

**Code that looks too long or tangled**
> "Audit what you just wrote against the engineering disciplines in design.md before we move on."

**Suspected missed files during a rename or search**
> "Search the entire project — source, HTML, scripts, docs — not just Swift files."

**Structural change made without updating ARCHITECTURE.md**
> "Update ARCHITECTURE.md — decision log and anything you noticed."

**Something feels like drift but you can't name it**
> "Do a focused code quality read on [file or area]. Flag anything that violates design.md. Be specific."

**Claude states an intention instead of acting**
> "Don't tell me you'll do that — do it now, or put it in the improvement backlog."

**After a long session, want a sanity check**
> "Re-read design.md and ARCHITECTURE.md and tell me if anything we've done today conflicts with either."
