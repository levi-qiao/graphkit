#!/usr/bin/env sh
# octopus-skill installer — clones the library once and installs it as a single
# `/octopus` skill (an umbrella that routes to the loop-graph or quest arm inside).
# Deliberately does NOT touch any existing `graphkit` install, so a running loop
# is never disturbed; invoke the new library as /octopus.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/levi-qiao/octopus-skill/main/install.sh | sh
# Claude Code users can instead install via the plugin marketplace:
#   /plugin marketplace add levi-qiao/octopus-skill  &&  /plugin install octopus@octopus-skill
set -eu

REPO="https://github.com/levi-qiao/octopus-skill.git"
CACHE="${OCTOPUS_CACHE:-$HOME/.local/share/octopus-skill}"
NAME="octopus"

# 1. Clone or update the library once. (If OCTOPUS_CACHE points at an existing
#    clone — e.g. your dev checkout — it's updated in place and linked live.)
if [ -d "$CACHE/.git" ]; then
  echo "Updating octopus-skill in $CACHE ..."
  git -C "$CACHE" pull --ff-only || echo "  (skipped pull — local changes present)"
else
  echo "Cloning octopus-skill -> $CACHE"
  mkdir -p "$(dirname "$CACHE")"
  git clone --depth 1 "$REPO" "$CACHE"
fi

# 2. Symlink the whole library into each host skills dir as `octopus`. One entry;
#    the root SKILL.md routes to skills/loop-graph or skills/quest, and every
#    ../../lib reference resolves because the whole repo sits under the link.
link_octopus() {
  skills_dir="$1"
  [ -d "$(dirname "$skills_dir")" ] || return 0   # host not installed — skip
  mkdir -p "$skills_dir"
  dest="$skills_dir/$NAME"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    bak="$dest.bak-$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$bak"
    echo "  backed up existing $NAME -> $bak"
  fi
  ln -sfn "$CACHE" "$dest"
  echo "  linked $NAME -> $dest"
}

echo "Installing /octopus (existing /graphkit installs are left untouched):"
link_octopus "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
link_octopus "${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"

echo ""
echo "✅ octopus-skill installed. In your host, run:  /octopus"
