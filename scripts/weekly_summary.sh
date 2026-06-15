#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-$(eval echo ~$(whoami))}"
export PATH="${HOME}/.local/bin:${HOME}/.openclaw/bin:${HOME}/.local/share/fnm/node-versions/v24.13.1/installation/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config/config.sh}"

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" | tee -a "${LOG_FILE:-/dev/stderr}"
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

[[ -f "$CONFIG_FILE" ]] || fail "Missing config file: $CONFIG_FILE. Run scripts/setup.sh first."
# shellcheck source=/dev/null
source "$CONFIG_FILE"

PROJECT_TAG="${PROJECT_TAG:-default}"
CHAT_NAME="${CHAT_NAME:-Group Chat}"
MEMORY_DIR="$(resolve_path "${MEMORY_DIR:-memory}")"
LOG_DIR="$(resolve_path "${LOG_DIR:-logs}")"
LOG_FILE="${LOG_FILE:-$LOG_DIR/weekly-summary.log}"
TIMEZONE="${TIMEZONE:-Asia/Shanghai}"
AGENT_ID="${AGENT_ID:-${PROJECT_TAG}}"

mkdir -p "$MEMORY_DIR" "$LOG_DIR"

ISO_WEEK="$(TZ="$TIMEZONE" python3 - <<'PY'
from datetime import datetime
print(f'{datetime.now().isocalendar()[1]:02d}')
PY
)"
OUTPUT_FILE="$MEMORY_DIR/week-${ISO_WEEK}-memory.md"
RAW_FILE="$(mktemp)"
SUMMARY_FILE="$(mktemp)"
PROMPT_FILE="$(mktemp)"
trap 'rm -f "$RAW_FILE" "$SUMMARY_FILE" "$PROMPT_FILE"' EXIT

log "Step 1/4: collecting existing daily memory files for past 7 days"
: > "$RAW_FILE"
FOUND_DATES=()
SKIPPED_DATES=()
for offset in 6 5 4 3 2 1 0; do
  DAY="$(TZ="$TIMEZONE" date -d "${offset} days ago" '+%Y-%m-%d')"
  FILE="$MEMORY_DIR/$DAY.md"
  if [[ -s "$FILE" ]]; then
    FOUND_DATES+=("$DAY")
    {
      printf '\n<!-- BEGIN %s -->\n' "$DAY"
      cat "$FILE"
      printf '\n<!-- END %s -->\n' "$DAY"
    } >> "$RAW_FILE"
    log "Included daily memory: $DAY"
  else
    SKIPPED_DATES+=("$DAY")
    log "Skipped missing daily memory: $DAY"
  fi
done

log "Step 2/4: summarizing weekly memory"
cat > "$PROMPT_FILE" <<EOF_PROMPT
请只基于下面实际存在的每日 memory 文件内容生成结构化周报，不要编造不存在的信息。

输出到 memory/week-${ISO_WEEK}-memory.md，Markdown 格式：
# Week $ISO_WEEK memory

## 覆盖日期
- YYYY-MM-DD

## 本周要点
- ...

## 进展与决策
- ...

## 待办 / 未解决
- ...

## 风险与阻塞
- ...

## 重要 MSG-ID 引用
- [MSG-xxx] ...

要求：
- 只汇总实际存在的文件，缺失日期不要补写内容。
- 保留重要 MSG-ID 或原始 ID 引用。
- 没有证据的内容不要写。
- 项目标签：$PROJECT_TAG；聊天名：$CHAT_NAME。

每日 memory 原文：
$(cat "$RAW_FILE")
EOF_PROMPT

SUMMARY_STATUS="OK"
if [[ ! -s "$RAW_FILE" ]]; then
  SUMMARY_STATUS="NO_DAILY_FILES"
  {
    printf '# Week %s memory\n\n' "$ISO_WEEK"
    printf '[LLM_FAILED] No daily memory files found in the past 7 days.\n\n'
    printf '## 覆盖日期\n- 无\n\n'
    printf '## 缺失日期\n'
    for day in "${SKIPPED_DATES[@]}"; do printf -- '- %s\n' "$day"; done
  } > "$SUMMARY_FILE"
elif openclaw agent --agent "$AGENT_ID" --message "$(cat "$PROMPT_FILE")" --timeout 60 > "$SUMMARY_FILE" 2>> "$LOG_FILE"; then
  if [[ ! -s "$SUMMARY_FILE" ]]; then
    SUMMARY_STATUS="LLM_EMPTY"
    {
      printf '# Week %s memory\n\n' "$ISO_WEEK"
      printf '[LLM_FAILED] LLM returned an empty weekly summary. Raw daily memory follows.\n\n'
      cat "$RAW_FILE"
    } > "$SUMMARY_FILE"
  fi
else
  SUMMARY_STATUS="LLM_FAILED"
  {
    printf '# Week %s memory\n\n' "$ISO_WEEK"
    printf '[LLM_FAILED] LLM command failed. Raw daily memory follows.\n\n'
    cat "$RAW_FILE"
  } > "$SUMMARY_FILE"
fi

SUMMARY_LENGTH="$(wc -c < "$SUMMARY_FILE" | tr -d ' ')"
log "Included dates: ${FOUND_DATES[*]:-none}"
log "Skipped dates: ${SKIPPED_DATES[*]:-none}"
log "SUMMARY status: $SUMMARY_STATUS"
log "SUMMARY length: $SUMMARY_LENGTH"
log "SUMMARY SHA256: $(sha256sum "$SUMMARY_FILE" | awk '{print $1}')"

log "Step 3/4: writing weekly memory file"
cp "$SUMMARY_FILE" "$OUTPUT_FILE"
LINE_COUNT="$(wc -l < "$OUTPUT_FILE" | tr -d ' ')"
log "Weekly memory file written: $OUTPUT_FILE ($LINE_COUNT lines)"
if [[ "$LINE_COUNT" -lt 3 ]]; then
  log "WARNING: weekly memory file suspiciously short ($LINE_COUNT lines)"
fi

log "Step 4/4: complete"
log "Weekly memory summary complete"
