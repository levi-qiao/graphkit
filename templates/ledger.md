<!--
graphkit template: ledger.md — THE SINGLE SCOREBOARD (shared state between nodes).
The executor node rewrites this every round; the supervisor node only reads it.
Keep it COMPACT: it is read every round, so bloat costs tokens. When history piles
up, archive the old rounds to a separate file and carry only load-bearing facts
forward in the "Starting snapshot" below.
-->

# {{PROJECT}} — graphkit Ledger

> This ledger is the run's only scoreboard. Authority order: {{AUTHORITY_LAYERS}} > this ledger. Environment facts: `ops.md`. Corrections from the supervisor: `directives.md`.
> When rounds accumulate, archive to `archive/ledger-archive-<date>.md` beside this file and keep only the snapshot below. Don't open archives unless debugging.

## Status header

Current milestone: {{M1 or "single goal"}} | Round: 0 (starts at 1) | Last round net lines: —
Smallest unclosed item: {{FIRST_ITEM}}
Convergence: fires at {{CONVERGE_EVERY|5}} rounds since last **or** +{{NET_LINE_CAP|400}} net lines, whichever first | since last: 0 rounds / +0 net | **next round converges: no**
Milestone gate: `open`   <!-- open | pending-audit | passed. Only meaningful for multi-milestone runs with a supervisor; single-goal / no-supervisor runs leave it `n/a`. The executor sets it `pending-audit` when it closes the current milestone's last exit condition (promotion requested, executor keeps looping — does NOT advance); the supervisor re-verifies the boundary and, on pass, appends an acceptance directive; the executor flips it `passed` only when that directive lands, and only then starts the next milestone. Advancing while this is `pending-audit` is a red line. -->
Run status: `active`   <!-- active | paused | exit-ready | stalled | closed. A terminal status (exit-ready/stalled/closed) is the signal for both loops to stop themselves. Note: `pending-audit` on the Milestone gate is NOT a terminal Run status — the executor keeps looping. -->

---

## Starting snapshot (carried-forward — replaces bulk history)

{{SNAPSHOT — everything a fresh executor needs and nothing it doesn't:
- what's already done (closed milestones, with one-line evidence),
- current state of the in-progress milestone,
- baseline metric anchors (for reference, not to be passed off as current measurements),
- working-tree alignment (branch tips, any uncommitted state to reconcile first),
- still-in-force constraints distilled from any prior directives.
Keep it tight.}}

---

## Gate scoreboard

| Gate | Status | Evidence / next action |
| --- | --- | --- |
| {{exit condition 1}} | open / in-progress / closed / owner-blocked | {{...}} |

## Metric snapshot (if the goal is metric-driven)

| Metric | Baseline | Current |
| --- | --- | --- |
| {{metric}} | {{baseline}} | {{measured or "pending"}} |

## owner-blocked (genuinely case-by-case human-decision items — log the one-line question, don't decide)

<!-- Only items with NO standing authorization. If a STANDING pre-authorization in
     directives.md covers the action and its evidence bar is met, execute it — it does
     not belong here. This list is for calls that truly need the owner case by case. -->

{{none yet, or list}}

## Debt & gap register (log every gap here; never silently fix or ignore)

| ID | Priority | Milestone | One line |
| --- | --- | --- | --- |
| GAP-001 | P? | {{M?}} | {{...}} |

## Rounds log

<!-- Append one block per round. Format: -->
<!--
### Round N — <date>
- **Item**: ...
- **Gate**: <commands + result>
- **Change**: <what + why, 1-2 lines>
- **Verify**: <narrowest test/smoke + result>
- **Net lines**: +x/-y
- **Open**: <what's still not closed on this item>
- **Next**: <the next smallest item>
-->
