# caged-claude

Run [Claude Code](https://code.claude.com) in an isolated Docker container.
Each project directory gets its own sandboxed environment and its own Claude
context – projects never share history.

## Why

Claude Code runs directly on your system by default: it can read and write any
file your user can access, and execute arbitrary shell commands. Two protection
mechanisms exist, but each has gaps on its own.

**Claude Code's built-in sandbox** (using `bubblewrap` on Linux) provides
OS-level filesystem and network isolation. You can configure it to deny reads
outside the project directory and restrict outbound network access to an
allowlist of domains. However, the isolation is only as strong as its
configuration — it requires deliberate setup, and a misconfigured or missing
`denyRead` rule silently leaves your home directory readable.

**Docker** provides structural isolation: the container can only see what you
explicitly mount. There is no configuration to get wrong — your SSH keys,
credentials, and other projects are invisible to Claude by construction, not
by policy.

`caged-claude` combines both: Docker enforces the filesystem boundary without
any configuration, while Claude Code's sandbox adds network isolation on top.
The result:

- **Filesystem:** Claude can only see the directory you launched it from.
  SSH keys, `.env` files, and everything else on your host are structurally
  invisible — not just policy-blocked.
- **Network:** With sandbox enabled inside the container, outbound traffic
  can be restricted to an allowlist of domains (e.g. only `api.anthropic.com`).
- **Per-project isolation:** Every project gets its own Docker volume for
  Claude's state (`.claude/`), so contexts and histories never bleed across
  projects.
- **No escape hatch at the filesystem level.** Claude Code's sandbox has an
  intentional `dangerouslyDisableSandbox` mechanism that lets Claude request
  to run commands outside the sandbox. Inside a Docker container, that escape
  hatch still can't reach your host filesystem — Docker's mount boundary holds
  regardless.

## Requirements

- Linux (tested on Ubuntu/Fedora)
- [Docker](https://docs.docker.com/engine/install/)

## Installation

```bash
git clone https://github.com/you/caged-claude.git
cd caged-claude
bash install.sh
```

The installer will:

1. Check that `docker` is available.
2. Add `~/.local/bin` to your `PATH` if it isn't there already.
3. Copy the `caged-claude` script to `~/.local/bin/`.
4. Build the Docker image.

## Usage

```bash
cd ~/your-project
caged-claude
```

That's it. Claude Code starts inside a container that can only access
`~/your-project`.

### Other commands

| Command | Description |
|---|---|
| `caged-claude` | Start Claude Code in the current directory |
| `caged-claude update-claude` | Force a rebuild of the Docker image |
| `caged-claude clean-cage` | Remove all per-project `.claude` volumes |
| `caged-claude help` | Show wrapper help followed by claude's own help |
| `caged-claude [args...]` | Pass arguments directly to claude (e.g. `config`, a prompt) |

The wrapper only intercepts `clean-cage`, `update-claude`, and `help`.
Everything else is forwarded straight to `claude` inside the container, so all
of Claude Code's own flags and subcommands work as normal.

## How it works

### Filesystem isolation

The current directory is bind-mounted to `/workspace` inside the container.
Nothing else on your host filesystem is visible to Claude.

### Per-project context

Claude Code uses the working directory path as a key for storing conversation
history and project context. To preserve this behaviour inside the container,
`entrypoint.sh` creates a symlink at the original host path (e.g.
`/home/user/my-project`) pointing to `/workspace`. Claude therefore "sees" the
real path and stores context under it.

Each project gets its own named Docker volume derived from a hash of the host
path (with the directory basename for readability):

```
/home/user/my-project  →  volume: caged-claude-my-project-a1b2c3d4e5f6
```

Volumes persist across container restarts, so history is not lost between
sessions.

### Network isolation (optional)

Claude Code's built-in sandbox can be enabled inside the container to restrict
outbound network access. Install `bubblewrap` in the image and configure
`.claude/settings.json` in the project volume to allow only the domains Claude
needs. Because the sandbox runs inside Docker, its filesystem restrictions are
redundant — but the network allowlist is additive and genuinely useful.

### Automatic image updates

On each launch `caged-claude` checks whether the Docker image was built more
than `UPDATE_INTERVAL_DAYS` days ago (default: 7). If so, it rebuilds the
image automatically before starting the container. You can change the interval
by editing `UPDATE_INTERVAL_DAYS` at the top of the `caged-claude` script.

You can also trigger a rebuild at any time:

```bash
caged-claude update-claude
```

### Authentication

Authentication is handled by Claude Code itself. On first launch, Claude Code
will prompt you to log in. Login state is stored in the per-project Docker
volume (`~/.claude/` inside the container), so you stay logged in across
sessions for that project.

### Cleaning up volumes

To remove all per-project volumes created by `caged-claude` (this deletes
Claude's history for all projects):

```bash
caged-claude clean-cage
```

The command lists the volumes and asks for confirmation before deleting
anything.

## Repository structure

```
caged-claude/
├── README.md        this file
├── install.sh       installer
├── Dockerfile       container image definition
├── entrypoint.sh    container entrypoint (sets up path symlink)
└── caged-claude     main script (copied to ~/.local/bin/)
```

## Limitations

- **Network isolation requires extra setup.** The container has full network
  access by default. Restricting it requires enabling Claude Code's built-in
  sandbox inside the container (`bubblewrap`) and configuring a domain
  allowlist.
- **Linux only.** The script uses bash and Docker; it has not been tested on
  macOS or Windows.
