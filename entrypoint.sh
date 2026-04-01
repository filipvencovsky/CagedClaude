#!/bin/bash
set -e

# ── UID/GID mapping ──────────────────────────────────────────────────────────
# Match the container user to the host user so that files created in the
# bind-mounted workspace have correct ownership on the host.

HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"

groupmod -o -g "$HOST_GID" claude 2>/dev/null || true
usermod -o -u "$HOST_UID" -g "$HOST_GID" claude 2>/dev/null || true

chown "$HOST_UID:$HOST_GID" /home/claude
chown -R "$HOST_UID:$HOST_GID" /home/claude/.claude 2>/dev/null || true

# ── workspace symlink ────────────────────────────────────────────────────────
# CLAUDE_WORKSPACE contains the original host path (e.g. /home/user/project).
# We recreate that path structure inside the container via a symlink so that
# Claude Code stores history under the real path instead of /workspace.

if [[ -n "$CLAUDE_WORKSPACE" ]]; then
    parent=$(dirname "$CLAUDE_WORKSPACE")
    mkdir -p "$parent"
    if [[ ! -e "$CLAUDE_WORKSPACE" ]]; then
        ln -sf /workspace "$CLAUDE_WORKSPACE"
    fi
    cd "$CLAUDE_WORKSPACE"
else
    cd /workspace
fi

export HOME=/home/claude
exec gosu claude claude "$@"
