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
| **Codex** | ✅ `/loop <interval>` → heartbeat automation¹ | ✅ task self-drives (adaptive) — **no** native refuter | ✅¹ | ✅ |
| **Cursor** | ✅ loop/repeat (run capped ~20 min) | ❌ | ✅ | ❌ |
| **shell / cron** | ✅ `while … sleep` / crontab | ❌ | ✅ | ❌ |

**Grok and Codex run both arms; Claude Code runs both\*; only Cursor and shell are
loop-only** (no goal → graphkit arm). So the arm is a **task-shape** choice on most
hosts — the host only rules options out. Grok is the only host whose goal carries a
*native adversarial verifier*; on Codex and Claude Code a "verified goal" leans on the
objective's own acceptance criteria. (\*Claude Code has no separate `/goal` — its quest
is a self-paced single `/loop`; for an independent verifier use graphkit, where the
supervisor is the verifier.)

¹ **Codex has two drive modes, and which you use depends on the arm:**
- **quest** — a task / `/goal` **self-drives to done** (adaptive, auto-wakes each round,
  no command needed); "done" is a real terminus, so this is the goal arm's natural fit.
  No separate refuter — the acceptance criteria carry verification.
- **graphkit** — drive **both** nodes with a `/loop <interval>` typed in conversation,
  which Codex compiles to a **heartbeat automation** (needs an *explicit* interval like
  `4m`, or no timer is created). **Never drive a graphkit node with a goal /
  self-driving task:** a graphkit node legitimately *parks* (`pending-audit`, `stalled`,
  awaiting a supervisor directive), and a goal harness has no "parked, waiting" rest
  state — it reads "not done" and re-fires the parked node forever (**livelock**,
  burning tokens on "still stalled" turns). The interval heartbeat parks cleanly: it
  ticks, cheap-no-ops while parked, and deletes its own automation on a terminal status.

## Loop primitive (drives the executor / a plain repeating task)

| Host | Command | Interval | Adaptive? | Stop |
|------|---------|----------|-----------|------|
| **Claude Code** | `/loop [interval] <prompt>` | optional — omit to self-pace | **yes** (self-paced re-invokes when the round returns) | `ScheduleWakeup` `stop:true`; or `CronDelete` if scheduled via `CronCreate` |
| **Grok** | `/loop [interval] <prompt>` | `Ns/Nm/Nh/Nd`, min 60s; recurring expires after **7 days** | no — interval-driven | `scheduler_delete <job-id>` (id printed when the loop is created) |
| **Codex** | `/loop <interval> <prompt>` (in conversation) → **heartbeat automation** | **required** — e.g. `4m`; **no interval ⇒ no timer created** | no — interval heartbeat (the task self-drive is goal-mode, not for graphkit nodes — see ¹) | pause/delete the automation, or have the prompt stop it on a terminal ledger status |
| **Cursor** | client "loop"/repeat feature | interval-driven | no — and it **kills a run past ~20 min**, so each round must finish under the cap | stop the loop in-client |
| **shell/cron** | `while …; do …; sleep <interval>; done` / crontab | interval-driven | no | `break` on a terminal ledger status / `CronDelete` |

**Adaptive vs interval** is the load-bearing distinction for the graphkit arm's
gate-park: on the adaptive host (Claude Code self-paced) re-invocation is automatic,
so a round never gets cut off and a parked executor resumes for free. On interval
hosts (Grok `/loop`, Cursor, **Codex** heartbeat, shell/cron) **both loops must be
scheduled** and the executor keeps cheap-ticking until release — a loop that writes a
terminal status and stops cannot restart itself. (A Codex graphkit node therefore
uses the interval heartbeat, never a goal — see ¹.)

A fresh-context interval host (Codex heartbeat, Grok, shell) also **re-reads the run
files every round** — executor + ledger + directives — a fixed per-round token tax.
Two levers keep it affordable: **bound the ledger** (the ledger/executor templates'
`KEEP_ROUNDS` rotation — keep the last few rounds hot, archive the rest to
`rounds-archive.md`; an unbounded Rounds log makes each round cost more than the last,
**O(n²)** over a run) and **size rounds coarser** (batch sibling items sharing one
verification, so real work exceeds the tax). On the adaptive `/loop` host context
persists between rounds, so this tax is near-zero.

## Goal primitive (a built-in executor+verifier — the goal arm rides this)

| Host | Command | Built-in verifier? |
|------|---------|--------------------|
| **Grok** | `/goal <objective> [--budget <tokens>]` · `status`/`pause`/`resume`/`clear` | **yes** — plans acceptance criteria, works across rounds, and only marks complete after an **independent adversarial verifier** reproduces the evidence (defaults to *refuted* if it can't); anti-ratchet so it converges instead of re-litigating |
| **Codex** | `/goal <objective>` or just send it as a task — self-drives (**quest only**) | **adaptive** — self-drives to done and auto-wakes each round; no separate clean-context refuter, so lean on the objective's acceptance criteria. **Do not use this to drive a graphkit node — it livelocks at a park state (see ¹); use the interval `/loop` heartbeat there.** |
| **Claude Code** | *(no standalone `/goal`)* — use the graphkit arm; its clean-context supervisor is the verifier | n/a |
| **Cursor** | *(none — Cursor only loops)* — use the graphkit arm | n/a |

In the **goal arm** (quest) on a native-goal host (Grok, or Codex-as-quest), the
host's own harness is the acceptance layer — don't bolt a second supervisor loop on
top; that's the redundancy the goal arm exists to avoid. A Codex **graphkit** run is
different: there is no goal there — both nodes are interval `/loop` heartbeats and the
supervisor loop is the verifier, exactly as on every loop host.

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
