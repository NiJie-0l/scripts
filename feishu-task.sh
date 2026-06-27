#!/bin/bash
# feishu-task.sh — 飞书项目追踪 Base 快捷操作
set -euo pipefail
BASE_TOKEN="LBSHbAtDGalI4lsqi4Qcayrzn2C"
TABLE_ID="tblrFeMOIP8ikPbt"

case "${1:-list}" in
  list)
    echo "=== 任务列表 ==="
    lark-cli base +record-list --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --as user --format pretty 2>&1
    ;;
  add)
    [ $# -lt 2 ] && { echo "Usage: $0 add <任务名> [优先级] [截止日期]"; exit 1; }
    TASK="$2"
    PRI="${3:-P2-中}"
    DUE="${4:-}"
    JSON="{\"任务名称\":\"$TASK\",\"状态\":\"待办\",\"优先级\":\"$PRI\""
    [ -n "$DUE" ] && JSON="$JSON,\"截止日期\":\"$DUE\""
    JSON="$JSON}"
    lark-cli base +record-upsert --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --json "$JSON" --as user --format pretty 2>&1
    echo "✓ 已添加: $TASK"
    ;;
  done)
    [ $# -lt 2 ] && { echo "Usage: $0 done <关键词>"; exit 1; }
    RECORD=$(lark-cli base +record-search --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --filter "{\"conditions\":[{\"field_name\":\"任务名称\",\"operator\":\"contains\",\"value\":[\"$2\"]}]}" --as user --format json 2>&1)
    REC_ID=$(echo "$RECORD" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['data']['items'][0]['record_id'])" 2>/dev/null || echo "")
    [ -z "$REC_ID" ] && { echo "未找到: $2"; exit 1; }
    lark-cli base +record-upsert --base-token "$BASE_TOKEN" --table-id "$TABLE_ID" --record-id "$REC_ID" --json '{"状态":"已完成"}' --as user --format pretty 2>&1
    echo "✓ 已完成: $2"
    ;;
  *)
    echo "Usage: $0 [list|add|done]"
    echo "  list              列出所有任务"
    echo "  add <任务> [优先级] [截止日期]  添加任务"
    echo "  done <关键词>     标记完成"
    ;;
esac
