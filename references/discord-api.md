# Discord API Reference

## Endpoint

Use Discord channel message history:

```http
GET https://discord.com/api/v10/channels/{channel_id}/messages?limit=100
```

The daily script calls this endpoint for the configured `DISCORD_CHANNEL_ID`.

## Authentication

Discord bot authentication uses the bot token header:

```http
Authorization: Bot {token}
```

The script reads the token from `DISCORD_BOT_TOKEN`. Prefer exporting it as an environment variable in cron or the host environment instead of committing it into `config/config.sh`.

## Pagination

Discord returns messages in reverse chronological order. To fetch older pages, pass the last message snowflake ID from the current page as `before`:

```http
GET /channels/{channel_id}/messages?limit=100&before={oldest_message_id_from_previous_page}
```

`daily_summary_discord.sh` continues paging until it reaches messages older than Beijing-time midnight for the current day, or until Discord returns an empty page.

## Filtering

The script filters out bot-authored messages with:

```json
{ "author": { "bot": true } }
```

It then keeps only messages whose `timestamp` is at or after Beijing-time `00:00` for the target date.

## Required permissions

The bot must be in the server and channel with permission to read message history:

- `VIEW_CHANNEL`
- `READ_MESSAGE_HISTORY`

If messages are missing, check channel overrides as well as role-level permissions.

## Rate limits

Discord may return HTTP `429` with a retry-after payload when rate limited. The production script keeps requests small (`limit=100`) and stops once it has the current day, but large or very active channels can still hit rate limits. If that happens, reduce run frequency, inspect the response body in logs, and retry after the server-provided delay.
