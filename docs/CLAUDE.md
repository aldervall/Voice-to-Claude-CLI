# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Voice-to-Claude-CLI is a **cross-platform** Python application that provides local voice transcription using whisper.cpp. It records audio from your microphone and transcribes it to text completely locally - no API keys or cloud services required.

**Supported Platforms:**
- Linux distributions: Arch, Ubuntu/Debian, Fedora, OpenSUSE
- Display servers: Wayland and X11
- Desktop environments: KDE, GNOME, XFCE, i3, Sway, and others

**Documentation Guide:**
- **CLAUDE.md** (this file) - Developer guide for Claude Code: architecture, troubleshooting, development workflow
- **README.md** - User installation guide and quick start
- **docs/INDEX.md** - Complete documentation navigation and task finder
- **docs/ADVANCED.md** - User customization options (hotkeys, duration, beeps, notifications, scripting)
- **docs/HANDOVER.md** - Development session history and architectural decisions (29 sessions)

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

**New to this codebase?** Start here:
1. Read the **Documentation Guide** section above to understand where everything is
2. Check `docs/INDEX.md` for task-oriented navigation
3. Review the **Architecture Overview** section below for the big picture

**If the project is already installed**, activate the virtual environment:

```bash
source venv/bin/activate
```

**For new installations**, see README.md or run:
```bash
bash scripts/install.sh       # Automated installer
/voice-claudecli-install      # From Claude Code
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

- `/voice-claudecli-install` - Automated installation wizard (7-step guided installation)
- `/voice-claudecli-uninstall` - Complete uninstaller (removes everything cleanly)
- `/voice-claudecli` - Quick voice input (one-shot transcription, types into active window)

**Note:** All commands use consistent `/voice-claudecli` prefix for clarity (plugin name is "voice")

## Architecture Overview

### Comprehensive Architecture Map

#### Component Dependency Graph

```
                    ┌─────────────────────────────┐
                    │   whisper.cpp Server        │
                    │   localhost:2022            │
                    │   (HTTP Transcription API)  │
                    └──────────────┬──────────────┘
                                   │
                                   │ HTTP POST (WAV)
                                   │ JSON Response
                                   │
                    ┌──────────────▼──────────────┐
                    │   VoiceTranscriber          │
                    │   (voice_to_claude.py)      │
                    │                             │
                    │   - record_audio()          │
                    │   - transcribe_audio()      │
                    └──────────┬──────────────────┘
                               │
                ┌──────────────┼──────────────┬──────────────┐
                │              │              │              │
                ▼              ▼              ▼              ▼
         ┌──────────┐   ┌──────────┐  ┌──────────┐  ┌──────────┐
         │  Daemon  │   │ One-Shot │  │Interactive│  │  Skill   │
         │ Mode     │   │  Mode    │  │   Mode    │  │  Mode    │
         └────┬─────┘   └────┬─────┘  └────┬─────┘  └────┬─────┘
              │              │              │              │
              │              │              │              │
              ▼              ▼              │              │
      ┌───────────────────────────┐        │              │
      │   PlatformInfo            │◄───────┘              │
      │   (platform_detect.py)    │                       │
      │                           │                       │
      │   - copy_to_clipboard()   │                       │
      │   - type_text()           │                       │
      │   - simulate_paste()      │                       │
      └───────────────────────────┘                       │
              │                                            │
              ▼                                            ▼
    ┌─────────────────────┐                    ┌─────────────────────┐
    │ System Integration  │                    │  Claude Code        │
    │ - ydotool           │                    │  (JSON output)      │
    │ - wl-clipboard      │                    └─────────────────────┘
    │ - evdev (/dev/input)│
    │ - systemd services  │
    └─────────────────────┘
```

**Python Module Dependencies:**

```
voice_holdtospeak.py (Daemon)
├── imports: voice_to_claude.VoiceTranscriber
├── imports: voice_to_claude.SAMPLE_RATE, WHISPER_URL
├── imports: platform_detect.get_platform_info
├── uses: evdev (keyboard monitoring)
├── uses: sounddevice, scipy, numpy (streaming audio)
└── uses: requests (HTTP to whisper.cpp)

voice_to_text.py (One-shot)
├── imports: voice_to_claude.VoiceTranscriber, DURATION
├── imports: platform_detect.get_platform_info
└── no direct dependencies on evdev or sounddevice

voice_to_claude.py (Core Transcriber)
├── imports: sounddevice (audio capture)
├── imports: scipy.io.wavfile (WAV encoding)
├── imports: requests (HTTP client)
├── imports: numpy (audio data)
└── PROVIDES: VoiceTranscriber class (used by all 3 modes)

platform_detect.py (Platform Abstraction)
├── imports: subprocess (tool execution)
├── imports: shutil (tool detection)
└── PROVIDES: PlatformInfo singleton (used by daemon + one-shot)

skills/voice/scripts/transcribe.py (Claude Skill)
├── imports: voice_to_claude.VoiceTranscriber
├── imports: requests (server health check)
├── imports: subprocess (auto-start server)
└── outputs: JSON to stdout (consumed by Claude Code)
```

**Key Insight:** VoiceTranscriber is the central hub - all 4 interfaces depend on it.

#### Complete Data Flow (All Layers)

**Layer 1: Audio Capture**
```
Microphone Hardware
    ↓ (OS audio subsystem)
sounddevice.rec() / InputStream
    ↓ (16kHz mono int16 samples)
numpy.ndarray (audio_data)

Mode-Specific Capture:
- Daemon: StreamingRecorder (dynamic start/stop via queue)
- One-shot: Fixed 5s blocking recording
- Interactive: Fixed 5s blocking recording
- Skill: Fixed duration (user-specified, default 5s)
```

**Layer 2: Transcription (Shared Core)**
```
numpy.ndarray (int16 audio)
    ↓ (VoiceTranscriber.transcribe_audio)
scipy.io.wavfile.write()
    ↓ (temporary WAV file)
requests.post(WHISPER_URL)
    ↓ (HTTP multipart/form-data)
whisper.cpp server :2022
    ↓ (OpenAI-compatible API)
JSON response {"text": "..."}
    ↓ (extract .text field)
str (transcribed_text)
```

**Layer 3: Output (Mode-Specific)**
```
DAEMON MODE (voice_holdtospeak.py):
    str → platform.copy_to_clipboard()
    → wl-copy/xclip subprocess
    → time.sleep(0.15s) for clipboard sync
    → platform.simulate_paste_shortcut(use_shift=True)
    → ydotool key sequence (Shift+Ctrl+V)
    → Active window receives text

ONE-SHOT MODE (voice_to_text.py):
    str → platform.type_text()
    → ydotool/kdotool/xdotool/wtype subprocess
    → Active window receives text
    (fallback: clipboard if typing unavailable)

INTERACTIVE MODE (voice_to_claude.py):
    str → print() to stdout
    → Terminal display

SKILL MODE (transcribe.py):
    str → json.dumps({"text": ..., "duration": ...})
    → stdout (captured by Claude Code)
    → Injected into Claude conversation context
```

**Layer 4: Platform Abstraction**
```
platform_detect.get_platform_info() (singleton)
    ↓ (runtime detection)
PlatformInfo instance
    ├── display_server: wayland|x11|unknown
    ├── desktop_env: KDE|GNOME|...
    └── available_tools: {clipboard: [...], keyboard: [...]}

Tool Selection Hierarchy:

Clipboard:
    1. Wayland → wl-clipboard (preferred)
    2. X11 → xclip (preferred)
    3. X11 → xsel (fallback)
    4. None → error with install instructions

Keyboard:
    1. ydotool (preferred - works everywhere)
    2. KDE → kdotool (if ydotool unavailable)
    3. X11 → xdotool (if ydotool unavailable)
    4. Wayland → wtype (Sway-specific)
    5. None → fallback to clipboard
```

**Layer 5: System Integration**
```
systemd user services:
    voiceclaudecli-daemon.service
        ↓ ExecStart
    ~/.local/bin/voiceclaudecli-daemon (launcher script)
        ↓ (sets PROJECT_ROOT, activates venv)
    python -m src.voice_holdtospeak
        ↓ (imports VoiceTranscriber)
    Daemon running (monitoring F12)

evdev integration:
    /dev/input/event* (keyboard devices)
        ↓ (requires user in 'input' group)
    evdev.InputDevice.read()
        ↓ (ecodes.KEY_F12 events)
    HoldToSpeakDaemon.handle_key_event()
```

#### Installation Artifact Map

**Where Everything Goes:**
```
PROJECT ROOT (voice-to-claude-cli/)
├── src/                        # Python source modules
├── .whisper/                   # Self-contained whisper.cpp
│   ├── bin/
│   │   └── whisper-server-linux-x64  # Pre-built binary (51 MB)
│   ├── models/
│   │   └── ggml-base.en.bin         # Whisper model (142 MB, git-ignored)
│   └── scripts/
│       ├── start-server.sh          # Server startup script
│       ├── download-model.sh        # Model downloader
│       └── install-binary.sh        # Fallback builder
└── venv/                       # Python virtualenv (git-ignored)

USER HOME (~/)
├── .local/bin/                 # Launcher scripts (added to PATH)
│   ├── voiceclaudecli-daemon       # Daemon launcher
│   ├── voiceclaudecli-input        # One-shot launcher
│   └── voiceclaudecli-stop-server  # Server shutdown
├── .config/systemd/user/       # Systemd services
│   └── voiceclaudecli-daemon.service  # Hold-to-speak daemon
└── .local/share/systemd/user/  # (Alternative systemd location)

SYSTEM-WIDE
/usr/bin/ or /usr/local/bin/    # System packages
├── ydotool                     # Keyboard automation
├── wl-copy/wl-paste           # Wayland clipboard
├── xclip                       # X11 clipboard
└── paplay                      # Audio playback (beeps)

RUNTIME (Ephemeral)
/tmp/
└── tmp*.wav                    # Temporary audio files (cleaned up)

NETWORK
localhost:2022                  # whisper.cpp HTTP server
├── GET  /health                # Health check endpoint
└── POST /v1/audio/transcriptions  # Transcription endpoint
```

#### Daemon Lifecycle (Runtime State)

**Startup Sequence:**
```
┌─────────────────────────────────────────────────────────────┐
│ 1. systemctl --user start voiceclaudecli-daemon            │
│    ↓                                                        │
│ 2. Launcher script activates venv                          │
│    ↓                                                        │
│ 3. python -m src.voice_holdtospeak                         │
│    ↓                                                        │
│ 4. HoldToSpeakDaemon.__init__()                            │
│    ├── platform = get_platform_info() (detect environment) │
│    └── recorder = StreamingRecorder()                      │
│    ↓                                                        │
│ 5. ensure_whisper_server()                                 │
│    ├── Check: curl http://127.0.0.1:2022/health            │
│    ├── If not running: Popen([start-server.sh])            │
│    └── Wait up to 20s for /health to return 200            │
│    ↓                                                        │
│ 6. VoiceTranscriber() (verify connection)                  │
│    ↓                                                        │
│ 7. find_keyboard_devices() (enumerate /dev/input/*)        │
│    ↓                                                        │
│ 8. select.select() loop (monitor evdev events)             │
└─────────────────────────────────────────────────────────────┘
```

**Recording Cycle (F12 Press/Release):**
```
┌─────────────────────────────────────────────────────────────┐
│ F12 PRESSED (event.value == 1)                              │
│    ↓                                                        │
│ play_beep(800 Hz) - high tone                              │
│    ↓                                                        │
│ StreamingRecorder.start()                                  │
│    ├── Clear audio_queue                                   │
│    ├── is_recording = True                                 │
│    ├── start_time = time.time()                            │
│    └── sounddevice.InputStream.start()                     │
│         ↓ (continuous callback)                            │
│    audio_callback() → queue.put(audio_chunk)               │
│                                                             │
│ [User speaks while holding F12...]                         │
│                                                             │
│ F12 RELEASED (event.value == 0)                            │
│    ↓                                                        │
│ play_beep(400 Hz) - low tone                               │
│    ↓                                                        │
│ StreamingRecorder.stop()                                   │
│    ├── is_recording = False                                │
│    ├── stream.stop() / stream.close()                      │
│    ├── duration = time.time() - start_time                 │
│    ├── if duration < 0.3s: return None (ignore)            │
│    └── audio_data = np.concatenate(queue chunks)           │
│    ↓                                                        │
│ threading.Thread(_transcribe_and_type, audio_data)         │
│    ↓                                                        │
│ _transcribe_and_type()                                     │
│    ├── transcriber.transcribe_audio(audio_data)            │
│    │   ├── wav.write(tmp_file.wav)                         │
│    │   ├── requests.post(WHISPER_URL, files=...)           │
│    │   └── return json["text"]                             │
│    ├── platform.copy_to_clipboard(text)                    │
│    ├── time.sleep(0.15s) # clipboard sync                  │
│    ├── platform.simulate_paste_shortcut(use_shift=True)    │
│    └── show_notification(preview)                          │
└─────────────────────────────────────────────────────────────┘
```

**Error Handling Chain:**
```
┌─────────────────────────────────────────────────────────────┐
│ Exception in _transcribe_and_type()                         │
│    ↓ (caught by try/except)                                │
│ print(f"✗ Error: {e}")                                     │
│    ↓                                                        │
│ show_notification('Error: ...', icon='dialog-error')       │
│    ↓                                                        │
│ Thread exits (daemon continues running)                    │
│    ↓                                                        │
│ select.select() loop continues (ready for next F12 press)  │
└─────────────────────────────────────────────────────────────┘

Key Design Decisions:
1. Transcription happens in background thread (non-blocking)
2. Errors don't crash daemon (graceful degradation)
3. Minimum 0.3s duration prevents accidental triggers
4. Clipboard + paste (not direct typing) for reliability
5. Auto-start whisper server (213ms startup)
```

#### whisper.cpp HTTP API Contract

**Endpoints:**
```
GET /health
    Response: {"status": "ok"}
    Status: 200 (healthy), non-200 (unhealthy)
    Used by: All components to verify server availability

POST /v1/audio/transcriptions
    Request:
        Content-Type: multipart/form-data
        Fields:
            - file: audio.wav (binary WAV data, 16kHz mono int16)
            - model: "whisper-1" (required by OpenAI API compat)
    Response:
        Content-Type: application/json
        Body: {"text": "transcribed speech here"}
    Status:
        - 200: Success
        - 400: Invalid audio format
        - 500: Transcription error
    Used by: VoiceTranscriber.transcribe_audio()
```

**Server Configuration:**
- Binary: `.whisper/bin/whisper-server-linux-x64`
- Model: `.whisper/models/ggml-base.en.bin`
- Args:
  - `--host 127.0.0.1` (localhost only, no network exposure)
  - `--port 2022` (non-standard to avoid conflicts)
  - `--inference-path "/v1/audio/transcriptions"`
  - `--threads 4` (CPU parallelism)
  - `--processors 1` (single request at a time)
  - `--convert` (auto-convert audio formats)
  - `--print-progress` (logging)
- **Startup Time:** ~213ms (measured in Session 26)
- **Memory:** ~200-300 MB (base.en model)

#### Claude Code Integration Points

**Plugin Discovery:**
```
Claude Code scans:
    /home/user/voice-to-claude-cli/plugin.json
        ↓ (JSON defines plugin metadata)
    commands/                  # Slash commands
    ├── voice-claudecli.md              (/voice-claudecli)
    ├── voice-claudecli-install.md      (/voice-claudecli-install)
    └── voice-claudecli-uninstall.md    (/voice-claudecli-uninstall)
        ↓
    skills/                    # Autonomous skills
    └── voice/
        ├── SKILL.md                    (skill definition)
        └── scripts/transcribe.py       (execution script)
```

**Slash Command Flow:**
```
User types: /voice-claudecli
    ↓ (Claude Code executes command definition)
Run bash script:
    source venv/bin/activate
    python -m src.voice_to_text
    ↓ (blocks until transcription complete)
Output to Claude conversation
```

**Skill Flow (Autonomous):**
```
User says: "let me speak" or "record my voice"
    ↓ (Claude detects trigger phrases)
Claude autonomously decides to use skill
    ↓ (executes skill script)
python skills/voice/scripts/transcribe.py --duration 5
    ↓ (checks installation, auto-starts server)
VoiceTranscriber.record_audio() + transcribe_audio()
    ↓ (JSON output to stdout)
{"text": "user speech", "duration": 5}
    ↓ (Claude Code injects into context)
Claude receives transcribed text in conversation
```

**Skill Auto-Start Capability:**
```
skills/voice/scripts/transcribe.py
    ↓ (check server health)
requests.get("http://127.0.0.1:2022/health")
    ↓ (if not running)
subprocess.Popen(['bash', '.whisper/scripts/start-server.sh'])
    ↓ (wait up to 15s)
Server available at localhost:2022
    ↓
Continue with transcription
```

#### Cross-Platform Tool Hierarchy

**Clipboard Abstraction:**
```
┌─────────────────────────────────────────────────────────────┐
│ platform_detect.copy_to_clipboard(text)                     │
│    ↓                                                        │
│ if is_wayland and wl-clipboard available:                  │
│    subprocess.run(['wl-copy', text])                       │
│                                                             │
│ elif is_x11 and xclip available:                           │
│    subprocess.run(['xclip', '-selection', 'clipboard'],    │
│                   input=text.encode())                      │
│                                                             │
│ elif is_x11 and xsel available:                            │
│    subprocess.run(['xsel', '--clipboard', '--input'],      │
│                   input=text.encode())                      │
│                                                             │
│ elif wl-clipboard available (fallback):                    │
│    subprocess.run(['wl-copy', text])                       │
│                                                             │
│ else:                                                       │
│    return False  # No clipboard tool available             │
└─────────────────────────────────────────────────────────────┘
```

**Keyboard Abstraction:**
```
┌─────────────────────────────────────────────────────────────┐
│ platform_detect.type_text(text)                             │
│    ↓                                                        │
│ if ydotool available (PREFERRED):                          │
│    subprocess.run(['ydotool', 'type', text])               │
│                                                             │
│ elif is_kde and kdotool available:                         │
│    subprocess.run(['kdotool', 'type', text])               │
│                                                             │
│ elif is_x11 and xdotool available:                         │
│    subprocess.run(['xdotool', 'type', '--', text])         │
│                                                             │
│ elif is_wayland and wtype available:                       │
│    subprocess.run(['wtype', text])                         │
│                                                             │
│ else:                                                       │
│    return False  # Fallback to clipboard in caller         │
└─────────────────────────────────────────────────────────────┘
```

**Paste Shortcut (Daemon-Specific):**
```
┌─────────────────────────────────────────────────────────────┐
│ platform_detect.simulate_paste_shortcut(use_shift=True)    │
│    ↓                                                        │
│ if ydotool available:                                      │
│    if use_shift:  # For terminals                          │
│       ydotool key 42:1 29:1 47:1 47:0 29:0 42:0            │
│       # Shift+Ctrl+V key sequence                          │
│    else:          # For GUI apps                           │
│       ydotool key 29:1 47:1 47:0 29:0                      │
│       # Ctrl+V key sequence                                │
│                                                             │
│ else:                                                       │
│    return False  # Only ydotool supports key simulation    │
└─────────────────────────────────────────────────────────────┘
```

**Why Clipboard + Paste (Not Direct Typing):**
- Daemon mode uses: clipboard + paste shortcut
  - **Pros:** More reliable, faster for large text, works with special characters
  - **Cons:** Requires ydotool for auto-paste, overwrites clipboard
- One-shot mode uses: direct typing → clipboard fallback
  - **Pros:** Doesn't overwrite clipboard, works without ydotool
  - **Cons:** Slower for large text, some special chars can fail

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

**Resource-Efficient Design (Manual Shutdown):**
- **NO auto-start on boot** - whisper does NOT run as a systemd service
- **Auto-start on first use** - daemon starts whisper on first F12 press (~213ms startup)
- **Manual shutdown** - use `voiceclaudecli-stop-server` when done to save resources
- **Why?** Keeps your system lightweight when voice input isn't needed

**Commands:**
```bash
# Stop server manually (save resources)
voiceclaudecli-stop-server

# Check if running
curl http://127.0.0.1:2022/health

# Manual start (if needed)
bash .whisper/scripts/start-server.sh
```

**Important:** whisper.cpp is NO LONGER built from source. The pre-built binary in `.whisper/bin/` is used exclusively. No `/tmp/whisper.cpp` directory should exist after installation.

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

### Troubleshooting (Connection-Aware)

**Systematic Diagnosis Flow:**

```
Problem: "Voice input not working"
    ↓
1. Check whisper server:
   curl http://127.0.0.1:2022/health
   ├── ✗ Connection refused → Server not running
   │   └── Fix: voiceclaudecli-stop-server && bash .whisper/scripts/start-server.sh
   └── ✓ {"status":"ok"} → Server healthy
       ↓
2. Check Python imports:
   python -c "from src.voice_to_claude import VoiceTranscriber"
   ├── ✗ ImportError → venv not activated or deps missing
   │   └── Fix: source venv/bin/activate && pip install -r requirements.txt
   └── ✓ No error → Imports working
       ↓
3. Check platform tools:
   python -m src.platform_detect
   ├── Clipboard: None → Missing clipboard tool
   │   └── Fix: Install wl-clipboard (Wayland) or xclip (X11)
   ├── Keyboard: None → Missing keyboard tool
   │   └── Fix: Install ydotool + enable service
   └── ✓ Tools detected → Platform configured
       ↓
4. Check daemon (if using F12):
   systemctl --user status voiceclaudecli-daemon
   ├── ✗ Not running → Daemon stopped
   │   └── Fix: systemctl --user start voiceclaudecli-daemon
   ├── ✗ Failed → Check logs
   │   └── journalctl --user -u voiceclaudecli-daemon -n 50
   └── ✓ active (running) → Daemon healthy
       ↓
5. Check evdev access (if daemon):
   groups | grep input
   ├── ✗ No "input" → User not in input group
   │   └── Fix: sudo usermod -a -G input $USER && logout/login
   └── ✓ "input" found → evdev access granted
       ↓
6. Test transcription:
   source venv/bin/activate && python -m src.voice_to_claude
   ├── ✗ Empty transcription → Check microphone
   │   └── python -c "import sounddevice as sd; print(sd.query_devices())"
   └── ✓ Text appears → Core functionality working
```

**Component-Specific Issues:**

| Symptom | Broken Component | Diagnosis | Fix |
|---------|------------------|-----------|-----|
| "Connection refused" | whisper.cpp server | `curl http://127.0.0.1:2022/health` fails | `bash .whisper/scripts/start-server.sh` |
| "F12 not detected" | evdev integration | User not in `input` group | `sudo usermod -a -G input $USER` → logout/login |
| "Auto-paste failing" | ydotool | Service not running | `systemctl --user enable --now ydotool` |
| "Empty transcription" | Microphone | Wrong device selected | `python -c "import sounddevice as sd; print(sd.query_devices())"` |
| "Import errors" | Python venv | Dependencies missing | `source venv/bin/activate && pip install -r requirements.txt` |
| "Daemon not starting" | systemd service | Service file misconfigured | `journalctl --user -u voiceclaudecli-daemon -e` |
| "Clipboard not working" | Platform tools | Missing wl-clipboard/xclip | `python -m src.platform_detect` → install missing tools |

### Error Handling Chains

**How Errors Propagate Through Layers:**

**Scenario 1: whisper.cpp Server Down**
```
User presses F12 (daemon mode)
    ↓
VoiceTranscriber.transcribe_audio(audio_data)
    ↓ (HTTP POST to localhost:2022)
requests.post() → ConnectionError
    ↓ (caught in transcribe_audio)
return ""  # Empty string
    ↓ (_transcribe_and_type receives empty string)
if transcribed_text:  # False
    else:
        print("✗ No speech detected")
        show_notification('Voice Input', 'No speech detected', icon='dialog-warning')
    ↓
Thread exits, daemon continues running
```

**Scenario 2: Microphone Permission Denied**
```
User presses F12 (daemon mode)
    ↓
StreamingRecorder.start()
    ↓
sounddevice.InputStream(..., callback=...)
    ↓ (callback receives status)
if status:
    print(f"Audio status: {status}", file=sys.stderr)
    ↓ (recording continues with empty frames)
StreamingRecorder.stop()
    ↓ (audio_chunks list is empty)
if not audio_chunks:
    return None
    ↓ (handle_key_event receives None)
if audio_data is not None:  # False
    else:
        print("No audio data recorded")
        show_notification('Voice Input', 'Recording too short', icon='dialog-warning')
```

**Scenario 3: User Not in input Group (evdev Access Denied)**
```
HoldToSpeakDaemon.find_keyboard_devices()
    ↓
evdev.list_devices() → PermissionError (implicit - returns empty list)
    ↓
keyboard_devices = []  # Empty list
    ↓ (run() method)
if not self.keyboard_devices:
    print("✗ Error: Could not find any keyboard device with F12 key")
    print("\nTroubleshooting:")
    print("1. Make sure you're in the 'input' group:")
    print("   sudo usermod -a -G input $USER")
    print("2. Log out and log back in for group changes to take effect")
    sys.exit(1)
```

**Scenario 4: ydotool Service Not Running**
```
User presses F12 (daemon mode)
    ↓ (transcription succeeds)
platform.simulate_paste_shortcut(use_shift=True)
    ↓
subprocess.run(['ydotool', 'key', ...])
    ↓ (ydotool not found or service down)
FileNotFoundError or CalledProcessError
    ↓ (caught in simulate_paste_shortcut)
return False
    ↓ (type_text_via_clipboard receives False)
if platform.simulate_paste_shortcut(...):  # False
    else:
        print("⚠ Auto-paste not available")
        print("📋 Text is in clipboard - paste manually with Shift+Ctrl+V")
        return True  # Still successful - text in clipboard
```

**Scenario 5: Clipboard Tool Missing**
```
platform.copy_to_clipboard(text)
    ↓
clipboard_tool = self.get_clipboard_tool()  # Returns None
    ↓
if not clipboard_tool:
    return False
    ↓ (type_text_via_clipboard receives False)
if not self.platform.copy_to_clipboard(text):
    print("✗ Error: No clipboard tool available")
    print("\nPlease install required tools:")
    print(self.platform.get_install_instructions())
    return False
```

**Error Handling Philosophy:**
1. **Graceful Degradation** - Fall back to less-preferred methods (typing → clipboard)
2. **Non-Fatal Errors** - Daemon never crashes, always ready for next F12 press
3. **User-Friendly Messages** - Specific install instructions, not generic errors
4. **Silent Failures** - Optional features (beeps, notifications) fail silently
5. **Explicit Recovery** - All error messages include "how to fix" steps

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

### Code Change Impact Map (Expanded)

| File Modified | Requires Restart | Affected Components | Testing Procedure |
|---------------|------------------|---------------------|-------------------|
| **Core Transcription** | | | |
| `src/voice_to_claude.py` | Daemon + Skill | All 4 modes (shared VoiceTranscriber) | `systemctl --user restart voiceclaudecli-daemon && python -m src.voice_to_claude` |
| ├── `VoiceTranscriber.record_audio()` | Daemon + Skill | Audio capture (all modes) | Test with different durations |
| ├── `VoiceTranscriber.transcribe_audio()` | Daemon + Skill | HTTP communication (all modes) | Test with whisper server down |
| └── `WHISPER_URL`, `SAMPLE_RATE` | Daemon + Skill | Configuration (all modes) | Full system test |
| **Platform Abstraction** | | | |
| `src/platform_detect.py` | Daemon + One-shot | clipboard/keyboard operations | `python -m src.platform_detect` |
| ├── `PlatformInfo.copy_to_clipboard()` | Daemon | Daemon clipboard operations | Test auto-paste |
| ├── `PlatformInfo.type_text()` | One-shot | One-shot typing | Test one-shot mode |
| ├── `PlatformInfo.simulate_paste_shortcut()` | Daemon only | Daemon auto-paste | Test F12 workflow |
| └── Tool detection logic | Daemon + One-shot | Fallback behavior | Test on different DEs |
| **Daemon Mode** | | | |
| `src/voice_holdtospeak.py` | Daemon only | F12 hold-to-speak | `systemctl --user restart voiceclaudecli-daemon` |
| ├── `StreamingRecorder` | Daemon | Dynamic recording | Test press/release timing |
| ├── `handle_key_event()` | Daemon | F12 detection | Test key press/release |
| ├── `ensure_whisper_server()` | Daemon | Auto-start logic | Kill server, press F12 |
| └── Beeps, notifications | Daemon | User feedback | Test with BEEP_ENABLED |
| **One-Shot Mode** | | | |
| `src/voice_to_text.py` | None (one-shot) | Single transcription | `voiceclaudecli-input` |
| └── `type_text_into_window()` | None | Typing logic | Test manual invocation |
| **Claude Code Integration** | | | |
| `skills/voice/SKILL.md` | None (auto-reload) | Skill triggers | New Claude conversation |
| `skills/voice/scripts/transcribe.py` | None | Skill execution | `python skills/voice/scripts/transcribe.py` |
| ├── `check_installation()` | None | Installation check | Test without venv |
| └── `ensure_whisper_server()` | None | Auto-start logic | Test with server down |
| `commands/voice-claudecli*.md` | None (auto-reload) | Slash commands | `/voice-claudecli` in Claude |
| **Installation** | | | |
| `scripts/install.sh` | N/A | Installation flow | Fresh install on test system |
| `scripts/install-whisper.sh` | N/A | whisper.cpp setup | Remove .whisper/, re-run |
| `.whisper/scripts/start-server.sh` | Daemon (if auto-start) | Server startup | `bash .whisper/scripts/start-server.sh` |
| **Configuration** | | | |
| `config/voice-holdtospeak.service` | Daemon (service update) | systemd integration | `systemctl --user daemon-reload && restart` |
| `requirements.txt` | All modes | Python dependencies | `pip install -r requirements.txt && test all modes` |

**Propagation Rules:**
- `VoiceTranscriber` changes → Restart daemon + re-run skill script
- `PlatformInfo` changes → Restart daemon + test one-shot
- Daemon-only changes → Only restart daemon
- Skill changes → No restart needed (Claude reloads on next use)
- Installation changes → Full reinstall on test system

### Cross-Platform Guidelines

- Use `platform_detect.get_platform_info()` for environment detection
- Provide graceful fallbacks (typing → clipboard → error)
- Test on Wayland and X11 if possible
- Update all three modes if core transcription changes

### Recent Changes (Sessions 20-29)

**Session 29 (2025-11-18) - CLAUDE.md Comprehensive Enhancement:**
- Added massive "Comprehensive Architecture Map" section with visual diagrams
- Enhanced Troubleshooting with systematic diagnosis flowchart
- Expanded Code Change Impact Map with affected components and propagation rules
- Added "Error Handling Chains" section with 5 real-world scenarios
- Added "Installation Flow Visualization" with 7-phase detailed breakdown
- Transformed CLAUDE.md from reference guide to complete context map (~500 → ~1300 lines)
- Every connection, data flow, and component relationship now documented

**Session 28 (2025-11-17) - Complete Uninstaller & Command Consistency:**
- Created comprehensive `scripts/uninstall.sh` (9-step process, 3 modes)
- Added Claude Code plugin removal capability
- Renamed all commands to consistent `/voice-claudecli-*` prefix
- Updated 15 documentation files for naming consistency
- Added `/voice-claudecli-uninstall` command

**Session 27 (2025-11-17) - Error Reporting System:**
- Implemented optional error reporting with GitHub Gist upload
- Added privacy-first design with explicit consent prompts
- Created sanitized diagnostic reports with complete system context
- Added happy/sad emoji feedback system for failures
- Zero-friction anonymous error sharing

**Session 26 (2025-11-17) - Resource Efficiency & Installation Fixes:**
- Discovered whisper.cpp starts in ~213ms (blazingly fast!)
- Implemented manual shutdown approach (no 24/7 server)
- Created comprehensive `scripts/uninstall.sh` (6-step cleanup)
- Refactored `install-whisper.sh` to use ONLY pre-built binaries (no /tmp builds)
- Fixed install.sh sudo handling for non-interactive environments
- Fixed line 251 syntax error (case statement instead of if/pattern)
- Added `voiceclaudecli-stop-server` command for resource management
- Updated documentation for new resource-efficient workflow

**Session 25 (2025-11-17) - /init Command Validation:**
- Ran /init command to validate CLAUDE.md quality
- Confirmed exceptional documentation (5/5 stars)
- Updated session counts (24 → 25)
- No structural changes needed - file is production-ready

**Session 24 (2025-11-17) - CLAUDE.md Enhancement:**
- Enhanced CLAUDE.md with strategic improvements
- Updated documentation navigation and session counts
- Improved docs organization by category
- Added Session 23 to recent changes

**Session 23 (2025-11-17) - Documentation Excellence & v1.3.0:**
- CLAUDE.md analysis and rating (5/5 stars - exceptional)
- Fresh HANDOVER.md created (3,254 → 397 lines, 89% reduction)
- Version v1.3.0 released as "Latest" on GitHub
- Enhanced documentation structure and navigation

**Session 22 (2025-11-17) - Project Cleanup & Documentation:**
- Complete project audit (35 files analyzed)
- Created comprehensive documentation index (`docs/INDEX.md`)
- Removed 3 obsolete files (cleanup backup, duplicate handover)
- Enhanced CLAUDE.md with documentation guide
- All functionality verified and operational

**Sessions 20-21 - Critical Fixes:**
- Plugin discovery fixed (plugin.json moved to root)
- Installation scripts no longer use `set -e` (graceful error handling)
- Plugin name shortened to "voice" (commands: `/voice-claudecli-install`, `/voice-claudecli`)
- Added ldd test for pre-built whisper binary (commit e315fcb)
- Automatic fallback to source build if shared libraries missing

**Note:** `docs/PLUGIN_ARCHITECTURE.md` documents the historical plugin discovery issues - these are now RESOLVED. The file remains as a reference for the architectural decisions made.

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

**Docs:**
- **Navigation:** `docs/INDEX.md` (documentation finder)
- **Developer:** `docs/CLAUDE.md` (this file)
- **User:** `docs/README.md` (user guide), `docs/ADVANCED.md` (customization)
- **History:** `docs/HANDOVER.md` (29 sessions)
- **Testing:** `docs/INSTALLATION_FLOW.md` (7-phase guide), `docs/QUICK_TEST_CHECKLIST.md` (5-min tests)
- **Status:** `docs/INSTALLATION_STATUS.md` (current state), `docs/PROJECT_STRUCTURE_AUDIT.md` (file inventory)

**Generated files:**
- `~/.local/bin/voiceclaudecli-*` (launchers)
- `~/.config/systemd/user/voiceclaudecli-daemon.service`, `whisper-server.service`

## Design Principles

**Cross-Platform:** Runtime detection (no build step), graceful degradation (typing → clipboard → error), tool hierarchy (ydotool → kdotool/xdotool → clipboard)

**Architecture:** User Interface → Platform Abstraction → Core Transcription → whisper.cpp HTTP

**Error Handling:** All components catch exceptions gracefully, provide helpful install instructions, prevent daemon crashes

## Installation Script Architecture

**Key Principle:** NO `set -e` in user-facing scripts. All error handling must be explicit with helpful recovery steps.

**Installation Flow (7-Phase Visualization):**

```
PHASE 1: System Dependencies
┌─────────────────────────────────────────────────────────────┐
│ Distro Detection                                            │
│   ├── Arch: pacman -S ydotool python-pip wl-clipboard      │
│   ├── Debian: apt install ydotool python3-pip wl-clipboard │
│   ├── Fedora: dnf install ydotool python3-pip wl-clipboard │
│   └── OpenSUSE: zypper install ydotool python3-pip wl-clip │
│                                                             │
│ Result: System packages installed ✓                         │
└─────────────────────────────────────────────────────────────┘
                          ↓
PHASE 2: Python Virtual Environment
┌─────────────────────────────────────────────────────────────┐
│ python3 -m venv venv                                        │
│   Creates: PROJECT_ROOT/venv/                              │
│            ├── bin/python3                                  │
│            ├── lib/python3.x/site-packages/                │
│            └── pyvenv.cfg                                   │
│                                                             │
│ Result: Isolated Python environment ✓                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
PHASE 3: Python Dependencies
┌─────────────────────────────────────────────────────────────┐
│ source venv/bin/activate                                    │
│ pip install -r requirements.txt                             │
│   Installs:                                                 │
│     ├── requests>=2.31.0 (HTTP client for whisper.cpp)     │
│     ├── sounddevice>=0.4.6 (audio capture)                 │
│     ├── scipy>=1.11.0 (WAV file encoding)                  │
│     ├── numpy>=1.24.0 (audio data arrays)                  │
│     └── evdev>=1.6.0 (keyboard monitoring)                 │
│                                                             │
│ Result: Python packages installed ✓                         │
└─────────────────────────────────────────────────────────────┘
                          ↓
PHASE 4: User Groups
┌─────────────────────────────────────────────────────────────┐
│ sudo usermod -a -G input $USER                              │
│   Required for: /dev/input/* access (evdev keyboard)       │
│   Takes effect: After logout/login                         │
│                                                             │
│ Result: User added to 'input' group ✓                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
PHASE 5: Launcher Scripts
┌─────────────────────────────────────────────────────────────┐
│ Creates in ~/.local/bin/:                                   │
│   ├── voiceclaudecli-daemon (launches daemon mode)         │
│   │   #!/bin/bash                                           │
│   │   PROJECT_ROOT="..."                                    │
│   │   cd "$PROJECT_ROOT"                                    │
│   │   source venv/bin/activate                              │
│   │   python -m src.voice_holdtospeak                       │
│   │                                                          │
│   ├── voiceclaudecli-input (launches one-shot)             │
│   │   #!/bin/bash                                           │
│   │   PROJECT_ROOT="..."                                    │
│   │   cd "$PROJECT_ROOT"                                    │
│   │   source venv/bin/activate                              │
│   │   python -m src.voice_to_text                           │
│   │                                                          │
│   └── voiceclaudecli-stop-server (stops whisper)           │
│       #!/bin/bash                                           │
│       pkill -f whisper-server                               │
│                                                             │
│ Result: Executable commands in PATH ✓                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
PHASE 6: Systemd Services
┌─────────────────────────────────────────────────────────────┐
│ Creates in ~/.config/systemd/user/:                         │
│   └── voiceclaudecli-daemon.service                        │
│       [Unit]                                                │
│       Description=Voice-to-Claude-CLI Hold-to-Speak Daemon  │
│       [Service]                                             │
│       ExecStart=%h/.local/bin/voiceclaudecli-daemon         │
│       Restart=on-failure                                    │
│       [Install]                                             │
│       WantedBy=default.target                               │
│                                                             │
│ systemctl --user daemon-reload                              │
│ systemctl --user enable voiceclaudecli-daemon               │
│                                                             │
│ Result: Daemon auto-starts on login ✓                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
PHASE 7: whisper.cpp
┌─────────────────────────────────────────────────────────────┐
│ bash scripts/install-whisper.sh                             │
│   ├── Check: .whisper/bin/whisper-server-linux-x64 exists  │
│   │   └── If yes: ldd test (check shared libraries)        │
│   │       ├── All libs found → Use pre-built binary ✓      │
│   │       └── Missing libs → Build from source              │
│   │                                                          │
│   ├── Download model: .whisper/models/ggml-base.en.bin     │
│   │   Source: https://huggingface.co/ggerganov/whisper.cpp │
│   │   Size: 142 MB (with progress bar)                     │
│   │                                                          │
│   └── Test server: curl http://127.0.0.1:2022/health        │
│       └── Expected: {"status":"ok"}                         │
│                                                             │
│ Result: whisper.cpp ready ✓                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
                    ✓ INSTALLATION COMPLETE ✓
```

**What Gets Created (File Tree):**
```
voice-to-claude-cli/
├── venv/                              # Created in Phase 2
│   ├── bin/python3
│   └── lib/python3.x/site-packages/  # Populated in Phase 3
└── .whisper/
    ├── bin/
    │   └── whisper-server-linux-x64   # Verified/built in Phase 7
    └── models/
        └── ggml-base.en.bin           # Downloaded in Phase 7 (142 MB)

~/.local/bin/                          # Created in Phase 5
├── voiceclaudecli-daemon
├── voiceclaudecli-input
└── voiceclaudecli-stop-server

~/.config/systemd/user/                # Created in Phase 6
└── voiceclaudecli-daemon.service
```

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