#!/bin/bash
# Build ButtonDack packages for Arch Linux (.pkg.tar.zst) and Debian (.deb)

set -e

VERSION="${VERSION:-1.0.0}"
BUILD_DIR="$(dirname "$0")/../daemon/build"
PKG_DIR="$(dirname "$0")/pkg"
mkdir -p "$PKG_DIR" "$BUILD_DIR"

echo "==> Building daemon binaries..."
cd "$(dirname "$0")/../daemon"

# Build Linux amd64
GOOS=linux GOARCH=amd64 go build -ldflags "-X main.version=$VERSION" -o "$BUILD_DIR/buttondackd-linux-amd64" ./cmd/buttondackd/

# Build Linux arm64
GOOS=linux GOARCH=arm64 go build -ldflags "-X main.version=$VERSION" -o "$BUILD_DIR/buttondackd-linux-arm64" ./cmd/buttondackd/

# Build Windows
GOOS=windows GOARCH=amd64 go build -ldflags "-X main.version=$VERSION" -o "$BUILD_DIR/buttondackd.exe" ./cmd/buttondackd/

echo "==> Building .deb package..."
DEB_DIR="$PKG_DIR/buttondack_${VERSION}_amd64"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/local/bin"
mkdir -p "$DEB_DIR/etc/buttondack"
mkdir -p "$DEB_DIR/lib/systemd/system"

cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: buttondack
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: ButtonDack Team
Description: ButtonDack Daemon - Remote PC control with Spotify integration
 A daemon that provides WebSocket/REST API for controlling your PC
 from a Flutter mobile app, with Spotify now-playing support.
EOF

cp "$BUILD_DIR/buttondackd-linux-amd64" "$DEB_DIR/usr/local/bin/buttondackd"
chmod 755 "$DEB_DIR/usr/local/bin/buttondackd"
cp "$(dirname "$0")/buttondack.service" "$DEB_DIR/lib/systemd/system/"

dpkg-deb --build "$DEB_DIR"
echo "==> .deb package created: $(ls $PKG_DIR/*.deb)"

echo "==> Building Arch package..."
ARCH_DIR="$PKG_DIR/buttondack-$VERSION"
mkdir -p "$ARCH_DIR/usr/local/bin"
mkdir -p "$ARCH_DIR/etc/buttondack"
mkdir -p "$ARCH_DIR/usr/lib/systemd/system"

cat > "$ARCH_DIR/.PKGINFO" << EOF
pkgname = buttondack
pkgver = $VERSION-1
pkgdesc = ButtonDack Daemon - Remote PC control with Spotify integration
url = https://github.com/DerTraurigeHund/ButtonDack
builddate = $(date +%s)
packager = ButtonDack Team
size = $(stat -f%z "$BUILD_DIR/buttondackd-linux-amd64" 2>/dev/null || stat -c%s "$BUILD_DIR/buttondackd-linux-amd64")
arch = x86_64
EOF

cat > "$ARCH_DIR/.INSTALL" << 'EOF'
post_install() {
    echo "Enable with: systemctl enable --now buttondack@$(whoami)"
    echo "Config at: /etc/buttondack/config.yaml"
}
EOF

install -Dm755 "$BUILD_DIR/buttondackd-linux-amd64" "$ARCH_DIR/usr/local/bin/buttondackd"
install -Dm644 "$(dirname "$0")/buttondack.service" "$ARCH_DIR/usr/lib/systemd/system/buttondack.service"

# Create .MTREE
(cd "$ARCH_DIR" && find . -type f -exec sha256sum {} \; > .MTREE)

# Create tar.zst
cd "$PKG_DIR"
tar -c --zstd -f "buttondack-$VERSION-1-x86_64.pkg.tar.zst" -C "$ARCH_DIR" .
echo "==> Arch package created: $(ls $PKG_DIR/*.pkg.tar.zst)"

echo ""
echo "Done! Packages:"
ls -lh "$PKG_DIR"/*.deb "$PKG_DIR"/*.pkg.tar.zst 2>/dev/null || true
