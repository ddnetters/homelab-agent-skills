# homelab-agent-skills

Agent skills for common homelab services. Works with Claude Code, Cursor, Windsurf, and any agent that supports the [skills.sh](https://skills.sh) ecosystem.

## Skills

| Skill | Description | Install |
|-------|-------------|---------|
| [caddy-reverse-proxy](caddy-reverse-proxy/) | Caddy reverse proxy configuration and management | `npx skills add ddnetters/homelab-agent-skills@caddy-reverse-proxy` |
| [ntfy-notifications](ntfy-notifications/) | Self-hosted push notifications with ntfy | `npx skills add ddnetters/homelab-agent-skills@ntfy-notifications` |
| [arr-media-stack](arr-media-stack/) | Radarr, Sonarr, Prowlarr, qBittorrent media automation | `npx skills add ddnetters/homelab-agent-skills@arr-media-stack` |
| [langfuse-observability](langfuse-observability/) | LLM observability with Langfuse (traces, costs, metrics) | `npx skills add ddnetters/homelab-agent-skills@langfuse-observability` |
| [plex-media-server](plex-media-server/) | Plex Media Server API and management | `npx skills add ddnetters/homelab-agent-skills@plex-media-server` |

## Install all

```bash
npx skills add ddnetters/homelab-agent-skills
```

## Install one

```bash
npx skills add ddnetters/homelab-agent-skills@<skill-name>
```

## License

MIT
