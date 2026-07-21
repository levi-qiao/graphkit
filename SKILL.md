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

Five artifacts from a short interview:

1. **`executor.md`** — executor prompt: one task book, one cadence, anti-bloat rules, stop conditions, red lines.
2. **`ledger.md`** — the single scoreboard both nodes read; the executor rewrites it every round.
3. **`directives.md`** — the one-way corrections edge, seeded near-empty (STANDING locks + numbered corrections the supervisor appends).
4. **`ops.md`** *(optional)* — durable env facts (build commands, credential/data policy) the executor consults, not re-derives.
5. **`supervisor.md`** *(optional)* — supervisor prompt, scheduled; checkpoint-commits clean work, corrects drift via the directives file.

**Run directory — fixed, one per run.** Everything above goes in `.graphkit/<YYYY-MM-DD-slug>/` at the repo root (workspace root for multi-repo runs), plus an `archive/` subdir for in-run rotations. **A new run gets a new directory, generated fresh from the templates — never retarget or edit a previous run's files**: patching stale prompts wastes tokens and leaves leftover text steering toward the old goal. The old directory stays untouched (it *is* the archive); distill what still holds into the new ledger's starting snapshot and copy still-in-force STANDING directives forward. Commit the run directory unless data policy forbids — it's the durable state the graph depends on.

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
7. **Supervisor?** — want the scheduled clean-context supervisor? interval (default 30 min)? Fix the **owner-only decision list** (typical: DDL/schema, credentials / remote env / real-data exposure, spend beyond budget, lowering a metric bar, frozen contracts, push) — everything off that list the supervisor adjudicates itself so the run never stalls waiting for the owner.
   - **Pre-adjudicate the critical-path ones NOW — don't let the loop discover them.** If an owner-only category sits on the goal's *critical path* — the goal **is** dropping dead tables, so every round hits DDL; the goal **is** cutting cost, so every round hits spend — then leaving it on the blocking list means the loop can't do its own work: it just emits "proposals awaiting owner sign-off" and stalls. That defeats the loop. Settle it with the owner **in this interview**: turn it into a **standing authorization** — an objective, checkable **evidence bar** under which the executor acts autonomously and the owner retro-reviews (e.g. *"drop a table once evidence shows 0 rows + 0 code consumers + 0 reads/writes across all repos, applied via a reversible migration"*). Write each as a STANDING directive (`directives.md`). Only a decision that **genuinely can't be stated as a bar in advance** — one that needs the owner's judgment case by case — stays on the blocking list. Rule of thumb: if you can write the condition under which the answer is "yes", pre-authorize it; don't make the loop stop to ask.
8. **Loop host & interval** — every runtime is the same thing: **a loop that re-invokes the node on an interval**; the node resumes from the ledger each time and does one round (Claude Code `/loop`; a Cursor background agent's follow-up cycle; Grok, Codex, or any agent CLI in a shell `while`). A host only keeps the loop alive — it never becomes a second scoreboard, and it never changes the graph. Pick an **interval** (default 10 min). The loop must be able to **stop itself** when the ledger goes terminal, so it doesn't idle overnight. If a supervisor is chosen it's a **second loop** on its own interval in a fresh context — never a subagent inside the executor loop. Mixed models are first-class: cheap executor loop, strong supervisor loop.

Decide from context what you reasonably can and state the assumption; anything genuinely the user's call (data policy, DB access, lowering a bar) becomes a red line, a **standing authorization** (if you can pre-adjudicate it into a checkable evidence bar), or an `owner-blocked` item (only if it truly can't be pre-decided) — never silent, and never a blocking item the loop was supposed to execute.

**Step 2 — Generate** into a fresh `.graphkit/<YYYY-MM-DD-slug>/` from `templates/`: `executor.md`, `ledger.md` (seed status header + gate board + empty rounds log), `directives.md` (seeded from its template), `ops.md` (only if non-trivial env facts), `supervisor.md` (only if wanted). Point every internal path (`{{LEDGER_PATH}}`, `{{DIRECTIVES_PATH}}`) into the run directory. Replace every `{{PLACEHOLDER}}`, delete guidance comments. **Write lean** — bullets over prose, reference `ops.md` / repo standards instead of inlining, no repeated rationale (mirror the repo's own `AGENTS.md` / standards style). Keep the ledger compact; carry only load-bearing history.

**Step 3 — Start the executor loop, and tell the user how *in the chat*.** Don't generate a launch file — print the copy-paste command directly in the conversation, in the user's language, so they run one thing and nothing else. The command is a **thin pointer** at the run files (never the whole `executor.md` pasted in), so the loop re-reads the live files each round and can't drift; the executor's authority is `executor.md` + the ledger. Fill `{{RUN_DIR}}` / `{{INTERVAL}}` with the run's real values:

- **Claude Code (default):** `/loop {{INTERVAL}} Read {{RUN_DIR}}/executor.md and do the executor node's next single ledger round; when the ledger status header is exit-ready / stalled / closed, end the loop.`
- **Cursor:** point a background agent at `{{RUN_DIR}}/executor.md`; its follow-up cycle *is* the loop — same one-round instruction, ending when the ledger is terminal.
- **Grok / Codex / any agent CLI:** `while :; do <cli> "Read {{RUN_DIR}}/executor.md, do the next single ledger round"; grep -qE 'exit-ready|stalled|closed' {{RUN_DIR}}/ledger.md && break; sleep {{INTERVAL}}; done`

The loop runs fine on a **cheap/fast model** — structure, not model, keeps it on-spec. It **stops itself** when the ledger reaches a terminal status: the loop is dumb, the ledger decides.

**Step 4 — Start the supervisor loop** (if chosen), and print its command in the chat too. It's a **second loop in a fresh context** on its own interval — Claude Code: `CronCreate`, e.g. `7,37 * * * *` (off :00/:30 so fleets don't stampede), prompt = `Read and follow {{RUN_DIR}}/supervisor.md`; on other hosts, a separate scheduled session or `while … sleep`. **Never run it as a subagent inside the executor loop**, which collapses the separation. Give it a **strong model** (cold-read drift-judging is the hardest call; fires ~2×/hr, so cheap in aggregate). Each tick is a brand-new clean context that:

- reads only durable state (ledger + `git status`), never the executor's context;
- checkpoint-commits clean, gate-green, complete work (never half-written), local-only unless push is authorized;
- corrects drift **and wasteful method** (e.g. orders a smallest-slice pilot before a full-cohort burn) **only** by appending to `directives.md`; never edits the ledger;
- **decides by default**: adjudicates anything off the owner-only list itself (directive + one-line rationale for retro-review), sweeps `owner-blocked` each tick for items it can unblock — including any whose STANDING pre-authorization bar is now met — and escalates only genuine case-by-case owner-only calls;
- **stops its own loop when the run is over** — ledger `closed`/`exit-ready` and tree clean (final checkpoint first), or stalled-and-escalated with the executor no longer advancing — so the monitoring loop never idles overnight.

## The rules that make it work (encoded in the templates)

- **One scoreboard.** The ledger is the only source of truth. Code/docs/ledger conflict → fix the ledger first.
- **One item per round → verify same round → update ledger.** No batching, no "I'll test later".
- **Forced convergence.** Every Nth round (default 5th) adds zero features — only delete dead code, merge duplication, tighten interfaces; net lines ≤ 0. A round adding > ~400 net production lines forces the next to converge.
- **Register-then-defer.** A gap found mid-round goes into the ledger's debt register by priority — never silently patched on the side, never dropped.
- **No speculative building.** New endpoint/module/abstraction/pool needs a named real consumer in the ledger first. No compat double-paths, v1/v2 coexistence, or parallel error systems.
- **Pilot before full batch.** Expensive full-cohort operations (whole-set evals, bulk VLM/API sweeps, migrations) run a smallest-slice pilot first; full run only after the pilot verifies clean.
- **Honest measurement.** A metric counts only on the real, declared eval set (the frozen holdout in the ledger). Numbers from synthetic/self-generated inputs or a cherry-picked subset aren't progress and are never recorded — benchmark-gaming the clean-context supervisor must catch. Evidence artifacts (scorecards, eval reports) land at versioned persistent paths — the run directory or the repo, never scratch/tmp; a number whose artifact has vanished is struck and re-measured.
- **Stop conditions end the loop.** Milestone all-green → promotion request, stop for sign-off. All remaining items blocked → stop, escalate. Two rounds with no ledger/metric change → stop, stall diagnosis. Red line violated → stop immediately. On any of these the node writes a terminal ledger status **and ends its own loop** — the supervisor loop ends too once the run is done — so a finished or stuck run never idles overnight.
- **Clean-context separation, delegated authority.** The supervisor is a different node with a fresh context: steers via the directives edge, commits on authorization, and **decides everything off the owner-only list itself** (logged rationale, retro-reviewable) — escalating only genuine owner-only calls; never merges into the executor's context or writes its ledger.
- **Pre-adjudicate, don't propose-and-wait.** Owner-only decisions on the goal's critical path are settled at interview time into **standing authorizations** — an objective evidence bar the executor acts under autonomously (owner retro-reviews). A loop whose own work is owner-only (dropping dead tables, cutting spend) must not stall emitting proposals for the owner to sign; only a call that genuinely can't be stated as a bar in advance stays blocking.

## Files in this skill

- `templates/` — the five fill-in artifacts (executor, ledger, directives, ops, supervisor). The executor and supervisor prompts encode the loop's self-stop.
- `docs/methodology.md` — the deep dive (why each rule exists, failure modes it prevents).
- `examples/add-tests-to-cli/` — a fully worked, generic example.
- `examples/migrate-blob-storage/` — a longer worked example: milestones, a cohort pilot, and a supervisor directive in action.
