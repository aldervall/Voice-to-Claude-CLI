# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Voice-to-Claude-CLI is a **cross-platform** Python application that provides local voice transcription using whisper.cpp. It records audio from your microphone and transcribes it to text completely locally - no API keys or cloud services required.

**Supported Platforms:**
- Linux distributions: Arch, Ubuntu/Debian, Fedora, OpenSUSE
- Display servers: Wayland and X11
- Desktop environments: KDE, GNOME, XFCE, i3, Sway, and others

## Critical Prerequisites

**The whisper.cpp server MUST be running before any voice transcription will work.**

Quick check:
```bash
curl http://127.0.0.1:2022/health  # Expected: {"status":"ok"}
```

Not running? Start it:
```bash
# If installed via install.sh (recommended)
systemctl --user start whisper-server
systemctl --user status whisper-server

# Or use project-local binary
bash .whisper/scripts/start-server.sh
```

**NOTE:** The Claude Code skill script will automatically attempt to start the local whisper server if it's not running and the binary exists in `.whisper/bin/`.

**The application will NOT work without this server running.** All three modes (daemon, one-shot, interactive) depend on this HTTP endpoint.

## Quick Setup for Development

If the project is already installed, activate the virtual environment:

```bash
source venv/bin/activate
```

For new installations, see README.md or run:
```bash
bash scripts/install.sh  # Automated installer
/voice:voice-install     # From Claude Code (note: command prefix is /voice: not /voice-)
```

## Running and Testing

### Quick Verification - Is Everything Working?

```bash
# 1. Check whisper.cpp server
curl http://127.0.0.1:2022/health

# 2. Check Python environment
source venv/bin/activate
python -c "from src.voice_to_claude import VoiceTranscriber; from src.platform_detect import get_platform_info; print('✓ All imports successful')"

# 3. Check platform detection
python -m src.platform_detect

# 4. Check available microphones
python -c "import sounddevice as sd; print(sd.query_devices())"

# 5. Check services (if installed)
systemctl --user status voiceclaudecli-daemon whisper-server ydotool
```

### Three Modes of Operation

**Mode 1: Hold-to-Speak Daemon (Recommended for Users)**
```bash
systemctl --user start voiceclaudecli-daemon  # Start daemon
journalctl --user -u voiceclaudecli-daemon -f  # View logs
```
- Always-on F12 hotkey
- Auto-paste into active window
- Desktop notifications

**Mode 2: One-Shot Voice Input**
```bash
voiceclaudecli-input  # After install.sh
python voice_to_text.py  # From project directory
```
- Single transcription, types into active window, can be bound to hotkey

**Mode 3: Interactive Terminal**
```bash
source venv/bin/activate
python -m src.voice_to_claude
```
- Good for testing
- Displays transcriptions in terminal
- Press ENTER to record

## Claude Code Integration

### Voice Transcription Skill (Recommended)

The `skills/voice/` directory contains a Skill that enables Claude to autonomously offer voice transcription when appropriate.

**Setup:** The skill is automatically discovered - no configuration needed!

**How it works:**
- Claude detects when user wants voice input (phrases like "record my voice", "let me speak")
- Autonomously activates the voice transcription skill
- Runs Python script that communicates with whisper.cpp via HTTP
- Returns transcribed text directly to the conversation

**Files:**
- `skills/voice/SKILL.md` - Skill definition and instructions
- `skills/voice/scripts/transcribe.py` - Transcription script using VoiceTranscriber class

**Advantages:**
- ✅ Zero configuration - works immediately
- ✅ No config files to edit
- ✅ Direct communication with whisper.cpp
- ✅ Simple debugging - just run the Python script
- ✅ Auto-discovered by Claude Code

### Slash Commands Available

- `/voice:voice-install` - Automated installation wizard (7-step guided installation)
- `/voice:voice` - Quick voice input (one-shot transcription, types into active window)

**Note:** Commands use `/voice:` prefix (plugin name is "voice")

## Architecture Overview

### Core Components

**1. VoiceTranscriber Class** (`src/voice_to_claude.py`)
- Shared transcription logic used by all three modes
- `record_audio(duration)`: Captures audio via sounddevice (16kHz mono)
- `transcribe_audio(audio_data)`: Sends WAV to whisper.cpp HTTP endpoint
- Returns transcribed text string

**2. Platform Abstraction** (`src/platform_detect.py`)
- Runtime detection: Linux distro, display server (Wayland/X11), DE
- Tool discovery: clipboard (wl-clipboard/xclip), keyboard (ydotool/kdotool/xdotool), notifications
- Cross-platform APIs: `copy_to_clipboard()`, `type_text()`, `simulate_paste_shortcut()`
- Graceful degradation with helpful error messages

**3. Claude Code Skill** (`skills/voice/`)
- Autonomous voice transcription skill for Claude Code
- `SKILL.md`: Skill definition with trigger descriptions and instructions
- `scripts/transcribe.py`: Python script using VoiceTranscriber class
- Claude autonomously decides when to offer voice input
- Direct HTTP communication with whisper.cpp
- **Auto-start capability**: Automatically starts local whisper server if not running
- Zero-configuration - auto-discovered by Claude

**4. Three User Interfaces**

| File | Mode | Use Case | Input Method | Output Method |
|------|------|----------|--------------|---------------|
| `src/voice_holdtospeak.py` | Daemon | Always-on F12 hotkey | evdev keyboard monitoring | ydotool paste |
| `src/voice_to_text.py` | One-shot | Hotkey-bound script | Fixed 5s recording | platform_detect typing |
| `src/voice_to_claude.py` | Interactive | Testing/manual | Terminal ENTER prompt | Terminal stdout |
| `skills/voice/` | Claude Skill | Autonomous Claude-initiated | Skill script execution | JSON to Claude context |

**5. Installation System**
- `scripts/install.sh`: Master installer with distro auto-detection
- `scripts/install-whisper.sh`: Checks for pre-built binary, builds from source as fallback
- `.whisper/`: Self-contained whisper.cpp directory in project
  - `bin/`: Pre-built whisper-server binaries (linux-x64 included; linux-arm64 TODO)
  - `models/`: Whisper models (downloaded on first use)
  - `scripts/`: Helper scripts (download-model.sh, start-server.sh, install-binary.sh)
- Creates launcher scripts in `~/.local/bin`
- Configures systemd user services

### Key Configuration

- **Audio:** 16kHz sample rate (whisper requirement), 5s fixed duration for one-shot modes
- **Daemon:** F12 trigger key, 0.3s minimum duration, beeps enabled by default
- **Endpoint:** `http://127.0.0.1:2022/v1/audio/transcriptions` (whisper.cpp)

### Data Flow

```
Audio → sounddevice (16kHz) → WAV → HTTP POST → whisper.cpp → JSON → output (clipboard/ydotool/stdout)
```

### whisper.cpp Server Requirements

Server must run at `localhost:2022` with `/v1/audio/transcriptions` endpoint. Default config: `ggml-base.en.bin` model, 4 threads, 1 processor.

**Installation Locations:**
- **Binary:** `.whisper/bin/whisper-server-linux-x64` (pre-built, no compilation needed; ARM64 planned)
- **Models:** `.whisper/models/ggml-*.bin` (downloaded on first use)
- **Fallback:** `/tmp/whisper.cpp` (if building from source)

**Auto-start:** The Claude Code skill script will automatically start the local server if it exists in `.whisper/bin/` and is not already running.

Changing port/path requires updating `WHISPER_URL` in all Python files.

## Development Workflow

### After Code Changes

**Always restart daemon after editing Python files:**
```bash
systemctl --user restart voiceclaudecli-daemon
journalctl --user -u voiceclaudecli-daemon -f  # Monitor logs
```

### Quick Tests

```bash
# Verify system ready
curl http://127.0.0.1:2022/health && python -m src.platform_detect

# Test transcription
source venv/bin/activate && python -m src.voice_to_claude

# Check daemon status
systemctl --user status voiceclaudecli-daemon whisper-server ydotool
```

### Troubleshooting

| Issue | Fix |
|-------|-----|
| Daemon not responding | `systemctl --user restart voiceclaudecli-daemon` |
| Whisper not responding | `curl http://127.0.0.1:2022/health` then restart |
| F12 not detected | User must be in `input` group (logout/login required) |
| Auto-paste failing | `systemctl --user status ydotool` → enable if stopped |
| Empty transcriptions | Check mic: `python -c "import sounddevice as sd; print(sd.query_devices())"` |
| Import errors | `source venv/bin/activate && pip install -r requirements.txt` |

## Dependencies

**Python packages:** requests, sounddevice, scipy, numpy, evdev (see `requirements.txt`)

**System packages:**
- whisper.cpp server (`install-whisper.sh` handles this)
- Clipboard: wl-clipboard (Wayland) or xclip (X11)
- Daemon mode: ydotool, user in `input` group
- Optional: notify-send (notifications), paplay (beeps)

**Install everything:** `bash install.sh` (auto-detects distro)

## Important Notes for Development

### Service Name Inconsistency

**Service naming:**
- Service file: `voice-holdtospeak.service` (in repo at `config/`)
- Installed service: `voiceclaudecli-daemon.service` (by install.sh)
- Both run `voice_holdtospeak.py`
- **Important:** Always use `voiceclaudecli-daemon` when checking/restarting the installed service

### Code Change Impact Map

| File Modified | Requires Restart | How to Test |
|---------------|------------------|-------------|
| `src/voice_to_claude.py` | Daemon + Interactive + Skill | `systemctl --user restart voiceclaudecli-daemon` OR `python -m src.voice_to_claude` |
| `src/platform_detect.py` | Daemon + One-shot | `systemctl --user restart voiceclaudecli-daemon` OR `python -m src.platform_detect` |
| `src/voice_holdtospeak.py` | Daemon only | `systemctl --user restart voiceclaudecli-daemon` |
| `src/voice_to_text.py` | None (one-shot) | `voiceclaudecli-input` or `python -m src.voice_to_text` |
| `skills/voice/SKILL.md` | None (auto-reload) | Ask Claude to use voice in new conversation |
| `skills/voice/scripts/transcribe.py` | None | Run script directly: `python skills/voice/scripts/transcribe.py` |
| `scripts/install.sh` | N/A | Run installer on test system |

### Cross-Platform Guidelines

- Use `platform_detect.get_platform_info()` for environment detection
- Provide graceful fallbacks (typing → clipboard → error)
- Test on Wayland and X11 if possible
- Update all three modes if core transcription changes

### Recent Changes (Sessions 20-21)

**Critical Fixes Applied:**
- Plugin discovery fixed (plugin.json moved to root)
- Installation scripts no longer use `set -e` (graceful error handling)
- Plugin name shortened to "voice" (commands: `/voice:voice-install`, `/voice:voice`)
- Added ldd test for pre-built whisper binary (commit e315fcb)
- Automatic fallback to source build if shared libraries missing

**Known Issue:** Plugin installations before 2025-11-17 have old scripts without ldd test. See `docs/INSTALLATION_STATUS.md` for refresh options.

### Handover

When user says "handover", update `docs/HANDOVER.md` with what was accomplished and decisions made. See `docs/HANDOVER.md` for complete session history.

## File Organization

**Project Structure (Plugin Marketplace Edition):**
```
voice-to-claude-cli/
├── .claude-plugin/      # Plugin marketplace metadata
│   ├── marketplace.json       (marketplace catalog)
│   └── plugin.json            (plugin metadata)
├── skills/              # Claude Code skills (root level)
│   └── voice/
│       ├── SKILL.md           (skill definition)
│       └── scripts/
│           └── transcribe.py  (transcription script)
├── commands/            # Claude Code slash commands (root level)
│   ├── voice.md               (quick voice input)
│   └── voice-install.md       (installation wizard)
├── src/                 # Python source code
│   ├── __init__.py
│   ├── voice_to_claude.py     (VoiceTranscriber)
│   ├── platform_detect.py     (cross-platform)
│   ├── voice_holdtospeak.py   (daemon)
│   └── voice_to_text.py       (one-shot)
├── scripts/             # Installation scripts
│   ├── install.sh             (master installer)
│   └── install-whisper.sh     (whisper.cpp installer)
├── config/              # Configuration templates
│   └── voice-holdtospeak.service
├── docs/                # Documentation
│   ├── CLAUDE.md              (this file)
│   ├── README.md              (user docs)
│   ├── HANDOVER.md            (session history)
│   └── archive/               (old sessions)
├── .whisper/            # Self-contained whisper.cpp
└── venv/                # Python environment
```

**Core Python:** `src/voice_to_claude.py` (VoiceTranscriber), `src/platform_detect.py` (cross-platform), `src/voice_holdtospeak.py` (daemon), `src/voice_to_text.py` (one-shot)

**Installation:** `scripts/install.sh` (master), `scripts/install-whisper.sh` (whisper.cpp installer)

**whisper.cpp (self-contained):**
- `.whisper/bin/` - Pre-built x64 binary (ARM64 planned)
- `.whisper/models/` - Whisper models (git-ignored, 142 MB)
- `.whisper/scripts/` - Helper scripts (download, start, install)

**Plugin Discovery:** `plugin.json` (at root for Claude Code discovery), `.claude-plugin/marketplace.json` (for trusted marketplace installation)

**Claude Integration:** `skills/voice/` (Skill with auto-start capability), `commands/` (slash commands)

**Configuration:** `config/voice-holdtospeak.service` (systemd template), `requirements.txt`, `.gitignore`

**Docs:** `docs/CLAUDE.md` (this file), `docs/README.md` (user guide), `docs/HANDOVER.md` (session history), `docs/INSTALLATION_FLOW.md` (testing guide), `docs/QUICK_TEST_CHECKLIST.md` (5-min tests), `docs/INSTALLATION_STATUS.md` (current state), `HANDOVER_SUMMARY.md` (latest handover)

**Generated files:**
- `~/.local/bin/voiceclaudecli-*` (launchers)
- `~/.config/systemd/user/voiceclaudecli-daemon.service`, `whisper-server.service`

## Design Principles

**Cross-Platform:** Runtime detection (no build step), graceful degradation (typing → clipboard → error), tool hierarchy (ydotool → kdotool/xdotool → clipboard)

**Architecture:** User Interface → Platform Abstraction → Core Transcription → whisper.cpp HTTP

**Error Handling:** All components catch exceptions gracefully, provide helpful install instructions, prevent daemon crashes

## Installation Script Architecture

**Key Principle:** NO `set -e` in user-facing scripts. All error handling must be explicit with helpful recovery steps.

**Installation Flow (7 Steps):**
1. System Dependencies (distro-specific packages)
2. Python Virtual Environment (`venv/`)
3. Python Packages (`requirements.txt`)
4. User Groups (`input` group for evdev access)
5. Launcher Scripts (`~/.local/bin/voiceclaudecli-*`)
6. Systemd Services (daemon + whisper-server)
7. whisper.cpp (pre-built binary with ldd test, fallback to source build)

**Error Handling Pattern:**
```bash
if ! command_that_might_fail; then
    echo_error "What failed"
    echo_info "Troubleshooting steps:"
    echo "  1. Check X"
    echo "  2. Try Y"
    # Continue or exit depending on criticality
fi
```

**Visual Standards:**
- ASCII art banners with box-drawing characters
- Color-coded messages (echo_info, echo_success, echo_warning, echo_error)
- Progress indicators (1/7, 2/7, etc.)
- Platform-specific troubleshooting

## Quick Reference Card

**Check if system is ready:**
```bash
curl http://127.0.0.1:2022/health && python -m src.platform_detect
```

**One-liner health check:**
```bash
curl -s http://127.0.0.1:2022/health && systemctl --user is-active whisper-server ydotool && ls ~/.local/bin/voiceclaudecli-* && echo "✓ System healthy"
```

**Start whisper server (multiple options):**
```bash
systemctl --user start whisper-server          # systemd service
bash .whisper/scripts/start-server.sh           # project-local binary
```

**Test transcription:**
```bash
source venv/bin/activate && python -m src.voice_to_claude
```

**After code changes:**
```bash
systemctl --user restart voiceclaudecli-daemon
journalctl --user -u voiceclaudecli-daemon -f
```

**Debug a problem:**
1. Check whisper server: `curl http://127.0.0.1:2022/health`
2. Check services: `systemctl --user status voiceclaudecli-daemon whisper-server ydotool`
3. Check logs: `journalctl --user -u voiceclaudecli-daemon -n 50`
4. Check platform: `python -m src.platform_detect`
5. Check imports: `python -c "from src.voice_to_claude import VoiceTranscriber"`
6. Check binary: `ls -lh .whisper/bin/` (should show whisper-server binary)
- /init