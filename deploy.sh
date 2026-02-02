#!/usr/bin/env bash
set -euo pipefail

GEM_NAME="vagrant-claude-sandbox"
VERSION_FILE="lib/vagrant-claude-sandbox/version.rb"
GEMSPEC_FILE="${GEM_NAME}.gemspec"

# --- Helpers ---

current_version() {
  ruby -r "./lib/vagrant-claude-sandbox/version" -e "puts VagrantPlugins::ClaudeSandbox::VERSION"
}

usage() {
  cat <<EOF
Usage: $0 <new_version>

Bumps the version, builds the gem, publishes to RubyGems, and creates a git tag.

Steps performed:
  1. Validate the new version
  2. Run tests
  3. Update version in ${VERSION_FILE}
  4. Build the gem
  5. Publish to RubyGems
  6. Create and push a git tag

Example:
  $0 0.4.0
EOF
  exit 1
}

confirm() {
  local prompt="$1"
  read -r -p "${prompt} [y/N] " answer
  case "$answer" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Validation ---

if [[ $# -ne 1 ]]; then
  usage
fi

NEW_VERSION="$1"

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must follow semver format (e.g. 0.4.0)"
  exit 1
fi

OLD_VERSION=$(current_version)

if [[ "$NEW_VERSION" == "$OLD_VERSION" ]]; then
  echo "Error: New version ($NEW_VERSION) is the same as current version ($OLD_VERSION)"
  exit 1
fi

echo "Current version: ${OLD_VERSION}"
echo "New version:     ${NEW_VERSION}"
echo ""

# --- Pre-publish checks ---

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Warning: Working directory has uncommitted changes."
  if ! confirm "Continue anyway?"; then
    echo "Aborted."
    exit 1
  fi
fi

if ! confirm "Run tests before deploying?"; then
  echo "Skipping tests."
else
  echo "Running tests..."
  bundle exec rake spec
  echo "Tests passed."
fi

# --- Version bump ---

echo ""
echo "Bumping version from ${OLD_VERSION} to ${NEW_VERSION}..."
sed -i "s/VERSION = \"${OLD_VERSION}\"/VERSION = \"${NEW_VERSION}\"/" "$VERSION_FILE"
echo "Updated ${VERSION_FILE}"

# Verify the version was updated correctly
VERIFY_VERSION=$(current_version)
if [[ "$VERIFY_VERSION" != "$NEW_VERSION" ]]; then
  echo "Error: Version file update failed. Expected ${NEW_VERSION}, got ${VERIFY_VERSION}"
  exit 1
fi

# --- Build ---

echo ""
echo "Building gem..."
rm -f ${GEM_NAME}-*.gem
gem build "$GEMSPEC_FILE"

GEM_FILE="${GEM_NAME}-${NEW_VERSION}.gem"
if [[ ! -f "$GEM_FILE" ]]; then
  echo "Error: Expected gem file ${GEM_FILE} not found"
  exit 1
fi

echo "Built ${GEM_FILE}"

# --- Publish ---

echo ""
if ! confirm "Publish ${GEM_FILE} to RubyGems?"; then
  echo "Skipping publish. You can manually publish later with:"
  echo "  gem push ${GEM_FILE}"
  echo "  git tag -a v${NEW_VERSION} -m \"Release v${NEW_VERSION}\""
  echo "  git push origin v${NEW_VERSION}"
  exit 0
fi

echo "Publishing to RubyGems..."
gem push "$GEM_FILE"
echo "Published ${GEM_FILE} to RubyGems."

# --- Git tag ---

echo ""
echo "Creating git tag v${NEW_VERSION}..."
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
echo "Created tag v${NEW_VERSION}"

if confirm "Push tag v${NEW_VERSION} to origin?"; then
  git push origin "v${NEW_VERSION}"
  echo "Pushed tag v${NEW_VERSION} to origin."
else
  echo "Skipping tag push. You can push later with:"
  echo "  git push origin v${NEW_VERSION}"
fi

echo ""
echo "Deploy complete!"
echo ""
echo "Next steps:"
echo "  - Verify at https://rubygems.org/gems/${GEM_NAME}"
echo "  - Create a GitHub release at https://github.com/bgrgicak/${GEM_NAME}/releases"
echo "  - Test installation: vagrant plugin install ${GEM_NAME}"
