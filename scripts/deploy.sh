#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# RetroHexChat — Server-side build & deploy via DeployEx
#
# Usage:  bash deploy.sh <git-ref>
#         bash deploy.sh main
#         bash deploy.sh sun-2026-02-18.01
#
# This script runs ON the server (Sun or Moon). It:
#   1. Checks out the requested git ref
#   2. Builds a release tarball
#   3. Copies it to the DeployEx dist directory
#   4. Writes current.json so DeployEx picks up the new version
# ------------------------------------------------------------------

APP_NAME="retro_hex_chat"
SOURCE_DIR="$HOME/retro_hex_chat"
DIST_DIR="$HOME/releases/dist/${APP_NAME}"
VERSIONS_DIR="$HOME/releases/versions/${APP_NAME}/local"

GIT_REF="${1:?Usage: deploy.sh <git-ref>}"

echo "==> Deploy starting for ${APP_NAME} @ ${GIT_REF}"
echo "==> Source dir: ${SOURCE_DIR}"

# ------------------------------------------------------------------
# 1. Update source and checkout ref
# ------------------------------------------------------------------
cd "${SOURCE_DIR}"

echo "==> Fetching latest from origin..."
git fetch --all --prune

echo "==> Checking out ${GIT_REF}..."
git checkout "${GIT_REF}" --
git pull origin "${GIT_REF}" 2>/dev/null || true

echo "==> Pulling Git LFS files..."
git lfs pull

FULL_SHA=$(git rev-parse HEAD)
SHORT_SHA=$(git rev-parse --short HEAD)
MIX_VERSION=$(grep 'version:' mix.exs | head -1 | sed 's/.*"\(.*\)".*/\1/')
RELEASE_VERSION="${MIX_VERSION}-${SHORT_SHA}"

echo "==> Version: ${RELEASE_VERSION} (SHA: ${FULL_SHA})"

# ------------------------------------------------------------------
# 2. Patch version in mix.exs (temporary — restored after build)
# ------------------------------------------------------------------
echo "==> Patching mix.exs version to ${RELEASE_VERSION}..."
sed -i.bak "s/version: \"${MIX_VERSION}\"/version: \"${RELEASE_VERSION}\"/" mix.exs

cleanup() {
  echo "==> Restoring original mix.exs..."
  mv mix.exs.bak mix.exs 2>/dev/null || true
}
trap cleanup EXIT

# ------------------------------------------------------------------
# 3. Install dependencies & build assets
# ------------------------------------------------------------------
echo "==> Loading asdf environment..."
# shellcheck disable=SC1091
source "$HOME/.asdf/asdf.sh" 2>/dev/null || source /opt/asdf-vm/asdf.sh 2>/dev/null || true

export MIX_ENV=prod

echo "==> Installing Elixir deps..."
mix local.hex --force --if-missing
mix local.rebar --force --if-missing
mix deps.get --only prod

echo "==> Installing Node.js deps..."
npm install --prefix apps/retro_hex_chat_web/assets

echo "==> Compiling (MIX_ENV=prod)..."
mix compile

echo "==> Building assets..."
mix assets.deploy

echo "==> Building release..."
mix release retro_hex_chat --overwrite

# ------------------------------------------------------------------
# 4. Copy tarball to DeployEx dist directory
# ------------------------------------------------------------------
TARBALL="_build/prod/${APP_NAME}-${RELEASE_VERSION}.tar.gz"

if [ ! -f "${TARBALL}" ]; then
  echo "ERROR: Tarball not found at ${TARBALL}" >&2
  echo "==> Listing _build/prod/ for debugging:"
  ls -la _build/prod/*.tar.gz 2>/dev/null || echo "(no tarballs found)"
  exit 1
fi

mkdir -p "${DIST_DIR}" "${VERSIONS_DIR}"

echo "==> Copying tarball to ${DIST_DIR}/"
cp "${TARBALL}" "${DIST_DIR}/${APP_NAME}-${RELEASE_VERSION}.tar.gz"

# ------------------------------------------------------------------
# 5. Write current.json for DeployEx
# ------------------------------------------------------------------
CURRENT_JSON="${VERSIONS_DIR}/current.json"

echo "==> Writing ${CURRENT_JSON}"
cat > "${CURRENT_JSON}" <<EOF
{
  "version": "${RELEASE_VERSION}",
  "hash": "${FULL_SHA}",
  "pre_commands": ["eval RetroHexChat.Release.migrate"]
}
EOF

# ------------------------------------------------------------------
# 6. Fix permissions — DeployEx runs as the 'deployex' user and needs
#    read access to the tarball and current.json written by 'rodrigo'.
# ------------------------------------------------------------------
echo "==> Fixing permissions for DeployEx..."
chmod o+rx "${DIST_DIR}" "${VERSIONS_DIR}"
chmod o+r "${DIST_DIR}/${APP_NAME}-${RELEASE_VERSION}.tar.gz" "${CURRENT_JSON}"

echo "==> Deploy complete!"
echo "    App:     ${APP_NAME}"
echo "    Version: ${RELEASE_VERSION}"
echo "    SHA:     ${FULL_SHA}"
echo "    Tarball: ${DIST_DIR}/${APP_NAME}-${RELEASE_VERSION}.tar.gz"
echo "    DeployEx should pick up the new version within ~5 seconds."
