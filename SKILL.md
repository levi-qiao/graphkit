---
name: octopus
description: Umbrella entry for the octopus-skill prompt library — pick the right arm for a long-horizon agent task and follow it. Two arms share one discipline (verified-not-written "done", no test theater, no speculative building, forced convergence, owner red lines). The `loop-graph` arm builds an executor + clean-context supervisor as two scheduled loops — for the `/loop` primitive (Claude Code, Grok, Cursor, Codex, shell), multi-milestone phases, executor/supervisor split across hosts/models, owner-gated runs. The `quest` arm emits one objective prompt handed to a host that already drives a goal to done with its own verifier — for the goal primitive (Grok `/goal`, a Codex task). Use this when the user invokes /octopus or is unsure which arm fits.
---

# octopus 🐙 — one brain, many arms

A curated prompt library for long-horizon agent work. One shared discipline,
compiled to whichever host you run. Your job on invocation: **pick the arm, then
read and follow that arm's `SKILL.md`.** Don't reimplement it here.

## Pick the arm — task shape decides; the host only gates what's available

Decide by **task shape first**, then check the host can run it (full matrix in
[`lib/host-dialects.md`](lib/host-dialects.md)):

| Choose | When |
|--------|------|
| **[`quest`](skills/quest/SKILL.md)** | a *single self-contained* goal · reproducible acceptance · no non-skippable milestone gate · no owner-only call on the critical path → emit **one objective prompt**, run it with the host's goal command, ride its own verifier — no second loop |
| **[`loop-graph`](skills/loop-graph/SKILL.md)** | *any* of: multi-milestone phases with a non-skippable gate · executor and supervisor on different hosts/models/cadences · owner red-lines/gates that must stop the run · cross-session durability · you want an **independent** verifier → build the **executor + clean-context supervisor** two-loop graph |

The host only **gates which arms are reachable** — most now do both:

| Host | Can run | How |
|------|---------|-----|
| **Grok** | both | quest rides its **native adversarial verifier**; loop-graph = two `/loop`s |
| **Codex** | both | quest = `/goal` / send-as-task (self-drives to done). **loop-graph = drive *both* nodes with an interval `/loop` (heartbeat), never `/goal`** — a goal harness re-fires a parked/stalled node forever (livelock), having no "waiting for a directive" rest state. Codex `/loop` **needs an explicit interval** (e.g. `4m`) or no timer is created. |
| **Claude Code** | both\* | quest = a self-paced single `/loop` (\*no `/goal` command, no independent verifier); loop-graph = two `/loop`s (its supervisor is the verifier) |
| **Cursor**, **shell/cron** | loop-graph only | no goal primitive |

Default when genuinely unsure: **loop-graph** (it carries its own verifier and runs
on every loop-capable host).

## Then

Read the chosen arm's `SKILL.md` and run its interview → generation → delivery.
Shared reference both arms rest on:
- [`lib/host-dialects.md`](lib/host-dialects.md) — per-host `/loop` · goal · hook syntax, which primitive each host has, and wake/notify primitives.
- [`lib/methodology.md`](lib/methodology.md) — why each discipline rule exists and the failure mode it prevents.
