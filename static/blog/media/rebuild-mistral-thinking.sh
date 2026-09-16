#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
mkdir -p "$ROOT/tmp"

OUT=blog/media/mistral-thinking.gif DIR="$ROOT" TMPDIR="$ROOT/tmp" \
  READY_RE='tkn:' INPUT='run pi model list mistral and show me the results in a table' \
  WAIT_RE='took [0-9]+[.][0-9]+s' WAIT_TIMEOUT=300s \
  WIDTH=1449 HEIGHT=900 FONT_SIZE=14 FRAMERATE=24 PLAYBACK_SPEED=1 \
  SHRINK=0 KEEP_TAPE=1 \
  MARGIN=20 MARGIN_FILL='#674EFF' BORDER_RADIUS=10 WINDOW_BAR=Colorful \
  .pi-go/skills/vhs-e2e-gif/scripts/record-gif.sh \
  "pi --model mistral/zai-glm-5-2"
