# Advanced Usage - Voice-to-Claude-CLI

This document covers advanced usage scenarios, command-line tools, customization options, and standalone installation without Claude Code.

## Standalone Installation (Without Claude Code)

If you're not using Claude Code or want to install manually:

```bash
git clone https://github.com/aldervall/Voice-to-Claude-CLI
cd Voice-to-Claude-CLI
bash scripts/install.sh
```

The installer will:
1. Detect your Linux distribution
2. Install system dependencies
3. Set up Python virtual environment
4. Install whisper.cpp with pre-built binary
5. Create launcher scripts in `~/.local/bin/`
6. Configure systemd user services

## Command-Line Tools

After installation, these commands are available in `~/.local/bin/`:

### voiceclaudecli-daemon

Start the F12 hold-to-speak daemon:

```bash
voiceclaudecli-daemon
```

**What it does:**
- Monitors keyboard for F12 presses
- Records audio while F12 is held
- Transcribes and pastes into active window
- Shows desktop notifications

**Usage:**
```bash
# Start manually
voiceclaudecli-daemon

# Start as systemd service (recommended)
systemctl --user start voiceclaudecli-daemon

# Enable auto-start on login
systemctl --user enable voiceclaudecli-daemon

# Check status
systemctl --user status voiceclaudecli-daemon

# View logs
journalctl --user -u voiceclaudecli-daemon -f
```

### voiceclaudecli-input

One-shot voice input that types into the active window:

```bash
voiceclaudecli-input
```

**What it does:**
- Records for 5 seconds
- Transcribes audio
- Types result into currently focused window
- Exits after single transcription

**Usage:**
```bash
# Run once
voiceclaudecli-input

# Bind to a hotkey in your desktop environment
# KDE example: System Settings → Shortcuts → Custom Shortcuts
#   Command: /home/username/.local/bin/voiceclaudecli-input
#   Shortcut: Meta+V
```

### voiceclaudecli-interactive

Interactive terminal transcription mode:

```bash
voiceclaudecli-interactive
```

**What it does:**
- Terminal-based interface
- Press ENTER to start recording
- Speak for 5 seconds
- Displays transcription in terminal
- Repeat as needed

**Usage:**
```bash
# Start interactive session
voiceclaudecli-interactive

# Press ENTER to record
# Press Ctrl+C to exit
```

## Alternative Usage Methods (Non-Claude Code)

These methods work outside of Claude Code:

### Claude Code Skill (When Using Claude Code)

Inside Claude Code, you can say:
- "record my voice"
- "let me speak"
- "transcribe audio"

Claude will autonomously activate voice transcription.

### Slash Commands (Claude Code Only)

- `/voice` - Quick voice input in Claude chat
- `/voice-install` - Run the installer

## Customization

### Changing the Hotkey

Edit the daemon service file:

```bash
nano ~/.config/systemd/user/voiceclaudecli-daemon.service
```

Find the `ExecStart` line and add parameters:

```ini
[Service]
ExecStart=/home/username/.local/bin/voiceclaudecli-daemon --key KEY_F11
```

Available key codes (from evdev):
- `KEY_F12` (default)
- `KEY_F11`
- `KEY_F10`
- See `/usr/include/linux/input-event-codes.h` for full list

After changes:
```bash
systemctl --user daemon-reload
systemctl --user restart voiceclaudecli-daemon
```

### Recording Duration

Edit the Python source:

```bash
nano ~/path/to/voice-to-claude-cli/src/voice_holdtospeak.py
```

Find the `DURATION` constant at the top and change it:

```python
# Default is 5 seconds
DURATION = 10  # Change to 10 seconds
```

Restart the daemon:
```bash
systemctl --user restart voiceclaudecli-daemon
```

### Audio Beeps

Voice-to-Claude-CLI provides audio feedback when you start/stop recording. You can choose between **WAV files** (custom sounds) or **frequency tones** (simple beeps).

#### Using WAV Files (Custom Sounds)

**Default behavior:** The start beep now uses a WAV file (`sounds/start.wav`) for a more pleasant audio experience.

**To use your own WAV files:**

1. Place your WAV files in the `sounds/` directory:
   ```bash
   cp my-start-sound.wav sounds/start.wav
   cp my-stop-sound.wav sounds/stop.wav
   ```

2. Edit `src/voice_holdtospeak.py` (lines 28-32):
   ```python
   BEEP_USE_WAV_FILES = True
   BEEP_START_SOUND = os.path.join(os.path.dirname(__file__), '../sounds/start.wav')
   BEEP_STOP_SOUND = os.path.join(os.path.dirname(__file__), '../sounds/stop.wav')
   ```

3. Restart the daemon:
   ```bash
   systemctl --user restart voiceclaudecli-daemon
   ```

**WAV file requirements:**
- Format: Any WAV format supported by `paplay` (PCM, 16-bit recommended)
- Sample rate: Any (44.1kHz works well)
- Channels: Mono or stereo
- Duration: Keep short (100-500ms recommended for quick feedback)

**To trim a WAV file:**
```bash
# Using ffmpeg (trim to first 150ms)
ffmpeg -i sounds/start.wav -t 0.15 -c copy sounds/start-trimmed.wav
```

#### Using Frequency Tones (Simple Beeps)

**Switch back to frequency tones:**

Edit `src/voice_holdtospeak.py` (line 30):
```python
BEEP_USE_WAV_FILES = False  # Use frequency tones instead
```

**Customize frequency tones:**

Edit the constants (lines 35-37):
```python
BEEP_START_FREQUENCY = 800  # Hz - Higher = higher pitch
BEEP_STOP_FREQUENCY = 400   # Hz - Lower = lower pitch
BEEP_DURATION = 0.1         # seconds
```

#### Disable All Beeps

Edit `src/voice_holdtospeak.py` (line 26):
```python
BEEP_ENABLED = False  # Completely silent mode
```

After any changes, restart the daemon:
```bash
systemctl --user restart voiceclaudecli-daemon
```

### Desktop Notifications

**Disable notifications:**

Edit `src/voice_holdtospeak.py` and comment out `show_notification()` calls:

```python
# self.show_notification("Voice Transcription", preview)  # Disabled
```

**Change notification timeout:**

```python
NOTIFICATION_TIMEOUT = 5000  # milliseconds (5 seconds)
```

## Integration with Other Applications

### Bind to Global Hotkey (Non-F12)

**KDE Plasma:**
1. System Settings → Shortcuts → Custom Shortcuts
2. Click "Edit" → "New" → "Global Shortcut" → "Command/URL"
3. Trigger: Set your desired key (e.g., Meta+V)
4. Action: `/home/username/.local/bin/voiceclaudecli-input`

**GNOME:**
1. Settings → Keyboard → Keyboard Shortcuts
2. Click "+" to add custom shortcut
3. Name: Voice Input
4. Command: `/home/username/.local/bin/voiceclaudecli-input`
5. Set shortcut: Choose your key combination

**i3/Sway:**

Add to your config file:

```
bindsym $mod+v exec /home/username/.local/bin/voiceclaudecli-input
```

### Use in Scripts

```bash
#!/bin/bash
# Transcribe and save to file
cd /path/to/voice-to-claude-cli
source venv/bin/activate
TRANSCRIPTION=$(python -m src.voice_to_claude --once)
echo "$TRANSCRIPTION" >> notes.txt
```

### Pipe Output

```bash
# Transcribe and use in pipeline
cd /path/to/voice-to-claude-cli
source venv/bin/activate
python -m src.voice_to_claude --once | xargs -I {} echo "User said: {}"
```

## Development

### Running from Source

```bash
cd /path/to/voice-to-claude-cli
source venv/bin/activate

# Interactive mode
python -m src.voice_to_claude

# Hold-to-speak daemon
python -m src.voice_holdtospeak

# One-shot input
python -m src.voice_to_text
```

### Testing whisper.cpp Server

```bash
# Check if server is running
curl http://127.0.0.1:2022/health

# Start server manually
.whisper/scripts/start-server.sh

# Check server logs
journalctl --user -u whisper-server -f
```

### Platform Detection

```bash
# Check detected platform
cd /path/to/voice-to-claude-cli
source venv/bin/activate
python -m src.platform_detect
```

Output shows:
- Display server (Wayland/X11)
- Desktop environment
- Available tools (clipboard, keyboard simulation)

## Uninstallation

Complete removal of voice-to-claude-cli with automated uninstaller.

### Quick Uninstall

**Recommended:** Use the automated uninstaller:

```bash
# From Claude Code
/voice-claudecli-uninstall

# Or from terminal (interactive mode - prompts for each item)
bash scripts/uninstall.sh

# Remove everything (nuclear option)
bash scripts/uninstall.sh --all

# Keep models and project (remove only system integration)
bash scripts/uninstall.sh --keep-data
```

### Uninstall Modes

**Interactive Mode (default):**
- Prompts for each optional removal
- Shows disk space to be recovered
- Safe confirmation before proceeding

**All Mode (`--all`):**
- Removes EVERYTHING including:
  - System services and launcher scripts
  - Installation directories
  - whisper.cpp models (~142 MB)
  - Project directory
  - Claude Code plugin integration
- No prompts - use with caution!

**Keep Data Mode (`--keep-data`):**
- Removes only system integration:
  - systemd services
  - Launcher scripts
  - Installation directory
- Keeps for easy reinstall:
  - whisper.cpp models
  - Project directory
  - Claude Code plugin

### What Gets Removed

**Always Removed:**
- ✅ Systemd services (daemon, whisper-server)
- ✅ Launcher scripts (~/.local/bin/voiceclaudecli-*)
- ✅ Installation directory (~/.local/voiceclaudecli)
- ✅ Temporary build artifacts (/tmp/whisper.cpp)
- ✅ Running processes

**Optionally Removed (prompted in interactive mode):**
- 🔄 whisper.cpp models (~142 MB) - keeps if you want to reinstall
- 🔄 Project directory - keeps for easy reinstall
- 🔄 Claude Code plugin integration - searches multiple locations

**Never Removed:**
- ❌ User group membership (input group) - requires manual: `sudo deluser $USER input`

### Manual Uninstall (If Needed)

If you prefer to uninstall manually or the script doesn't work:

**1. Stop Services:**
```bash
systemctl --user stop voiceclaudecli-daemon whisper-server
systemctl --user disable voiceclaudecli-daemon whisper-server
pkill -f voice_holdtospeak
pkill -f whisper-server
```

**2. Remove Service Files:**
```bash
rm ~/.config/systemd/user/voiceclaudecli-daemon.service
rm ~/.config/systemd/user/whisper-server.service
systemctl --user daemon-reload
```

**3. Remove Launcher Scripts:**
```bash
rm ~/.local/bin/voiceclaudecli-*
```

**4. Remove Installation Directories:**
```bash
rm -rf ~/.local/voiceclaudecli
rm -rf /tmp/whisper.cpp
```

**5. Remove whisper.cpp Models (optional):**
```bash
rm -rf ~/voice-to-claude-cli/.whisper/models/
```

**6. Remove Project Directory (optional):**
```bash
cd ~
rm -rf ~/voice-to-claude-cli
```

**7. Remove Claude Code Plugin (optional):**
```bash
# From Claude Code
/plugin remove voice

# Or manually check these locations
rm -rf ~/.claude/plugins/voice-to-claude-cli
rm -rf ~/.config/claude/plugins/voice-to-claude-cli
rm -rf ~/.local/share/claude/plugins/voice-to-claude-cli
```

**8. Remove from input Group (optional, requires logout):**
```bash
sudo deluser $USER input
# Then log out and back in
```

### Reinstalling After Uninstall

**If you kept the project directory:**
```bash
cd ~/voice-to-claude-cli
bash scripts/install.sh
```

**If you removed everything:**
```bash
git clone https://github.com/aldervall/Voice-to-Claude-CLI.git
cd Voice-to-Claude-CLI
bash scripts/install.sh
```

## Troubleshooting

See main [README.md](README.md#troubleshooting) for common issues.

### Advanced Debugging

**Enable verbose logging:**

```bash
# Edit daemon service
nano ~/.config/systemd/user/voiceclaudecli-daemon.service

# Change ExecStart line
ExecStart=/home/username/.local/bin/voiceclaudecli-daemon --verbose

# Reload and restart
systemctl --user daemon-reload
systemctl --user restart voiceclaudecli-daemon

# View verbose logs
journalctl --user -u voiceclaudecli-daemon -f
```

**Test audio recording:**

```bash
cd /path/to/voice-to-claude-cli
source venv/bin/activate
python -c "from src.voice_to_claude import VoiceTranscriber; vt = VoiceTranscriber(); audio = vt.record_audio(3); print('Recording successful:', len(audio))"
```

**Test whisper.cpp transcription:**

```bash
cd /path/to/voice-to-claude-cli
source venv/bin/activate
python -c "from src.voice_to_claude import VoiceTranscriber; vt = VoiceTranscriber(); audio = vt.record_audio(3); print(vt.transcribe_audio(audio))"
```

## Privacy & Error Reporting

### Privacy-First Design

Voice-to-Claude-CLI is designed with **privacy as the foundation**:

- ✅ **100% Local Processing** - All voice transcription happens on your computer
- ✅ **No Cloud Services** - Zero API calls to external servers
- ✅ **No Telemetry** - We don't track usage, analytics, or collect any data
- ✅ **Open Source** - Full transparency - audit the code yourself

### Optional Error Reporting (Opt-In)

When installation errors occur, the installer can help us fix issues faster by allowing you to share diagnostic information. **This is completely optional and opt-in only.**

**Important:** Error reporting ONLY applies to the installation process (`scripts/install.sh`). The voice transcription daemon and runtime components **never** send any data anywhere - they operate 100% offline.

#### How It Works

1. **Installation fails** at any step
2. **Diagnostic report generated** and saved locally to:
   ```
   ~/.local/share/voice-to-claude-cli/error-reports/error-TIMESTAMP.txt
   ```
3. **You're asked** (interactive mode only): "Would you like to send this report?"
4. **Preview available** - You can see the entire report before deciding
5. **You decide:**
   - **Yes** → 😊 "Thank you! You're awesome!" → Report uploaded to GitHub gist
   - **No** → 😢 "Aww, okay... *sniff* We understand!" → Report stays local
6. **You get a URL** - Share it with us when filing an issue (if you sent it)

#### What's Included in Reports

**Safe technical data:**
- Operating system and version (e.g., "Ubuntu 22.04")
- Display server type (e.g., "Wayland" or "X11")
- Package manager and installation phase
- Error messages and exit codes
- Software versions (Python, pip, git)
- Package availability status

#### What's NEVER Included

**Personal information is sanitized:**
- ❌ Your username (replaced with `$USER`)
- ❌ Full file paths (replaced with `~`)
- ❌ Personal files or data
- ❌ Environment variables with secrets
- ❌ IP addresses
- ❌ Email or contact information

**Example:** See [docs/example-error-report.md](example-error-report.md) for exactly what a report looks like.

### Controlling Error Reporting

#### Environment Variable: `ENABLE_ERROR_REPORTING`

**Default: `prompt`** (ask permission interactively)

**Options:**

1. **Prompt mode (default):**
   ```bash
   bash scripts/install.sh
   # or
   ENABLE_ERROR_REPORTING=prompt bash scripts/install.sh
   ```
   - Interactive: Asks for consent with preview
   - Non-interactive: Saves report locally, no upload

2. **Always send (for CI/automation):**
   ```bash
   ENABLE_ERROR_REPORTING=always bash scripts/install.sh
   ```
   - Automatically sends reports without prompting
   - Useful for testing and CI environments
   - Still sanitizes all personal data

3. **Never send (privacy-focused):**
   ```bash
   ENABLE_ERROR_REPORTING=never bash scripts/install.sh
   ```
   - Disables error reporting prompts completely
   - Reports still saved locally for manual review
   - No network activity

#### Non-Interactive Mode Detection

The installer automatically detects non-interactive environments (CI/CD, scripts):
- No prompts shown
- Reports saved to `~/.local/share/voice-to-claude-cli/error-reports/`
- Set `ENABLE_ERROR_REPORTING=always` to auto-send in CI

#### Manual Sharing

If you skip sending during installation but later want to share:

1. **Find the report:**
   ```bash
   ls -lt ~/.local/share/voice-to-claude-cli/error-reports/
   ```

2. **Review the report:**
   ```bash
   cat ~/.local/share/voice-to-claude-cli/error-reports/error-TIMESTAMP.txt
   ```

3. **Create a gist manually:**
   - Visit: https://gist.github.com
   - Paste report contents
   - Create public gist
   - Share URL in GitHub issue

### Why We Ask

Error reports help us:
- **Fix distribution-specific issues** (package names, availability)
- **Improve error messages** with better troubleshooting steps
- **Identify common failure patterns** we didn't anticipate
- **Test on more platforms** than we have access to
- **Make installation smoother** for everyone

**We're genuinely grateful for your help - but it's never required!** 🙏

## Additional Resources

- **[README.md](README.md)** - Main documentation
- **[CLAUDE.md](CLAUDE.md)** - Developer guide and architecture
- **[HANDOVER.md](HANDOVER.md)** - Development history
- **[GitHub Issues](https://github.com/aldervall/Voice-to-Claude-CLI/issues)** - Report bugs
