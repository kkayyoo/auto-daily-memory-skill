# Feishu API Reference

This skill uses Feishu Open Platform APIs to fetch chat messages and optionally notify the chat when memory has been updated.

## Base URL

```text
https://open.feishu.cn/open-apis
```

Override with `FEISHU_API_BASE` only for tests or private gateways.

## Tenant access token

```http
POST /auth/v3/tenant_access_token/internal
Content-Type: application/json; charset=utf-8

{
  "app_id": "cli_xxx",
  "app_secret": "xxx"
}
```

Successful responses include `tenant_access_token`. The daily script also accepts a pre-provisioned `FEISHU_TENANT_ACCESS_TOKEN`.

## Fetch messages by chat container

```http
GET /im/v1/messages?container_id_type=chat&container_id=<chat_id>&page_size=<limit>
Authorization: Bearer <tenant_access_token>
```

Important implementation detail: this endpoint reads messages by `chat_id` as the container and does **not** require a `messageId`.

The response normally contains:

```json
{
  "data": {
    "items": [
      {
        "message_id": "om_xxx",
        "create_time": "...",
        "sender": { "sender_id": { "open_id": "ou_xxx" } },
        "msg_type": "text",
        "body": { "content": "{\"text\":\"hello\"}" }
      }
    ]
  }
}
```

## Send notification message

```http
POST /im/v1/messages?receive_id_type=chat_id
Authorization: Bearer <tenant_access_token>
Content-Type: application/json; charset=utf-8

{
  "receive_id": "oc_xxx",
  "msg_type": "text",
  "content": { "text": "Daily memory updated" }
}
```

## Permissions and scopes

The Feishu app must have permissions that allow:

- Reading messages in the target chat.
- Sending messages to the target chat if `SEND_NOTIFICATION=true`.
- Access to the target chat as a bot or app member according to Feishu platform rules.

Exact scope names can vary by Feishu tenant configuration. Check the app console if the API returns permission errors.
