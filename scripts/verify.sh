#!/usr/bin/env bash
set -u

export HOME="/home/azureuser"
export PATH="/home/azureuser/.local/bin:/home/azureuser/.openclaw/bin:/home/azureuser/.local/share/fnm/node-versions/v24.13.1/installation/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/config/config.sh}"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'
FAILURES=0
WARNINGS=0

ok() { printf "%b✓%b %s\n" "$GREEN" "$NC" "$*"; }
warn() { printf "%b!%b %s\n" "$YELLOW" "$NC" "$*"; WARNINGS=$((WARNINGS + 1)); }
bad() { printf "%b✗%b %s\n" "$RED" "$NC" "$*"; FAILURES=$((FAILURES + 1)); }

check_nonempty() {
  local name="$1" value="${!1:-}"
  if [[ -n "$value" ]]; then
    ok "$name 已设置"
  else
    bad "$name 未设置"
  fi
}

printf 'Auto Cron Memory Skill verification\n'
printf 'Repo: %s\n\n' "$REPO_ROOT"

if [[ -f "$CONFIG_FILE" ]]; then
  ok "config/config.sh 存在"
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
else
  bad "config/config.sh 不存在"
fi

CHANNEL_TYPE="${CHANNEL_TYPE:-}"
if [[ -n "$CHANNEL_TYPE" ]]; then
  ok "CHANNEL_TYPE=$CHANNEL_TYPE"
else
  bad "CHANNEL_TYPE 未设置"
fi

case "$CHANNEL_TYPE" in
  feishu)
    check_nonempty FEISHU_CHAT_ID
    if [[ -n "${FEISHU_TENANT_ACCESS_TOKEN:-}" ]]; then
      ok "FEISHU_TENANT_ACCESS_TOKEN 已设置"
    else
      check_nonempty FEISHU_APP_ID
      check_nonempty FEISHU_APP_SECRET
    fi
    ;;
  discord)
    DISCORD_BOT_TOKEN_EFFECTIVE="${DISCORD_BOT_TOKEN:-}"
    check_nonempty DISCORD_CHANNEL_ID
    if [[ -n "$DISCORD_BOT_TOKEN_EFFECTIVE" ]]; then
      ok "DISCORD_BOT_TOKEN 已设置"
    else
      bad "DISCORD_BOT_TOKEN 未设置"
    fi
    ;;
  *)
    bad "CHANNEL_TYPE 必须是 feishu 或 discord"
    ;;
esac

if command -v openclaw >/dev/null 2>&1; then
  ok "openclaw 可执行文件存在于 PATH ($(command -v openclaw))"
else
  bad "openclaw 可执行文件不存在于 PATH"
fi

if [[ -d "$REPO_ROOT/memory" || -d "$REPO_ROOT/${MEMORY_DIR:-memory}" ]]; then
  ok "memory 目录存在"
else
  bad "memory 目录不存在"
fi

if [[ -d "$REPO_ROOT/logs" || -d "$REPO_ROOT/${LOG_DIR:-logs}" ]]; then
  ok "logs 目录存在"
else
  bad "logs 目录不存在"
fi

CRONTAB_CONTENT="$(crontab -l 2>/dev/null || true)"
if printf '%s\n' "$CRONTAB_CONTENT" | grep -F "$REPO_ROOT/scripts/daily_summary" >/dev/null; then
  ok "cron 已注册（daily）"
else
  bad "cron 未注册（daily）"
fi

if printf '%s\n' "$CRONTAB_CONTENT" | grep -F "$REPO_ROOT/scripts/weekly_summary.sh" >/dev/null; then
  ok "cron 已注册（weekly）"
else
  bad "cron 未注册（weekly）"
fi

printf '\nSummary: %s failure(s), %s warning(s)\n' "$FAILURES" "$WARNINGS"
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
