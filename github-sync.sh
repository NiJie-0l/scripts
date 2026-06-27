#!/bin/bash
# github-sync.sh — 批量 push/pull workspace 所有仓库
set -euo pipefail
WS_DIR="$HOME/Desktop/workspace"
ACTION="${1:-status}"  # push | pull | status

echo "=== GitHub Sync: $ACTION ==="
find "$WS_DIR" -name ".git" -type d -maxdepth 4 | sort | while read gitdir; do
  repo=$(dirname "$gitdir")
  name=$(basename "$repo")
  cd "$repo"
  
  upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)
  [ -z "$upstream" ] && { echo "  skip (no remote): $name"; continue; }
  
  case "$ACTION" in
    push)
      git push 2>&1 | sed "s/^/  /" && echo "  ✓ pushed: $name" || echo "  ✗ failed: $name"
      ;;
    pull)
      git pull --rebase 2>&1 | sed "s/^/  /" && echo "  ✓ pulled: $name" || echo "  ✗ failed: $name"
      ;;
    status)
      ahead=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "0")
      behind=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo "0")
      dirty=""
      git diff --quiet 2>/dev/null || dirty=" (dirty)"
      echo "  $name: ahead=$ahead behind=$behind$dirty"
      ;;
  esac
done
