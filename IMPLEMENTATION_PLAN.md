# Implementation Plan

## Goal

Build `auto-cron-memory-skill`, an OpenClaw skill that lets any agent schedule automatic Feishu or Discord chat summarization into daily and weekly memory files with explicit anti-hallucination fallbacks.

## Round 1: Skill skeleton + Feishu support

- [x] Create `SKILL.md` with OpenClaw skill frontmatter and usage notes.
- [x] Create `config/config.template.sh`.
- [x] Create `scripts/setup.sh` with Feishu-first setup and daily cron registration.
- [x] Create `scripts/daily_summary.sh` for Feishu.
- [x] Document Feishu endpoints in `references/feishu-api.md`.
- [x] Add cron-safe environment exports and stderr logging.
- [x] Add summary length logging and fallback raw-message writes.

## Round 2: Discord support + multi-project tags

- [x] Create `scripts/daily_summary_discord.sh` using `GET /channels/{channel_id}/messages`.
- [x] Ensure daily memory headings and bullets include `[PROJECT: ...]` and `[ID: ...]`.
- [x] Document Discord API usage in `references/discord-api.md`.

## Round 3: Weekly summary + hallucination hardening

- [ ] Create `scripts/weekly_summary.sh` for `week-{N}-memory.md`.
- [ ] Register weekly cron in `scripts/setup.sh` at Sunday 23:58 BJT / 15:58 UTC.
- [ ] Add stronger hash, non-empty, and fallback checks.

## Round 4: Documentation + end-to-end verification

- [ ] Create `README.md`.
- [ ] Create `scripts/verify.sh`.
- [ ] Create `references/troubleshooting.md`.
- [ ] Final review of `SKILL.md` trigger coverage.

## Known implementation constraints

- Cron must export `HOME=/home/azureuser` and a full OpenClaw/Node-aware `PATH`.
- Cron logs must append stdout and stderr; do not hide stderr with `2>/dev/null`.
- Feishu fetch uses `im/v1/messages?container_id_type=chat` by `chat_id` and does not require `messageId`.
- Discord fetch uses `GET /channels/{channel_id}/messages`.
- If LLM summary is unavailable, failed, or empty, write raw messages with `[LLM_FAILED: fallback used]` instead of inventing content.
