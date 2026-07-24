---
name: octopus
description: Umbrella entry for the octopus-skill prompt library — pick the right arm for a long-horizon agent task and follow it. Two arms share one discipline (verified-not-written "done", no test theater, no speculative building, forced convergence, owner red lines). The `loop-graph` arm builds an executor + clean-context supervisor as two scheduled loops — for the `/loop` primitive (Claude Code, Grok, Cursor, shell), multi-milestone phases, executor/supervisor split across hosts/models, owner-gated runs. The `quest` arm emits one objective prompt handed to a host that already drives a goal to done with its own verifier — for the goal primitive (Grok `/goal`, a Codex task). Use this when the user invokes /octopus or is unsure which arm fits.
---

# octopus 🐙 — one brain, many arms

A curated prompt library for long-horizon agent work. One shared discipline,
compiled to whichever host you run. Your job on invocation: **pick the arm, then
read and follow that arm's `SKILL.md`.** Don't reimplement it here.

## Pick the arm — the host usually decides for you

The primitive a host has narrows the choice before task shape even matters (full
matrix in [`lib/host-dialects.md`](lib/host-dialects.md)):

| Host | Has | → Arm |
|------|-----|-------|
| **Cursor**, **shell/cron** | `loop` only | **loop-graph** |
| **Codex** | `goal` only (no `/loop`) | **quest** |
| **Claude Code** | `/loop` only (no standalone `/goal`) | **loop-graph** (its supervisor is the verifier) |
| **Grok** | both `/loop` and `/goal` | **either — decide by task shape ↓** |

On Grok (the only both-capable host), and whenever a host offers a real choice:

| Choose | When |
|--------|------|
| **[`quest`](skills/quest/SKILL.md)** | a *single self-contained* goal · executor+reviewer in the same run · no owner-only call on the critical path → emit **one objective prompt**, run it with the host's goal command (Grok `/goal`, a Codex task), ride its own verifier — no second loop |
| **[`loop-graph`](skills/loop-graph/SKILL.md)** | *any* of: multi-milestone phases with a non-skippable gate · executor and supervisor on different hosts/models/cadences · owner red-lines/gates that must stop the run · cross-session durability → build the **executor + clean-context supervisor** two-loop graph, driven by `/loop` |

Rule of thumb by primitive: **you'll drive it with `/loop` → loop-graph; you'll hand
it to a goal command → quest.** Default when genuinely unsure: **loop-graph** (it
carries its own verifier and runs on every loop-capable host).

## Then

Read the chosen arm's `SKILL.md` and run its interview → generation → delivery.
Shared reference both arms rest on:
- [`lib/host-dialects.md`](lib/host-dialects.md) — per-host `/loop` · goal · hook syntax, which primitive each host has, and wake/notify primitives.
- [`lib/methodology.md`](lib/methodology.md) — why each discipline rule exists and the failure mode it prevents.
