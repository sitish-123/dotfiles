#!/usr/bin/env bash
# Open a "path:line:col" token (as printed by Claude Code, grep, dart analyze,
# stack traces, ...) in VS Code at the right line.
#
# Invoked by a kitty mouse_map that first selects the whitespace-delimited
# token under the cursor and passes it as $1 via kitty's @selection
# placeholder. kitty launches us with --cwd=current, so $PWD is the cwd of the
# shell in the clicked window, which is what relative paths are relative to.

set -u

ref=${1-}
[ -z "$ref" ] && exit 0
[ "$ref" = "@selection" ] && exit 0   # nothing was selected

# Trim wrapping punctuation that comes from prose and markdown: backticks,
# quotes and brackets around the ref, and trailing sentence punctuation.
# Done with bash string ops rather than sed -- a bracket expression holding
# both `]` and quotes is a quoting minefield (a stray `\]` closes the class
# early and silently matches the wrong thing).
lead='`'\''"([{<'
trail='`'\''"),.:;]}>'
while [ -n "$ref" ] && [[ $lead == *"${ref:0:1}"* ]]; do ref=${ref:1}; done
while [ -n "$ref" ] && [[ $trail == *"${ref: -1}"* ]]; do ref=${ref%?}; done
[ -z "$ref" ] && exit 0

# Split off :line and :col if present.
line=""; col=""; path=$ref
if [[ $ref =~ ^(.+):([0-9]+):([0-9]+)$ ]]; then
  path=${BASH_REMATCH[1]}; line=${BASH_REMATCH[2]}; col=${BASH_REMATCH[3]}
elif [[ $ref =~ ^(.+):([0-9]+)$ ]]; then
  path=${BASH_REMATCH[1]}; line=${BASH_REMATCH[2]}
fi

# file:// URI -> plain path
[[ $path == file://* ]] && path=${path#file://}

# Expand a leading ~
[[ $path == "~"* ]] && path="$HOME${path#\~}"

resolve() {
  # $1 candidate; echo it if it exists
  [ -e "$1" ] && printf '%s' "$1" && return 0
  return 1
}

target=""
if [[ $path == /* ]]; then
  target=$(resolve "$path") || true
else
  # relative to the clicked window's cwd, then to the git worktree root
  target=$(resolve "$PWD/$path") || {
    root=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || root=""
    [ -n "$root" ] && target=$(resolve "$root/$path") || true
  }
fi

if [ -z "$target" ]; then
  # Not a path we can find. If it looks like a URL, hand it to the browser;
  # otherwise stay silent rather than popping an error over the terminal.
  [[ $ref == *://* ]] && exec xdg-open "$ref"
  exit 0
fi

if [ -n "$line" ]; then
  goto=$target:$line
  [ -n "$col" ] && goto=$goto:$col
  exec code --goto "$goto"
fi
exec code "$target"
