#!/bin/bash

#===============================================================================
# Voice-to-Claude-CLI Uninstaller
#
# Removes all components installed by install.sh:
# - Systemd user services
# - Launcher scripts
# - Installation directories
# - Temporary build artifacts
# - Running processes
#
# Usage: bash scripts/uninstall.sh
#===============================================================================

set -e

# Color output functions
echo_info() { echo -e "\033[1;34mℹ\033[0m $1"; }
echo_success() { echo -e "\033[1;32m✓\033[0m $1"; }
echo_warning() { echo -e "\033[1;33m⚠\033[0m $1"; }
echo_error() { echo -e "\033[1;31m✗\033[0m $1"; }

# Banner
cat << "EOF"

╔═══════════════════════════════════════════════════════╗
║                                                       ║
║        🗑  Voice-to-Claude-CLI Uninstaller          ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

EOF

echo_info "This will remove all Voice-to-Claude-CLI components"
echo_warning "This action cannot be undone!"
echo ""
echo "The following will be removed:"
echo "  • Systemd services (daemon, whisper-server)"
echo "  • Launcher scripts in ~/.local/bin/"
echo "  • Installation directory: ~/.local/voiceclaudecli"
echo "  • Temporary build directory: /tmp/whisper.cpp"
echo "  • Running processes"
echo ""
echo_info "Project directory will NOT be removed: $(pwd)"
echo ""

# Ask for confirmation (if running interactively)
if [ -t 0 ]; then
    read -p "Continue with uninstall? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Uninstall cancelled"
        exit 0
    fi
fi

echo ""
echo "========================================="
echo " Step 1/6: Stopping Services"
echo "========================================="
echo ""

# Stop systemd services
for service in voiceclaudecli-daemon whisper-server voice-holdtospeak voice-input; do
    if systemctl --user is-active "$service" &>/dev/null; then
        echo_info "Stopping $service..."
        systemctl --user stop "$service" 2>/dev/null || true
        echo_success "Stopped $service"
    fi
done

# Disable systemd services
for service in voiceclaudecli-daemon whisper-server voice-holdtospeak voice-input; do
    if systemctl --user is-enabled "$service" &>/dev/null; then
        echo_info "Disabling $service..."
        systemctl --user disable "$service" 2>/dev/null || true
        echo_success "Disabled $service"
    fi
done

echo ""
echo "========================================="
echo " Step 2/6: Killing Running Processes"
echo "========================================="
echo ""

# Kill any running processes
if pgrep -f "voice_holdtospeak" &>/dev/null; then
    echo_info "Killing voice_holdtospeak processes..."
    pkill -f "voice_holdtospeak" || true
    echo_success "Killed voice_holdtospeak"
fi

if pgrep -f "whisper-server" &>/dev/null; then
    echo_info "Killing whisper-server processes..."
    pkill -f "whisper-server" || true
    echo_success "Killed whisper-server"
fi

sleep 1  # Give processes time to die

echo ""
echo "========================================="
echo " Step 3/6: Removing Systemd Services"
echo "========================================="
echo ""

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICES_REMOVED=0

for service_file in voiceclaudecli-daemon.service whisper-server.service voice-holdtospeak.service voice-input.service; do
    if [ -f "$SERVICE_DIR/$service_file" ]; then
        echo_info "Removing $service_file..."
        rm -f "$SERVICE_DIR/$service_file"
        echo_success "Removed $service_file"
        SERVICES_REMOVED=$((SERVICES_REMOVED + 1))
    fi
done

if [ $SERVICES_REMOVED -gt 0 ]; then
    echo_info "Reloading systemd daemon..."
    systemctl --user daemon-reload
    echo_success "Systemd daemon reloaded"
else
    echo_info "No systemd services found"
fi

echo ""
echo "========================================="
echo " Step 4/6: Removing Launcher Scripts"
echo "========================================="
echo ""

BIN_DIR="$HOME/.local/bin"
SCRIPTS_REMOVED=0

for script in voiceclaudecli-daemon voiceclaudecli-input voiceclaudecli-interactive voiceclaudecli-stop-server claude-voice-input voice-input; do
    if [ -f "$BIN_DIR/$script" ]; then
        echo_info "Removing $script..."
        rm -f "$BIN_DIR/$script"
        echo_success "Removed $script"
        SCRIPTS_REMOVED=$((SCRIPTS_REMOVED + 1))
    fi
done

if [ $SCRIPTS_REMOVED -eq 0 ]; then
    echo_info "No launcher scripts found"
fi

echo ""
echo "========================================="
echo " Step 5/6: Removing Installation Dirs"
echo "========================================="
echo ""

# Remove ~/.local/voiceclaudecli
if [ -d "$HOME/.local/voiceclaudecli" ]; then
    echo_info "Removing ~/.local/voiceclaudecli..."
    DIR_SIZE=$(du -sh "$HOME/.local/voiceclaudecli" 2>/dev/null | cut -f1)
    rm -rf "$HOME/.local/voiceclaudecli"
    echo_success "Removed ~/.local/voiceclaudecli ($DIR_SIZE)"
else
    echo_info "~/.local/voiceclaudecli not found"
fi

# Remove /tmp/whisper.cpp
if [ -d "/tmp/whisper.cpp" ]; then
    echo_info "Removing /tmp/whisper.cpp..."
    TMP_SIZE=$(du -sh "/tmp/whisper.cpp" 2>/dev/null | cut -f1)
    rm -rf "/tmp/whisper.cpp"
    echo_success "Removed /tmp/whisper.cpp ($TMP_SIZE)"
else
    echo_info "/tmp/whisper.cpp not found"
fi

echo ""
echo "========================================="
echo " Step 6/6: Final Cleanup"
echo "========================================="
echo ""

# Remove any whisper build logs
if [ -f "/tmp/whisper-build.log" ]; then
    rm -f "/tmp/whisper-build.log"
    echo_success "Removed /tmp/whisper-build.log"
fi

echo ""
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║           ✨ UNINSTALL COMPLETE! ✨                  ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

EOF

echo_success "Voice-to-Claude-CLI has been completely removed"
echo ""
echo_info "What was NOT removed:"
echo "  • Project directory: $(pwd)"
echo "  • Python virtual environment: $(pwd)/venv/"
echo "  • whisper.cpp binaries: $(pwd)/.whisper/"
echo ""
echo_info "Optional manual cleanup:"
echo "  • Remove project directory: rm -rf $(pwd)"
echo "  • Remove from 'input' group: sudo deluser \$USER input"
echo "  • (Group removal requires logout to take effect)"
echo ""
echo_success "You can reinstall anytime by running: bash scripts/install.sh"
echo ""
