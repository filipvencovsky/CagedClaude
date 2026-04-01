#!/bin/bash
# install.sh – set up caged-claude on this machine
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
DATA_DIR="$HOME/.local/share/caged-claude"

# ── helpers ───────────────────────────────────────────────────────────────────

ok()   { echo "  [ok] $*"; }
info() { echo "  [..] $*"; }
die()  { echo "  [!!] $*" >&2; exit 1; }

# ── checks ────────────────────────────────────────────────────────────────────

echo ""
echo "=== caged-claude installer ==="
echo ""

echo "Checking dependencies..."

command -v docker &>/dev/null \
    || die "Docker not found. Install it from https://docs.docker.com/engine/install/"
ok "docker"


# ── directories ───────────────────────────────────────────────────────────────

mkdir -p "$BIN_DIR"
mkdir -p "$DATA_DIR"

# ── PATH ──────────────────────────────────────────────────────────────────────

if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    info "Adding ~/.local/bin to PATH in ~/.bashrc"
    echo '' >> ~/.bashrc
    echo '# caged-claude' >> ~/.bashrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    ok "PATH updated (restart your shell or run: source ~/.bashrc)"
else
    ok "~/.local/bin already in PATH"
fi

# ── install script ────────────────────────────────────────────────────────────

cp "$SCRIPT_DIR/caged-claude" "$BIN_DIR/caged-claude"
chmod +x "$BIN_DIR/caged-claude"
ok "caged-claude installed to $BIN_DIR/caged-claude"

# Save the location of the Dockerfile so the script can rebuild later
echo "$SCRIPT_DIR" > "$DATA_DIR/docker-path"
ok "Build path saved to $DATA_DIR/docker-path"

# ── Docker image ──────────────────────────────────────────────────────────────

echo ""
echo "Building Docker image (this may take a minute)..."
docker build --no-cache -t caged-claude "$SCRIPT_DIR"
touch "$DATA_DIR/last-update"
ok "Docker image built"

# ── done ──────────────────────────────────────────────────────────────────────

echo ""
echo "=== Installation complete ==="
echo ""
echo "Usage:"
echo "  cd ~/your-project"
echo "  caged-claude"
echo ""
echo "Other commands:"
echo "  caged-claude update-claude   force image rebuild"
echo "  caged-claude clean-cage      remove all per-project volumes"
echo "  caged-claude help            show help"
echo ""
