# gogcli Complete Command Reference

## Table of contents

- [Authentication](#authentication)
- [Gmail — Search & Read](#gmail--search--read)
- [Gmail — Send & Compose](#gmail--send--compose)
- [Gmail — Drafts](#gmail--drafts)
- [Gmail — Labels](#gmail--labels)
- [Gmail — Batch Operations](#gmail--batch-operations)
- [Gmail — Filters](#gmail--filters)
- [Gmail — Settings](#gmail--settings)
- [Gmail — Delegation](#gmail--delegation)
- [Gmail — Watch (Pub/Sub)](#gmail--watch-pubsub)
- [Gmail — Email Tracking](#gmail--email-tracking)
- [Calendar — List & Search Events](#calendar--list--search-events)
- [Calendar — Create & Update](#calendar--create--update)
- [Calendar — Delete & RSVP](#calendar--delete--rsvp)
- [Calendar — Recurring Events](#calendar--recurring-events)
- [Calendar — Special Event Types](#calendar--special-event-types)
- [Calendar — Availability](#calendar--availability)
- [Calendar — Team Calendars](#calendar--team-calendars)
- [Calendar — Management](#calendar--management)
- [Environment Variables](#environment-variables)
- [Global Flags](#global-flags)

## Authentication

```bash
gog auth credentials <path>                        # Store OAuth client credentials
gog auth credentials list                          # List stored credentials
gog --client work auth credentials <path>          # Named OAuth client
gog auth add <email>                               # Authorize account
gog auth add <email> --services gmail,calendar     # Specific services only
gog auth add <email> --services gmail --gmail-scope readonly  # Read-only Gmail
gog auth add <email> --manual                      # Headless/remote flow
gog auth add <email> --force-consent               # Re-authorize with fresh consent
gog auth list                                      # List accounts
gog auth list --check                              # Validate tokens
gog auth status                                    # Current auth state
gog auth services                                  # Available services and scopes
gog auth remove <email>                            # Remove account
gog auth alias set <alias> <email>                 # Create alias
gog auth alias list                                # List aliases
gog auth keyring [backend]                         # Show/set keyring (auto|keychain|file)
```

## Gmail — Search & Read

```bash
gog gmail search '<query>' --max 10
gog gmail search 'from:x@y.com newer_than:7d has:attachment'
gog gmail messages search '<query>' --max 10 --include-body  # Message-level with bodies

gog gmail thread get <threadId>
gog gmail thread get <threadId> --download                   # Download attachments
gog gmail thread get <threadId> --download --out-dir ./dir
gog gmail get <messageId>
gog gmail get <messageId> --format metadata
gog gmail attachment <messageId> <attachmentId> --out ./file
gog gmail url <threadId>                                     # Web URL
gog gmail history --since <historyId>
```

## Gmail — Send & Compose

```bash
gog gmail send --to a@b.com --subject "Hi" --body "Text"
gog gmail send --to a@b.com --subject "Hi" --body-file ./msg.txt
gog gmail send --to a@b.com --subject "Hi" --body-file -          # Stdin
gog gmail send --to a@b.com --subject "Hi" --body "Text" --body-html "<p>HTML</p>"

# Reply with threading and quoted original
gog gmail send --reply-to-message-id <msgId> --quote \
  --to a@b.com --subject "Re: Hi" --body "Reply text"

# Track opens (requires tracking setup)
gog gmail send --to a@b.com --subject "Hi" --body-html "<p>Hi</p>" --track
```

## Gmail — Drafts

```bash
gog gmail drafts list
gog gmail drafts create --subject "Draft" --body "Body"
gog gmail drafts create --to a@b.com --subject "Draft" --body "Body"
gog gmail drafts create --reply-to-message-id <msgId> --quote --subject "Re: Hi" --body "Reply"
gog gmail drafts update <draftId> --subject "Updated" --body "New body"
gog gmail drafts update <draftId> --quote --subject "Re: Hi" --body "Reply"
gog gmail drafts send <draftId>
```

## Gmail — Labels

```bash
gog gmail labels list
gog gmail labels get INBOX --json                  # Includes message counts
gog gmail labels create "My Label"
gog gmail labels rename "Old" "New"
gog gmail labels delete <labelIdOrName>
gog gmail thread modify <threadId> --add STARRED --remove INBOX
gog gmail labels modify <threadId> --add STARRED --remove INBOX  # Alias
```

## Gmail — Batch Operations

```bash
gog gmail batch delete <msgId> <msgId>
gog gmail batch modify <msgId> <msgId> --add STARRED --remove INBOX

# Batch via piping
gog --json gmail search 'from:noreply@x.com' --max 200 | \
  jq -r '.threads[].id' | xargs -n 50 gog gmail labels modify --remove UNREAD

gog --json gmail search 'older_than:1y' --max 200 | \
  jq -r '.threads[].id' | xargs -n 50 gog gmail labels modify --remove INBOX
```

## Gmail — Filters

```bash
gog gmail filters list
gog gmail filters create --from 'noreply@example.com' --add-label 'Notifications'
gog gmail filters delete <filterId>
gog gmail filters export --out ./filters.json
```

## Gmail — Settings

```bash
# Forwarding
gog gmail autoforward get
gog gmail autoforward enable --email forward@example.com
gog gmail autoforward disable
gog gmail forwarding list
gog gmail forwarding add --email forward@example.com

# Send-as aliases
gog gmail sendas list
gog gmail sendas create --email alias@example.com

# Vacation responder
gog gmail vacation get
gog gmail vacation enable --subject "Out of office" --message "..."
gog gmail vacation disable
```

## Gmail — Delegation

```bash
gog gmail delegates list
gog gmail delegates add --email delegate@example.com
gog gmail delegates remove --email delegate@example.com
```

## Gmail — Watch (Pub/Sub)

```bash
gog gmail watch start --topic projects/<p>/topics/<t> --label INBOX
gog gmail watch serve --bind 127.0.0.1 --token <shared> --hook-url http://localhost:18789/hooks/agent
gog gmail watch serve --bind 0.0.0.0 --verify-oidc --oidc-email <svc@...> --hook-url <url>
```

## Gmail — Email Tracking

```bash
gog gmail track setup --worker-url https://gog-email-tracker.<acct>.workers.dev
gog gmail send --to x@y.com --subject "Hi" --body-html "<p>Hi</p>" --track
gog gmail track opens <tracking_id>
gog gmail track opens --to x@y.com
gog gmail track status
```

Note: `--track` requires exactly 1 recipient and an HTML body.

## Calendar — List & Search Events

```bash
gog calendar events <calendarId> --today
gog calendar events <calendarId> --tomorrow
gog calendar events <calendarId> --week
gog calendar events <calendarId> --days 3
gog calendar events <calendarId> --from today --to friday
gog calendar events <calendarId> --from today --to friday --weekday  # Day-of-week columns
gog calendar events <calendarId> --from 2025-01-01T00:00:00Z --to 2025-01-08T00:00:00Z
gog calendar events --all --today                  # All calendars
gog calendar events --calendars 1,3                # By index
gog calendar events --cal Work --cal Personal      # By name

gog calendar event <calendarId> <eventId>          # Single event detail
gog calendar get <calendarId> <eventId>            # Alias
gog calendar get <calendarId> <eventId> --json     # JSON with timezone + localized times

gog calendar search "meeting" --today
gog calendar search "meeting" --days 365
gog calendar search "meeting" --from 2025-01-01T00:00:00Z --to 2025-01-31T00:00:00Z --max 50
```

Search defaults to 30 days ago through 90 days ahead unless explicit range given.

## Calendar — Create & Update

```bash
gog calendar create <calendarId> \
  --summary "Meeting" \
  --from 2025-01-15T10:00:00Z \
  --to 2025-01-15T11:00:00Z

gog calendar create <calendarId> \
  --summary "Team Sync" \
  --from 2025-01-15T14:00:00Z \
  --to 2025-01-15T15:00:00Z \
  --attendees "alice@example.com,bob@example.com" \
  --location "Zoom" \
  --send-updates all

gog calendar update <calendarId> <eventId> \
  --summary "Updated Meeting" \
  --from 2025-01-15T11:00:00Z \
  --to 2025-01-15T12:00:00Z

# Add attendees without replacing existing ones
gog calendar update <calendarId> <eventId> \
  --add-attendee "alice@example.com,bob@example.com"
```

## Calendar — Delete & RSVP

```bash
gog calendar delete <calendarId> <eventId>
gog calendar delete <calendarId> <eventId> --send-updates all --force

gog calendar respond <calendarId> <eventId> --status accepted
gog calendar respond <calendarId> <eventId> --status declined
gog calendar respond <calendarId> <eventId> --status tentative

# Propose alternative time (opens browser)
gog calendar propose-time <calendarId> <eventId>
gog calendar propose-time <calendarId> <eventId> --decline --comment "Can we do 5pm?"
```

## Calendar — Recurring Events

```bash
gog calendar create <calendarId> \
  --summary "Payment" \
  --from 2025-02-11T09:00:00-03:00 \
  --to 2025-02-11T09:15:00-03:00 \
  --rrule "RRULE:FREQ=MONTHLY;BYMONTHDAY=11" \
  --reminder "email:3d" \
  --reminder "popup:30m"
```

## Calendar — Special Event Types

```bash
# Focus time
gog calendar create primary --event-type focus-time \
  --from 2025-01-15T13:00:00Z --to 2025-01-15T14:00:00Z
gog calendar focus-time --from 2025-01-15T13:00:00Z --to 2025-01-15T14:00:00Z

# Out of office
gog calendar create primary --event-type out-of-office \
  --from 2025-01-20 --to 2025-01-21 --all-day
gog calendar out-of-office --from 2025-01-20 --to 2025-01-21 --all-day

# Working location
gog calendar create primary --event-type working-location \
  --working-location-type office --working-office-label "HQ" \
  --from 2025-01-22 --to 2025-01-23
gog calendar working-location --type office --office-label "HQ" \
  --from 2025-01-22 --to 2025-01-23
```

## Calendar — Availability

```bash
gog calendar freebusy --calendars "primary,work@example.com" \
  --from 2025-01-15T00:00:00Z --to 2025-01-16T00:00:00Z
gog calendar freebusy --cal Work --from 2025-01-15T00:00:00Z --to 2025-01-16T00:00:00Z

gog calendar conflicts --calendars "primary,work@example.com" --today
gog calendar conflicts --all --today
```

## Calendar — Team Calendars

Requires Cloud Identity API for Google Workspace.

```bash
gog calendar team <group-email> --today
gog calendar team <group-email> --week
gog calendar team <group-email> --freebusy          # Busy/free blocks only
gog calendar team <group-email> --query "standup"   # Filter by title
```

## Calendar — Management

```bash
gog calendar calendars                              # List calendars
gog calendar acl <calendarId>                       # Access control rules
gog calendar colors                                 # Available event colors (IDs 1-11)
gog calendar time --timezone America/New_York        # Show time
gog calendar users                                  # Workspace users
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GOG_ACCOUNT` | Default account email or alias |
| `GOG_ACCESS_TOKEN` | Direct access token (CI/headless) |
| `GOG_CLIENT` | OAuth client name |
| `GOG_JSON` | Default JSON output |
| `GOG_PLAIN` | Default plain output |
| `GOG_COLOR` | Color mode: `auto`, `always`, `never` |
| `GOG_TIMEZONE` | Output timezone (IANA, `UTC`, or `local`) |
| `GOG_ENABLE_COMMANDS` | Allowlist commands (e.g. `calendar,gmail`) |
| `GOG_KEYRING_BACKEND` | Keyring: `auto`, `keychain`, `file` |
| `GOG_KEYRING_PASSWORD` | Password for file keyring (CI) |

## Global Flags

| Flag | Purpose |
|------|---------|
| `--account <email\|alias\|auto>` | Account to use |
| `--json` | JSON output |
| `--plain` | Stable TSV output |
| `--force` | Skip confirmations |
| `--no-input` | Never prompt (CI) |
| `--verbose` | Debug logging |
| `--color <mode>` | Color mode |
| `--enable-commands <csv>` | Allowlist commands |
