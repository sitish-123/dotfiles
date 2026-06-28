#!/usr/bin/env bash
# Capture local config changes into the repo and push to GitHub.
# Usage: ./sync.sh ["commit message"]
source "$(dirname "$0")/lib/common.sh"

# 1) Capture live configs into the repo. If a config is already symlinked into
#    the repo (post-install), it IS the repo — skip the copy.
info "Capturing live configs"
for d in "${MANAGED_CONFIGS[@]}"; do
    src="$CONFIG_HOME/$d"
    [ -e "$src" ] || continue
    if [ -L "$src" ] && [ "$(readlink -f "$src")" = "$DOT_ROOT/config/$d" ]; then
        continue
    fi
    rsync -a --delete --exclude '.git' --exclude '*.log' --exclude '__pycache__' \
        "$src/" "$DOT_ROOT/config/$d/"
done

# 2) Push the hyprtasking fork submodule if it has new commits.
FORK="$DOT_ROOT/pkgs/hyprtasking"
if git -C "$FORK" rev-parse 2>/dev/null >/dev/null; then
    if [ -n "$(git -C "$FORK" status --porcelain)" ]; then
        info "Committing + pushing hyprtasking fork"
        git -C "$FORK" add -A
        git -C "$FORK" commit -m "${1:-sync}" 2>/dev/null || true
    fi
    git -C "$FORK" push 2>/dev/null || warn "fork push skipped (nothing to push?)"
fi

# 3) Commit + push the dotfiles repo (captures config edits + submodule pointer).
cd "$DOT_ROOT"
git add -A
if git diff --cached --quiet; then
    ok "nothing to sync"
    exit 0
fi
git commit -m "${1:-sync $(date +'%Y-%m-%d %H:%M')}"
git push && ok "synced to GitHub" || warn "push failed"
