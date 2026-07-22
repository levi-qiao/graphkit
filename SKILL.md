---
name: graphkit
description: Run a long-horizon coding task as a small graph of agent nodes instead of one drifting loop. Generates an executor node (works against a single-source-of-truth ledger) and a clean-context supervisor node that audits from outside the executor's context — re-verifying claimed-done work, checkpoint-committing what passes, and correcting drift through a one-way directives file. Use for multi-round tasks where an agent tends to scope-creep, fake "done", or quietly lower the bar. Nodes share no context, so the executor runs on a cheap/fast model while a strong model supervises.
---

# graphkit — a graph of agent nodes, not a drifting loop

## What it does & why

Turns a vague long-horizon request ("make it production-ready", "accuracy above baseline", "finish the migration") into a small **graph of agent nodes** that stays on-spec across many rounds:

- an **executor node** — drives the work round by round against a single scoreboard;
- a **clean-context supervisor node** — audits the work from *outside* the executor's context (re-verifying claimed-done against the shared standards) and corrects course before drift compounds.

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
5. **`supervisor.md`** *(optional)* — supervisor prompt, scheduled; independently re-verifies claimed-done work, checkpoint-commits what passes, decides pending items, and corrects drift / steers the plan via the directives file.

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
7. **Supervisor?** — want the scheduled clean-context supervisor? It's an **independent acceptance auditor**: each tick it re-runs the gates and checks the real diff against the acceptance bar and the shared standards (`ops.md`, the repo's `AGENTS.md`/`CLAUDE.md`), catching drift / fake-done / concealment, then commits what passes, decides pending items, **adjudicates milestone promotions** (releases the executor into the next milestone when the evidence holds, so it doesn't stall for sign-off at every boundary), and steers the plan via directives. Interval (default 30 min)? Fix the **owner-only decision list** (typical: DDL/schema, credentials / remote env / real-data exposure, spend beyond budget, lowering a metric bar, frozen contracts, push) — everything off that list the supervisor adjudicates itself so the run never stalls waiting for the owner.
   - **Pre-adjudicate the critical-path ones NOW — don't let the loop discover them.** If an owner-only category sits on the goal's *critical path* — the goal **is** dropping dead tables, so every round hits DDL; the goal **is** cutting cost, so every round hits spend — then leaving it on the blocking list means the loop can't do its own work: it just emits "proposals awaiting owner sign-off" and stalls. That defeats the loop. Settle it with the owner **in this interview**: turn it into a **standing authorization** — an objective, checkable **evidence bar** under which the executor acts autonomously and the owner retro-reviews (e.g. *"drop a table once evidence shows 0 rows + 0 code consumers + 0 reads/writes across all repos, applied via a reversible migration"*). Write each as a STANDING directive (`directives.md`). Only a decision that **genuinely can't be stated as a bar in advance** — one that needs the owner's judgment case by case — stays on the blocking list. Rule of thumb: if you can write the condition under which the answer is "yes", pre-authorize it; don't make the loop stop to ask.
8. **Loop host, pacing & interval** — every runtime is a **loop that re-invokes the node and resumes from the ledger**; it never becomes a second scoreboard or changes the graph. Hosts pace two ways — pick and size accordingly:
   - **Adaptive** (no interval to set): **Codex** task, **Claude Code** self-paced `/loop` — the runtime re-invokes when the previous round returns, so a round never gets cut off. Prefer these when round duration varies a lot.
   - **Interval** (you set a delay): **Grok**, **Cursor**, cron, shell `while … sleep`. Size the delay from **how long one round takes** (implement + the gate command), so a tick lands *after* the round finishes, not during it. Estimate from the plan: light doc/config round + fast gates ≈ **5m**; unit-test / build round ≈ **10m**; heavy integration / eval round ≈ **15m** (round up). **Cursor caps a run at ~20m and kills overruns — never exceed 20m there; if a round can't finish under 20m, split it smaller or use an adaptive host.**

   Compute a recommended **executor interval** and, if a supervisor is chosen, a **supervisor interval** — the supervisor is a second loop, longer and phase-offset (≈ 2–3× the executor, min ~20–30m), in a fresh context; it observes and must never interrupt an in-flight executor round. Both loops **stop themselves** when the ledger goes terminal, so nothing idles overnight. Mixed models are first-class: cheap executor loop, strong supervisor loop. **The two loops need not run on the same host or even in Claude Code** — if the host is Grok / Cursor / another CLI, or the user just wants to drive the loops themselves elsewhere, the deliverable is the loop *prompts* (see Delivery below), not a launch here.

Decide from context what you reasonably can and state the assumption; anything genuinely the user's call (data policy, DB access, lowering a bar) becomes a red line, a **standing authorization** (if you can pre-adjudicate it into a checkable evidence bar), or an `owner-blocked` item (only if it truly can't be pre-decided) — never silent, and never a blocking item the loop was supposed to execute.

**Step 2 — Generate** into a fresh `.graphkit/<YYYY-MM-DD-slug>/` from `templates/`: `executor.md`, `ledger.md` (seed status header + convergence tracker + milestone gate + gate board + empty rounds log), `directives.md` (seeded from its template), `ops.md` (only if non-trivial env facts), `supervisor.md` (only if wanted). Point every internal path (`{{LEDGER_PATH}}`, `{{DIRECTIVES_PATH}}`) into the run directory. Replace every `{{PLACEHOLDER}}`, delete guidance comments. **Set the convergence bounds from the plan** — `CONVERGE_EVERY` / `NET_LINE_CAP` aren't dogma: a feature-dense milestone converges more often (smaller N / cap), a cleanup or migration plan can loosen them (default 5 rounds / 400 net lines) — and seed them into the ledger's convergence tracker. **Write lean** — bullets over prose, reference `ops.md` / repo standards instead of inlining, no repeated rationale (mirror the repo's own `AGENTS.md` / standards style). Keep the ledger compact; carry only load-bearing history.

**Delivery — launch here, or hand off the prompts.** Read it from the host answer (interview point 8), and offer prompts-only explicitly as a choice — don't assume this session is the host:

- **Launch here** — the host *is* this Claude Code session: Steps 3–4 start the loop(s) for the user.
- **Prompts-only** — the host is Grok / Cursor / another client, or the user just wants the prompts to drive elsewhere: **launch nothing locally.** Generate the artifacts, **commit the run directory** so the external client can read the live files, then print the loop prompts as labeled copy-paste blocks — the **executor** loop and, if chosen, the **supervisor** loop — each a thin pointer at the run files with its **recommended interval filled in**, in the user's language. These are the same prompts Steps 3–4 describe; the user pastes each into their client's loop feature and sets the interval. Re-print them verbatim any time the user asks again.

**One uniform command shape — so a newcomer isn't confused.** Print *both* loops the same way: **slash command + explicit interval + thin-pointer prompt**, e.g. `/loop {{INTERVAL}} Read {{RUN_DIR}}/<node>.md …`. The executor and supervisor differ **only in the interval** (supervisor longer, phase-offset), never in form. **Never print a bare prompt or an interval-less `/loop`** — a beginner can't tell an incomplete command from a complete one, so the `/loop` and the time must always be present. On a non-Claude client, keep the same shape in that client's loop syntax, interval included.

**Step 3 — Start the executor loop, and tell the user how *in the chat*** (prompts-only: print it, don't launch) — with the **recommended interval already filled in** (the executor interval computed above), never a bare `{{INTERVAL}}` placeholder. Print the copy-paste command directly in the conversation, in the user's language, so they run one thing and nothing else. The command is a **thin pointer** at the run files (never the whole `executor.md` pasted in), so the loop re-reads the live files each round and can't drift; the executor's authority is `executor.md` + the ledger. Give the one that matches their host:

- **Claude Code:** `/loop {{EXEC_INTERVAL}} Read {{RUN_DIR}}/executor.md and do the executor node's next single ledger round; when the ledger status header is exit-ready / stalled / closed, end the loop.` **Always show the interval** — it's what the user copies. Self-pacing is available by dropping the interval, but don't print the bare interval-less form as the default; it reads as incomplete.
- **Codex (adaptive — no interval):** delegate a task pointing at `{{RUN_DIR}}/executor.md`; it re-invokes itself each round and never cuts a round off.
- **Cursor:** background agent on `{{RUN_DIR}}/executor.md`, schedule `{{EXEC_INTERVAL}}` **≤ 20m** (Cursor kills a run past ~20m — keep each round under that cap); its follow-up cycle *is* the loop, ending when the ledger is terminal.
- **Grok / any agent CLI (shell):** a `while … sleep` loop is **sequential by construction** — the round runs to closure *before* the sleep, so a tick never interrupts an in-flight round:
  ```sh
  while :; do
    <cli> "Read {{RUN_DIR}}/executor.md, do the next single ledger round"
    grep -qE 'exit-ready|stalled|closed' {{RUN_DIR}}/ledger.md && break
    sleep {{EXEC_INTERVAL}}
  done
  ```
  If instead a wall-clock scheduler (cron / Cursor) fires ticks regardless of whether the last finished, guard each tick with a portable lock so an overlapping tick **skips** rather than starting a second round: `mkdir {{RUN_DIR}}/.round.lock 2>/dev/null || exit 0; trap 'rmdir {{RUN_DIR}}/.round.lock' EXIT; <cli> "…one round…"`.

The loop runs fine on a **cheap/fast model** — structure, not model, keeps it on-spec. It **stops itself** when the ledger reaches a terminal status: the loop is dumb, the ledger decides.

**Step 4 — Start the supervisor loop** (if chosen; prompts-only: print it, don't launch), and print its command in the chat too — in the **same `/loop <interval> <prompt>` shape as the executor** so the user sees one pattern, with its own **recommended interval filled in** (the supervisor interval computed above: longer than the executor's and phase-offset, so it never lands on the executor's ticks): `/loop {{SUP_INTERVAL}} Read and follow {{RUN_DIR}}/supervisor.md`. In Claude Code you *may* instead schedule it precisely off-the-hour with `CronCreate` (e.g. `7,37 * * * *` for ~30m, off :00/:30 so fleets don't stampede) — the advanced option; on other hosts use the client's loop feature or `while … sleep {{SUP_INTERVAL}}` — always with the interval shown. It only observes and checkpoints clean boundaries — it **never interrupts an in-flight executor round**. **Never run it as a subagent inside the executor loop**, which collapses the separation. Give it a **strong model** (cold-read drift-judging is the hardest call; fires ~2×/hr, so cheap in aggregate). Each tick is a brand-new clean context that:

- reads only durable state (ledger + `git status`) **and the shared standards both nodes obey** (`ops.md`, the repo's `AGENTS.md`/`CLAUDE.md`/lint) — never the executor's context;
- **independently audits acceptance**: re-runs the claimed-done item's gate/eval and inspects the real diff/artifact against the acceptance criteria and those shared standards, catching **drift, fake-done, and undisclosed shortcuts** the executor's own context hides — trusting its own re-verification, not the ledger's word;
- checkpoint-commits only **audited**, clean, gate-green, complete work (never half-written), local-only unless push is authorized;
- corrects drift **and wasteful method** (e.g. orders a smallest-slice pilot before a full-cohort burn) **and steers the plan** (adds/re-prioritizes/splits items, inserts acceptance checks, orders redos of audit-failed work) **only** by appending to `directives.md`; never edits the ledger;
- **decides by default**: adjudicates anything off the owner-only list itself (directive + one-line rationale for retro-review), sweeps `owner-blocked` each tick for items it can unblock — including any whose STANDING pre-authorization bar is now met — and escalates only genuine case-by-case owner-only calls; **adjudicates milestone promotion** — at a boundary it re-verifies the milestone's exit conditions and, if evidence is sufficient, releases the executor into the next milestone via an acceptance directive instead of letting it idle for human sign-off (escalating only the final / North Star promotion or an owner-only boundary);
- **stops its own loop when the run is over** — ledger `closed`/`exit-ready`, tree clean, final item's audit passed (final checkpoint first), or stalled-and-escalated with the executor no longer advancing — so the monitoring loop never idles overnight.

## The rules that make it work (encoded in the templates)

- **One scoreboard.** The ledger is the only source of truth. Code/docs/ledger conflict → fix the ledger first.
- **One item per round → verify same round → update ledger.** No batching, no "I'll test later".
- **Forced convergence — tracked in the ledger, not in the agent's head.** The status header carries a convergence tracker (rounds-since + net-lines-since + an explicit `next round converges` flag), so a stateless per-round loop reads the trigger instead of recomputing a modulo it can silently skip. A convergence round — zero features, only delete/merge/tighten, net lines ≤ 0 — fires on whichever comes **first**: N rounds since the last one (default 5) or accumulated net production lines over the cap (default 400); then the tracker resets. N and the cap are tuned to the plan's feature density at generation, and the supervisor audits that a flagged convergence actually converged.
- **Register-then-defer.** A gap found mid-round goes into the ledger's debt register by priority — never silently patched on the side, never dropped.
- **No speculative building.** New endpoint/module/abstraction/pool needs a named real consumer in the ledger first. No compat double-paths, v1/v2 coexistence, or parallel error systems.
- **Pilot before full batch.** Expensive full-cohort operations (whole-set evals, bulk VLM/API sweeps, migrations) run a smallest-slice pilot first; full run only after the pilot verifies clean.
- **Honest measurement.** A metric counts only on the real, declared eval set (the frozen holdout in the ledger). Numbers from synthetic/self-generated inputs or a cherry-picked subset aren't progress and are never recorded — benchmark-gaming the clean-context supervisor must catch. Evidence artifacts (scorecards, eval reports) land at versioned persistent paths — the run directory or the repo, never scratch/tmp; a number whose artifact has vanished is struck and re-measured.
- **Stop conditions end the loop.** An **intermediate** milestone going all-green does **not** stop the run when a supervisor is present: the executor sets the ledger's **Milestone gate to `pending-audit`** (an explicit tracked flag, like the convergence tracker — not a state held in the agent's head), writes a promotion request, and keeps looping while the supervisor independently re-verifies that milestone and **releases it into the next one via an acceptance directive**; the executor flips the gate to `passed` only when that directive lands, and **starting the next milestone while the gate is `pending-audit` is a red line** — this is what makes the gate non-skippable. A parked executor never ends its loop (nothing would restart it) and never idle-spins: it works the debt register / convergence / read-only prep, falling back to a cheap no-op tick only when nothing else remains — and **the stall guard does not count these gate-park rounds** (they're waiting on the supervisor, not stuck), so it never self-terminates at the gate; it stays alive so its next tick can read the acceptance directive. Because staying alive across the wait is load-bearing, on **interval hosts (Cursor, cron, shell)** both loops must be scheduled and the executor keeps cheap-ticking until release — the pattern is most natural on **adaptive hosts** (Codex, self-paced `/loop`) where re-invocation is automatic. Human sign-off is reserved for the final / North Star promotion, a boundary that crosses an owner-only line, or a run with no supervisor. All remaining items blocked → stop, escalate. Two rounds with no ledger/metric change (**except while parked at a `pending-audit` gate**) → stop, stall diagnosis. Red line violated → stop immediately. On any of these the node writes a terminal ledger status **and ends its own loop** — the supervisor loop ends too once the run is done — so a finished or stuck run never idles overnight.
- **Clean-context separation, delegated authority.** The supervisor is a different node with a fresh context: it **independently re-verifies claimed-done work against the acceptance bar and the shared standards** (`ops.md`, repo `AGENTS.md`/`CLAUDE.md`) — catching drift, fake-done, and concealment the executor can't see in its own context — commits only what passes, **decides everything off the owner-only list itself** (logged rationale, retro-reviewable), and shapes the plan through the directives edge; escalating only genuine owner-only calls, never merging into the executor's context or writing its ledger.
- **Pre-adjudicate, don't propose-and-wait.** Owner-only decisions on the goal's critical path are settled at interview time into **standing authorizations** — an objective evidence bar the executor acts under autonomously (owner retro-reviews). A loop whose own work is owner-only (dropping dead tables, cutting spend) must not stall emitting proposals for the owner to sign; only a call that genuinely can't be stated as a bar in advance stays blocking.

## Files in this skill

- `templates/` — the five fill-in artifacts (executor, ledger, directives, ops, supervisor). The executor and supervisor prompts encode the loop's self-stop.
- `docs/methodology.md` — the deep dive (why each rule exists, failure modes it prevents).
- `examples/add-tests-to-cli/` — a fully worked, generic example.
- `examples/migrate-blob-storage/` — a longer worked example: milestones, a cohort pilot, and a supervisor directive in action.
