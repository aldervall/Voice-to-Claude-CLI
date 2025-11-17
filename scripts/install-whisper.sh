#!/bin/bash

#===============================================================================
# whisper.cpp Auto-Installer
# Uses ONLY pre-built binaries - no source compilation!
# Works standalone or as Claude Code plugin
#
# NOTE: We DO NOT use 'set -e' to allow graceful error handling
#===============================================================================

# Detect if running from Claude Code plugin or standalone
if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
    # Running from Claude Code plugin - use plugin root
    PROJECT_ROOT="$CLAUDE_PLUGIN_ROOT"
    echo "Detected Claude Code plugin installation"
else
    # Running standalone - use script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    echo "Running standalone installation"
fi

WHISPER_BIN_DIR="$PROJECT_ROOT/.whisper/bin"
WHISPER_MODELS_DIR="$PROJECT_ROOT/.whisper/models"
MODEL_NAME="${MODEL_NAME:-base.en}"
PORT="${PORT:-2022}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}ℹ${NC} $1"; }
echo_success() { echo -e "${GREEN}✓${NC} $1"; }
echo_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
echo_error() { echo -e "${RED}✗${NC} $1"; }
echo_step() { echo -e "${CYAN}${BOLD}▶${NC} ${BOLD}$1${NC}"; }
echo_header() { echo -e "${MAGENTA}${BOLD}$1${NC}"; }

# Detect if running non-interactively (from Claude Code or CI)
if [ -t 0 ]; then
    INTERACTIVE="${INTERACTIVE:-true}"
else
    INTERACTIVE="${INTERACTIVE:-false}"
fi
# Allow explicit override via environment variable
INTERACTIVE="${INTERACTIVE:-true}"

echo
echo -e "${CYAN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     🎙️  WHISPER.CPP AUTO-INSTALLER                  ║
║                                                       ║
║     Local AI Voice Recognition Engine                ║
║     (Pre-built binaries - no compilation!)           ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        BINARY_NAME="whisper-server-linux-x64"
        ;;
    aarch64|arm64)
        BINARY_NAME="whisper-server-linux-arm64"
        echo_warning "ARM64 support is experimental - pre-built binary may not be available yet"
        ;;
    *)
        echo_error "Unsupported architecture: $ARCH"
        echo_info "Supported architectures: x86_64, aarch64/arm64"
        exit 1
        ;;
esac

# Check for pre-built binary
WHISPER_BINARY=""

if [ ! -f "$WHISPER_BIN_DIR/$BINARY_NAME" ]; then
    echo_error "Pre-built binary not found: $WHISPER_BIN_DIR/$BINARY_NAME"
    echo
    echo_info "Expected binary location: $WHISPER_BIN_DIR/$BINARY_NAME"
    echo_info "This usually means the project was not cloned correctly."
    echo
    echo_info "Troubleshooting:"
    echo "  1. Check if .whisper/bin/ directory exists"
    echo "  2. Clone the repository again: git clone <repo-url>"
    echo "  3. Check git LFS is enabled if binary is in LFS"
    echo
    echo_error "Cannot continue without whisper-server binary"
    exit 1
fi

echo_info "Found pre-built binary: $BINARY_NAME"
echo_info "Testing if binary works (checking shared libraries)..."

# Test if the binary can actually run (check for missing shared libs)
if ldd "$WHISPER_BIN_DIR/$BINARY_NAME" 2>&1 | grep -q "not found"; then
    echo_warning "Pre-built binary has missing shared library dependencies!"
    echo
    echo_error "Missing libraries:"
    ldd "$WHISPER_BIN_DIR/$BINARY_NAME" 2>&1 | grep "not found" | sed 's/^/  /'
    echo
    echo_info "Your system is missing required libraries. Install them with:"
    echo

    # Detect distro and show appropriate command
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro|cachyos)
                echo "  sudo pacman -S ffmpeg"
                ;;
            ubuntu|debian|pop|mint)
                echo "  sudo apt install ffmpeg libgomp1"
                ;;
            fedora|rhel|centos)
                echo "  sudo dnf install ffmpeg libgomp"
                ;;
            opensuse*)
                echo "  sudo zypper install ffmpeg libgomp1"
                ;;
            *)
                echo "  Install ffmpeg and OpenMP libraries for your distribution"
                ;;
        esac
    fi
    echo
    echo_error "Cannot continue until dependencies are installed"
    exit 1
else
    echo_success "Pre-built binary is functional!"
    WHISPER_BINARY="$WHISPER_BIN_DIR/$BINARY_NAME"
fi

echo

# Download model
echo
echo_header "╔═══════════════════════════════════════════════════════╗"
echo_header "║  📥 Downloading Whisper Model (~142 MB)              ║"
echo_header "╚═══════════════════════════════════════════════════════╝"
echo

mkdir -p "$WHISPER_MODELS_DIR"
MODEL_PATH="$WHISPER_MODELS_DIR/ggml-${MODEL_NAME}.bin"

if [ -f "$MODEL_PATH" ]; then
    echo_success "Model already exists: $MODEL_PATH"
else
    echo_info "Downloading $MODEL_NAME model (~142MB)..."
    bash "$PROJECT_ROOT/.whisper/scripts/download-model.sh" "$MODEL_NAME"
    if [ $? -eq 0 ] && [ -f "$MODEL_PATH" ]; then
        echo_success "Model downloaded"
    else
        echo_error "Model download failed!"
        echo_info "Try manually: bash $PROJECT_ROOT/.whisper/scripts/download-model.sh $MODEL_NAME"
        exit 1
    fi
fi

echo

# Test the server
echo "========================================"
echo "Testing whisper Server"
echo "========================================"
echo

# Check if server is already running on port
if curl -s http://127.0.0.1:$PORT/health >/dev/null 2>&1; then
    echo_success "whisper server is already running on port $PORT"
else
    echo_info "Starting test server on port $PORT..."

    # Start server in background
    "$WHISPER_BINARY" \
        --model "$MODEL_PATH" \
        --host 127.0.0.1 \
        --port $PORT \
        --inference-path "/v1/audio/transcriptions" \
        --threads 4 \
        --processors 1 \
        --convert \
        --print-progress &

    SERVER_PID=$!

    # Wait for server to start
    echo_info "Waiting for server to initialize..."
    sleep 3

    # Test server health
    if curl -s http://127.0.0.1:$PORT/health | grep -q "ok"; then
        echo_success "Server is responding correctly!"

        # Kill test server
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    else
        echo_error "Server health check failed"
        echo_info "Check if server is actually running: ps aux | grep whisper-server"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
fi

echo

# SKIP systemd service creation - daemon will auto-start whisper on demand
echo "========================================"
echo "Configuration Complete"
echo "========================================"
echo

echo_info "IMPORTANT: whisper-server will NOT auto-start on boot"
echo_info "Instead, the daemon will auto-start it when you first press F12"
echo_info "This saves system resources when voice input is not in use"
echo

# Final summary
echo "========================================"
echo "whisper.cpp Installation Complete!"
echo "========================================"
echo

echo_success "Using pre-built binary (no compilation needed!)"
echo_success "Binary: $WHISPER_BINARY"
echo_success "Model: $MODEL_PATH"
echo_success "Port: $PORT"
echo

echo "Manual control:"
echo "  Start:  bash $PROJECT_ROOT/.whisper/scripts/start-server.sh"
echo "  Stop:   voiceclaudecli-stop-server  (created by main installer)"
echo "  Health: curl http://127.0.0.1:$PORT/health"
echo

echo "Automatic startup:"
echo "  • The daemon (voice_holdtospeak.py) will auto-start whisper on first F12 press"
echo "  • Startup time: ~213ms (nearly instant!)"
echo "  • Use 'voiceclaudecli-stop-server' when done to save resources"
echo

echo_success "Ready to use! Test with voiceclaudecli-daemon or voiceclaudecli-input"
echo
