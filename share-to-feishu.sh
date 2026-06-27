#!/bin/bash
# share-to-feishu.sh — 一键共享文件/文档到飞书内部知识库
# 用法:
#   share-to-feishu.sh file <本地文件路径> [分类] [备注]
#   share-to-feishu.sh doc <标题>              # 创建新文档
#   share-to-feishu.sh list                    # 列出已共享文件
set -euo pipefail

WIKI_SPACE="7656194978053360597"
FILE_BASE="NiPlbVGSQa3Rkas20KXctF88nag"
FILE_TABLE="tblUg532XZjG1xBp"
PROJ_BASE="LBSHbAtDGalI4lsqi4Qcayrzn2C"
PROJ_TABLE="tblrFeMOIP8ikPbt"

case "${1:-help}" in

  file)
    [ $# -lt 2 ] && { echo "Usage: $0 file <文件路径> [分类] [备注]"; exit 1; }
    FILEPATH="$2"
    CATEGORY="${3:-其他}"
    NOTE="${4:-}"
    
    [ ! -f "$FILEPATH" ] && { echo "ERROR: 文件不存在: $FILEPATH"; exit 1; }
    
    FILENAME=$(basename "$FILEPATH")
    echo "=== 上传文件到飞书 ==="
    echo "  文件: $FILENAME"
    echo "  分类: $CATEGORY"
    
    # 上传到飞书云空间
    RESULT=$(lark-cli drive +upload "$FILEPATH" --as user --format json 2>&1) || {
      echo "ERROR: 上传失败"
      echo "$RESULT"
      exit 1
    }
    
    FILE_TOKEN=$(echo "$RESULT" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['data']['file']['token'])" 2>/dev/null || echo "")
    
    if [ -n "$FILE_TOKEN" ]; then
      echo "  ✓ 已上传, token: $FILE_TOKEN"
      # 记录到文件索引 Base
      lark-cli base +record-upsert \
        --base-token "$FILE_BASE" \
        --table-id "$FILE_TABLE" \
        --json "{\"文件名\":\"$FILENAME\",\"分类\":[\"$CATEGORY\"],\"上传人\":\"riynat\",\"备注\":\"$NOTE\"}" \
        --as user --format json >/dev/null 2>&1
      echo "  ✓ 已记录到文件索引"
    else
      echo "  WARN: 上传成功但无法解析 token"
    fi
    ;;

  doc)
    [ $# -lt 2 ] && { echo "Usage: $0 doc <标题>"; exit 1; }
    TITLE="$2"
    echo "=== 创建飞书文档 ==="
    echo "  标题: $TITLE"
    
    RESULT=$(lark-cli wiki +node-create \
      --space-id "$WIKI_SPACE" \
      --obj-type docx \
      --title "$TITLE" \
      --as user --format json 2>&1)
    
    URL=$(echo "$RESULT" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['data']['url'])" 2>/dev/null || echo "")
    
    if [ -n "$URL" ]; then
      echo "  ✓ 文档已创建: $URL"
      # 在项目追踪里加一条
      lark-cli base +record-upsert \
        --base-token "$PROJ_BASE" \
        --table-id "$PROJ_TABLE" \
        --json "{\"任务名称\":\"文档: $TITLE\",\"状态\":\"进行中\",\"优先级\":[\"P2-中\"],\"飞书链接\":{\"link\":\"$URL\",\"text\":\"打开文档\"}}" \
        --as user --format json >/dev/null 2>&1
      echo "  ✓ 已添加到项目追踪"
    else
      echo "  WARN: 创建可能失败"
      echo "$RESULT"
    fi
    ;;

  list)
    echo "=== 已共享文件 ==="
    lark-cli base +record-list \
      --base-token "$FILE_BASE" \
      --table-id "$FILE_TABLE" \
      --as user --format pretty 2>&1
    ;;

  add-member)
    [ $# -lt 3 ] && { echo "Usage: $0 add-member <姓名/邮箱> [reader|editor|admin]"; exit 1; }
    MEMBER="$2"
    ROLE="${3:-reader}"
    
    echo "=== 添加知识库成员 ==="
    echo "  成员: $MEMBER"
    echo "  权限: $ROLE"
    
    # 先搜索用户 open_id
    OPEN_ID=$(lark-cli contact +search-user --query "$MEMBER" --format json 2>&1 | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['data']['items'][0]['open_id'])" 2>/dev/null || echo "")
    
    if [ -z "$OPEN_ID" ]; then
      echo "ERROR: 未找到用户: $MEMBER"
      exit 1
    fi
    
    # 角色映射
    case "$ROLE" in
      reader) MEMBER_ROLE="reader" ;;
      editor) MEMBER_ROLE="editor" ;;
      admin)  MEMBER_ROLE="admin" ;;
      *)      MEMBER_ROLE="reader" ;;
    esac
    
    lark-cli wiki +member-add \
      --space-id "$WIKI_SPACE" \
      --member-id "$OPEN_ID" \
      --member-type openid \
      --member-role "$MEMBER_ROLE" \
      --as user --format json 2>&1
    
    echo "  ✓ 已添加"
    ;;

  help|*)
    echo "飞书内部共享工具"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  file <文件路径> [分类] [备注]   上传文件到飞书+记录索引"
    echo "  doc <标题>                      创建共享文档"
    echo "  list                            列出已共享文件"
    echo "  add-member <姓名> [权限]        添加知识库成员"
    echo ""
    echo "权限: reader(只读) editor(可编辑) admin(管理)"
    ;;
esac

# ─── 大文件走 COS ───
cos-upload)
    [ $# -lt 2 ] && { echo "Usage: $0 cos-upload <文件路径> [备注]"; exit 1; }
    FILEPATH="$2"
    NOTE="${3:-}"
    [ ! -f "$FILEPATH" ] && { echo "ERROR: 文件不存在: $FILEPATH"; exit 1; }
    
    FILENAME=$(basename "$FILEPATH")
    SIZE=$(du -sh "$FILEPATH" | cut -f1)
    
    echo "=== 大文件上传到 COS ==="
    echo "  文件: $FILENAME ($SIZE)"
    
    URL=$(python3 "$(dirname "$0")/cos-share.py" upload "$FILEPATH" 2>&1 | grep "下载链接:" | sed 's/.*下载链接: //')
    
    if [ -n "$URL" ]; then
      echo "  ✓ 已上传到 COS"
      echo "  链接: $URL"
      # 记录到飞书文件索引
      lark-cli base +record-upsert \
        --base-token "$FILE_BASE" \
        --table-id "$FILE_TABLE" \
        --json "{\"文件名\":\"$FILENAME\",\"分类\":[\"文档\"],\"上传人\":\"riynat\",\"备注\":\"COS: $URL $NOTE\"}" \
        --as user --format json >/dev/null 2>&1
      echo "  ✓ 已记录到飞书文件索引"
    else
      echo "  ERROR: 上传失败"
    fi
    ;;
