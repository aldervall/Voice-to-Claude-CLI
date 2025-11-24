#!/bin/bash
# Sync main repo changes to AUR package
# Usage: ./scripts/sync-aur.sh [version]
# Example: ./scripts/sync-aur.sh 1.5.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUR_DIR="$PROJECT_ROOT/aur"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get version from argument or git tag
if [ -n "$1" ]; then
    VERSION="$1"
else
    VERSION=$(git -C "$PROJECT_ROOT" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
    if [ -z "$VERSION" ]; then
        echo_error "No version specified and no git tags found"
        echo "Usage: $0 <version>"
        exit 1
    fi
fi

echo_info "Syncing AUR package for version $VERSION"

# Check AUR directory exists
if [ ! -d "$AUR_DIR" ]; then
    echo_error "AUR directory not found: $AUR_DIR"
    exit 1
fi

# Download release tarball and calculate checksum
TARBALL_URL="https://github.com/aldervall/Voicetype/archive/v${VERSION}.tar.gz"
echo_info "Fetching checksum from: $TARBALL_URL"

CHECKSUM=$(curl -sL "$TARBALL_URL" | sha256sum | cut -d' ' -f1)
if [ -z "$CHECKSUM" ] || [ "$CHECKSUM" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]; then
    echo_error "Failed to download release or release not found"
    echo "Make sure v$VERSION is released on GitHub"
    exit 1
fi

echo_info "SHA256: $CHECKSUM"

# Update PKGBUILD
PKGBUILD="$AUR_DIR/PKGBUILD"
echo_info "Updating PKGBUILD..."

# Update version
sed -i "s/^pkgver=.*/pkgver=$VERSION/" "$PKGBUILD"

# Update checksum
sed -i "s/^sha256sums=.*/sha256sums=('$CHECKSUM')/" "$PKGBUILD"

# Reset pkgrel to 1 for new version
sed -i "s/^pkgrel=.*/pkgrel=1/" "$PKGBUILD"

# Copy install file if it exists in main repo
if [ -f "$PROJECT_ROOT/aur-files/voicetype.install" ]; then
    cp "$PROJECT_ROOT/aur-files/voicetype.install" "$AUR_DIR/"
    echo_info "Copied voicetype.install"
fi

# Regenerate .SRCINFO
echo_info "Regenerating .SRCINFO..."
cd "$AUR_DIR"
makepkg --printsrcinfo > .SRCINFO

echo ""
echo_info "AUR package synced successfully!"
echo ""
echo "Next steps:"
echo "  cd $AUR_DIR"
echo "  git diff  # Review changes"
echo "  git add PKGBUILD .SRCINFO voicetype.install"
echo "  git commit -m \"Update to $VERSION\""
echo "  git push origin master"
