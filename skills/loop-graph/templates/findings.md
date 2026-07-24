<!--
graphkit template: findings.md — the SCOUT'S SINGLE-WRITER STATE EDGE.
Seeded empty at generation time into the run directory. The scout node writes here;
the executor reads it ON-REFERENCE ONLY (when it hits a ledger pointer), never
every round. The supervisor may read it during audit to verify the executor consumed
findings correctly.

Discipline: State edge, single-writer (scout), read-on-reference (executor).

POINTER CONVENTION — the ledger carries a one-line pointer at the decision point:
    blocked-on: findings#<brief-id>
The executor opens this file (or findings/<brief-id>.md) only when it reaches that
row. Most rounds it never reads findings.

CONSUME-AND-RETIRE — once the executor folds the decision into the plan:
  1. Record the decision + rationale in the ledger's round log.
  2. Move the consumed finding to archive/findings-<brief-id>.md (or delete it).
  3. Remove the blocked-on pointer from the ledger.
The findings edge stays O(active briefs), not O(total briefs ever dispatched).

PARALLEL SCOUTS — when multiple scouts run concurrently, each writes its own file
under findings/<brief-id>.md instead of this root findings.md. Each file is
single-writer (its scout). The pointer convention stays the same:
    blocked-on: findings/<brief-id>#<section>
On a single-scout run, this root file suffices. Create the findings/ directory only
when concurrency is real.
-->

# {{PROJECT}} — Findings (scout → executor, read-on-reference)

<!-- Findings appear below as the scout completes research briefs. The executor
     reads a finding only when it reaches the corresponding blocked-on pointer in
     the ledger. Once consumed, the finding is archived (moved to archive/) and the
     pointer is removed. -->

(no findings yet)
