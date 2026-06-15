**[English](README.md)** · [中文](README.zh.md)

---

# Auto Cron Memory Skill

Automatically pulls Feishu or Discord group chat history, summarises it with an LLM, and writes daily and weekly memory files for your OpenClaw agent.

## Features

- **Feishu daily memory** — fetches messages via `im/v1/messages?container_id_type=chat` using `FEISHU_CHAT_ID`, no `messageId` required.
- **Discord daily memory** — fetches channel messages via `GET /channels/{channel_id}/messages`, filters bot messages, and supports `before`-cursor pagination.
- **Daily / weekly output** — generates `memory/YYYY-MM-DD.md` and `memory/week-{N}-memory.md` (ISO week number, 01–52).
- **Multi-project tags** — use `PROJECT_TAG` to write `## [PROJECT: ...]` headings in memory, so one agent can handle multiple topics.
- **Anti-hallucination fallback** — when the LLM fails or returns empty output, writes `[LLM_FAILED: fallback used]` and preserves the raw messages; never fabricates a summary.
- **Cron-safe environment** — every script explicitly exports `HOME` and a full `PATH`; stderr is always appended to the log file, never silenced with `2>/dev/null`.

## Quick Start

### 1. Clone

```bash
git clone https://github.com/kkayyoo/auto-daily-memory-skill.git
cd auto-daily-memory-skill
```

### 2. Run setup

```bash
bash scripts/setup.sh
```

The setup wizard creates `config/config.sh`, `memory/`, and `logs/`, then registers daily and weekly cron jobs.

### 3. Verify

```bash
bash scripts/verify.sh
bash scripts/daily_summary.sh          # CHANNEL_TYPE=feishu
bash scripts/daily_summary_discord.sh  # CHANNEL_TYPE=discord
bash scripts/weekly_summary.sh
```

## Configuration

| Variable | Required | Description |
|---|:---:|---|
| `CHANNEL_TYPE` | ✅ | `feishu` or `discord`. |
| `PROJECT_TAG` | — | Memory project label, defaults to `default`. |
| `CHAT_NAME` | — | Display name used in memory headings. |
| `MEMORY_DIR` | — | Output directory for memory files, defaults to `memory`. |
| `LOG_DIR` | — | Log directory, defaults to `logs`. |
| `TIMEZONE` | — | Date timezone, defaults to `Asia/Shanghai`. |
| `DAILY_CRON_UTC` | — | Daily cron schedule (UTC), defaults to `59 15 * * *` (23:59 BJT). |
| `WEEKLY_CRON_UTC` | — | Weekly cron schedule (UTC), defaults to `58 15 * * 0` (Sunday 23:58 BJT). |
| `AGENT_ID` | — | Agent id passed to `openclaw agent --agent`; falls back to `PROJECT_TAG`. |
| `FEISHU_CHAT_ID` | Feishu ✅ | Feishu group chat id. |
| `FEISHU_APP_ID` | Conditional | Required when `FEISHU_TENANT_ACCESS_TOKEN` is not set. |
| `FEISHU_APP_SECRET` | Conditional | Required when `FEISHU_TENANT_ACCESS_TOKEN` is not set. |
| `FEISHU_TENANT_ACCESS_TOKEN` | Conditional | Can replace `FEISHU_APP_ID` + `FEISHU_APP_SECRET`. |
| `FEISHU_MESSAGE_LIMIT` | — | Feishu page size per request. |
| `DISCORD_BOT_TOKEN` | Discord ✅ | Discord bot token; recommended via env var. |
| `DISCORD_CHANNEL_ID` | Discord ✅ | Discord channel id. |
| `DISCORD_MESSAGE_LIMIT` | — | Discord messages per page, defaults to `100`. |
| `SEND_NOTIFICATION` | — | Send Feishu notification after writing memory, defaults to `false`. |

## Troubleshooting

Full details in [`references/troubleshooting.md`](references/troubleshooting.md). Common issues:

- **`openclaw not found` in cron** — check that the script and crontab entry both set a full explicit `PATH`.
- **`SUMMARY length=0`** — check `openclaw agent --timeout`, the agent id, and stderr in the log file.
- **Message count is 0** — verify chat/channel id, token, permissions, and that messages actually exist for that day.
- **Feishu API `code != 0`** — check `APP_ID`, `APP_SECRET`, the tenant token, and required scopes (`im:message:readonly`, `im:chat:readonly`).
- **Weekly summary is empty** — check that `memory/YYYY-MM-DD.md` files exist for the past 7 days.

## Known Limitations

- Feishu script parses text messages; complex cards, files, and images retain only extractable text fields.
- High-volume Discord channels may hit the 429 rate limit; check retry hints in the log.
- LLM calls require a locally available `openclaw agent`; no direct OpenAI or Claude API key needed.
- Running `setup.sh` again overwrites `config/config.sh`; back up your credentials first.
