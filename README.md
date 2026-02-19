# homelab-claude-skills

Claude Code agent skills for common homelab services.

## Skills

| Skill | Description | Install |
|-------|-------------|---------|
| [caddy-reverse-proxy](caddy-reverse-proxy/) | Caddy reverse proxy configuration and management | `npx skills add ddnetters/homelab-claude-skills@caddy-reverse-proxy` |
| [ntfy-notifications](ntfy-notifications/) | Self-hosted push notifications with ntfy | `npx skills add ddnetters/homelab-claude-skills@ntfy-notifications` |
| [arr-media-stack](arr-media-stack/) | Radarr, Sonarr, Prowlarr, qBittorrent media automation | `npx skills add ddnetters/homelab-claude-skills@arr-media-stack` |
| [langfuse-observability](langfuse-observability/) | LLM observability with Langfuse (traces, costs, metrics) | `npx skills add ddnetters/homelab-claude-skills@langfuse-observability` |
| [plex-media-server](plex-media-server/) | Plex Media Server API and management | `npx skills add ddnetters/homelab-claude-skills@plex-media-server` |

## Install all

```bash
npx skills add ddnetters/homelab-claude-skills
```

## Install one

```bash
npx skills add ddnetters/homelab-claude-skills@<skill-name>
```

## License

MIT
