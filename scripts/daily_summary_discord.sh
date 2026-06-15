#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-$(eval echo ~$(whoami))}"
export PATH="${HOME}/.local/bin:${HOME}/.openclaw/bin:${HOME}/.local/share/fnm/node-versions/v24.13.1/installation/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config/config.sh}"
LOG_DIR_FALLBACK="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR_FALLBACK"
LOG_FILE="${LOG_FILE:-$LOG_DIR_FALLBACK/daily_summary_discord.log}"

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

resolve_path() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    printf '%s\n' "$p"
  else
    printf '%s/%s\n' "$REPO_ROOT" "$p"
  fi
}

ENV_DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-}"
[[ -f "$CONFIG_FILE" ]] || fail "Missing config file: $CONFIG_FILE. Run scripts/setup.sh first."
# shellcheck source=/dev/null
source "$CONFIG_FILE"

CHANNEL_TYPE="${CHANNEL_TYPE:-feishu}"
[[ "$CHANNEL_TYPE" == "discord" ]] || fail "scripts/daily_summary_discord.sh handles Discord only; got CHANNEL_TYPE=$CHANNEL_TYPE"

PROJECT_TAG="${PROJECT_TAG:-default}"
CHAT_NAME="${CHAT_NAME:-Discord chat}"
MEMORY_DIR="$(resolve_path "${MEMORY_DIR:-memory}")"
LOG_DIR="$(resolve_path "${LOG_DIR:-logs}")"
TIMEZONE="${TIMEZONE:-Asia/Shanghai}"
DISCORD_API_BASE="${DISCORD_API_BASE:-https://discord.com/api/v10}"
DISCORD_MESSAGE_LIMIT="${DISCORD_MESSAGE_LIMIT:-100}"
AGENT_ID="${AGENT_ID:-${PROJECT_TAG}}"

mkdir -p "$MEMORY_DIR" "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/daily_summary_discord.log}"

DATE_STR="$(TZ="$TIMEZONE" date '+%Y-%m-%d')"
START_TS="$(TZ="$TIMEZONE" date -d "$DATE_STR 00:00:00" '+%Y-%m-%dT%H:%M:%S%z')"
MEMORY_FILE="$MEMORY_DIR/$DATE_STR.md"
RAW_FILE="$(mktemp)"
SUMMARY_FILE="$(mktemp)"
PROMPT_FILE="$(mktemp)"
PAGE_FILE="$(mktemp)"
ALL_FILE="$(mktemp)"
trap 'rm -f "$RAW_FILE" "$SUMMARY_FILE" "$PROMPT_FILE" "$PAGE_FILE" "$ALL_FILE"' EXIT

log "Step 1/5: validating Discord configuration"
[[ -n "${DISCORD_CHANNEL_ID:-}" ]] || fail "DISCORD_CHANNEL_ID is required"
DISCORD_BOT_TOKEN="${ENV_DISCORD_BOT_TOKEN:-${DISCORD_BOT_TOKEN:-${DISCORD_TOKEN:-}}}"
[[ -n "$DISCORD_BOT_TOKEN" ]] || fail "DISCORD_BOT_TOKEN environment variable is required"

log "Step 2/5: fetching Discord messages since Beijing midnight"
: > "$ALL_FILE"
BEFORE=""
PAGE=0
while :; do
  PAGE=$((PAGE + 1))
  URL="$DISCORD_API_BASE/channels/${DISCORD_CHANNEL_ID}/messages?limit=${DISCORD_MESSAGE_LIMIT:-100}"
  if [[ -n "$BEFORE" ]]; then
    URL="$URL&before=$BEFORE"
  fi

  curl -fsS "$URL" \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H 'Content-Type: application/json' > "$PAGE_FILE" 2>> "$LOG_FILE"

  PAGE_COUNT="$(python3 - "$PAGE_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
print(len(data) if isinstance(data, list) else 0)
PY
)"
  log "Fetched Discord page $PAGE: $PAGE_COUNT messages"
  [[ "$PAGE_COUNT" -gt 0 ]] || break

  cat "$PAGE_FILE" >> "$ALL_FILE"
  printf '\n' >> "$ALL_FILE"

  BEFORE="$(python3 - "$PAGE_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
if isinstance(data, list) and data:
    print(data[-1].get('id', ''))
PY
)"

  OLDEST_TS="$(python3 - "$PAGE_FILE" <<'PY'
import json, sys
from datetime import datetime
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
if isinstance(data, list) and data:
    print(data[-1].get('timestamp', ''))
PY
)"

  if python3 - "$OLDEST_TS" "$START_TS" <<'PY'
import sys
from datetime import datetime
oldest, start = sys.argv[1:3]
if not oldest:
    sys.exit(1)
oldest_dt = datetime.fromisoformat(oldest.replace('Z', '+00:00'))
start_dt = datetime.fromisoformat(start)
sys.exit(0 if oldest_dt < start_dt else 1)
PY
  then
    log "Reached messages older than Beijing midnight; stopping pagination"
    break
  fi

  [[ -n "$BEFORE" ]] || break
done

python3 - "$ALL_FILE" "$RAW_FILE" "$START_TS" <<'PY'
import json, sys
from datetime import datetime
src, dst, start_s = sys.argv[1:4]
start = datetime.fromisoformat(start_s)
messages = []
for line in open(src, encoding='utf-8'):
    line = line.strip()
    if not line:
        continue
    data = json.loads(line)
    if isinstance(data, list):
        messages.extend(data)

rows = []
seen = set()
for m in messages:
    mid = m.get('id')
    if mid in seen:
        continue
    seen.add(mid)
    author = m.get('author') or {}
    if author.get('bot') is True:
        continue
    ts_s = m.get('timestamp') or ''
    if not ts_s:
        continue
    ts = datetime.fromisoformat(ts_s.replace('Z', '+00:00'))
    if ts < start:
        continue
    username = author.get('global_name') or author.get('username') or 'unknown'
    text = (m.get('content') or '').replace('\n', ' ').strip()
    if not text and m.get('attachments'):
        text = '[attachment] ' + ' '.join(a.get('url','') for a in m.get('attachments', []))
    hhmm = ts.astimezone(start.tzinfo).strftime('%H:%M')
    rows.append((ts, f'[{hhmm}] {username}: {text}'))

rows.sort(key=lambda x: x[0])
with open(dst, 'w', encoding='utf-8') as f:
    for _, line in rows:
        f.write(line + '\n')
print(len(rows))
PY
MESSAGE_COUNT="$(wc -l < "$RAW_FILE" | tr -d ' ')"
log "Discord messages kept after bot/date filters: $MESSAGE_COUNT"

log "Step 3/5: building LLM prompt and summarizing"
cat > "$PROMPT_FILE" <<EOF_PROMPT
请只基于下面的 Discord 群聊原始消息生成当天记忆，不要编造不存在的信息。

输出格式必须是 Markdown：
# $DATE_STR 群组日志

## [PROJECT: $PROJECT_TAG] $CHAT_NAME
- [MSG-001 HH:MM] 重要讨论...

## 今日要点
- ...

## 进展与决策
- ...

## 待办 / 未解决
- ...

## 其他备注
- ...

要求：
- 保留重要消息的 MSG-ID 引用。
- 没有证据的内容不要写。
- 如果消息很少，可以简短总结。

原始消息：
$(cat "$RAW_FILE")
EOF_PROMPT

SUMMARY_STATUS="OK"
if [[ ! -s "$RAW_FILE" ]]; then
  SUMMARY_STATUS="NO_MESSAGES"
  printf '# %s 群组日志\n\n## [PROJECT: %s] %s\n- [NO_MESSAGES] No Discord messages after filtering.\n\n## 今日要点\n- 无可汇总消息。\n\n## 进展与决策\n- 无。\n\n## 待办 / 未解决\n- 无。\n\n## 其他备注\n- 消息数为 0。\n' "$DATE_STR" "$PROJECT_TAG" "$CHAT_NAME" > "$SUMMARY_FILE"
elif openclaw agent --agent "$AGENT_ID" --message "$(cat "$PROMPT_FILE")" --timeout 60 > "$SUMMARY_FILE" 2>> "$LOG_FILE"; then
  if [[ ! -s "$SUMMARY_FILE" ]]; then
    SUMMARY_STATUS="LLM_EMPTY"
    printf '# %s 群组日志\n\n## [PROJECT: %s] %s\n[LLM_FAILED: fallback used] LLM returned an empty summary. Raw messages follow.\n\n' "$DATE_STR" "$PROJECT_TAG" "$CHAT_NAME" > "$SUMMARY_FILE"
    cat "$RAW_FILE" >> "$SUMMARY_FILE"
  fi
else
  SUMMARY_STATUS="LLM_FAILED"
  printf '# %s 群组日志\n\n## [PROJECT: %s] %s\n[LLM_FAILED: fallback used] LLM command failed. Raw messages follow.\n\n' "$DATE_STR" "$PROJECT_TAG" "$CHAT_NAME" > "$SUMMARY_FILE"
  cat "$RAW_FILE" >> "$SUMMARY_FILE"
fi
SUMMARY_LENGTH="$(wc -c < "$SUMMARY_FILE" | tr -d ' ')"
log "SUMMARY status: $SUMMARY_STATUS"
log "SUMMARY length: $SUMMARY_LENGTH"

log "Step 4/5: writing daily memory file"
cp "$SUMMARY_FILE" "$MEMORY_FILE"
LINE_COUNT="$(wc -l < "$MEMORY_FILE" | tr -d ' ')"
log "Memory file written: $MEMORY_FILE ($LINE_COUNT lines)"
if [[ "$LINE_COUNT" -lt 3 ]]; then
  log "WARNING: memory file suspiciously short ($LINE_COUNT lines)"
fi

log "Step 5/5: complete"
log "Daily Discord memory summary complete"
