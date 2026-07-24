# Example: scout researches a library choice off the critical path

A worked example showing the **scout node** in action. The executor hits a "which library?" decision, the supervisor dispatches a scout, the scout writes findings, and the executor consumes and retires them — all without blocking the critical path.

## The scenario

`shutterlog` (same fictional app as [`migrate-blob-storage`](../migrate-blob-storage/)) needs an S3-compatible client library for its object-store migration. The executor has reached M1 (dual-path writes) and needs to pick a library before implementing the upload path. Rather than block the executor while it researches, the supervisor dispatches a scout.

## The flow

### 1. Executor hits the decision point

During Round 2, the executor reaches the upload-path implementation and realizes it needs to choose between three S3 client libraries. It logs a pointer in the ledger:

```markdown
### Round 2 — 2025-01-15
- **Item**: implement dual-path upload (new photos → object store)
- **blocked-on**: findings#s3-client
- **Next**: continue with request-routing (not blocked) while scout researches
```

The executor doesn't stop — it works the next unblocked item (request routing).

### 2. Supervisor dispatches the scout

On its next tick, the supervisor sees the `blocked-on` pointer. It appends a research brief to `directives.md`:

```markdown
D-003 · 2025-01-15 — dispatch scout: brief `s3-client`.
  Question: which S3-compatible client library for Python fits our constraints?
  Context: requirements in ops.md (async, <5MB dep, streaming uploads, no C extension).
  Constraints: must support MinIO + AWS S3; must have async interface; actively maintained (commit in last 90d).
  Cap: 8000 tokens.
```

### 3. Scout activates and writes findings

A fresh scout context spins up, reads the brief, researches the three candidates, and writes `findings.md`:

```markdown
# Findings: s3-client

**Brief**: Which S3-compatible Python client library fits our async/size/maintenance constraints?
**Status**: complete
**Date**: 2025-01-15

## Answer

`minioclient` fits all constraints. `boto3` fails the size constraint (28MB); `aioboto` is unmaintained (last commit 11 months ago).

## Comparison

| Option | Fits constraints? | Key tradeoff | Evidence |
| --- | --- | --- | --- |
| minioclient 7.2 | yes | smaller community, but API is S3-compatible | PyPI: 1.2MB, async since v7, last commit 12d ago |
| boto3 1.34 | no (size) | 28MB installed; no native async (needs aiobotocore) | PyPI metadata |
| aioboto 0.9 | no (maintenance) | last commit 2024-02-03; open CVE unfixed | GitHub insights |

## Recommendation

minioclient — only option that satisfies all four constraints simultaneously.

## Notes

- Verified MinIO compat: minioclient README lists MinIO as primary target
- Checked async: `minioclient.aio` module since v7.0.0 (2024-06-01)
- No C extensions: pure Python (confirmed via setup.cfg `ext_modules = []`)
```

The scout stops. One activation, one file, done.

### 4. Executor consumes and retires

Round 4: the executor reaches the upload-path item again (request routing is done). It reads `findings.md`, accepts the recommendation, and records the decision:

```markdown
### Round 4 — 2025-01-15
- **Item**: implement dual-path upload (resumed — scout answered)
- **Decision**: minioclient 7.2 — fits all constraints per findings#s3-client
- **Change**: added minioclient to requirements, implemented async upload path
- **Retire**: findings#s3-client consumed → moved to archive/findings-s3-client.md
```

The `blocked-on` pointer is removed from the ledger. The findings edge returns to empty.

## The points

1. **No critical-path block.** The executor worked request routing (Rounds 2–3) while the scout researched. The decision point didn't stall the run.

2. **Single-writer preserved.** The scout writes only `findings.md`; the executor writes only the ledger. No contention, no invariant breakage.

3. **Read-on-reference, not read-every-round.** The executor opened `findings.md` only in Round 4 when it hit the pointer. Rounds 2–3 never touched it — zero token cost.

4. **Consume-and-retire.** Once the decision landed in the ledger, the finding was archived. The findings edge stays O(active briefs).

5. **Advisory only.** The scout recommended; the executor decided. If the executor had disagreed (e.g. "minioclient's community is too small for our SLA"), it would have picked differently and recorded why — the scout has no authority to override.
