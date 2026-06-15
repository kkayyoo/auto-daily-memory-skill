# Auto Cron Memory Skill

自动把飞书或 Discord 群聊历史拉取、总结并写入 OpenClaw agent 的每日和每周 memory 文件。

## 功能列表

- **飞书每日记忆**：通过 `im/v1/messages?container_id_type=chat` 按 `FEISHU_CHAT_ID` 拉取群聊消息。
- **Discord 每日记忆**：通过 `GET /channels/{channel_id}/messages` 拉取频道消息，过滤 bot 消息并支持 `before` 翻页。
- **每日/每周输出**：生成 `memory/YYYY-MM-DD.md` 和 `memory/week-N-memory.md`。
- **多项目标签**：用 `PROJECT_TAG` 在 memory 中写入 `## [PROJECT: ...]`，便于一个 agent 管多个主题。
- **防幻觉 fallback**：LLM 失败或输出为空时写入 `[LLM_FAILED: fallback used]` 或 `[LLM_FAILED]`，并保留原始消息，不编造总结。
- **cron 安全环境**：脚本显式 export `HOME` 和完整 `PATH`，stderr 进入日志。

## 安装步骤

### 1. Clone

```bash
git clone https://github.com/kkayyoo/auto-daily-memory-skill.git
cd auto-daily-memory-skill
```

### 2. 运行 setup

```bash
bash scripts/setup.sh
```

setup 会创建 `config/config.sh`、`memory/`、`logs/`，并注册 daily 与 weekly cron。

### 3. 验证

```bash
bash scripts/verify.sh
bash scripts/daily_summary.sh          # CHANNEL_TYPE=feishu
bash scripts/daily_summary_discord.sh  # CHANNEL_TYPE=discord
bash scripts/weekly_summary.sh
```

## 配置说明

| 变量 | 必填 | 说明 |
|---|---:|---|
| `CHANNEL_TYPE` | 是 | `feishu` 或 `discord`。 |
| `PROJECT_TAG` | 否 | memory 项目标签，默认 `default`。 |
| `CHAT_NAME` | 否 | memory 标题中的群聊显示名。 |
| `MEMORY_DIR` | 否 | memory 输出目录，默认 `memory`。 |
| `LOG_DIR` | 否 | 日志目录，默认 `logs`。 |
| `TIMEZONE` | 否 | 日期时区，默认 `Asia/Shanghai`。 |
| `DAILY_CRON_UTC` | 否 | 每日 cron，默认 `59 15 * * *`，即北京时间 23:59。 |
| `WEEKLY_CRON_UTC` | 否 | 每周 cron，默认 `58 15 * * 0`，即周日北京时间 23:58。 |
| `AGENT_ID` | 否 | `openclaw agent --agent` 使用的 agent id；为空时默认使用 `PROJECT_TAG`。 |
| `FEISHU_CHAT_ID` | 飞书必填 | 飞书群 chat id。 |
| `FEISHU_APP_ID` | 条件必填 | 无 `FEISHU_TENANT_ACCESS_TOKEN` 时需要。 |
| `FEISHU_APP_SECRET` | 条件必填 | 无 `FEISHU_TENANT_ACCESS_TOKEN` 时需要。 |
| `FEISHU_TENANT_ACCESS_TOKEN` | 条件必填 | 可替代 `FEISHU_APP_ID` + `FEISHU_APP_SECRET`。 |
| `FEISHU_MESSAGE_LIMIT` | 否 | 飞书单次拉取数量。 |
| `DISCORD_BOT_TOKEN` | Discord 必填 | Discord bot token，推荐通过环境变量提供。 |
| `DISCORD_CHANNEL_ID` | Discord 必填 | Discord channel id。 |
| `DISCORD_MESSAGE_LIMIT` | 否 | Discord 每页消息数，默认 `100`。 |
| `SEND_NOTIFICATION` | 否 | 飞书写入后是否发送通知，默认 `false`。 |

## 故障排查快速入口

详见 [`references/troubleshooting.md`](references/troubleshooting.md)。常见入口：

- cron 中 `openclaw not found`：检查脚本和 crontab 的显式 `PATH`。
- `SUMMARY length=0`：检查 `openclaw agent --timeout`、agent id 和日志 stderr。
- 消息数为 0：检查 chat/channel id、token、权限和当天是否确有消息。
- 飞书 API `code != 0`：检查 `APP_ID`、`APP_SECRET`、tenant token 和权限。
- 周报为空：检查过去 7 天 `memory/YYYY-MM-DD.md` 是否存在。

## 已知限制

- 飞书脚本当前按配置的接口响应解析文本消息；复杂卡片、文件、图片只会保留可解析字段。
- Discord 大流量频道可能遇到 429 rate limit，需要根据日志中的 retry 信息调整运行方式。
- LLM 调用依赖本机可用的 `openclaw agent`，不直接调用 OpenAI 或 Claude API。
- setup 会覆盖已有 `config/config.sh`，重新运行前请备份本地密钥。
