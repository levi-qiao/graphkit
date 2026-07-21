# The graphkit methodology

Every rule here exists to prevent a specific, observed failure mode of long-running agent work. This document explains the *why* so you can adapt the rules without breaking them.

## Why a graph, not a loop

A single agent grinding a long task is a *loop*: the same context, growing round after round, judging its own output. The failure is structural — by round 30 the context is full of the shortcuts, half-truths, and quietly-lowered bars that got it there, and that polluted history is exactly what it reasons from. It cannot audit its own drift, because the audit runs in the drifted context.

graphkit's answer is to make the run a small **graph of nodes that share no context** — only durable, inspectable state:

- the **executor node** advances the work, round by round;
- the **supervisor node** boots fresh every tick, reads only the ledger and git tree, and judges the run from the outside;
- the edges between them are files a human can open: the **ledger** (shared scoreboard), the **directives file** (one-way corrections), the **git tree** (checkpoints).

Rules 1–7 keep the *executor* honest within a round. Rule 8 — clean-context separation — is what a loop structurally cannot give you, and it's the reason this is a graph. Rule 9 keeps successive *runs* honest with each other.

## 1. One scoreboard (the ledger)

**Rule:** a single `ledger.md` is the only source of truth. When code, docs, and ledger disagree, the ledger is fixed first, then the code.

**Prevents:** *state fragmentation.* Without one canonical place, round 30 rediscovers a decision made in round 5, re-opens a closed question, or builds a thing that already exists. The ledger is small on purpose — it's read every round, so it must stay cheap. When it grows, archive old rounds and carry forward only load-bearing facts in a "starting snapshot". The ledger is also the edge the supervisor reads, so keeping it honest keeps the whole graph observable.

## 2. One item per round → verify same round → update ledger

**Rule:** each round picks the single smallest unclosed item, implements it, verifies it with the narrowest test/gate/smoke, and records the result — all in one round.

**Prevents:** *batching debt and fake progress.* Batching hides which change broke a gate. "I'll test later" becomes "never". Verifying in the same round means "done" always means "verified to closure", not "written". The same instinct scales up: an expensive full-cohort operation (whole-set eval, bulk VLM/API sweep, migration) gets a **smallest-slice pilot first** — validate on a handful of items, then go wide; burning the full set to discover a config bug is the batch-debt failure at cohort scale.

## 3. Forced convergence rounds

**Rule:** every Nth round (default 5) does zero new features — only deletion, de-duplication, interface tightening; net lines ≤ 0. A single round adding more than the net-line cap (default 400) forces the next round to converge.

**Prevents:** *monotonic growth.* Agents add far more readily than they remove. Without a periodic forcing function, the codebase only grows, and complexity compounds until the run can no longer reason about it. Convergence rounds are where the run pays down what it borrowed.

## 4. Register-then-defer

**Rule:** any gap found mid-round is logged in the ledger's debt register with a priority and queued for a later round. Never silently patched now; never dropped.

**Prevents:** two opposite failures at once — *scope explosion* (fixing every gap you trip over turns one item into ten) and *silent loss* (noticing a bug and forgetting it). Registering makes gaps visible and schedulable without derailing the current item.

## 5. No speculative building

**Rule:** before adding any endpoint / module / protocol / config / pool, register its real consumer in the ledger. No consumer → don't build. No compat double-paths, no v1/v2 coexistence, no parallel error systems, no second delivery channels.

**Prevents:** *"might need it later" bloat* and *two-truths architecture.* The most expensive drift is a second way to do something that already has a way. Requiring a named consumer kills speculative abstractions at the door.

## 6. Stop conditions

**Rule:** three ways to stop cleanly —
- **Milestone exit all-green** → write a promotion request, stop for human sign-off.
- **All remaining items blocked** → stop with an escalation report.
- **Two rounds with no ledger/metric change** → stop with a stall diagnosis.

And one way to stop hard: **any red-line violation halts the run immediately.**

**Prevents:** *spinning.* A run with no stop condition burns tokens re-touching the same untouchable items. Explicit stops turn "stuck" into a signal instead of silent churn.

## 7. Red lines

**Rule:** a short list of non-negotiables that halt the run: no push without authorization, no destructive git on others' work, no secrets/real data in code/logs/commits, frozen contracts stay frozen, metrics only go up (a regressing change is rolled back the same round).

**Prevents:** *irreversible or unsafe actions.* These are the things you cannot undo cheaply — a bad push, a leaked key, a silently lowered accuracy bar. They are absolute, not heuristics.

## 8. Clean-context supervisor separation

**Rule:** the supervisor is a **different node with a fresh context**, spun up each tick. It reads only durable state (ledger + git) **plus the shared standards both nodes obey** (`ops.md`, the repo's `AGENTS.md`/`CLAUDE.md`/lint), and it is an **independent acceptance auditor, not just a watchdog**: it **re-verifies the executor's claimed-done work itself** — re-running the gates and inspecting the real diff/artifact against the acceptance bar and those standards — so it catches drift, fake-done, and undisclosed shortcuts the executor's own context hides. It checkpoint-commits **only what passes its audit**, and corrects drift, wasteful *method*, and a stale plan **only through the directives file the executor reads** — never by editing the ledger the executor is actively writing, never by joining the executor's context. It is also a **decider**: it adjudicates every call **off the owner-only list** itself — directive plus a one-line rationale the owner can retro-review — escalating only the short list of genuinely human calls.

**Prevents:** *self-blind drift and concealment, write contention — and escalation stalls.* A same-context agent can't catch the drift its own context caused, and it will report its own shortcuts as "done"; a clean-context auditor that re-runs acceptance against the shared standards catches both, because it wasn't there when the corner was cut and it doesn't take the ledger's word for it. Two agents editing the same scoreboard corrupt it — so the directives file is a strict one-way edge: supervisor writes, executor reads. Checkpoint commits are the supervisor's job precisely because commit authorization is a red line for the executor. And a supervisor that only watches and escalates leaves the run idling for hours on calls a competent reviewer could make — delegated authority with a logged rationale keeps the run moving while keeping the owner able to overrule after the fact. The deeper stall is upstream: if an owner-only category sits on the goal's *own critical path* — the goal **is** dropping dead tables, so every round hits DDL — then no amount of supervisor delegation helps, because the decision genuinely belongs to the owner. The fix is to move it earlier: **pre-adjudicate it in the interview into a standing authorization** — an objective evidence bar (e.g. "drop once 0 rows + 0 consumers + 0 reads/writes, via reversible migration") the executor acts under autonomously and the owner retro-reviews. Without that, the loop can only emit "proposals awaiting sign-off" and stop — which is not a loop. Only a decision that truly can't be written as a bar in advance stays blocking. This node separation is the load-bearing difference between a graph and a loop.

## 9. One run, one directory

**Rule:** every run generates its artifacts fresh into its own `.graphkit/<YYYY-MM-DD-slug>/` directory. A successor run never edits the previous run's prompts or ledger — it distills what still holds into its own starting snapshot, carries still-in-force STANDING directives forward, and leaves the old directory untouched as the archive.

**Prevents:** *state bleed between runs.* Retargeting an old executor prompt or ledger means patching stale goals line by line — token-expensive, error-prone, and the leftover text quietly steers the new run toward the old goal. Fresh generation from templates plus a distilled snapshot carries exactly the learnings and none of the stale scaffolding; a fixed, predictable location means the supervisor cron and a fresh executor always find state in the same place.

---

## Tuning

The numbers (convergence every 5, 400-line cap, 30-minute tick) are defaults, not dogma. Tune them in the interview to your project's rhythm. What must not change is the *shape*: a single scoreboard, one-item rounds with same-round verification, a forcing function against growth, visible-and-deferred gaps, hard stop conditions, absolute red lines, and — above all — a supervisor node whose context is separate from the executor's. Remove any one of those and the graph collapses back into a drifting loop.
