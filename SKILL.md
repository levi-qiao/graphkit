---
name: graphkit
description: Run a long-horizon coding task as a small graph of agent nodes instead of one drifting loop. Generates an executor node (works against a single-source-of-truth ledger) and a clean-context supervisor node that watches from outside the executor's context — checkpoint-committing clean work and correcting drift through a one-way directives file. Use for multi-round tasks where an agent tends to scope-creep, fake "done", or quietly lower the bar. Nodes share no context, so the executor runs on a cheap/fast model while a strong model supervises.
---

# graphkit — a graph of agent nodes, not a drifting loop

## What it does & why

Turns a vague long-horizon request ("make it production-ready", "accuracy above baseline", "finish the migration") into a small **graph of agent nodes** that stays on-spec across many rounds:

- an **executor node** — drives the work round by round against a single scoreboard;
- a **clean-context supervisor node** — watches from *outside* the executor's context and corrects course before drift compounds.

Why a graph, not a loop: an agent grinding a long task **is inside the context that drifted**, so it rationalizes scope creep and calls half-done work "done". graphkit's nodes talk only through durable, inspectable state (ledger, git tree, directives file) — never a shared, polluted context. The supervisor boots fresh each tick and judges the run like an outside reviewer.

## The graph it builds

```
        ┌─────────────┐   reads / rewrites   ┌──────────────┐
        │  EXECUTOR    │ ───────────────────▶ │              │
        │  node        │ ◀─────────────────── │  ledger.md   │  ← single scoreboard
        │ (does work)  │                      │ (shared state)│
        └─────────────┘                      └──────────────┘
              ▲                                      ▲
              │ reads each round                     │ reads only (never writes it)
              │                                      │
        ┌───────────────┐   appends corrections ┌──────────────────┐
        │ directives.md │ ◀──────────────────── │   SUPERVISOR     │  ← fresh, CLEAN context
        └───────────────┘                       │   node (watches) │     every tick
                                                 └──────────────────┘
                                                     │ checkpoint-commits clean work
                                                     │ escalates human-only calls
                                                     ▼
                                                   git / you
```

Four artifacts from a short interview:

1. **`executor.md`** — executor prompt: one task book, one cadence, anti-bloat rules, stop conditions, red lines.
2. **`ledger.md`** — the single scoreboard both nodes read; the executor rewrites it every round.
3. **`ops.md`** *(optional)* — durable env facts (build commands, credential/data policy) the executor consults, not re-derives.
4. **`supervisor.md`** *(optional)* — supervisor prompt, scheduled; checkpoint-commits clean work, corrects drift via the directives file.

Invariants: **ledger = the only scoreboard**; **one item per round → verify → update ledger**; **the supervisor steers only through `directives.md` (a one-way edge) — it never edits the ledger or shares the executor's context**.

## When to use it

- Task spans many rounds; the user won't babysit each one.
- "Done" is verifiable (tests, gates, metrics) — the graph needs a definition of done it can check itself.
- Real risk of scope creep, "looks done" work, or quietly changing contracts / lowering the bar.

**Not** for a one-shot edit, or when success needs a human to judge every time — say so, suggest a plain task.

## Language

Interview in the user's language and mirror it in the prose inside the artifacts (goals, notes, red lines). Keep structural keywords, headings, and field names as in the templates so files stay tool-friendly.

## How to run it

**Step 1 — Interview** (fill the blanks, don't assume; present tradeoffs, don't silently pick). Ask in order — skip only if context already answers:

1. **Repos & branches**, and what must never be touched (others' uncommitted work, `main`, remote DBs).
2. **North Star** — the goal in one sentence + **how it's verified**. Push until each goal is checkable ("tests pass", "metric ≥ baseline"), not "make it work".
3. **Milestones** (optional) — ordered phases M1→Mn, each with an exit condition. Single goal → skip.
4. **Gates** — the exact per-repo verify commands (test/lint/build); capture special flags for `ops.md`.
5. **Red lines** — halt-the-run non-negotiables: no unauthorized push, no destructive git on others' work, no secrets/real data in code/logs/commits, frozen contracts, metrics-only-up.
6. **Commit authorization** — may the executor commit? push? (Default: executor implements+verifies; commit is a separate authorized step.)
7. **Supervisor?** — want the scheduled clean-context supervisor? interval (default 30 min)?

Decide from context what you reasonably can and state the assumption; anything genuinely the user's call (data policy, DB access, lowering a bar) becomes a red line or an `owner-blocked` item — never silent.

**Step 2 — Generate** from `templates/`: `executor.md`, `ledger.md` (seed status header + gate board + empty rounds log), `ops.md` (only if non-trivial env facts), `supervisor.md` (only if wanted). Replace every `{{PLACEHOLDER}}`, delete guidance comments. **Write lean** — bullets over prose, reference `ops.md` / repo standards instead of inlining, no repeated rationale (mirror the repo's own `AGENTS.md` / standards style). Keep the ledger compact; carry only load-bearing history.

**Step 3 — Start the executor** in a **fresh context** (new session or loop mechanism); it's self-contained (points at ledger + ops). It runs fine on a **cheap/fast model** — structure, not model, keeps it on-spec.

**Step 4 — Start the supervisor** (if chosen) on the interval — Claude Code: `CronCreate`, e.g. `7,37 * * * *` (off :00/:30 so fleets don't stampede). Give it a **strong model** (cold-read drift-judging is the hardest call; fires ~2×/hr, so cheap in aggregate). Each tick is a brand-new clean context that:

- reads only durable state (ledger + `git status`), never the executor's context;
- checkpoint-commits clean, gate-green, complete work (never half-written), local-only unless push is authorized;
- corrects drift **only** by appending to `directives.md`; never edits the ledger;
- escalates must-decide gaps to the human.

## The rules that make it work (encoded in the templates)

- **One scoreboard.** The ledger is the only source of truth. Code/docs/ledger conflict → fix the ledger first.
- **One item per round → verify same round → update ledger.** No batching, no "I'll test later".
- **Forced convergence.** Every Nth round (default 5th) adds zero features — only delete dead code, merge duplication, tighten interfaces; net lines ≤ 0. A round adding > ~400 net production lines forces the next to converge.
- **Register-then-defer.** A gap found mid-round goes into the ledger's debt register by priority — never silently patched on the side, never dropped.
- **No speculative building.** New endpoint/module/abstraction/pool needs a named real consumer in the ledger first. No compat double-paths, v1/v2 coexistence, or parallel error systems.
- **Honest measurement.** A metric counts only on the real, declared eval set (the frozen holdout in the ledger). Numbers from synthetic/self-generated inputs or a cherry-picked subset aren't progress and are never recorded — benchmark-gaming the clean-context supervisor must catch.
- **Stop conditions.** Milestone all-green → promotion request, stop for sign-off. All remaining items blocked → stop, escalate. Two rounds with no ledger/metric change → stop, stall diagnosis. Red line violated → stop immediately.
- **Clean-context separation.** The supervisor is a different node with a fresh context: steers via the directives edge, commits on authorization, escalates human-only calls — never merges into the executor's context or writes its ledger.

## Files in this skill

- `templates/` — the four fill-in artifacts (executor, ledger, ops, supervisor).
- `docs/methodology.md` — the deep dive (why each rule exists, failure modes it prevents).
- `examples/add-tests-to-cli/` — a fully worked, generic example.
