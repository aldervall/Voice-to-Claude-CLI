# Voice-to-Claude-CLI: Universal Local Voice Transcription

A **cross-platform** local voice transcription tool that converts speech to text using whisper.cpp. Completely private - no API keys or cloud services required.

## Quick Install (Claude Code Plugin)

```bash
/plugin add aldervall/Voice-to-Claude-CLI
```

Then run `/voice-install` and you're done! Say "record my voice" to Claude to start using it.

## Features

- **🌐 Cross-Platform** - Works on Arch, Ubuntu, Fedora, OpenSUSE
- **🖥️ Multi-Environment** - Supports Wayland & X11, KDE & GNOME & more
- **🔒 100% Local** - All processing happens on your machine
- **🔑 No API Keys** - No cloud services, no accounts needed
- **⚡ Fast Install** - Pre-built x64 binary included, no compilation needed (5 sec vs 5 min)
- **📦 Self-Contained** - whisper.cpp bundled in project, survives reboots
- **🎯 Three Modes**:
  - **Hold-to-Speak Daemon** - Always-on F12 hotkey (recommended)
  - **One-Shot Voice Input** - Quick voice input for typing into applications
  - **Interactive Mode** - Terminal-based transcription sessions
- **🛡️ Privacy First** - Your voice never leaves your computer
- **⚙️ Fast** - Uses whisper.cpp for efficient local transcription
- **🤖 Claude Integration** - Zero-config Skill with auto-start + slash commands for Claude Code

## Platform Compatibility

### Supported Linux Distributions
✅ Arch Linux / Manjaro / CachyOS
✅ Ubuntu / Debian / Pop!_OS / Linux Mint
✅ Fedora / RHEL / Rocky Linux / AlmaLinux
✅ OpenSUSE / SLES

### Display Servers
✅ Wayland (KDE, GNOME, Sway, Hyprland, etc.)
✅ X11 (all desktop environments)

### Desktop Environments
✅ KDE Plasma
✅ GNOME
✅ XFCE
✅ Cinnamon
✅ i3 / Sway
✅ Others (any DE with freedesktop.org standards)

### Prerequisites

- **Python 3.8 or higher**
- **Working microphone**
- **Linux** (any of the distributions listed above)

## Installation

### Option 1: Claude Code Plugin (Easiest)

If you're using [Claude Code](https://claude.ai/code), you can install Voice-to-Claude-CLI as a plugin directly from GitHub:

**Step 1: Add the plugin**
```bash
/plugin add aldervall/Voice-to-Claude-CLI
```

**Step 2: Run the installer**
```bash
/voice-install
```

That's it! The voice transcription skill and commands are now available. Just say "record my voice" to Claude, or use `/voice` for quick voice input.

**What gets installed:**
- ✅ Voice transcription skill (auto-activated when you want to speak)
- ✅ `/voice` command - Quick voice input
- ✅ `/voice-install` command - Installation wizard
- ✅ System dependencies, Python environment, whisper.cpp server
- ✅ F12 hold-to-speak daemon, one-shot input, interactive mode

**How it works:**
1. The plugin provides the skill and commands in Claude Code
2. When you run `/voice-install`, it executes the installation script
3. After installation, just say "record my voice" to Claude or press `/voice`
4. Claude automatically records and transcribes your speech locally

### Option 2: Standalone Installation

## Quick Start (Recommended)

### Automated Installation

**One-command install for all Linux distributions:**

```bash
bash install.sh
```

This will:
- ✅ Auto-detect your distribution (Arch/Ubuntu/Fedora/OpenSUSE)
- ✅ Auto-detect display server (Wayland/X11)
- ✅ Install all required system dependencies
- ✅ Set up Python virtual environment
- ✅ Use pre-built whisper.cpp binary (x64 included; ARM64 planned - TODO)
- ✅ Download whisper model (142 MB) on first use
- ✅ Create systemd services (with auto-start)
- ✅ Set up daemon, one-shot, and interactive modes

**From Claude Code:**

```bash
/voice-install
```

Claude will guide you through the entire installation process.

## Manual Installation

<details>
<summary>Click to expand manual installation steps</summary>

### 1. Install System Dependencies

**Arch Linux:**
```bash
sudo pacman -S ydotool wl-clipboard python-pip
```

**Ubuntu/Debian:**
```bash
sudo apt install ydotool wl-clipboard python3-pip python3-venv
```

**Fedora:**
```bash
sudo dnf install ydotool wl-clipboard python3-pip
```

**OpenSUSE:**
```bash
sudo zypper install ydotool wl-clipboard python3-pip
```

**Note:** For X11, replace `wl-clipboard` with `xclip`

### 2. Enable Services and Permissions

```bash
# Enable ydotool daemon (required for keyboard automation)
systemctl --user enable --now ydotool

# Add yourself to input group (required for F12 key monitoring)
sudo usermod -a -G input $USER
# ⚠️ Log out and log back in after this!
```

### 3. Python Setup

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt
```

### 4. Install whisper.cpp

```bash
# Automated installer
bash install-whisper.sh

# Or manual installation (see CLAUDE.md)
```

</details>

## Usage

### Option 1: Hold-to-Speak Daemon (Recommended)

Always-on background service with F12 hold-to-speak functionality.

#### Setup

```bash
# Install system dependencies (Arch Linux)
sudo pacman -S wl-clipboard ydotool

# Enable ydotool daemon
systemctl --user enable --now ydotool

# Add yourself to input group (required for keyboard monitoring)
sudo usermod -a -G input $USER
# Log out and back in after this

# Install systemd service
mkdir -p ~/.config/systemd/user/
cp voiceclaudecli-daemon.service ~/.config/systemd/user/
systemctl --user daemon-reload

# Start the daemon
systemctl --user start voiceclaudecli-daemon

# Enable auto-start on login
systemctl --user enable voiceclaudecli-daemon
```

#### Usage

1. Hold F12 → Hear beep + see "Recording..." notification
2. Speak while holding F12
3. Release F12 → Hear beep + see "Transcribing..." notification
4. Text automatically pastes into active window
5. Desktop notification shows preview of transcribed text

```bash
# View logs
journalctl --user -u voiceclaudecli-daemon -f

# Stop daemon
systemctl --user stop voiceclaudecli-daemon
```

### Option 2: One-Shot Voice Input

Quick voice input script that types transcription into the active window.

```bash
voiceclaudecli-input  # After install.sh
```

**Optional:** Bind to system hotkey:
- System Settings → Shortcuts → Custom Shortcuts
- Trigger: Meta+V (or your preference)
- Command: `voiceclaudecli-input`

### Option 3: Interactive Terminal Mode

Terminal-based transcription for testing or standalone use.

```bash
source venv/bin/activate
python voice_to_claude.py
```

**Commands:**
- **Press ENTER**: Record for 5 seconds
- **Type 'quit' or 'exit'**: End session

## Dependencies

### Python Packages
- `requests` - HTTP client for whisper.cpp API
- `sounddevice` - Microphone recording
- `scipy` - Audio file I/O
- `numpy` - Audio data processing
- `evdev` - Keyboard event monitoring (for daemon)

### System Dependencies (for daemon mode)
- `whisper.cpp` - Local speech-to-text server
- `ydotool` - Keyboard automation for Wayland
- `wl-clipboard` - Clipboard management
- `notify-send` - Desktop notifications (standard on KDE Plasma)
- `paplay` - Audio beep feedback (optional)

## Configuration

Edit settings in the Python files:

- `SAMPLE_RATE = 16000` - Whisper's expected audio format
- `DURATION = 5` - Recording length in seconds (voice_to_claude.py, voice_to_text.py)
- `TRIGGER_KEY = ecodes.KEY_F12` - Hotkey for hold-to-speak (voice_holdtospeak.py)
- `MIN_RECORDING_DURATION = 0.3` - Minimum recording time (voice_holdtospeak.py)

## Troubleshooting

### Whisper server not running
```bash
# Check status
curl http://127.0.0.1:2022/health

# Should return: {"status":"ok"}
```

### No microphone detected
```bash
# List available devices
python -c "import sounddevice as sd; print(sd.query_devices())"
```

### Hold-to-speak daemon not working
```bash
# Check you're in input group
groups $USER  # Should show "input"

# Check daemon status
systemctl --user status voiceclaudecli-daemon

# View logs for errors
journalctl --user -u voiceclaudecli-daemon -f
```

### Auto-paste not working
```bash
# Check ydotool daemon is running
systemctl --user status ydotool

# If not running, enable it
systemctl --user enable --now ydotool
```

## Claude Code Integration

### Voice Transcription Skill (Recommended)

The easiest way to use voice transcription with Claude Code - **zero configuration required!**

**Installation:**

**Option 1: Plugin (Easiest)**
```bash
/plugin add aldervall/Voice-to-Claude-CLI
/voice-install
```
The skill and commands are instantly available!

**Option 2: Local Project**
After running `bash scripts/install.sh`, the skill is auto-discovered from `.claude/skills/voice/`

**How it works:**
- Claude autonomously offers voice input when appropriate
- Say "record my voice", "let me speak", or "voice input"
- Claude activates the skill and transcribes your speech
- **Auto-starts whisper server** if not running (using bundled binary)

**Advantages:**
- ✅ No config files to edit
- ✅ Works immediately after installation
- ✅ Automatically starts whisper server if needed
- ✅ Claude decides when to offer voice input
- ✅ Completely autonomous
- ✅ Available as plugin or local project

### Slash Commands

- `/voice-install` - Guided installation wizard
- `/voice` - Quick voice input (types into Claude)

## System Requirements

- **Linux** (see Platform Compatibility section)
- **Display server:** Wayland or X11
- **At least 200MB free disk space** (for whisper model)
- **Working microphone**

## Architecture

### Three Components

1. **voice_holdtospeak.py** - Background daemon with F12 hold-to-speak
   - Real-time keyboard monitoring with evdev
   - Dynamic audio recording (start/stop with key press/release)
   - Desktop notifications for feedback
   - Automated paste via ydotool

2. **voice_to_text.py** - One-shot voice input script
   - Fixed 5-second recording
   - Types into active window
   - Can be bound to hotkey

3. **voice_to_claude.py** - Interactive terminal mode
   - Terminal-based transcription
   - Good for testing
   - Displays results in terminal

All three modes use the same `VoiceTranscriber` class that communicates with the local whisper.cpp server.

## Privacy & Security

- ✅ **100% Local** - All voice processing happens on your machine
- ✅ **No Network Calls** - Except to localhost whisper.cpp server
- ✅ **No Cloud Services** - No API keys, no accounts, no tracking
- ✅ **No Data Collection** - Your voice recordings are temporary and deleted after transcription

## License

MIT
