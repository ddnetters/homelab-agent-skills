---
name: slite-knowledge-base
description: Slite knowledge base API — ask questions, search notes, retrieve content, manage users and groups, and audit knowledge health via the REST API
---

# Slite Knowledge Base

Slite is a team knowledge base with AI-powered search. Use this skill to query notes, ask questions, search content, and audit knowledge health via the Slite API.

## Setup

### Generate an API key

1. Open the organization menu (top left of the Slite app)
2. Click **Settings**
3. In the left panel, click **API**
4. Click **Create a new key** and follow the prompts
5. Copy the key immediately — it is only shown once

You can create multiple keys and revoke unused ones from the same page.

### Configure

```bash
export SLITE_API_KEY="YOUR_API_KEY"
```

All endpoints use Bearer token auth against `https://api.slite.com/v1`.

```bash
# Base pattern for all requests
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/<endpoint>"
```

## Authentication check

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/me" | jq .
```

Returns: `displayName`, `email`, `organizationName`, `organizationDomain`.

## Ask (AI-powered Q&A)

### Ask a question

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/ask?question=How+do+we+handle+on-call+rotations" | \
  jq '{answer, sources: [.sources[] | {title, url}]}'
```

### Scoped to a parent note

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/ask?question=What+is+our+deploy+process&parentNoteId=NOTE_ID" | \
  jq '{answer, sources: [.sources[] | {title, url}]}'
```

### With a specific assistant

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/ask?question=YOUR_QUESTION&assistantId=ASSISTANT_ID" | \
  jq '{answer, sources: [.sources[] | {id, title, url, updatedAt}]}'
```

## Notes

### List notes

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes" | \
  jq '{total, hasNextPage, notes: [.notes[] | {id, title, updatedAt}]}'
```

### Filter and sort

```bash
# By owner
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes?ownerId=USER_ID" | jq '.notes[] | {id, title}'

# By parent note
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes?parentNoteId=NOTE_ID" | jq '.notes[] | {id, title}'

# Sort by last edited (descending)
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes?orderBy=lastEditedAt_DESC" | jq '.notes[] | {id, title}'
```

Order options: `lastEditedAt_DESC`, `lastEditedAt_ASC`, `listPosition_DESC`, `listPosition_ASC`.

### Paginate through notes

```bash
# First page
RESPONSE=$(curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes")
echo "$RESPONSE" | jq '{total, hasNextPage}'

# Next page (use nextCursor from previous response)
CURSOR=$(echo "$RESPONSE" | jq -r '.nextCursor')
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes?cursor=$CURSOR" | jq '.notes[] | {id, title}'
```

### Get note by ID

```bash
# Default format
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes/NOTE_ID" | jq '{id, title, content}'

# As markdown
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes/NOTE_ID?format=md" | jq '{id, title, content}'

# As HTML
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes/NOTE_ID?format=html" | jq '{id, title, content}'
```

Format options: `md`, `html`, `sliteml`.

### Get note children

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes/NOTE_ID/children" | \
  jq '{total, hasNextPage, notes: [.notes[] | {id, title}]}'

# Paginate children (max 50 per page)
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/notes/NOTE_ID/children?cursor=CURSOR" | jq '.notes[] | {id, title}'
```

## Search

### Basic search

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/search-notes?query=deployment+guide" | \
  jq '.hits[] | {id, title, highlight}'
```

### Search with filters

```bash
# Scoped to a parent note subtree
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/search-notes?query=onboarding&parentNoteId=NOTE_ID" | \
  jq '.hits[] | {id, title}'

# Filter by review state
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/search-notes?query=api&reviewState=Verified" | \
  jq '.hits[] | {id, title}'

# Filter by hierarchy depth
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/search-notes?query=runbook&depth=2" | \
  jq '.hits[] | {id, title}'

# Include archived notes
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/search-notes?query=old+process&includeArchived=true" | \
  jq '.hits[] | {id, title}'
```

Review states: `Verified`, `Outdated`, `VerificationRequested`, `VerificationExpired`.

### Search with pagination

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/search-notes?query=meeting+notes&page=0&hitsPerPage=20" | \
  jq '{nbPages, page, hits: [.hits[] | {id, title}]}'
```

### Search with highlight tags

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/search-notes?query=deploy&highlightPreTag=**&highlightPostTag=**" | \
  jq '.hits[] | {title, highlight}'
```

### Filter by edit date

```bash
# Notes edited after a date
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/search-notes?query=roadmap&lastEditedAfter=2026-01-01T00:00:00Z" | \
  jq '.hits[] | {id, title}'
```

## Knowledge management

### List all notes

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes?first=50" | \
  jq '{total, hasNextPage, notes: [.notes[] | {id, title}]}'
```

### Filter by review state

```bash
# Find outdated notes
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes?reviewStateList=Outdated&first=50" | \
  jq '.notes[] | {id, title}'

# Notes pending verification
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes?reviewStateList=VerificationRequested&first=50" | \
  jq '.notes[] | {id, title}'
```

### Filter by owner or channel

```bash
# By owner
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes?ownerIdList=USER_ID&first=50" | \
  jq '.notes[] | {id, title}'

# By channel
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes?channelIdList=CHANNEL_ID&first=50" | \
  jq '.notes[] | {id, title}'
```

### Recent notes

```bash
# Notes created or updated in the last 7 days
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes?sinceDaysAgo=7&first=50" | \
  jq '.notes[] | {id, title}'
```

### Public notes

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes/public?first=50" | \
  jq '.notes[] | {id, title}'
```

### Inactive notes

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes/inactive?first=50" | \
  jq '.notes[] | {id, title}'
```

### Empty notes

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/knowledge-management/notes/empty?first=50" | \
  jq '.notes[] | {id, title}'
```

## Users

### Search users

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/users?query=john" | \
  jq '.users[] | {id, displayName, email}'
```

### Include archived users

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/users?query=jane&includeArchived=true" | \
  jq '.users[] | {id, displayName, email, archivedAt}'
```

### Get user by ID

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/users/USER_ID" | \
  jq '{id, displayName, email, organizationRole, isGuest}'
```

## Groups

### Search groups

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/groups?query=engineering" | \
  jq '.groups[] | {id, name, description}'
```

### Get group by ID

```bash
curl -s -H "Authorization: Bearer $SLITE_API_KEY" \
  "https://api.slite.com/v1/groups/GROUP_ID" | jq '{id, name, description}'
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| 401 Unauthorized | Check `SLITE_API_KEY` is set and valid. Regenerate at Settings → API |
| 422 Validation error | Check required parameters. `query` is required for `/users` and `/groups` |
| 429 Rate limited | Back off and retry. Reduce request frequency |
| 404 Not found | Verify the note/user/group ID exists and you have access |
| Empty search results | Try broader query terms, check `parentNoteId` scope, try `includeArchived=true` |
| Pagination not working | Use `nextCursor` from response for notes, `page` param for search |

## Tips

- The `/ask` endpoint uses AI to answer from your knowledge base — great for natural language queries
- Use `format=md` when fetching note content for the most readable output
- Knowledge management endpoints help audit content health: find inactive, empty, or outdated notes
- Paginated endpoints return `hasNextPage` and `nextCursor` — loop until `hasNextPage` is false
- Search supports `hitsPerPage` up to 100 (use `page` starting at 0)
- Knowledge management endpoints accept `first` up to 50 per page
