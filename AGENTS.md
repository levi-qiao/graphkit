# AGENTS.md — working on octopus-skill

Guidance for any agent (or human) editing **this repo**. Read before changing anything.
The same rules apply in Claude Code — [`CLAUDE.md`](CLAUDE.md) imports this file.

## What this repo is

A **curated, opinionated prompt library** for long-horizon agent work, framed as
**"graph engineering."** It ships **Markdown prompts, not application code** — there
is no build step and no runtime. One umbrella (`/octopus`) routes to two arms:

- **`skills/loop-graph/`** — an executor node + a clean-context supervisor node driven
  by two loops (for `/loop`-capable hosts).
- **`skills/quest/`** — one objective prompt for a goal-capable host (Grok `/goal`, a Codex task).

Deep context lives in [`lib/methodology.md`](lib/methodology.md) (the *why* behind each
rule) and [`skills/loop-graph/docs/model.md`](skills/loop-graph/docs/model.md) (the
node/edge vocabulary + invariants). The contribution bar is in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Layout

| Path | What it is |
|---|---|
| `SKILL.md` | umbrella router (`/octopus`) — picks the arm, doesn't do the work |
| `skills/<arm>/SKILL.md` | the arm's interview → generate → deliver flow |
| `skills/<arm>/templates/*.md` | node **prompts** pasted into an agent — not code; keep `{{PLACEHOLDER}}`s and structural headings intact |
| `skills/loop-graph/examples/` | concrete, fully worked runs (these *are* project-specific — that's correct) |
| `lib/host-dialects.md` | the **single owner** of per-host facts (loop/goal syntax, hooks) — put host specifics here, don't scatter them |
| `.claude-plugin/` | Claude Code plugin + marketplace manifests |

## Rules that are easy to get wrong (don't)

1. **Keep templates host- and goal-agnostic.** Never hardcode a specific project or
   domain into `templates/`, `lib/`, or a `SKILL.md`. Rules adapt to whatever goal the
   user writes; scope eval/measurement-specific language behind *"when a check is a
   measurement."* Mine real runs for failure modes, then write them up generically.
   (Examples under `examples/` are the one place concrete is right.)
2. **Anti-bloat governance — the library holds itself to its own rule.** No prompt
   enters without a real consumer (a run it was proven on). Curated > comprehensive.
   New abstraction/config in a template needs a concrete motivating case.
3. **Don't break the load-bearing shape.** The graph's invariants are the product:
   single scoreboard (`ledger` = **exactly one writer**); one item per round → verify
   same round → update ledger; forced convergence; register-then-defer; hard stop
   conditions; absolute red lines; the supervisor is a **clean-context** node that
   steers only through the **one-way directives edge**, never editing the ledger or
   sharing the executor's context. Tune the numbers, not the shape.
4. **Node = one prompt + one single-writer edge.** To add a role: propose in an issue
   with its tuple first, give it its **own** edge (never partition an existing one),
   keep it **off the hot path** (only the ledger is read every round; new edges are read
   *on-reference* via a one-line ledger pointer), wire both peers, ship a generic
   example. The scout (#17→#18→#19) is the reference. See `CONTRIBUTING.md`.

## Editing conventions

- **Bilingual.** Arm READMEs ship EN + 中文 — mirror any change into `README.zh-CN.md`.
  Interview in the user's language but keep template headings/field names/placeholders unchanged.
- **Links, not bare paths, in human-facing docs.** Cross-file references are markdown
  links; runtime-artifact names (`ledger.md`, `ops.md` — generated per run, not repo
  files) stay code spans.
- **Mermaid diagrams stay mirrored** across EN + zh-CN.
- **No secrets or real client data, ever** — examples use fictional projects.
- **Surgical changes**, matching surrounding style. Every changed line traces to the request.

## Checks (there is no test suite)

- After touching `.claude-plugin/` or the skill layout, run **`claude plugin validate .`** — it must pass.
- After editing an example, confirm its `ledger.md` + executor prompt still tell a coherent story.

## Commits & PRs

- **Conventional commits**: `feat(loop-graph): …`, `docs: …`, `fix(quest): …`.
- **Branch + PR**, don't push straight to `main` (this file is the exception the owner asked for). PR body states the failure mode the change addresses or the tuning it documents.
- **Distribution**: installable via the curl script *and* the Claude Code plugin. The
  plugin `version` is **intentionally omitted** so Claude Code uses the git SHA
  (users auto-update on every push) — don't add a version unless starting a real release process.
