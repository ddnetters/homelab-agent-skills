# agent-skills

A curated collection of agent skills for developer tools, infrastructure, media automation, and more. Works with Claude Code, Cursor, Windsurf, and any agent that supports the [skills.sh](https://skills.sh) ecosystem.

## Skills

| Skill | Description | Install |
|-------|-------------|---------|
| [caddy-reverse-proxy](caddy-reverse-proxy/) | Caddy reverse proxy configuration and management | `npx skills add ddnetters/agent-skills@caddy-reverse-proxy` |
| [ntfy-notifications](ntfy-notifications/) | Self-hosted push notifications with ntfy | `npx skills add ddnetters/agent-skills@ntfy-notifications` |
| [arr-media-stack](arr-media-stack/) | Radarr, Sonarr, Prowlarr, qBittorrent media automation | `npx skills add ddnetters/agent-skills@arr-media-stack` |
| [langfuse-observability](langfuse-observability/) | LLM observability with Langfuse (traces, costs, metrics) | `npx skills add ddnetters/agent-skills@langfuse-observability` |
| [plex-media-server](plex-media-server/) | Plex Media Server API and management | `npx skills add ddnetters/agent-skills@plex-media-server` |
| [slite-knowledge-base](slite-knowledge-base/) | Slite knowledge base API — ask, search, notes, and knowledge health | `npx skills add ddnetters/agent-skills@slite-knowledge-base` |
| [invoking-codex-exec](invoking-codex-exec/) | One-shot `codex exec` dispatch — flags, sandbox traps, PID-based monitoring, recovery | `npx skills add ddnetters/agent-skills@invoking-codex-exec` |
| [codex-task-waves](codex-task-waves/) | Single-task codex delegation — plan → split into waves → dispatch → review → PR | `npx skills add ddnetters/agent-skills@codex-task-waves` |
| [codex-issue-waves](codex-issue-waves/) | Multi-issue parallel codex batches in isolated worktrees, then review and merge waves | `npx skills add ddnetters/agent-skills@codex-issue-waves` |

See [CODEX_WAVES.md](CODEX_WAVES.md) for the end-to-end flowchart across the three codex skills.

## Install all

```bash
npx skills add ddnetters/agent-skills
```

## Install one

```bash
npx skills add ddnetters/agent-skills@<skill-name>
```

## License

MIT
