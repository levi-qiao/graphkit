# Loop-Graph Model

This document defines the shared vocabulary for designing loop-graph runs. Read it once when proposing a new node or edge; templates implement these concepts implicitly — running nodes never parse this file.

**Scope:** loop-graph only. The quest arm externalizes state onto the host's own harness (Grok `/goal`, Codex task) rather than onto files; it satisfies the same law by different machinery.

---

## The Law

> No load-bearing state may live only in a node's context; it must be externalized onto a typed edge.

This is the checkable definition of drift: **drift = load-bearing state that stayed in context and never made it onto an edge.**

Code-review test for a new template: does this node derive X from its own prior rounds' context instead of reading it from the ledger? → bug.

The convergence tracker (#7) and the milestone gate (#11) both work because they moved a computed predicate — "should I converge?", "may I advance?" — from the executor's mental arithmetic onto the state edge where a stateless re-activation reads it cold.

---

## Nodes

A node is a specialized agent role. Each node is described by a tuple:

```
(prompt, model, activation, read-set, write-set, authority, stop-condition)
```

| Field | What it answers |
|-------|-----------------|
| `prompt` | What does this node do? (the `.md` file) |
| `model` | Which model tier runs it? |
| `activation` | When does it fire? (cadence, event, manual) |
| `read-set` | Which edges + ambient context may it read? |
| `write-set` | Which edges may it write? |
| `authority` | What may it decide without escalation? |
| `stop-condition` | When does it end its loop? |

### Current roles

| Role | Model | Activation | Reads | Writes | Authority | Stops when |
|------|-------|------------|-------|--------|-----------|------------|
| **Executor** | cheap/fast | per-round (adaptive or interval) | ledger, directives, ambient | ledger | implementation decisions | ledger reaches `exit-ready` or `closed` |
| **Supervisor** | strong | cadence (e.g. 30min) | ledger, git diff, ambient | directives | drift corrections, acceptance, plan adjustments | nothing left to commit |

`authority` is the field #9 exposed as missing: "who decides X without escalating?" The executor decides *how* to implement; the supervisor decides *whether* the work meets acceptance criteria; the owner decides DDL, credentials, red-line exceptions.

---

## Edges

An edge is a durable, typed channel between nodes. Two types:

| Type | Discipline | Example |
|------|------------|---------|
| **State** (blackboard) | single-writer, overwrite | `ledger.md` — the scoreboard |
| **Signal** (queue) | single-writer, append-only, one-way | `directives.md` — supervisor → executor |

### What is NOT an edge

**Ambient context** — read-only files that exist before and after a run: `ops.md`, `AGENTS.md`/`CLAUDE.md`, lint config, the templates themselves. Nobody writes them *between* nodes at runtime; they don't carry information along a run's timeline. They're the repo, not the graph.

The test: can you determine "reuse an existing edge vs create a new one" using only state + signal? Yes — #9 proved it. The proposed `gates.md` had signal discipline (append-only, supervisor → executor) but its content was a single flag (pass/fail per milestone) → that's a field on the state edge (`ledger.md`). Two types were enough.

---

## Applying the vocabulary

When proposing a new construct (node, edge, flag), fill in the tuple / classify the edge type first. If the proposal collapses into an existing construct, it wasn't needed.

| Proposal | Analysis | Outcome |
|----------|----------|---------|
| Auditor node (#9) | Activation = "at milestone gates" needs event-bus the graph doesn't have; degrades to cadence poller = supervisor. Authority = acceptance = already supervisor's. | Collapsed into a tracked flag + red line on the existing supervisor |
| `gates.md` edge | Signal discipline, but content = one flag per milestone → fits as a field on the state edge | Collapsed into `Milestone gate:` header in `ledger.md` |

The vocabulary earns its keep when filling in the tuple saves one issue → discussion → rewrite cycle.

---

## References

- #7 — convergence tracker (state edge field)
- #9 — auditor proposal → gate rule
- #11 — milestone gate implementation
- #12 — this vocabulary's design discussion
- #15 — worked example showing the gate in action
