#!/bin/bash
# repo-status.sh — 检查 workspace 所有仓库状态
set -euo pipefail

WS_DIR="$HOME/Desktop/workspace"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Workspace Repo Status ==="
echo ""

find "$WS_DIR" -name ".git" -type d -maxdepth 4 | sort | while read gitdir; do
  repo=$(dirname "$gitdir")
  reponame=$(basename "$repo")
  
  cd "$repo"
  
  # 分支
  branch=$(git branch --show-current 2>/dev/null || echo "?")
  
  # 未提交变更
  dirty=""
  git diff --quiet 2>/dev/null || dirty="${YELLOW}dirty${NC}"
  git diff --cached --quiet 2>/dev/null || dirty="${RED}staged${NC}"
  [ -z "$dirty" ] && dirty="${GREEN}clean${NC}"
  
  # 未推送 commits
  ahead=""
  upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)
  if [ -n "$upstream" ]; then
    n=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "0")
    [ "$n" != "0" ] && ahead=" (+$n unpushed)"
  else
    ahead=" (no remote)"
  fi
  
  # 最后 commit
  last=$(git log -1 --format="%cr" 2>/dev/null || echo "?")
  
  echo "  $reponame"
  echo "    branch: $branch | status: $dirty$ahead | last: $last"
done

echo ""
echo "=== GitHub Rate Limit ==="
gh api rate_limit 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
c=d['rate']
print(f\"  {c['remaining']}/{c['limit']} remaining (resets at {c['reset']})\")" 2>/dev/null || echo "  (not authenticated)"
