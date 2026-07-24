# Contributing to octopus-skill

Thanks for helping! octopus-skill is a small, opinionated prompt library — one
umbrella router (`/octopus`), two arms (`loop-graph`, `quest`), and a shared brain
in `lib/`. Contributions that keep it curated rather than comprehensive are the
most welcome.

## Good contributions

- **Real-world tunings** of the defaults (convergence interval, net-line cap, loop
  cadence) with a note on the project shape they suited.
- **New worked examples** under an arm's `examples/` — must be fully generic and
  secret-free (see below).
- **Clarity fixes** to the arm templates, `lib/methodology.md`, or the
  `lib/host-dialects.md` matrix (corrections to what a host actually supports are
  especially valued).
- **Translations** — arm READMEs ship EN + 中文; more languages welcome, mirror the
  existing structure.
- **New host dialects** — if an agent runtime has a loop or goal primitive not yet
  in `lib/host-dialects.md`, add it there (the single owner of host facts).

## Adding a new node role (`loop-graph`)

The graph grows one node at a time — a node is **one Markdown prompt + one inspectable edge**, no runtime. The scout ([#17](https://github.com/levi-qiao/octopus-skill/issues/17) → [#18](https://github.com/levi-qiao/octopus-skill/pull/18) → [#19](https://github.com/levi-qiao/octopus-skill/issues/19)) is the reference example; the path that merged cleanly:

1. **Propose in an issue first.** State the node's *tuple* — `(prompt, model, activation, read-set, write-set, authority, stop-condition)` — and which existing role it's distinct from. The vocabulary lives in [`skills/loop-graph/docs/model.md`](skills/loop-graph/docs/model.md).
2. **Give it its own single-writer edge.** Never partition an existing edge — the ledger has exactly one writer. A new writer means a new file it alone writes; other nodes read it. Preserve the edge invariants in `model.md`.
3. **Keep it off the hot path.** Only the ledger is read every round. A new edge is read *on-reference* (a one-line ledger pointer), so it never bloats the per-round token cost.
4. **Wire both peers.** A node nobody dispatches or consumes is dead — add the handoff to `executor.md` / `supervisor.md`, kept optional (“delete if no *X* node”).
5. **Ship a worked example** under the arm's `examples/` proving the full dispatch → consume flow, generic and secret-free.

## Hard rules

- **No secrets, no real client data, ever** — in examples, fixtures, docs, or commit
  messages. Examples must use fictional projects.
- **No prompt enters the library without a real consumer** — a run it was actually
  proven on. This is octopus's own anti-bloat rule turned on itself; curated and
  opinionated beats a junk drawer.
- **Keep it minimal.** New abstraction or config in a template needs a concrete
  motivating case. The library preaches anti-bloat; the repo should practice it.
- **Don't break the shape.** The methodology's load-bearing parts (single scoreboard,
  one-item rounds with same-round verification, a forcing function against growth,
  register-then-defer, hard stop conditions, absolute red lines, and — for
  `loop-graph` — a supervisor node whose context is separate from the executor's)
  are the product. Tune the numbers, not the shape.

## How to submit

1. Fork and branch.
2. Make the change; if you touched an example, sanity-check that its ledger and
   executor prompt still tell a coherent story.
3. Open a PR describing the failure mode your change addresses or the tuning it
   documents.

By contributing, you agree your contributions are licensed under the [MIT License](LICENSE).
