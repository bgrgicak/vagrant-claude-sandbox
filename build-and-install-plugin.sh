#!/usr/bin/env bash
set -euo pipefail

GEMSPEC="vagrant-claude-sandbox.gemspec"
PLUGIN_NAME="vagrant-claude-sandbox"

version=$(ruby -I lib -e "require 'vagrant-claude-sandbox/version'; puts VagrantPlugins::ClaudeSandbox::VERSION")
gem_file="${PLUGIN_NAME}-${version}.gem"

echo "==> Building gem (v${version})..."
gem build "$GEMSPEC"

echo "==> Destroying existing environment..."
vagrant destroy -f 2>/dev/null || true

echo "==> Uninstalling old plugin..."
vagrant plugin uninstall "$PLUGIN_NAME" 2>/dev/null || true

echo "==> Installing ${gem_file}..."
vagrant plugin install "$gem_file"

echo "==> Starting environment..."
vagrant up

echo "==> Done. Run 'vagrant claude' to launch Claude CLI."
