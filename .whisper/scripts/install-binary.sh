#!/usr/bin/env bash
# Fallback: Build whisper-server from source if pre-built binary doesn't work
# NOTE: We DO NOT use 'set -e' to allow graceful error handling

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
MODELS_DIR="$SCRIPT_DIR/../models"
BUILD_DIR="/tmp/whisper.cpp"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  🔨 Building whisper.cpp from Source                 ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "This creates a binary optimized for your system"
echo "Required tools: git, cmake, make, g++ or clang++"
echo ""

# Check for required tools
MISSING_TOOLS=""
for cmd in git cmake make; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_TOOLS="$MISSING_TOOLS $cmd"
    fi
done

# Check for C++ compiler
if ! command -v g++ &> /dev/null && ! command -v clang++ &> /dev/null; then
    MISSING_TOOLS="$MISSING_TOOLS g++"
fi

if [ -n "$MISSING_TOOLS" ]; then
    echo "✗ Error: Missing required build tools:$MISSING_TOOLS"
    echo ""
    echo "Install with:"
    echo "  Arch:   sudo pacman -S git cmake make base-devel"
    echo "  Ubuntu: sudo apt install git cmake make build-essential"
    echo "  Fedora: sudo dnf install git cmake make gcc-c++"
    echo ""
    exit 1
fi

# Clone whisper.cpp
echo "▶ Cloning whisper.cpp repository..."
if [ -d "$BUILD_DIR" ]; then
    echo "  Build directory exists, cleaning it..."
    rm -rf "$BUILD_DIR"
fi

if ! git clone --depth 1 https://github.com/ggerganov/whisper.cpp "$BUILD_DIR" 2>&1; then
    echo "✗ Failed to clone whisper.cpp repository"
    echo "  Check your internet connection and try again"
    exit 1
fi

cd "$BUILD_DIR"

# Configure with CMake (modern build system, better than Makefile)
echo ""
echo "▶ Configuring build with CMake..."
echo "  • Building whisper-server only (not all examples)"
echo "  • Using static libraries for better portability"
echo "  • Release build for optimal performance"
echo ""

if ! cmake -B build \
    -DWHISPER_BUILD_SERVER=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release 2>&1; then
    echo "✗ CMake configuration failed"
    exit 1
fi

# Build
echo ""
echo "▶ Building whisper-server (this may take 30-120 seconds)..."
NPROC=$(nproc 2>/dev/null || echo 4)
echo "  Using $NPROC parallel jobs"
echo ""

if ! cmake --build build --config Release --target whisper-server -j"$NPROC" 2>&1; then
    echo "✗ Build failed"
    echo ""
    echo "Common issues:"
    echo "  • Insufficient disk space in /tmp"
    echo "  • Missing development libraries"
    echo "  • Outdated compiler version"
    exit 1
fi

# Verify build succeeded
if [ ! -f "$BUILD_DIR/build/bin/whisper-server" ]; then
    echo "✗ Build completed but binary not found at expected location"
    echo "  Expected: $BUILD_DIR/build/bin/whisper-server"
    exit 1
fi

# Copy binary
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        TARGET="$BIN_DIR/whisper-server-linux-x64"
        ;;
    aarch64|arm64)
        TARGET="$BIN_DIR/whisper-server-linux-arm64"
        ;;
    *)
        echo "⚠ Warning: Unknown architecture $ARCH, using generic name"
        TARGET="$BIN_DIR/whisper-server"
        ;;
esac

echo ""
echo "▶ Installing binary..."
mkdir -p "$BIN_DIR"
cp "$BUILD_DIR/build/bin/whisper-server" "$TARGET"
chmod +x "$TARGET"

# Verify the built binary works
echo ""
echo "▶ Verifying binary..."
if ldd "$TARGET" 2>&1 | grep -q "not found"; then
    echo "⚠ Warning: Built binary still has missing dependencies:"
    ldd "$TARGET" 2>&1 | grep "not found" | sed 's/^/  /'
    echo ""
    echo "This might still work, but if it fails, install missing system libraries"
else
    echo "✓ Binary looks good (all dependencies satisfied)"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  ✓ Build Complete!                                   ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "Binary: $TARGET"
echo "Size:   $(ls -lh "$TARGET" | awk '{print $5}')"
echo ""

# Model download is handled by parent script (install-whisper.sh)
exit 0
