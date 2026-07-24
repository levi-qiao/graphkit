<!--
octopus quest arm: quest.md — the SINGLE objective prompt.
Replace every {{PLACEHOLDER}}, delete guidance comments, then hand the result to
the host's goal command (grok `/goal <this>`; Codex: delegate a task with this brief).
There is NO separate supervisor prompt and NO second loop: the host's own harness
is the acceptance auditor. Your only job is to write an objective whose acceptance
criteria that harness can actually check. If the host only loops and has no goal
command (Claude Code, Cursor, shell), use the loop-graph arm instead — see ../../loop-graph.
-->

{{OBJECTIVE_ONE_SENTENCE}} — in {{PROJECT_OR_REPOS}}. Deliver everything below
yourself; do not stop to ask permission for the obvious next step.

## Done means verified (the acceptance criteria the verifier will re-check)

{{EXIT_TABLE — one row per goal, each with a *reproducible* check the verifier can
run without you. Example:
| # | Goal | Verified by (command / artifact) |
| G1 | … | `make test` green |
| G2 | metric ≥ baseline | scorecard at <persistent path> shows ≥ X on the frozen eval set |
The verifier defaults to "refuted" when it can't reproduce a check — so every row
must be checkable from committed code + saved evidence, never from your prose.}}

## Discipline (these are what keep a long goal from drifting)

- **One item at a time, verified the same round.** Pick the smallest unclosed
  item, implement it, verify it with the narrowest gate/test/smoke, then move on.
  "Done" means "verified to closure", never "written".
- **No test theater.** A passing test must prove the *shipped* code works on the
  real path — no hard-coded expected values, no starting past the thing under
  test, no re-implementing it inside the test. A test that passes while the
  program is broken is worse than none. Commit the tests. Saved run output is
  supplemental evidence only; the verifier must independently re-run the
  acceptance command against the final tree and never treat saved output as
  authoritative.
- **No speculative building.** Before adding any endpoint / module / config /
  pool, name its real consumer. No consumer → don't build it. No compat
  double-paths, no v1/v2 coexistence, no parallel error systems.
- **Converge, don't only grow.** Periodically ({{CONVERGE_EVERY|~every 5 items}} or
  once you've added {{NET_LINE_CAP|~400}} net lines) do a pass that adds zero
  features — delete dead code, merge duplication, tighten interfaces (net lines
  ≤ 0). Don't weaken or delete an acceptance criterion to make it pass — the
  verifier treats a self-serving criterion change as grounds to refute.
- **Found a gap? Register, don't fix-on-the-side, don't drop it.** Note it, give
  it a priority, and queue it — don't let one item silently balloon into ten.
- **Expensive runs pilot first.** Any full-cohort eval / bulk sweep / migration
  runs a smallest-slice pilot first, then goes wide only once the pilot is clean.

## Red lines (violate → stop immediately)

{{RED_LINES — the non-negotiables. Typical set:
- No reset/stash/clean of changes you didn't make.
- No commit/push without authorization{{; no push at all if that's the rule}}.
- No destructive ops against {{protected resource}}.
- Real data / secrets / license content never enter code, fixtures, logs, or commits.
- Frozen contracts: zero changes.
- Metrics only go up: any change that regresses a metric is rolled back the same round.
- Metrics measured ONLY on the declared real eval set; a number from synthetic or
  cherry-picked inputs does not count and is never recorded as progress.}}

## When to hand back

Finish the whole objective. Legitimately stop only for: a genuine external
blocker (missing credentials, network down, a denied permission), or a decision
that truly needs {{OWNER|the owner}} and cannot be settled by an evidence bar you
were given above. State the blocker and the exact evidence/action needed —
{{OWNER|the owner}} resumes you afterward. Do not stop merely to announce progress.
