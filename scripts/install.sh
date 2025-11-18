#!/bin/bash
#
# Voice-to-Claude-CLI Universal Installer
# Supports: Arch, Ubuntu/Debian, Fedora, OpenSUSE
# Works standalone or as Claude Code plugin
#
# NOTE: We DO NOT use 'set -e' to allow graceful error handling

# Detect if running from Claude Code plugin or standalone
if [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
    # Running from Claude Code plugin - use plugin root
    SCRIPT_DIR="$CLAUDE_PLUGIN_ROOT/scripts"
    PROJECT_ROOT="$CLAUDE_PLUGIN_ROOT"
    echo "Detected Claude Code plugin installation"
else
    # Running standalone - use script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    echo "Running standalone installation"
fi

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/voiceclaudecli}"
BIN_DIR="$HOME/.local/bin"

# Track installation start time for error reporting
INSTALL_START_TIME=$(date +%s)
CURRENT_PHASE="Initialization"

# Load error reporting module
if [ -f "$SCRIPT_DIR/error-reporting.sh" ]; then
    source "$SCRIPT_DIR/error-reporting.sh"
    echo "Error reporting module loaded (opt-in)"
else
    echo_warning "Error reporting module not found - skipping"
fi

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

# Parse command line arguments
FORCE_INSTALL=false
for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE_INSTALL=true
            echo_warning "Force mode enabled: Will reinstall all components"
            ;;
        --help|-h)
            echo "Voice-to-Claude-CLI Installer"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force    Force reinstall all components (packages, scripts, services)"
            echo "  --help     Show this help message"
            exit 0
            ;;
    esac
done

# Detect if running non-interactively (from Claude Code or CI)
if [ -t 0 ]; then
    INTERACTIVE="${INTERACTIVE:-true}"
else
    INTERACTIVE="${INTERACTIVE:-false}"
fi
# Allow explicit override via environment variable
INTERACTIVE="${INTERACTIVE:-true}"

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID" | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# Detect display server (Wayland vs X11)
detect_display_server() {
    if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        echo "wayland"
    else
        echo "x11"
    fi
}

# Check if running with sudo (we don't want that)
if [ "$EUID" -eq 0 ]; then
    echo_error "Please do NOT run this script with sudo!"
    echo_info "The script will request sudo privileges only when needed."
    exit 1
fi

clear
echo -e "${CYAN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     🎙️  VOICE-TO-CLAUDE-CLI INSTALLER 🚀            ║
║                                                       ║
║     Local Voice Transcription - 100% Private         ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo

# Privacy notice
echo_header "╭───────────────────────────────────────────────────────╮"
echo_header "│  📋 Privacy & Error Reporting                        │"
echo_header "╰───────────────────────────────────────────────────────╯"
echo
echo_info "Privacy First:"
echo "  • 100% local processing - your voice never leaves your computer"
echo "  • No telemetry, no tracking, no cloud services"
echo "  • Open source - audit the code yourself"
echo
echo_info "Optional Installation Error Reporting (This Installer Only):"
echo "  • If installation fails, you'll be asked to share a diagnostic report"
echo "  • This ONLY applies to installation errors, not voice transcription"
echo "  • We sanitize all personal info (usernames, paths)"
echo "  • You can preview the full report before sending"
echo "  • Helps us fix issues faster for everyone"
echo
echo "  We're not snooping - just grateful for your help! 🙏"
echo
echo_info "Control: Set ENABLE_ERROR_REPORTING=never to disable prompts"
echo

# Detect environment
DISTRO=$(detect_distro)
DISPLAY_SERVER=$(detect_display_server)

echo_info "Detected distribution: $DISTRO"
echo_info "Detected display server: $DISPLAY_SERVER"
echo

# Map distro to package manager and packages
case "$DISTRO" in
    arch|manjaro|cachyos|endeavouros)
        PKG_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S --needed --noconfirm"
        PACKAGES="ydotool python-pip python-virtualenv"

        if [ "$DISPLAY_SERVER" = "wayland" ]; then
            PACKAGES="$PACKAGES wl-clipboard"
        else
            PACKAGES="$PACKAGES xclip"
        fi
        ;;

    ubuntu|debian|pop|mint|elementary)
        PKG_MANAGER="apt"
        INSTALL_CMD="sudo apt-get install -y"
        PACKAGES="ydotool python3-pip python3-venv"

        if [ "$DISPLAY_SERVER" = "wayland" ]; then
            PACKAGES="$PACKAGES wl-clipboard"
        else
            PACKAGES="$PACKAGES xclip"
        fi

        # Update package list first
        echo_info "Updating package list..."
        sudo apt-get update -qq
        ;;

    fedora|rhel|centos|rocky|almalinux)
        PKG_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
        PACKAGES="ydotool python3-pip python3-virtualenv"

        if [ "$DISPLAY_SERVER" = "wayland" ]; then
            PACKAGES="$PACKAGES wl-clipboard"
        else
            PACKAGES="$PACKAGES xclip"
        fi
        ;;

    opensuse*|sles)
        PKG_MANAGER="zypper"
        INSTALL_CMD="sudo zypper install -y"
        PACKAGES="ydotool python3-pip python3-virtualenv"

        if [ "$DISPLAY_SERVER" = "wayland" ]; then
            PACKAGES="$PACKAGES wl-clipboard"
        else
            PACKAGES="$PACKAGES xclip"
        fi
        ;;

    *)
        echo_error "Unsupported distribution: $DISTRO"
        echo_info "Supported distributions: Arch, Ubuntu/Debian, Fedora, OpenSUSE"
        echo_info "You can manually install dependencies and run 'pip install -r requirements.txt'"
        exit 1
        ;;
esac

# Install system dependencies
echo
echo_header "╔═══════════════════════════════════════════════════════╗"
echo_header "║  📦 STEP 1/7: Install System Dependencies            ║"
echo_header "╚═══════════════════════════════════════════════════════╝"
echo

CURRENT_PHASE="STEP 1/7: Install System Dependencies"

# Check which packages are already installed (unless --force)
if [ "$FORCE_INSTALL" = true ]; then
    MISSING_PACKAGES="$PACKAGES"
else
    MISSING_PACKAGES=""
    for pkg in $PACKAGES; do
        case "$PKG_MANAGER" in
            pacman)
                if ! pacman -Qi "$pkg" &>/dev/null; then
                    MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
                fi
                ;;
            apt)
                if ! dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
                    MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
                fi
                ;;
            dnf)
                if ! rpm -q "$pkg" &>/dev/null; then
                    MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
                fi
                ;;
            zypper)
                if ! rpm -q "$pkg" &>/dev/null; then
                    MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
                fi
                ;;
        esac
    done
fi

if [ -z "$MISSING_PACKAGES" ]; then
    echo_success "All system packages already installed ✓"
    echo_info "Packages: $PACKAGES"
else
    echo_step "Missing packages detected:$MISSING_PACKAGES"
    echo

    # Check if we can run sudo (interactive mode with TTY)
    if [ "$INTERACTIVE" = "true" ] && [ -t 0 ]; then
        echo_info "Attempting to install packages (may require sudo password)..."
        echo

        # Try to install packages with error handling
        error_output=$($INSTALL_CMD $MISSING_PACKAGES 2>&1)
        exit_code=$?

        if [ $exit_code -ne 0 ]; then
            echo_error "Package installation failed!"
            echo
            echo_info "Please install manually:"
            echo "  $INSTALL_CMD $MISSING_PACKAGES"
            echo
            echo_warning "Installation will continue, but some features may not work"
        else
            echo_success "System dependencies installed!"
        fi
    else
        # Non-interactive mode: Don't attempt sudo, just show instructions
        echo_warning "Running in non-interactive mode - cannot use sudo"
        echo
        echo_info "📋 Please install these packages manually:"
        echo
        case "$DISTRO" in
            arch|manjaro|cachyos|endeavouros)
                echo "  sudo pacman -S --needed$MISSING_PACKAGES"
                ;;
            ubuntu|debian|pop|mint|elementary)
                echo "  sudo apt-get install$MISSING_PACKAGES"
                ;;
            fedora|rhel|centos|rocky|almalinux)
                echo "  sudo dnf install$MISSING_PACKAGES"
                ;;
            opensuse*|sles)
                echo "  sudo zypper install$MISSING_PACKAGES"
                ;;
        esac
        echo
        echo_warning "Some features will not work until these packages are installed"
        echo_info "Continuing with installation..."
        echo
    fi
fi
echo

# Enable ydotool daemon (required for keyboard automation)
echo
echo_header "╔═══════════════════════════════════════════════════════╗"
echo_header "║  ⌨️  STEP 2/7: Enable ydotool Daemon                 ║"
echo_header "╚═══════════════════════════════════════════════════════╝"
echo

if systemctl --user is-enabled ydotool.service &>/dev/null; then
    echo_success "ydotool daemon already enabled"
else
    echo_info "Enabling ydotool daemon..."
    if systemctl --user enable --now ydotool.service 2>/dev/null; then
        echo_success "ydotool daemon enabled"
    else
        echo_warning "Failed to enable ydotool daemon"
        echo_info "This is optional - the daemon will try to use alternative tools"
        echo_info "To enable manually later:"
        echo "  systemctl --user enable --now ydotool.service"
    fi
fi

echo

# Add user to input group (required for keyboard event monitoring)
echo
echo_header "╔═══════════════════════════════════════════════════════╗"
echo_header "║  👤 STEP 3/7: Add User to 'input' Group              ║"
echo_header "╚═══════════════════════════════════════════════════════╝"
echo

if groups | grep -q '\binput\b'; then
    echo_success "Already in 'input' group"
else
    echo_info "Need to add $USER to 'input' group (required for F12 key detection)"
    echo

    # Check if we can run sudo (interactive mode with TTY)
    if [ "$INTERACTIVE" = "true" ] && [ -t 0 ]; then
        echo_info "Attempting to add user to 'input' group (may require sudo password)..."
        if sudo usermod -a -G input "$USER" 2>/dev/null; then
            echo_success "Added to 'input' group"
            echo_warning "⚠️  You MUST log out and log back in for this to take effect!"
            NEEDS_LOGOUT=true
        else
            echo_warning "Failed to add user to 'input' group (sudo failed)"
            echo
            echo_info "📋 Please run this manually:"
            echo "  sudo usermod -a -G input $USER"
            echo_info "Then log out and log back in"
        fi
    else
        # Non-interactive mode: Don't attempt sudo, just show instructions
        echo_warning "Running in non-interactive mode - cannot use sudo"
        echo
        echo_info "📋 Please run this command manually in a terminal:"
        echo "  sudo usermod -a -G input $USER"
        echo
        echo_info "Then log out and log back in for changes to take effect"
        echo_warning "F12 hold-to-speak mode will NOT work until this is done"
    fi
fi

echo

# Install Python virtual environment and dependencies
echo
echo_header "╔═══════════════════════════════════════════════════════╗"
echo_header "║  🐍 STEP 4/7: Install Python Dependencies            ║"
echo_header "╚═══════════════════════════════════════════════════════╝"
echo

CURRENT_PHASE="STEP 4/7: Install Python Dependencies"

# Determine install location
# Check if PROJECT_ROOT is inside HOME directory
case "$PROJECT_ROOT" in
    "$HOME"|"$HOME/"*)
        # Already in home directory, install in place
        INSTALL_DIR="$PROJECT_ROOT"
        echo_info "Installing in place: $INSTALL_DIR"
        ;;
    *)
        # Copy to ~/.local/voiceclaudecli
        echo_info "Installing to: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
        cp -r "$PROJECT_ROOT"/* "$INSTALL_DIR/"
        cd "$INSTALL_DIR"
        ;;
esac

# Create virtual environment
if [ ! -d "$INSTALL_DIR/venv" ]; then
    echo_info "Creating Python virtual environment..."
    python3 -m venv "$INSTALL_DIR/venv"
    echo_success "Virtual environment created"
else
    echo_success "Virtual environment already exists"
fi

# Install Python packages
source "$INSTALL_DIR/venv/bin/activate"

# Check if packages are already installed (unless --force)
if [ "$FORCE_INSTALL" = false ] && pip show requests sounddevice scipy numpy evdev &>/dev/null; then
    echo_success "Python dependencies already installed ✓"
else
    echo_info "Installing Python packages (this may take a minute)..."
    pip install --upgrade pip -q
    echo "ℹ Installing dependencies..."
    pip install -r "$INSTALL_DIR/requirements.txt" --progress-bar on
    echo_success "Python packages installed"
fi

deactivate

echo

# Create launcher scripts in ~/.local/bin
echo
echo_header "╔═══════════════════════════════════════════════════════╗"
echo_header "║  🚀 STEP 5/7: Create Launcher Scripts                ║"
echo_header "╚═══════════════════════════════════════════════════════╝"
echo

mkdir -p "$BIN_DIR"

# Create voiceclaudecli-daemon launcher
if [ "$FORCE_INSTALL" = false ] && [ -f "$BIN_DIR/voiceclaudecli-daemon" ]; then
    echo_success "Launcher script voiceclaudecli-daemon already exists ✓"
else
    cat > "$BIN_DIR/voiceclaudecli-daemon" <<EOF
#!/bin/bash
cd "$INSTALL_DIR"
source "$INSTALL_DIR/venv/bin/activate"
exec python -m src.voice_holdtospeak "\$@"
EOF
    chmod +x "$BIN_DIR/voiceclaudecli-daemon"
    echo_success "Created: $BIN_DIR/voiceclaudecli-daemon"
fi

# Create voiceclaudecli-input launcher (one-shot)
if [ "$FORCE_INSTALL" = false ] && [ -f "$BIN_DIR/voiceclaudecli-input" ]; then
    echo_success "Launcher script voiceclaudecli-input already exists ✓"
else
    cat > "$BIN_DIR/voiceclaudecli-input" <<EOF
#!/bin/bash
cd "$INSTALL_DIR"
source "$INSTALL_DIR/venv/bin/activate"
exec python -m src.voice_to_text "\$@"
EOF
    chmod +x "$BIN_DIR/voiceclaudecli-input"
    echo_success "Created: $BIN_DIR/voiceclaudecli-input"
fi

# Create voiceclaudecli-interactive launcher
if [ "$FORCE_INSTALL" = false ] && [ -f "$BIN_DIR/voiceclaudecli-interactive" ]; then
    echo_success "Launcher script voiceclaudecli-interactive already exists ✓"
else
    cat > "$BIN_DIR/voiceclaudecli-interactive" <<EOF
#!/bin/bash
cd "$INSTALL_DIR"
source "$INSTALL_DIR/venv/bin/activate"
exec python -m src.voice_to_claude "\$@"
EOF
    chmod +x "$BIN_DIR/voiceclaudecli-interactive"
    echo_success "Created: $BIN_DIR/voiceclaudecli-interactive"
fi

# Create voiceclaudecli-stop-server launcher (manual shutdown)
if [ "$FORCE_INSTALL" = false ] && [ -f "$BIN_DIR/voiceclaudecli-stop-server" ]; then
    echo_success "Launcher script voiceclaudecli-stop-server already exists ✓"
else
    cat > "$BIN_DIR/voiceclaudecli-stop-server" <<EOF
#!/bin/bash
# Stop the whisper.cpp server to free up system resources

echo "Stopping whisper.cpp server..."

# Find and kill whisper-server processes
if pgrep -f "whisper-server" > /dev/null; then
    pkill -f "whisper-server"
    sleep 1
    if pgrep -f "whisper-server" > /dev/null; then
        echo "✗ Failed to stop whisper-server (still running)"
        echo "ℹ Try manually: pkill -9 -f whisper-server"
        exit 1
    else
        echo "✓ whisper-server stopped successfully"
        echo "ℹ Run 'voiceclaudecli-daemon' or press F12 to restart automatically"
    fi
else
    echo "ℹ whisper-server is not running"
fi
EOF
    chmod +x "$BIN_DIR/voiceclaudecli-stop-server"
    echo_success "Created: $BIN_DIR/voiceclaudecli-stop-server"
fi

echo

# Install systemd service
echo
echo_header "╔═══════════════════════════════════════════════════════╗"
echo_header "║  ⚙️  STEP 6/7: Install systemd Service               ║"
echo_header "╚═══════════════════════════════════════════════════════╝"
echo

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

# Create service file with correct paths
if [ "$FORCE_INSTALL" = false ] && [ -f "$SYSTEMD_USER_DIR/voiceclaudecli-daemon.service" ]; then
    echo_success "Systemd service already configured ✓"
else
    cat > "$SYSTEMD_USER_DIR/voiceclaudecli-daemon.service" <<EOF
[Unit]
Description=Voice-to-Claude-CLI Hold-to-Speak Daemon
After=default.target

[Service]
Type=simple
ExecStart=$BIN_DIR/voiceclaudecli-daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

    echo_success "Created systemd service: $SYSTEMD_USER_DIR/voiceclaudecli-daemon.service"
fi

# Reload systemd
systemctl --user daemon-reload
echo_success "Systemd daemon reloaded"

echo

# Ask about whisper.cpp installation
echo
echo_header "╔═══════════════════════════════════════════════════════╗"
echo_header "║  🎙️  STEP 7/7: whisper.cpp Server                    ║"
echo_header "╚═══════════════════════════════════════════════════════╝"
echo

CURRENT_PHASE="STEP 7/7: whisper.cpp Server"

echo_step "Voice transcription engine setup"
echo_info "Model download: ~142 MB (one-time, with progress bar)"
echo_info "This is the magic behind local voice recognition! ✨"
echo

if command -v whisper-server &>/dev/null || [ -f "/tmp/whisper.cpp/build/bin/whisper-server" ]; then
    echo_success "whisper.cpp appears to be already installed"
    INSTALL_WHISPER="n"
else
    if [ "$INTERACTIVE" = "true" ]; then
        read -p "Install whisper.cpp server? (recommended) [Y/n]: " INSTALL_WHISPER
        INSTALL_WHISPER=${INSTALL_WHISPER:-y}
    else
        # Non-interactive mode: default to yes
        INSTALL_WHISPER="${AUTO_INSTALL_WHISPER:-y}"
        echo_info "Non-interactive mode: Installing whisper.cpp server (override with AUTO_INSTALL_WHISPER=n)"
    fi
fi

if [[ "$INSTALL_WHISPER" =~ ^[Yy] ]]; then
    if [ -f "$SCRIPT_DIR/install-whisper.sh" ]; then
        bash "$SCRIPT_DIR/install-whisper.sh"
    else
        echo_warning "install-whisper.sh not found, skipping whisper.cpp installation"
        echo_info "You can install whisper.cpp manually or run install-whisper.sh later"
    fi
else
    echo_warning "Skipped whisper.cpp installation"
    echo_info "You must install whisper.cpp server manually for voice transcription to work"
fi

echo

# Final summary
echo
echo
echo -e "${GREEN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║          ✨ INSTALLATION COMPLETE! ✨                ║
║                                                       ║
║     🎙️  Voice-to-Claude-CLI is ready to use! 🚀     ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo

if [ -n "$NEEDS_LOGOUT" ]; then
    echo_warning "⚠️  IMPORTANT: You MUST log out and log back in for 'input' group to take effect!"
    echo
fi

echo_success "🎉 Voice transcription system installed successfully!"
echo

echo "Available commands:"
echo "  voiceclaudecli-daemon       - Start F12 hold-to-speak daemon"
echo "  voiceclaudecli-input        - One-shot voice input"
echo "  voiceclaudecli-interactive  - Interactive terminal mode"
echo "  voiceclaudecli-stop-server  - Stop whisper.cpp server (save resources)"
echo

echo "To start the daemon as a service:"
echo "  systemctl --user start voiceclaudecli-daemon"
echo "  systemctl --user enable voiceclaudecli-daemon  # Auto-start on login"
echo

echo "To check daemon status:"
echo "  systemctl --user status voiceclaudecli-daemon"
echo

echo "To view daemon logs:"
echo "  journalctl --user -u voiceclaudecli-daemon -f"
echo

if [[ "$INSTALL_WHISPER" =~ ^[Yy] ]]; then
    echo_info "whisper.cpp server should be running on port 2022"
    echo_info "Test with: curl http://127.0.0.1:2022/health"
    echo
fi

echo "Installation directory: $INSTALL_DIR"
echo

echo "For more information, see README.md"
echo
