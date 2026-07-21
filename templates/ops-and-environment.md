<!--
graphkit template: ops.md — durable environment facts.
The executor node consults this instead of re-deriving build/env/data facts every round.
Only create this file if there ARE non-trivial facts worth pinning. Keep it factual.
Red line: secrets / credentials / real data content NEVER go in this file — only policy
about them (where they come from, that they're env-injected, that they never get logged).
-->

# {{PROJECT}} — Environment & Ops Facts

> The executor consults this only when it touches builds / credentials / data / performance. It is not re-read every round.
> Red line: license / keys / real data content never enter the repo, logs, or commits — only the policy for handling them lives here.

## Build / test

{{Per-repo exact commands and any required flags. Example:
- Python: `.venv/bin/python -m pytest <file>`; full gate `make lint && make test`.
- Java: `mvn -s <path-to-settings> -pl <module> test` (the `-s` is required — without it, dependency resolution fails).
- Frontend: `pnpm build && tsc --noEmit`.
}}

## Standards / conventions (the shared yardstick)

{{The repo's own standards both nodes obey and the supervisor audits against — point at the source of truth, don't restate it: `AGENTS.md` / `CLAUDE.md`, lint & style config, naming/format conventions, "definition of done". E.g. "conventions in `AGENTS.md`; `make lint` enforces style; a change is done only when its gate is green AND lint passes." Delete if the repo has none.}}

## Credentials / secrets policy

{{How secrets are provided (env injection), and the hard rule that they are never printed / stored / logged / committed. Sample config values left blank. No actual values here.}}

## Data policy

{{Where the real/sensitive data lives, that outputs keep only anonymized aggregate metrics, and that real names / values never get persisted. If not applicable, delete this section.}}

## Cost / resource notes (optional)

{{If the run's work changes the resource footprint, record the bounded analysis here so it's not re-litigated: what's the bottleneck, what extra memory/CPU/disk/network it needs, and why it's bounded.}}
