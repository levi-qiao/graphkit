# Host dialects

The methodology is host-agnostic — the same discipline runs on any agent that can
loop or hold a goal. Only the *invocation syntax*, the *primitives a host actually
has*, and the *wake/notify* hooks differ. This table is the single owner of those
differences; skills point here instead of re-describing each host.

## What each host has (and therefore which arm it can run)

| Host | `loop` (scheduled/self-paced repeat) | `goal` (set-objective + verify-to-done) | Runs graphkit arm? | Runs goal arm? |
|------|:---:|:---:|:---:|:---:|
| **Grok** | ✅ `/loop` | ✅ `/goal` — native adversarial verifier | ✅ | ✅ |
| **Claude Code** | ✅ `/loop` | ⚠️ no standalone command — the graphkit **supervisor** is its verifier | ✅ | via graphkit |
| **Codex** | ❌ no loop command | ✅ task self-drives (adaptive) — **no** native refuter | via a task¹ | ✅ |
| **Cursor** | ✅ loop/repeat (run capped ~20 min) | ❌ | ✅ | ❌ |
| **shell / cron** | ✅ `while … sleep` / crontab | ❌ | ✅ | ❌ |

**Grok is the only host with both as first-class commands** — so on Grok the arm is a
genuine task-shape choice; everywhere else the host narrows it. Cursor and shell can
*only* loop → graphkit arm. Codex has **no loop command** and can *only* hold a goal →
goal arm. Claude Code has no separate `/goal`, so "a verified goal" on Claude *is*
graphkit (the supervisor is the verifier).

¹ Codex has no loop command, but its task **re-invokes itself each round** (adaptive)
— it **auto-wakes**, self-driving the goal to done with no prompting between rounds.
So its natural fit is the goal arm: you just **send the objective as a task, no
command needed**; Codex has no separate refuter, so the objective's own acceptance
criteria carry the verification.

## Loop primitive (drives the executor / a plain repeating task)

| Host | Command | Interval | Adaptive? | Stop |
|------|---------|----------|-----------|------|
| **Claude Code** | `/loop [interval] <prompt>` | optional — omit to self-pace | **yes** (self-paced re-invokes when the round returns) | `ScheduleWakeup` `stop:true`; or `CronDelete` if scheduled via `CronCreate` |
| **Grok** | `/loop [interval] <prompt>` | `Ns/Nm/Nh/Nd`, min 60s; recurring expires after **7 days** | no — interval-driven | `scheduler_delete <job-id>` (id printed when the loop is created) |
| **Cursor** | client "loop"/repeat feature | interval-driven | no — and it **kills a run past ~20 min**, so each round must finish under the cap | stop the loop in-client |
| **shell/cron** | `while …; do …; sleep <interval>; done` / crontab | interval-driven | no | `break` on a terminal ledger status / `CronDelete` |

**Adaptive vs interval** is the load-bearing distinction for the graphkit arm's
gate-park: on the adaptive host (Claude Code self-paced) re-invocation is automatic,
so a round never gets cut off and a parked executor resumes for free. On interval
hosts (Grok `/loop`, Cursor, shell/cron) **both loops must be scheduled** and the
executor keeps cheap-ticking until release — a loop that writes a terminal status
and stops cannot restart itself.

## Goal primitive (a built-in executor+verifier — the goal arm rides this)

| Host | Command | Built-in verifier? |
|------|---------|--------------------|
| **Grok** | `/goal <objective> [--budget <tokens>]` · `status`/`pause`/`resume`/`clear` | **yes** — plans acceptance criteria, works across rounds, and only marks complete after an **independent adversarial verifier** reproduces the evidence (defaults to *refuted* if it can't); anti-ratchet so it converges instead of re-litigating |
| **Codex** | just send the objective as a task — **no command needed** (it self-drives) | **adaptive** — self-drives to done across rounds and **auto-wakes** each round; no separate clean-context refuter, so lean harder on the objective's own acceptance criteria |
| **Claude Code** | *(no standalone `/goal`)* — use the graphkit arm; its clean-context supervisor is the verifier | n/a |
| **Cursor** | *(none — Cursor only loops)* — use the graphkit arm | n/a |

Where a host has a native goal harness (Grok, Codex), its verifier **is** the
supervisor — do not bolt a second supervisor loop on top; that is the redundancy the
goal arm exists to avoid. Where it doesn't (Claude Code, Cursor), use the graphkit arm.

## Wake / notify / keep-alive primitives

| Need | Claude Code | Grok | Cursor |
|------|-------------|------|--------|
| **Keep the agent working until a condition holds** (tests green, gate passes) | loop re-invocation | **`Stop` hook** — blocks the turn from ending until the condition holds, feeds the reason back to the model | — |
| **Ping the owner when a run parks / finishes** | — | **`Notification` hook** — HTTP/shell on task-finish or a surfaced notice | — |
| **Guard a red line before a tool runs** | hooks / permissions | **`PreToolUse` hook** — deny a dangerous command before it runs | — |

For the graphkit arm's "supervisor unresponsive at gate" backstop, a Grok
`Notification` hook turns a silent stall into an owner ping; a `Stop` hook can hold
the executor turn open until an acceptance directive lands instead of letting the
loop end. These are optional reliability upgrades, not required for the base pattern.
