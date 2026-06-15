#!/usr/bin/env bash
# Auto Cron Memory Skill configuration template.
# Copy to config/config.sh and edit, or run scripts/setup.sh.

# Channel type: feishu or discord
CHANNEL_TYPE="feishu"

# Human-readable title used in memory headings.
CHAT_NAME="My Group Chat"

# Structured memory project tag, for example jobseeker, dev, investor.
PROJECT_TAG="my-project"

# Daily memory output directory. Relative paths are resolved from the skill repo root.
MEMORY_DIR="memory"

# Log directory. Relative paths are resolved from the skill repo root.
LOG_DIR="logs"

# Time zone label used by scripts for dates. Asia/Shanghai gives Beijing time.
TIMEZONE="Asia/Shanghai"

# Daily cron in UTC. Default: 23:59 BJT = 15:59 UTC.
DAILY_CRON_UTC="59 15 * * *"

# Weekly cron in UTC. Default: Sunday 23:58 BJT = Sunday 15:58 UTC.
WEEKLY_CRON_UTC="58 15 * * 0"

# Optional LLM command. The script pipes raw extracted messages to this command.
# Example: LLM_COMMAND='openclaw ask --stdin "Summarize these messages into concise memory bullets"'
# Leave empty to write raw messages with a fallback marker.
LLM_COMMAND=""
# OpenClaw agent id used for openclaw agent --agent. Defaults to PROJECT_TAG if empty.
AGENT_ID=""

# If true, send a notification back to the chat when memory is written.
SEND_NOTIFICATION="false"

# Feishu settings.
FEISHU_CHAT_ID=""
FEISHU_APP_ID=""
FEISHU_APP_SECRET=""
# Optional pre-provisioned tenant access token. If empty, APP_ID/APP_SECRET are used.
FEISHU_TENANT_ACCESS_TOKEN=""
FEISHU_MESSAGE_LIMIT="50"

# Discord (required when CHANNEL_TYPE=discord)
# Prefer exporting DISCORD_BOT_TOKEN in the environment for secrets.
DISCORD_BOT_TOKEN=""
DISCORD_CHANNEL_ID=""
DISCORD_MESSAGE_LIMIT="100"

# Advanced: override API roots only for private gateways or tests.
FEISHU_API_BASE="https://open.feishu.cn/open-apis"
DISCORD_API_BASE="https://discord.com/api/v10"
