#!/usr/bin/env bash
set -euo pipefail

# Script to check and update 3x-ui to the latest version
# Usage: ./update.sh [version]
# If version is not specified, shows the latest releases with Go version requirements

# Configuration
REPO_OWNER="MHSanaei"
REPO_NAME="3x-ui"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
NUM_VERSIONS=3  # Number of recent versions to fetch and display

echo "=== 3x-ui Update Script ==="
echo ""

# Prefetch available Go version from nixpkgs
echo "Checking available Go version in nixpkgs..."
GO_VERSION_AVAILABLE=$(nix eval --impure --raw --expr '(import <nixpkgs> {}).go.version' 2>/dev/null || echo "unknown")
echo "Available Go version in nixpkgs: $GO_VERSION_AVAILABLE"
echo ""

# Step 1: Determine version to use
if [ $# -eq 0 ]; then
    echo "Fetching latest ${NUM_VERSIONS} releases from GitHub..."
    RELEASES=$(curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases?per_page=${NUM_VERSIONS}")

    if [ -z "$RELEASES" ] || [ "$RELEASES" = "[]" ]; then
        echo "Error: Failed to fetch releases from GitHub"
        exit 1
    fi

    echo ""
    echo "Latest ${NUM_VERSIONS} releases:"
    echo ""

    # Parse releases and get Go versions
    declare -a VERSIONS
    declare -a GO_VERSIONS

    for i in $(seq 0 $((NUM_VERSIONS - 1))); do
        VERSION=$(echo "$RELEASES" | jq -r ".[$i].tag_name" | sed 's/^v//')

        if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
            break
        fi

        VERSIONS+=("$VERSION")

        # Fetch go.mod for this version
        GO_VERSION=$(curl -sL "${REPO_URL}/raw/v${VERSION}/go.mod" | grep '^go ' | awk '{print $2}' || echo "unknown")
        GO_VERSIONS+=("$GO_VERSION")

        printf "%d) v%-10s (Go %s)\n" $((i+1)) "$VERSION" "$GO_VERSION"
    done

    echo ""
    read -p "Select version (1-${#VERSIONS[@]}) or press Enter to cancel: " SELECTION

    if [ -z "$SELECTION" ]; then
        echo "Cancelled."
        exit 0
    fi

    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt "${#VERSIONS[@]}" ]; then
        echo "Error: Invalid selection"
        exit 1
    fi

    NEW_VERSION="${VERSIONS[$((SELECTION-1))]}"
    GO_VERSION_REQUIRED="${GO_VERSIONS[$((SELECTION-1))]}"

    echo ""
    echo "Selected version: $NEW_VERSION (requires Go $GO_VERSION_REQUIRED)"
else
    NEW_VERSION="$1"
    echo "Using specified version: $NEW_VERSION"
    echo ""
    echo "Checking Go version requirement..."

    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    curl -sL "${REPO_URL}/raw/v${NEW_VERSION}/go.mod" -o "${TEMP_DIR}/go.mod"

    if [ ! -f "${TEMP_DIR}/go.mod" ]; then
        echo "Error: Failed to download go.mod"
        exit 1
    fi

    GO_VERSION_REQUIRED=$(grep '^go ' "${TEMP_DIR}/go.mod" | awk '{print $2}')

    echo "Go version required: $GO_VERSION_REQUIRED"
fi

# Compare Go versions
if [ "$GO_VERSION_AVAILABLE" != "unknown" ] && [ "$GO_VERSION_REQUIRED" != "unknown" ]; then
    if printf '%s\n' "$GO_VERSION_REQUIRED" "$GO_VERSION_AVAILABLE" | sort -V -C; then
        echo "✅ Available Go version is sufficient"
    else
        echo "⚠️  WARNING: Required Go $GO_VERSION_REQUIRED, but only $GO_VERSION_AVAILABLE is available"
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi
fi

echo ""
echo "=== Calculating Hashes ==="

# Calculate source hash
echo "Calculating source hash..."
SRC_HASH_BASE32=$(nix-prefetch-url --unpack "${REPO_URL}/archive/refs/tags/v${NEW_VERSION}.tar.gz" 2>&1 | tail -n1)
SRC_HASH=$(nix hash convert --hash-algo sha256 --to base64 "$SRC_HASH_BASE32" 2>/dev/null || echo "$SRC_HASH_BASE32")
echo "Source hash: sha256-${SRC_HASH}"

# Calculate vendor hash
echo ""
echo "Calculating vendor hash (this may take a while)..."
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

cd "$WORK_DIR"

# Clone the repository
git clone --depth 1 --branch "v${NEW_VERSION}" "${REPO_URL}.git" . >/dev/null 2>&1

# Vendor dependencies using nix-shell to ensure Go is available
VENDOR_HASH=$(nix-shell -p go git --run '
    go mod vendor 2>/dev/null
    nix hash path vendor
')

echo "Vendor hash: ${VENDOR_HASH}"

cd - >/dev/null

echo ""
echo "=== Summary ==="
echo ""
echo "Version:              $NEW_VERSION"
echo "Go version required:  $GO_VERSION_REQUIRED"
echo "Go version available: $GO_VERSION_AVAILABLE"
echo "Source hash:          sha256-${SRC_HASH}"
echo "Vendor hash:          ${VENDOR_HASH}"
echo ""

# Ask if user wants to update module.nix
read -p "Update module.nix with these values? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Updating module.nix..."

    # Update version
    sed -i "s|version = \".*\";|version = \"${NEW_VERSION}\";|" module.nix

    # Update minGoVersion
    sed -i "s|minGoVersion = \".*\";|minGoVersion = \"${GO_VERSION_REQUIRED}\";|" module.nix

    # Update source hash
    sed -i "s|hash = \"sha256-.*\";|hash = \"sha256-${SRC_HASH}\";|" module.nix

    # Update vendor hash (handles both quoted strings and lib.fakeHash)
    if [[ "$VENDOR_HASH" == sha256-* ]]; then
        sed -i "s|vendorHash = .*;|vendorHash = \"${VENDOR_HASH}\";|" module.nix
    else
        sed -i "s|vendorHash = .*;|vendorHash = \"sha256-${VENDOR_HASH}\";|" module.nix
    fi

    echo "✅ module.nix updated successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Review changes: git diff module.nix"
    echo "  2. Test build: nix flake check"
    echo "  3. Commit: git commit -am 'Update to version $NEW_VERSION'"
    echo "  4. Push: git push"
else
    echo "Update cancelled. You can manually update module.nix with the values above."
fi