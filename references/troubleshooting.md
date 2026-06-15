# Troubleshooting

## `openclaw not found` in cron

**Symptom**

`logs/daily_summary.log` or `logs/weekly-summary.log` shows `openclaw: command not found`.

**Cause**

cron runs with a minimal environment and may not load shell rc files.

**Fix**

Use scripts that explicitly export `HOME` and a full `PATH`. The included scripts and setup cron lines do this:

```bash
export HOME=/home/azureuser
export PATH=/home/azureuser/.local/bin:/home/azureuser/.openclaw/bin:/home/azureuser/.local/share/fnm/node-versions/v24.13.1/installation/bin:/usr/local/bin:/usr/bin:/bin:$PATH
```

Then verify:

```bash
bash scripts/verify.sh
crontab -l
```

## `SUMMARY length=0`

**Symptom**

The log prints `SUMMARY length: 0` or the memory file is almost empty.

**Cause**

The LLM command returned no text, timed out, or failed before writing stdout.

**Fix**

- Check the same log file for stderr from `openclaw agent`.
- Verify the configured `AGENT_ID` exists and can answer.
- Increase or inspect `openclaw agent --timeout 60` behavior if summaries often time out.
- Confirm fallback markers appear. Empty LLM output should produce `[LLM_FAILED: fallback used]` plus raw messages for daily files, or `[LLM_FAILED]` for weekly files.

## Message count is 0

**Symptom**

Daily log shows message count 0.

**Feishu fixes**

- Check `FEISHU_CHAT_ID` is the target group chat id.
- Check tenant token or app credentials are current.
- Confirm the app has message read permissions and is allowed in the chat.
- Confirm there were messages in the target day/time window.

**Discord fixes**

- Check `DISCORD_CHANNEL_ID` is correct.
- Check `DISCORD_BOT_TOKEN` is exported in the cron environment or present in config.
- Confirm the bot is in the server/channel.
- Confirm bot-authored messages are intentionally filtered out.

## Feishu API `code != 0`

**Symptom**

Feishu returns an error JSON instead of message items.

**Fix**

- Check `FEISHU_APP_ID` and `FEISHU_APP_SECRET`.
- If using `FEISHU_TENANT_ACCESS_TOKEN`, refresh it.
- Confirm app permissions include:
  - `im:message:readonly`
  - `im:chat:readonly`
- Check whether the app needs to be installed or re-approved after adding scopes.
- Keep stderr and response logs; do not hide errors with `2>/dev/null`.

## `week-N-memory.md` is empty

**Symptom**

Weekly summary file has no useful content.

**Cause**

There are no daily files in the past 7 days, or the LLM failed and fallback had no raw material.

**Fix**

- Check `memory/YYYY-MM-DD.md` files exist for the past 7 days.
- Run a daily summary manually before running weekly summary.
- Inspect `logs/weekly-summary.log` for skipped dates and `SUMMARY length`.

## cron is not registered

**Symptom**

`bash scripts/verify.sh` reports daily or weekly cron missing.

**Fix**

Re-run setup:

```bash
bash scripts/setup.sh
crontab -l
```

The setup script preserves unrelated crontab entries and replaces only entries with this skill's markers.
