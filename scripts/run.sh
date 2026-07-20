#!/usr/bin/env bash
# graphkit runner — drives a node loop through a coding-agent CLI.
#
# Each round (executor) or tick (supervisor) is ONE fresh headless CLI invocation,
# so the graph's clean-context invariant holds in delegated mode: no session ever
# spans two rounds, and the two nodes never share a context.
#
# Usage (run from the workspace root — generated prompts use workspace-relative paths):
#   scripts/run.sh executor   <run-dir> --cli <name> [--model M] [--rounds N]              [--dry-run] [-- extra CLI args]
#   scripts/run.sh supervisor <run-dir> --cli <name> [--model M] [--ticks N] [--interval D] [--dry-run] [-- extra CLI args]
#   scripts/run.sh stop       <run-dir>
#
# CLIs: claude | codex | grok | agy | cursor   (all invoked full-auto & headless; see invoke())
# Defaults: --rounds 10, --ticks 12, --interval 30m (interval accepts 45s / 30m / 2h / plain seconds)
#
# Control surface (the closed loop):
#   - budget:    the loop never exceeds --rounds / --ticks
#   - stop file: `scripts/run.sh stop <run-dir>` (touches <run-dir>/STOP; both loops exit before next invocation)
#   - sentinel:  a node ending its output with "GRAPHKIT_STOP: <reason>" ends its loop
#   - breaker:   2 consecutive CLI failures abort the loop
#   - logs:      <run-dir>/logs/<node>-<n>.log (full output of every invocation)

set -u

die() { echo "run.sh: $*" >&2; exit 1; }

NODE=${1:-}; RUN_DIR=${2:-}
[ -n "$NODE" ] && [ -n "$RUN_DIR" ] || die "usage: run.sh executor|supervisor|stop <run-dir> [options]"
shift 2

if [ "$NODE" = "stop" ]; then
  touch "$RUN_DIR/STOP" && echo "STOP set — loops on $RUN_DIR exit before their next invocation."
  exit 0
fi
case "$NODE" in executor|supervisor) ;; *) die "unknown node '$NODE' (executor|supervisor|stop)";; esac

CLI="" MODEL="" ROUNDS=10 TICKS=12 INTERVAL=1800 DRY_RUN=0
EXTRA=()
while [ $# -gt 0 ]; do
  case "$1" in
    --cli)      CLI=${2:?}; shift 2;;
    --model)    MODEL=${2:?}; shift 2;;
    --rounds)   ROUNDS=${2:?}; shift 2;;
    --ticks)    TICKS=${2:?}; shift 2;;
    --interval) v=${2:?}; shift 2
                case "$v" in
                  *h) INTERVAL=$(( ${v%h} * 3600 ));;
                  *m) INTERVAL=$(( ${v%m} * 60 ));;
                  *s) INTERVAL=${v%s};;
                  *)  INTERVAL=$v;;
                esac;;
    --dry-run)  DRY_RUN=1; shift;;
    --)         shift; EXTRA=("$@"); break;;
    *)          die "unknown option '$1'";;
  esac
done

PROMPT_FILE="$RUN_DIR/$NODE.md"
[ -f "$PROMPT_FILE" ] || die "$PROMPT_FILE not found — is $RUN_DIR a graphkit run directory (with a generated $NODE.md)?"
command -v "${CLI:-}" >/dev/null 2>&1 || [ "$CLI" = "cursor" ] || die "--cli is required and must be an installed CLI (claude|codex|grok|agy|cursor); got '${CLI:-}'"

# One fresh invocation per round/tick; the wrapper line makes the node end after one
# unit of work and declare loop-ending conditions machine-readably.
if [ "$NODE" = executor ]; then
  WRAP="[graphkit runner] Headless delegated mode: you get a fresh context each round. Execute exactly ONE round of the cadence below, update the ledger, then end your reply. If a stop condition triggers (milestone sign-off, all-blocked, stall, red line), make the LAST line of your reply exactly: GRAPHKIT_STOP: <reason>"
else
  WRAP="[graphkit runner] Headless delegated mode: this invocation is ONE supervisor tick. If the run must halt (stall verdict, red-line violation, milestone sign-off needed), make the LAST line of your reply exactly: GRAPHKIT_STOP: <reason>"
fi
PROMPT="$WRAP

$(cat "$PROMPT_FILE")"

# invoke <logfile> — one headless, full-auto CLI call; prompt via stdin where supported.
invoke() {
  log=$1
  case "$CLI" in
    claude) cmd=(claude -p --dangerously-skip-permissions);            [ -n "$MODEL" ] && cmd+=(--model "$MODEL");;
    codex)  cmd=(codex exec --dangerously-bypass-approvals-and-sandbox); [ -n "$MODEL" ] && cmd+=(-m "$MODEL");;
    grok)   cmd=(grok --permission-mode bypassPermissions);            [ -n "$MODEL" ] && cmd+=(-m "$MODEL");;
    agy)    cmd=(agy --dangerously-skip-permissions --print-timeout 60m); [ -n "$MODEL" ] && cmd+=(--model "$MODEL");;
    cursor) cmd=(cursor-agent --force);                                [ -n "$MODEL" ] && cmd+=(--model "$MODEL");;
    *)      die "unknown --cli '$CLI' (claude|codex|grok|agy|cursor)";;
  esac
  cmd+=("${EXTRA[@]+"${EXTRA[@]}"}")
  case "$CLI" in
    claude) cmd+=();          stdin=1;;   # claude -p reads the prompt from stdin
    codex)  cmd+=(-);         stdin=1;;   # codex exec - reads it from stdin
    grok)   cmd+=(-p "$PROMPT"); stdin=0;;
    agy)    cmd+=(-p "$PROMPT"); stdin=0;;
    cursor) cmd+=(-p "$PROMPT"); stdin=0;;
  esac
  if [ "$DRY_RUN" = 1 ]; then
    shown=(); for a in "${cmd[@]}"; do [ "$a" = "$PROMPT" ] && a="<prompt: $(printf '%s' "$PROMPT" | wc -c | tr -d ' ') bytes from $PROMPT_FILE>"; shown+=("$a"); done
    echo "dry-run [$NODE/$CLI]: ${shown[*]}$( [ $stdin = 1 ] && echo '  << prompt on stdin' )"
    return 0
  fi
  if [ $stdin = 1 ]; then printf '%s' "$PROMPT" | "${cmd[@]}" >"$log" 2>&1
  else "${cmd[@]}" >"$log" 2>&1
  fi
}

[ "$DRY_RUN" = 1 ] && { invoke /dev/null; exit 0; }

mkdir -p "$RUN_DIR/logs"
[ "$NODE" = executor ] && BUDGET=$ROUNDS || BUDGET=$TICKS
FAILS=0 N=0
while [ "$N" -lt "$BUDGET" ]; do
  [ -e "$RUN_DIR/STOP" ] && { echo "[$NODE] STOP file present — exiting."; exit 0; }
  N=$((N + 1))
  LOG="$RUN_DIR/logs/$NODE-$N-$(date +%Y%m%d-%H%M%S).log"
  echo "[$NODE] $N/$BUDGET via $CLI${MODEL:+ ($MODEL)} → $LOG"
  if invoke "$LOG"; then
    FAILS=0
    if tail -n 3 "$LOG" | grep -q '^ *GRAPHKIT_STOP:'; then
      echo "[$NODE] node signalled stop: $(grep -o 'GRAPHKIT_STOP:.*' "$LOG" | tail -1)"
      exit 0
    fi
  else
    FAILS=$((FAILS + 1))
    echo "[$NODE] $CLI exited nonzero (fail $FAILS/2) — see $LOG" >&2
    [ "$FAILS" -ge 2 ] && die "$NODE loop aborted after 2 consecutive CLI failures"
  fi
  [ "$NODE" = supervisor ] && [ "$N" -lt "$BUDGET" ] && sleep "$INTERVAL"
done
echo "[$NODE] budget of $BUDGET reached — exiting. Re-run to continue."
