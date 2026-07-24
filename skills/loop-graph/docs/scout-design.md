# Scout Node — Design Record

> This document supplements `model.md` (on `docs/model-vocabulary` branch) with the scout's formal vocabulary entries. Once `model-vocabulary` merges, these should be folded into the main model doc and this file deleted.

## Node tuple

```
(prompt, model, activation, read-set, write-set, authority, stop-condition)
```

| Field | Value |
|-------|-------|
| `prompt` | `templates/scout.md` |
| `model` | cheap/fast (Haiku-tier) — research is parallelizable, not judgment-heavy |
| `activation` | on-demand: dispatched via research brief in directives (supervisor or owner) |
| `read-set` | ledger (read-only), ops/ambient (read-only), external docs |
| `write-set` | `findings.md` (single-scout) or `findings/<brief-id>.md` (parallel) |
| `authority` | advisory only — may surface options + tradeoffs; may NOT alter plan, ledger, or implementation |
| `stop-condition` | brief answered, OR token/time cap hit, OR blocked needing clarification |

### Roles table addition (for model.md)

| Role | Model | Activation | Reads | Writes | Authority | Stops when |
|------|-------|------------|-------|--------|-----------|------------|
| **Scout** | cheap/fast | on-demand (research brief) | ledger, ambient, external | findings | advisory — options + tradeoffs, no plan/impl changes | brief answered, cap hit, or blocked |

## Edge: findings

| Property | Value |
|----------|-------|
| Type | **State** (single-writer, overwrite) |
| Writer | scout (single-writer per findings file) |
| Reader | executor (read-on-reference, via ledger pointer) |
| Discipline | read-on-reference; consume-and-retire |
| File | `findings.md` (single) or `findings/<brief-id>.md` (parallel) |

### Why state, not signal?

The scout overwrites its findings file as it works (refining the comparison table, updating status). It's not append-only — a partial finding gets overwritten with the complete version. This matches state-edge discipline: single-writer, latest-value-wins.

### Pointer convention

The ledger carries a one-line reference at the decision point:
```
blocked-on: findings#<brief-id>
```

The executor opens the findings file **only** when it reaches that row. No other round reads it.

### Retire convention

Once consumed:
1. Executor records the decision + rationale in its round log.
2. Finding moves to `archive/findings-<brief-id>.md`.
3. `blocked-on` pointer removed from ledger.

## Applying the vocabulary (collapse analysis)

| Proposal | Analysis | Outcome |
|----------|----------|---------|
| Scout node (#17) | Activation = on-demand (not cadence/event) — distinct from supervisor. Authority = advisory only (no plan/impl changes) — distinct from executor and supervisor. Write-set = dedicated findings edge (not ledger) — new single-writer file, not a partition of an existing edge. | **Does not collapse** — genuinely new information-flow pattern: off-critical-path research → dedicated state edge → read-on-reference consumption |

## Worked example

See [`examples/scout-library-choice/`](../examples/scout-library-choice/) for the full narrative. Summary:

1. **Executor** hits "which library?" → logs `blocked-on: findings#s3-client` in ledger → continues next unblocked item
2. **Supervisor** sees pointer on next tick → dispatches scout via research brief in directives
3. **Scout** activates in fresh context → researches → writes comparison to `findings.md` → stops
4. **Executor** reaches pointer row → reads findings → decides → records decision in ledger → retires finding to archive

The critical path never blocked. The findings edge carried research without touching the ledger's token budget.
