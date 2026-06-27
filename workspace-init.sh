#!/bin/bash
# workspace-init.sh — 在 workspace 里快速创建新项目
set -euo pipefail

WS_DIR="$HOME/Desktop/workspace"
GITHUB_USER="NiJie-0l"

usage() {
  echo "Usage: $0 <project-name> <visibility> [template]"
  echo "  visibility: public | private"
  echo "  template:   python | node | minimal (default: minimal)"
  echo ""
  echo "Examples:"
  echo "  $0 my-api public python"
  echo "  $0 internal-tool private"
  exit 1
}

[ $# -lt 2 ] && usage

NAME="$1"
VISIBILITY="$2"
TEMPLATE="${3:-minimal}"
CATEGORY="$VISIBILITY"
TARGET_DIR="$WS_DIR/projects/$CATEGORY/$NAME"

if [ -d "$TARGET_DIR" ]; then
  echo "ERROR: $TARGET_DIR already exists"
  exit 1
fi

echo "=== Creating project: $NAME ($VISIBILITY, template: $TEMPLATE) ==="

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"
git init -b main

# 模板内容
case "$TEMPLATE" in
  python)
    mkdir -p src tests .github/workflows
    cat > pyproject.toml << PYEOF
[project]
name = "$NAME"
version = "0.1.0"
requires-python = ">=3.10"

[project.optional-dependencies]
dev = ["pytest", "pytest-cov", "ruff"]

[tool.ruff]
line-length = 120

[tool.pytest.ini_options]
testpaths = ["tests"]
PYEOF
    cat > tests/test_placeholder.py << 'TPEOF'
def test_placeholder():
    assert True
TPEOF
    cat > .github/workflows/ci.yml << CIEOF
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -e ".[dev]"
      - run: pytest --cov
      - run: ruff check .
CIEOF
    ;;
  node)
    mkdir -p src .github/workflows
    cat > package.json << NJEOF
{
  "name": "$NAME",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "start": "node src/index.js",
    "test": "node --test"
  },
  "license": "MIT"
}
NJEOF
    ;;
esac

# 通用文件
cat > README.md << RDEOF
# $NAME

<!-- Add description here -->

## Setup

\`\`\`bash
# Add setup instructions
\`\`\`

## License

MIT
RDEOF

cat > LICENSE << LIEOF
MIT License

Copyright (c) 2026 $GITHUB_USER

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LIEOF

# Commit
git add -A
git commit -m "init: $NAME"

# Create GitHub repo and push
FLAG="--private"
[ "$VISIBILITY" = "public" ] && FLAG="--public"

gh repo create "$NAME" $FLAG --source=. --push --description "$NAME" 2>&1 || {
  echo "WARNING: GitHub repo creation failed. Local repo is ready at $TARGET_DIR"
  echo "You can create the repo later with: gh repo create $NAME $FLAG --source=. --push"
}

# 更新索引
echo ""
echo "=== Project created ==="
echo "  Local:  $TARGET_DIR"
echo "  GitHub: $GITHUB_USER/$NAME"
echo "  Visibility: $VISIBILITY"
echo ""
echo "Don't forget to update .meta/index.json!"
