#!/usr/bin/env bash
set -euo pipefail

export HOME="/home/azureuser"
export PATH="/home/azureuser/.local/bin:/home/azureuser/.openclaw/bin:/home/azureuser/.local/share/fnm/node-versions/v24.13.1/installation/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config/config.sh}"

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

resolve_path() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    printf '%s\n' "$p"
  else
    printf '%s/%s\n' "$REPO_ROOT" "$p"
  fi
}

[[ -f "$CONFIG_FILE" ]] || fail "Missing config file: $CONFIG_FILE. Run scripts/setup.sh first."
# shellcheck source=/dev/null
source "$CONFIG_FILE"

CHANNEL_TYPE="${CHANNEL_TYPE:-feishu}"
[[ "$CHANNEL_TYPE" == "feishu" ]] || fail "scripts/daily_summary.sh handles Feishu only; got CHANNEL_TYPE=$CHANNEL_TYPE"

PROJECT_TAG="${PROJECT_TAG:-default}"
CHAT_NAME="${CHAT_NAME:-Feishu chat}"
MEMORY_DIR="$(resolve_path "${MEMORY_DIR:-memory}")"
LOG_DIR="$(resolve_path "${LOG_DIR:-logs}")"
TIMEZONE="${TIMEZONE:-Asia/Shanghai}"
FEISHU_API_BASE="${FEISHU_API_BASE:-https://open.feishu.cn/open-apis}"
FEISHU_MESSAGE_LIMIT="${FEISHU_MESSAGE_LIMIT:-50}"
SEND_NOTIFICATION="${SEND_NOTIFICATION:-false}"

mkdir -p "$MEMORY_DIR" "$LOG_DIR"

DATE_STR="$(TZ="$TIMEZONE" date '+%Y-%m-%d')"
MEMORY_FILE="$MEMORY_DIR/$DATE_STR.md"
RAW_FILE="$(mktemp)"
SUMMARY_FILE="$(mktemp)"
RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$RAW_FILE" "$SUMMARY_FILE" "$RESPONSE_FILE"' EXIT

log "Step 1/6: validating Feishu configuration"
[[ -n "${FEISHU_CHAT_ID:-}" ]] || fail "FEISHU_CHAT_ID is required"

get_tenant_token() {
  if [[ -n "${FEISHU_TENANT_ACCESS_TOKEN:-}" ]]; then
    printf '%s\n' "$FEISHU_TENANT_ACCESS_TOKEN"
    return 0
  fi
  [[ -n "${FEISHU_APP_ID:-}" && -n "${FEISHU_APP_SECRET:-}" ]] || fail "Set FEISHU_TENANT_ACCESS_TOKEN or FEISHU_APP_ID/FEISHU_APP_SECRET"

  local token_response token
  token_response="$(curl -fsS -X POST "$FEISHU_API_BASE/auth/v3/tenant_access_token/internal" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "{\"app_id\":\"$FEISHU_APP_ID\",\"app_secret\":\"$FEISHU_APP_SECRET\"}")"
  token="$(printf '%s' "$token_response" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("tenant_access_token", ""))')"
  [[ -n "$token" ]] || fail "Unable to obtain Feishu tenant_access_token: $token_response"
  printf '%s\n' "$token"
}

log "Step 2/6: obtaining Feishu tenant token"
TENANT_TOKEN="$(get_tenant_token)"
log "Token obtained: length ${#TENANT_TOKEN}"

log "Step 3/6: fetching messages using chat_id container"
MESSAGE_URL="$FEISHU_API_BASE/im/v1/messages?container_id_type=chat&container_id=$FEISHU_CHAT_ID&page_size=$FEISHU_MESSAGE_LIMIT"
curl -fsS -G "$MESSAGE_URL" \
  -H "Authorization: Bearer $TENANT_TOKEN" \
  -H 'Content-Type: application/json; charset=utf-8' > "$RESPONSE_FILE"

python3 - "$RESPONSE_FILE" "$RAW_FILE" <<'PY'
import json, sys, hashlib
src, dst = sys.argv[1:3]
data = json.load(open(src, encoding='utf-8'))
items = data.get('data', {}).get('items', []) or []
lines = []
for idx, item in enumerate(items, start=1):
    sender = item.get('sender', {}).get('sender_id', {}).get('open_id') or item.get('sender', {}).get('id') or 'unknown'
    create_time = item.get('create_time') or item.get('update_time') or ''
    msg_type = item.get('msg_type') or item.get('message_type') or 'unknown'
    content = item.get('body', {}).get('content') or item.get('content') or ''
    try:
        parsed = json.loads(content)
        if isinstance(parsed, dict):
            content = parsed.get('text') or parsed.get('content') or json.dumps(parsed, ensure_ascii=False)
    except Exception:
        pass
    message_id = item.get('message_id') or f'MSG-{idx:03d}'
    safe = str(content).replace('\n', ' ').strip()
    lines.append(f'- [ID: {message_id}] [{create_time}] {sender} ({msg_type}): {safe}')
raw = '\n'.join(lines)
open(dst, 'w', encoding='utf-8').write(raw + ('\n' if raw else ''))
print(f'MESSAGE_COUNT={len(items)}')
print(f'MESSAGES_SHA256={hashlib.sha256(raw.encode()).hexdigest()}')
PY
MESSAGE_COUNT="$(wc -l < "$RAW_FILE" | tr -d ' ')"
log "Fetched message lines: $MESSAGE_COUNT"
log "Raw messages SHA256: $(sha256sum "$RAW_FILE" | awk '{print $1}')"

log "Step 4/6: summarizing or falling back"
SUMMARY_STATUS="OK"
if [[ ! -s "$RAW_FILE" ]]; then
  SUMMARY_STATUS="NO_MESSAGES"
  printf '[NO_MESSAGES] No Feishu messages were returned for this run.\n' > "$SUMMARY_FILE"
elif [[ -n "${LLM_COMMAND:-}" ]]; then
  if bash -lc "$LLM_COMMAND" < "$RAW_FILE" > "$SUMMARY_FILE"; then
    if [[ ! -s "$SUMMARY_FILE" ]]; then
      SUMMARY_STATUS="LLM_EMPTY"
      printf '[LLM_FAILED: fallback used] LLM returned an empty summary. Raw messages follow.\n\n' > "$SUMMARY_FILE"
      cat "$RAW_FILE" >> "$SUMMARY_FILE"
    fi
  else
    SUMMARY_STATUS="LLM_FAILED"
    printf '[LLM_FAILED: fallback used] LLM command failed. Raw messages follow.\n\n' > "$SUMMARY_FILE"
    cat "$RAW_FILE" >> "$SUMMARY_FILE"
  fi
else
  SUMMARY_STATUS="LLM_NOT_CONFIGURED"
  printf '[LLM_FAILED: fallback used] LLM_COMMAND is not configured. Raw messages follow.\n\n' > "$SUMMARY_FILE"
  cat "$RAW_FILE" >> "$SUMMARY_FILE"
fi
SUMMARY_LENGTH="$(wc -c < "$SUMMARY_FILE" | tr -d ' ')"
log "SUMMARY status: $SUMMARY_STATUS"
log "SUMMARY length: $SUMMARY_LENGTH"
log "SUMMARY SHA256: $(sha256sum "$SUMMARY_FILE" | awk '{print $1}')"

log "Step 5/6: writing daily memory file"
if [[ ! -f "$MEMORY_FILE" ]]; then
  printf '# %s daily memory\n\n' "$DATE_STR" > "$MEMORY_FILE"
fi
{
  printf '\n## [PROJECT: %s] %s\n\n' "$PROJECT_TAG" "$CHAT_NAME"
  cat "$SUMMARY_FILE"
  printf '\n'
} >> "$MEMORY_FILE"
MEMORY_LINES="$(wc -l < "$MEMORY_FILE" | tr -d ' ')"
[[ "$MEMORY_LINES" -gt 0 ]] || fail "Memory file is empty after write: $MEMORY_FILE"
log "Memory file: $MEMORY_FILE"
log "Memory lines: $MEMORY_LINES"

send_notification() {
  local text="$1"
  local payload
  payload="$(printf '%s' "$text" | json_escape)"
  curl -fsS -X POST "$FEISHU_API_BASE/im/v1/messages?receive_id_type=chat_id" \
    -H "Authorization: Bearer $TENANT_TOKEN" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "{\"receive_id\":\"$FEISHU_CHAT_ID\",\"msg_type\":\"text\",\"content\":{\"text\":$payload}}" >/dev/null
}

log "Step 6/6: optional Feishu notification"
if [[ "$SEND_NOTIFICATION" == "true" ]]; then
  send_notification "Daily memory updated: $DATE_STR, project=$PROJECT_TAG, summary_status=$SUMMARY_STATUS, length=$SUMMARY_LENGTH"
  log "Notification sent"
else
  log "Notification disabled"
fi

log "Daily Feishu memory summary complete"
