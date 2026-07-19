---
name: graphkit
description: Run a long-horizon coding task as a small graph of agent nodes instead of one drifting loop. Interviews the user, then generates an executor node (does the work against a single-source-of-truth ledger) and a clean-context supervisor node that watches from OUTSIDE the executor's context window — checkpoint-committing clean work and correcting drift through a one-way directives file. Use when a task spans many rounds and the agent tends to scope-creep, fake "done", or quietly lower the bar — because an agent inside a long run cannot audit its own drift, and a supervisor with a fresh context can. Nodes share no context, so the executor can run on a cheap/fast model (Cursor, Grok, a local model) while a strong model handles authoring and supervision — cutting cost without losing reliability.
---

# graphkit — a graph of agent nodes, not a drifting loop

## What this skill does

Turns a vague, long-horizon request ("make this project production-ready", "get accuracy above baseline", "finish the migration") into a small **graph of agent nodes** that stays on-spec across many rounds:

- an **executor node** that drives the work forward, round by round, against a single scoreboard;
- a **clean-context supervisor node** that watches the executor **from outside its context window** and corrects course before drift compounds.

The shift from *loop* to *graph* is the whole point. A single agent grinding a long task can't see its own drift — **it is inside the very context that drifted**, so it rationalizes scope creep and calls half-done work "done". graphkit separates the run into nodes that communicate only through durable, inspectable state (a ledger, a git tree, a directives file) — never through a shared, polluted context. The supervisor boots **fresh every tick**, reads only that durable state, and judges the run the way a reviewer would: objectively, from the outside.

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

It produces up to four artifacts from a short interview:

1. **`executor.md`** — the executor node's prompt. One task book, one cadence, hard anti-bloat rules, explicit stop conditions and red lines.
2. **`ledger.md`** — the single source of truth / scoreboard the executor rewrites every round; the shared state both nodes read.
3. **`ops.md`** *(optional)* — durable environment facts (build commands, credential policy, data policy) the executor consults but doesn't re-derive.
4. **`supervisor.md`** *(optional)* — the clean-context supervisor node's prompt, fired on a schedule to checkpoint-commit clean work and inject corrections through the directives file.

The core invariants: **the ledger is the only scoreboard**, the executor does **one item per round → verify → update ledger**, and the **supervisor never shares or edits the executor's live context** — it steers only through `directives.md`, a one-way edge.

## When to use it

- The task spans many rounds and the user won't babysit each one.
- Success is verifiable (tests, gates, metrics) — the graph needs a definition of "done" it can check itself.
- There's real risk of scope creep, half-finished "looks done" work, or the agent quietly changing contracts / lowering the bar — exactly the drift a same-context agent can't catch in itself.

Do **not** use it for a one-shot edit, or when success can't be verified without a human every time — say so and suggest a plain task instead.

## Language

**Conduct the interview in whatever language the user is writing in** — mirror them. If they write in Chinese, ask in Chinese; if in Spanish, ask in Spanish. Match that language in the prose you put inside the generated artifacts too (their goals, notes, red lines). Keep structural keywords, headings, and field names as they are in the templates so the files stay tool-friendly. Do not force the conversation into English.

## How to run it

### Step 1 — Interview (fill the blanks, don't assume)

Ask the user for exactly these, in order. Skip a question only if the answer is already unambiguous from context. Present tradeoffs; don't silently pick.

1. **Repos & branches.** Which repo(s), which branch each. Confirm what must never be touched (other people's uncommitted work, `main`, remote DBs).
2. **North Star.** The goal in one sentence, and — critically — **how it is verified**. Push until each goal has a checkable definition ("tests pass", "metric ≥ baseline", "gate green"), not "make it work".
3. **Milestones (optional).** If the work has ordered phases, list them M1→Mn with an **exit condition** each. If it's a single goal, skip — one milestone is fine.
4. **Gates.** The exact per-repo verification commands (test / lint / build). These become the every-round gate. If a build needs special flags (settings file, env), capture them for `ops.md`.
5. **Red lines.** Non-negotiables that halt the run if violated: no push without authorization, no destructive git on others' work, no secrets/real data in code/logs/commits, frozen contracts, "metrics only go up", etc.
6. **Commit authorization.** May the executor commit? Push? Or does the supervisor / a human handle commits? (Default: executor implements + verifies; commits are a separate authorized step.)
7. **Supervisor?** Do they want the clean-context supervisor node — scheduled, checkpoint-committing, drift-correcting? If yes, at what interval (default 30 min)?

For anything you can reasonably decide from context, decide it and state the assumption. For anything genuinely the user's call (data policy, DB access, lowering a metric bar), it becomes a red line or an `owner-blocked` item — never decide it silently.

### Step 2 — Generate artifacts

Fill the templates in `templates/` with the interview answers:

- `templates/executor.md` → the user's `executor.md`
- `templates/ledger.md` → the user's `ledger.md` (seed the status header, gate scoreboard, and an empty rounds log)
- `templates/ops-and-environment.md` → the user's `ops.md`, only if there are non-trivial build/env/data facts worth pinning
- `templates/supervisor.md` → the user's `supervisor.md`, only if they want the supervisor node

Write them to a location the user picks (default: a `graphkit/` folder beside the target repos). Replace every `{{PLACEHOLDER}}` and delete the guidance comments. Keep the ledger **compact** — it is read every round; bloat costs tokens. Carry only load-bearing history forward.

### Step 3 — Start the executor node

Hand the user the generated `executor.md` and tell them to launch it in a **fresh agent context** (a new session, or their loop mechanism). The prompt points at the ledger + ops file, so the executor node is self-contained.

Tell them it's **model-agnostic and the place to save money**: the executor grinds one explicit ledger item per round with the rules held outside its context, so it runs fine on a **cheap / fast agent** (Cursor's budget tier, Grok, a local or OSS coder) — it does not need to be the frontier model that authored the graph. The structure, not the model, is what keeps it on-spec.

### Step 4 — Start the supervisor node (if chosen)

Schedule `supervisor.md` on the chosen interval. In Claude Code this is `CronCreate` with a cron like `7,37 * * * *` (every 30 min, off the :00/:30 marks so fleets don't stampede). Give this node a **strong model** — judging drift from a cold read is the hardest call in the graph, and since it fires only every ~30 min it stays cheap in aggregate even at frontier rates. Each tick spins up **a brand-new agent with a clean context** — this is what makes it a supervisor and not more of the same drift. It:

- reads only durable state — the ledger + `git status` of each repo — never the executor's context,
- checkpoint-commits clean, gate-green, complete work (never half-written state), local-only unless push is authorized,
- **corrects drift only by appending to `directives.md`, a one-way edge the executor reads each round — never by editing the ledger the executor is actively writing**,
- surfaces must-decide gaps to the human instead of guessing.

## The rules that make it work (encoded in the templates)

- **One scoreboard.** The ledger is the only source of truth. Code / docs / ledger conflict → fix the ledger first.
- **One item per round → verify same round → update ledger.** No batching, no "I'll test later".
- **Forced convergence.** Every Nth round (default 5th) does zero new features — only delete dead code, merge duplication, tighten interfaces; net lines ≤ 0. A single round adding > ~400 net production lines forces the next round to converge.
- **Register-then-defer.** Any gap found mid-round is *logged in the ledger's debt register*, never silently fixed on the side and never ignored. It gets queued by priority.
- **No speculative building.** New endpoint/module/abstraction/pool requires a named real consumer in the ledger first. No compat double-paths, no v1/v2 coexistence, no parallel error systems.
- **Stop conditions.** Milestone exit all-green → write a promotion request and stop for human sign-off. All remaining items blocked → stop with an escalation report. Two rounds with no ledger/metric change → stop with a stall diagnosis. Any red line violated → stop immediately.
- **Clean-context separation.** The supervisor is a *different node with a fresh context*. It steers via the directives edge, commits on authorization, and escalates human-only calls — it never merges into the executor's context, and it never writes the executor's ledger.

## Files in this skill

- `templates/` — the four fill-in artifacts (executor, ledger, ops, supervisor).
- `docs/methodology.md` — the deep dive (why each rule exists, failure modes it prevents).
- `examples/add-tests-to-cli/` — a fully worked, generic example.
