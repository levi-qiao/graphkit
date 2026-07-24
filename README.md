# octopus-skill 🐙

**One brain, many arms.** A curated library of battle-tested prompts for
long-horizon agent work, compiled to whatever host you run — Claude Code, Grok,
Cursor, Codex. The methodology is shared; each *arm* adapts it to a host's native
shape (a loop, or a goal). Like an octopus, one nervous system reaching into
different environments and changing color to fit each one.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
![Hosts: Claude Code · Grok · Cursor · Codex](https://img.shields.io/badge/hosts-Claude%20Code%20·%20Grok%20·%20Cursor%20·%20Codex-8A2BE2)

English · [简体中文](README.zh-CN.md)

<img alt="the graph: an executor node and a clean-context supervisor node communicating only through durable files" src="assets/graph.png" width="100%" />

## Why this exists

A strong model authoring a tuned, opinionated prompt beats hand-driving a host ad
hoc — for repeatable, long-horizon, high-stakes work. (For a quick one-off, just
type the task; the library's ROI is in reuse.) The durable value isn't any one
mechanism — it's the **discipline**: "done" means verified not written, no test
theater, no speculative building, forced convergence against growth, and hard
owner red lines. That discipline is host-agnostic. octopus is where it lives, once,
and gets compiled down to each host.

## The arms

| Arm | Use when | Ships |
|-----|----------|-------|
| **[`loop-graph`](skills/loop-graph)** | you'll drive it with `/loop` (Claude Code, Grok, Cursor, shell); multi-round work that scope-creeps or fakes "done"; multi-milestone phases; executor and supervisor split across hosts/models; owner-gated | an **executor node** (works a single-source-of-truth ledger) + a clean-context **supervisor node** that re-verifies from outside and corrects via a one-way directives file — two loops |
| **[`quest`](skills/quest)** | you'll hand it to a goal command that self-drives to done (Grok `/goal`, a Codex task); a single self-contained goal, executor+reviewer in the same run | **one objective prompt** that folds the discipline in and rides the host's own verifier — no second loop |

Not sure which? The decision rule lives at the top of each arm's `SKILL.md`, and
the host capability matrix is in [`lib/host-dialects.md`](lib/host-dialects.md).

## Which host, which way

Two arms, one discipline. **Pick the arm by task shape** — then run it the way your
host wants. Most hosts now do both; the host only rules options out.

- **loop-graph** — multi-milestone / non-skippable gate / executor+supervisor split
  across hosts / owner-gated, or you want an **independent** verifier. Two prompts: an
  **executor** loop that works the ledger, plus a clean-context **supervisor** loop
  that re-verifies from outside and steers via a one-way directives file. *The
  supervisor is always a `/loop`, never a goal* — an auditor must wake from outside the
  executor's context on an interval; a goal races to "done".
- **quest** — a **single self-contained goal** that drives to a real "done". One
  objective prompt; the host's own harness drives it (and, on Grok, verifies it). No
  second loop.

Authoritative syntax + matrix: [`lib/host-dialects.md`](lib/host-dialects.md).

| Host | What it has | How to run each arm |
|---|---|---|
| **Grok** | **both** `/loop` **and** a `/goal` with a **native adversarial verifier** | **quest:** `/goal <objective>`. **loop-graph:** executor `/loop` + supervisor `/loop`. |
| **Codex** | **both** — a task self-drives a goal to done; a `/loop <interval>` in chat creates a **heartbeat timer** | **quest:** `/goal` / just send the objective as a task (self-drives; no independent verifier — make acceptance reproducible). **loop-graph:** drive **both** nodes with an interval `/loop` (e.g. `/loop 4m …`) — **needs an explicit interval, and never `/goal`**: a goal re-fires a *parked* node forever (livelock). |
| **Claude Code** | `/loop` (adaptive / self-paced); **no `/goal` command** | **loop-graph:** executor `/loop` (omit interval → self-paced) + supervisor `/loop`; the supervisor is the verifier. **quest:** a self-paced single `/loop` (no independent verifier). |
| **Cursor** | `/loop` only (interval; a run past **~20 min is killed**); no goal | **loop-graph only.** Executor `/loop` + supervisor `/loop`; keep every round under 20 min. |
| **shell / cron** | `while … sleep` / crontab only; no goal | **loop-graph only.** Both loops scheduled; `break` on a terminal ledger status. |

Rule of thumb: **task shape picks the arm; the host only rules options out** (Cursor &
shell can't quest — no goal). The **supervisor is always a `/loop`, never a goal**. On
Codex: quest → `/goal`; loop-graph → interval `/loop` heartbeats for *both* nodes,
because a goal livelocks a parked loop-graph node.

## The brain (`lib/`)

- **[`methodology.md`](lib/methodology.md)** — *why* each rule exists, tied to the
  specific failure mode of long agent runs it prevents. Read this to adapt rules
  without breaking them.
- **[`host-dialects.md`](lib/host-dialects.md)** — the single owner of per-host
  differences: loop/goal invocation syntax, adaptive-vs-interval behavior, and
  wake/notify/keep-alive primitives (Grok `Stop`/`Notification` hooks, etc.).

## Install

**Claude Code — plugin.** Claude Code's skill loader does **not** follow symlinked skill dirs, so install it here as a plugin (versioned, auto-updating via the marketplace):

```
/plugin marketplace add levi-qiao/octopus-skill
/plugin install octopus@octopus-skill
```

**Codex / Cursor — script.** These hosts' loaders *do* follow symlinks, so the script clones the library and symlinks it as a single `/octopus` skill (edits to the clone are live):

```sh
curl -fsSL https://raw.githubusercontent.com/levi-qiao/octopus-skill/main/install.sh | sh
```

Any existing `/graphkit` install is left untouched; to install from a local clone, run `./install.sh` from the repo root.

**How it's invoked.** `/octopus` is **user-invoked** (type it) *and* **model-invoked** — your agent auto-triggers it on a long-horizon task from the skill description, then routes to the right arm. Both arms are self-contained, so `loop-graph` and `quest` can also be invoked directly.

## Governance — keep it a library, not a junk drawer

octopus applies its own anti-bloat rule to itself: **no prompt enters the library
without a real consumer** — a run it was actually proven on. Curated and
opinionated beats comprehensive. Same bar the executor holds inside a run.

## Credits

The `loop-graph` arm grew from real runs and community input — it began life as the
standalone *graphkit* skill, and this repo is that project, evolved (the old
`graphkit` URL redirects here). Special thanks to
**[@BrightProgrammer7](https://github.com/BrightProgrammer7)** — the
`migrate-blob-storage` worked example and the design discussions that sharpened
the milestone-gate and node/edge vocabulary.

## License

See [LICENSE](LICENSE).
