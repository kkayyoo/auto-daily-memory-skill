#!/usr/bin/env bash
set -euo pipefail

export HOME="/home/azureuser"
export PATH="/home/azureuser/.local/bin:/home/azureuser/.openclaw/bin:/home/azureuser/.local/share/fnm/node-versions/v24.13.1/installation/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
CONFIG_FILE="$CONFIG_DIR/config.sh"
TEMPLATE_FILE="$CONFIG_DIR/config.template.sh"

prompt() {
  local label="$1" default="${2:-}" value
  if [[ -n "$default" ]]; then
    read -r -p "$label [$default]: " value
    printf '%s\n' "${value:-$default}"
  else
    read -r -p "$label: " value
    printf '%s\n' "$value"
  fi
}

escape_sed() {
  printf '%s' "$1" | sed 's/[&/]/\\&/g'
}

replace_var() {
  local key="$1" value="$2" escaped
  escaped="$(escape_sed "$value")"
  sed -i "s/^${key}=.*/${key}=\"${escaped}\"/" "$CONFIG_FILE"
}

register_cron_line() {
  local marker="$1" line="$2" tmp
  tmp="$(mktemp)"
  crontab -l > "$tmp" 2>/dev/null || true
  grep -v "$marker" "$tmp" > "$tmp.filtered" || true
  printf '%s\n' "$line" >> "$tmp.filtered"
  crontab "$tmp.filtered"
  rm -f "$tmp" "$tmp.filtered"
}

echo "Auto Cron Memory Skill setup"
echo "Repo: $REPO_ROOT"

mkdir -p "$CONFIG_DIR" "$REPO_ROOT/logs" "$REPO_ROOT/memory"
cp "$TEMPLATE_FILE" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

CHANNEL_TYPE="$(prompt 'Channel type (feishu/discord)' 'feishu')"
PROJECT_TAG="$(prompt 'Project tag' 'jobseeker')"
CHAT_NAME="$(prompt 'Chat display name' '求职准备群')"
MEMORY_DIR="$(prompt 'Memory dir' 'memory')"
LOG_DIR="$(prompt 'Log dir' 'logs')"
TIMEZONE="$(prompt 'Timezone for memory dates' 'Asia/Shanghai')"
DAILY_CRON_UTC="$(prompt 'Daily cron in UTC (23:59 BJT = 15:59 UTC)' '59 15 * * *')"
WEEKLY_CRON_UTC="$(prompt 'Weekly cron in UTC (Sunday 23:58 BJT = 15:58 UTC)' '58 15 * * 0')"
SEND_NOTIFICATION="$(prompt 'Send chat notification after write? (true/false)' 'false')"

replace_var CHANNEL_TYPE "$CHANNEL_TYPE"
replace_var PROJECT_TAG "$PROJECT_TAG"
replace_var CHAT_NAME "$CHAT_NAME"
replace_var MEMORY_DIR "$MEMORY_DIR"
replace_var LOG_DIR "$LOG_DIR"
replace_var TIMEZONE "$TIMEZONE"
replace_var DAILY_CRON_UTC "$DAILY_CRON_UTC"
replace_var WEEKLY_CRON_UTC "$WEEKLY_CRON_UTC"
replace_var SEND_NOTIFICATION "$SEND_NOTIFICATION"

case "$CHANNEL_TYPE" in
  feishu)
    FEISHU_CHAT_ID="$(prompt 'Feishu chat_id')"
    FEISHU_APP_ID="$(prompt 'Feishu app_id (optional if token is provided)' '')"
    FEISHU_APP_SECRET="$(prompt 'Feishu app_secret (optional if token is provided)' '')"
    FEISHU_TENANT_ACCESS_TOKEN="$(prompt 'Feishu tenant_access_token (optional if app credentials are provided)' '')"
    FEISHU_MESSAGE_LIMIT="$(prompt 'Feishu message limit' '50')"
    replace_var FEISHU_CHAT_ID "$FEISHU_CHAT_ID"
    replace_var FEISHU_APP_ID "$FEISHU_APP_ID"
    replace_var FEISHU_APP_SECRET "$FEISHU_APP_SECRET"
    replace_var FEISHU_TENANT_ACCESS_TOKEN "$FEISHU_TENANT_ACCESS_TOKEN"
    replace_var FEISHU_MESSAGE_LIMIT "$FEISHU_MESSAGE_LIMIT"
    DAILY_SCRIPT="$REPO_ROOT/scripts/daily_summary.sh"
    ;;
  discord)
    DISCORD_CHANNEL_ID="$(prompt 'Discord channel_id')"
    DISCORD_BOT_TOKEN="$(prompt 'Discord bot token (optional; env DISCORD_BOT_TOKEN is preferred)' '')"
    DISCORD_MESSAGE_LIMIT="$(prompt 'Discord message limit' '50')"
    replace_var DISCORD_CHANNEL_ID "$DISCORD_CHANNEL_ID"
    replace_var DISCORD_BOT_TOKEN "$DISCORD_BOT_TOKEN"
    replace_var DISCORD_MESSAGE_LIMIT "$DISCORD_MESSAGE_LIMIT"
    DAILY_SCRIPT="$REPO_ROOT/scripts/daily_summary_discord.sh"
    ;;
  *)
    echo "Unsupported channel type: $CHANNEL_TYPE" >&2
    exit 1
    ;;
esac

chmod +x "$REPO_ROOT/scripts"/*.sh

CRON_LOG="$REPO_ROOT/logs/daily_summary.log"
CRON_MARKER="auto-cron-memory-skill:daily:$REPO_ROOT"
CRON_LINE="$DAILY_CRON_UTC export HOME=/home/azureuser; export PATH=/home/azureuser/.local/bin:/home/azureuser/.openclaw/bin:/home/azureuser/.local/share/fnm/node-versions/v24.13.1/installation/bin:/usr/local/bin:/usr/bin:/bin:\$PATH; cd $REPO_ROOT && CONFIG_FILE=$CONFIG_FILE bash $DAILY_SCRIPT >> $CRON_LOG 2>&1 # $CRON_MARKER"
register_cron_line "$CRON_MARKER" "$CRON_LINE"

WEEKLY_SCRIPT="$REPO_ROOT/scripts/weekly_summary.sh"
WEEKLY_CRON_LOG="$REPO_ROOT/logs/weekly-summary.log"
WEEKLY_CRON_MARKER="auto-cron-memory-skill:weekly:$REPO_ROOT"
WEEKLY_CRON_LINE="$WEEKLY_CRON_UTC export HOME=/home/azureuser; export PATH=/home/azureuser/.local/bin:/home/azureuser/.openclaw/bin:/home/azureuser/.local/share/fnm/node-versions/v24.13.1/installation/bin:/usr/local/bin:/usr/bin:/bin:\$PATH; cd $REPO_ROOT && CONFIG_FILE=$CONFIG_FILE /bin/bash $WEEKLY_SCRIPT >> $WEEKLY_CRON_LOG 2>&1 # $WEEKLY_CRON_MARKER"
register_cron_line "$WEEKLY_CRON_MARKER" "$WEEKLY_CRON_LINE"

echo "Config written: $CONFIG_FILE"
echo "Daily cron registered:"
crontab -l | grep "$CRON_MARKER" || true
echo "Weekly cron registered:"
crontab -l | grep "$WEEKLY_CRON_MARKER" || true
echo "Setup complete"
