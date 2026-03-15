# waonder-claude-plugin

Claude Code plugin exclusively for **Waonder apps** — provides custom skills, agents, and hooks for mobile, backend, and infrastructure development.

## Installation

### Option 1: Global Install for Local Development (Recommended)

```bash
cd waonder-claude-plugin
chmod +x scripts/setup-local.sh
./scripts/setup-local.sh
```

This registers the plugin globally with a cache symlink. Changes are picked up on every session restart.

### Option 2: Local Development

```bash
claude --plugin-dir /path/to/waonder-claude-plugin
```

## Usage

Once installed, access skills with the `waonder-claude-plugin:` prefix:

```bash
/waonder-claude-plugin:waonder-help
/waonder-claude-plugin:waonder-setup-locally
```

## Plugin Structure

```
waonder-claude-plugin/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   └── marketplace.json     # Marketplace catalog
├── skills/                  # Custom slash commands
│   ├── waonder-help/
│   │   └── SKILL.md
│   └── waonder-setup-locally/
│       └── SKILL.md
├── agents/                  # Specialized AI agents
├── hooks/
│   └── hooks.json           # Event handlers
├── scripts/
│   └── setup-local.sh       # Global setup script
├── CLAUDE.md                # Project rules
├── LICENSE
└── README.md
```

## Adding Skills

Create a new directory under `skills/` with a `SKILL.md` file:

```
skills/
└── my-new-skill/
    └── SKILL.md
```

### Skill Naming Convention

| Domain | Platforms | Example |
|--------|-----------|---------|
| `generic` | (none) | `waonder-help` |
| `mobile` | ios, android, web | `mobile-android-auth-flow` |
| `backend` | services, infrastructure, database | `backend-services-api-reviewer` |

## License

MIT License - see [LICENSE](LICENSE) for details.
