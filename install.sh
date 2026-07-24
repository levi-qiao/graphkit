#!/usr/bin/env sh
# octopus-skill installer — clones the library once and symlinks it as a single
# `/octopus` skill into the hosts whose loader FOLLOWS symlinks: Codex and Cursor.
# Claude Code does NOT load symlinked skill dirs — install it there as a plugin:
#   /plugin marketplace add levi-qiao/octopus-skill  &&  /plugin install octopus@octopus-skill
# Existing `/graphkit` installs are left untouched. Usage:
#   curl -fsSL https://raw.githubusercontent.com/levi-qiao/octopus-skill/main/install.sh | sh
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

# 2. Symlink the whole library into each symlink-following host's skills dir as
#    `octopus` (Codex, Cursor — NOT Claude Code, which ignores symlinked skills).
#    One entry; the root SKILL.md routes to skills/loop-graph or skills/quest, and
#    every ../../lib reference resolves because the whole repo sits under the link.
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

echo "Linking /octopus into symlink-following hosts (Codex, Cursor):"
link_octopus "${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
link_octopus "${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}"

echo ""
echo "✅ Linked for Codex / Cursor — run:  /octopus"
echo "ℹ️  Claude Code does not load symlinked skills; install it there as a plugin:"
echo "     /plugin marketplace add levi-qiao/octopus-skill"
echo "     /plugin install octopus@octopus-skill"
