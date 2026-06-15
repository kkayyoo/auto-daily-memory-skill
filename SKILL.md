---
name: auto-cron-memory-skill
description: Automatically schedule Feishu or Discord group chat collection, LLM summarization, and daily/weekly structured memory file updates for OpenClaw agents.
metadata:
  version: 0.1.0
  author: OpenClaw Community
  keywords:
    - feishu
    - discord
    - cron
    - memory
    - daily
    - weekly
    - chat-summary
    - llm-summary
license: MIT
---

# Auto Cron Memory Skill

Use this skill when an OpenClaw agent should automatically turn group chat history into durable memory files.

## What it provides

- Daily scheduled chat collection, defaulting to **23:59 Beijing time**.
- Feishu support via `im/v1/messages?container_id_type=chat` using a `chat_id` container.
- Discord support via channel message history collection.
- Structured daily memory files in `memory/YYYY-MM-DD.md` with project tags and message IDs.
- Weekly rollups in `memory/week-N-memory.md`.
- Anti-hallucination fallback: if the LLM summary fails or returns empty output, raw messages are written with an explicit fallback marker.
- Cron-safe scripts that export `HOME`, a complete `PATH`, and append both stdout and stderr to logs.

## Quick start

```bash
cd /path/to/auto-cron-memory-skill
bash scripts/setup.sh
```

The setup wizard writes `config/config.sh` and registers cron jobs without removing unrelated crontab entries.

## Daily command

```bash
bash scripts/daily_summary.sh
```

## Configuration

Copy or generate the config from:

```bash
cp config/config.template.sh config/config.sh
```

Then set the channel, credentials, chat or channel ID, project tag, memory directory, and optional LLM command.

## Trigger keywords

Use this skill for: Feishu memory, Discord memory, cron memory, daily chat summary, weekly memory, scheduled group chat summary, automatic OpenClaw memory, `memory/YYYY-MM-DD.md`, and chat-to-memory automation.
