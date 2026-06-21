#!/usr/bin/env bash
# Development tooling installer for the opencode container image.
#
# Runs as the unprivileged "opencode" user during the image build and mirrors
# the devcontainer features + .devcontainer/post-create.sh setup:
#   - Oh My Zsh (zsh is the user's default login shell)
#   - Python (latest, managed by Astral uv) + uv tools ty and ruff
#   - Rust (rustup) + the rust-analyzer component for the opencode Rust LSP
#   - Node global tooling: pnpm and typescript
#   - Playwright browsers (chromium, firefox, webkit)
#   - opencode itself, with LSP enabled so servers auto-install on demand
#
# All tools install under $HOME so the image needs no root privileges here.

set -euo pipefail

echo "============================== OPENCODE SETUP ======================================"

# ------------------------------------------------------------------------------
# Oh My Zsh (unattended; keeps the default .zshrc which install scripts append to)
# ------------------------------------------------------------------------------
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ------------------------------------------------------------------------------
# Astral uv + latest Python + uv-managed tools (ty, ruff)
# ------------------------------------------------------------------------------
curl -LsSf https://astral.sh/uv/install.sh | sh

# uv installs to ~/.local/bin; make it available for the rest of this script.
export PATH="${HOME}/.local/bin:${PATH}"

uv python install
uv tool install ty@latest
uv tool install ruff@latest

# ------------------------------------------------------------------------------
# Rust via rustup + rust-analyzer (required by the opencode Rust LSP)
# ------------------------------------------------------------------------------
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
export PATH="${HOME}/.cargo/bin:${PATH}"
rustup component add rust-analyzer

# ------------------------------------------------------------------------------
# Node global tooling: pnpm, typescript, and the Playwright CLI
# (user-local npm prefix, no root)
#
# The browsers themselves are NOT downloaded here. They are large (~GBs) and
# would bloat the image, so PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD keeps the install
# to just the CLI. The browsers are fetched lazily, in the background, on the
# first container start (see entrypoint.sh). Wolfi uses apk, which Playwright's
# `--with-deps` does not support, so the OS libraries are added at the image
# layer instead.
# ------------------------------------------------------------------------------
npm config set prefix "${HOME}/.npm-global"
export PATH="${HOME}/.npm-global/bin:${PATH}"
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install -g pnpm typescript playwright

# ------------------------------------------------------------------------------
# opencode
#
# The official installer drops the binary in ~/.opencode/bin and appends a PATH
# export to the shell rc that matches $SHELL (zsh for this user).
# ------------------------------------------------------------------------------
curl -fsSL https://raw.githubusercontent.com/anomalyco/opencode/refs/heads/dev/install | bash

# ------------------------------------------------------------------------------
# opencode configuration (default location) with LSP enabled so opencode
# auto-installs the language servers for detected file types.
# ------------------------------------------------------------------------------
mkdir -p "${HOME}/.config/opencode"
cat > "${HOME}/.config/opencode/opencode.json" << 'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": true
}
JSON

# ------------------------------------------------------------------------------
# Default workspace
# ------------------------------------------------------------------------------
mkdir -p "${HOME}/workspace"

echo "============================== OPENCODE SETUP COMPLETE =============================="
