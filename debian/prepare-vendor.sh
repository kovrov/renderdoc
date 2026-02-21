#!/bin/bash
# Download vendor archives required for an offline PPA build.
# Run this once before creating the source package with debuild -S.
#
# Usage:
#   bash debian/prepare-vendor.sh
#
set -euo pipefail

VENDOR_DIR="$(dirname "$0")/vendor"
mkdir -p "$VENDOR_DIR"

SWIG_URL="https://github.com/baldurk/swig/archive/renderdoc-modified-7.zip"
SWIG_DEST="$VENDOR_DIR/swig-renderdoc-modified-7.zip"

# pcre is provided by libpcre3-dev on the target distro — no need to vendor it.

download() {
    local url="$1" dest="$2"
    if [ -f "$dest" ]; then
        echo "Already present: $dest"
        return 0
    fi
    echo "Downloading $url ..."
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$dest" "$url"
    elif command -v curl &>/dev/null; then
        curl -L --progress-bar -o "$dest" "$url"
    else
        echo "Error: neither wget nor curl found." >&2
        exit 1
    fi
    echo "Saved: $dest"
}

download "$SWIG_URL"  "$SWIG_DEST"

# Create the upstream orig tarball from the current git HEAD.
# The upstream version is extracted from debian/changelog.
UPSTREAM_VERSION="$(dpkg-parsechangelog -l "$(dirname "$0")/changelog" -S Version | sed 's/-[^-]*$//')"
SOURCE_NAME="$(dpkg-parsechangelog -l "$(dirname "$0")/changelog" -S Source)"
ORIG_TARBALL="$(dirname "$0")/../../${SOURCE_NAME}_${UPSTREAM_VERSION}.orig.tar.gz"
if [ -f "$ORIG_TARBALL" ]; then
    echo "Already present: $ORIG_TARBALL"
else
    echo "Creating orig tarball: $ORIG_TARBALL"
    git -C "$(dirname "$0")/.." archive \
        --prefix="${SOURCE_NAME}-${UPSTREAM_VERSION}/" HEAD \
        | gzip -9 > "$ORIG_TARBALL"
    echo "Saved: $ORIG_TARBALL"
fi

# Regenerate debian/source/include-binaries from the vendor files we manage.
INCLUDE_BINARIES="$(dirname "$0")/source/include-binaries"
{
    for f in "$VENDOR_DIR"/*.zip "$VENDOR_DIR"/*.tar.gz; do
        [ -f "$f" ] || continue
        # Path must be relative to the source root (parent of debian/).
        realpath --relative-to="$(dirname "$0")/.." "$f"
    done
} | sort > "$INCLUDE_BINARIES"

echo "Updated $INCLUDE_BINARIES"
echo
echo "Vendor archives ready in $VENDOR_DIR"
echo "You can now build and upload the the source package:"
echo "  debuild -S -sa"
echo "  dput <HOST> ../renderdoc_${UPSTREAM_VERSION}_source.changes"
echo "Or run a local build:"
echo "  debuild -b -uc -us"
