# Contributing

Thanks for helping improve agent-skills!

## Adding a new skill

1. Create a folder with your skill name: `my-skill/SKILL.md`
2. Add YAML frontmatter with `name` and `description`
3. Write clear, copy-paste-ready examples
4. Test commands against the actual service
5. Open a PR

## Updating an existing skill

- Fix incorrect commands or outdated API endpoints
- Add missing patterns or troubleshooting tips
- Improve clarity

## Rules

- **No credentials.** Use placeholders like `YOUR_API_KEY`, `your-server.example.com`
- **Test your examples.** Don't guess at API endpoints — verify them
- **Keep it practical.** Focus on commands people actually run, not exhaustive API docs
- **One SKILL.md per skill.** Keep everything in a single file for easy installation

## Skill format

```markdown
---
name: my-skill
description: One-line description for search/discovery
---

# Skill Title

Overview of what this skill covers.

## Section

\`\`\`bash
# Example commands with placeholders
curl -H "X-Api-Key: YOUR_KEY" http://localhost:8080/api/endpoint
\`\`\`

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Common issue | How to fix it |
```
