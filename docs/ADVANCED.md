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

**Disable beeps:**

Edit `src/voice_holdtospeak.py`:

```python
# Find the play_beep() calls and comment them out
# self.play_beep(BEEP_START_FREQUENCY, BEEP_DURATION)  # Disabled
```

**Change beep frequency:**

Edit the constants at the top of `src/voice_holdtospeak.py`:

```python
BEEP_START_FREQUENCY = 800  # Hz - Higher = higher pitch
BEEP_STOP_FREQUENCY = 400   # Hz - Lower = lower pitch
BEEP_DURATION = 0.1         # seconds
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

### Remove Services

```bash
# Stop and disable services
systemctl --user stop voiceclaudecli-daemon whisper-server
systemctl --user disable voiceclaudecli-daemon whisper-server

# Remove service files
rm ~/.config/systemd/user/voiceclaudecli-daemon.service
rm ~/.config/systemd/user/whisper-server.service

# Reload systemd
systemctl --user daemon-reload
```

### Remove Launcher Scripts

```bash
rm ~/.local/bin/voiceclaudecli-*
```

### Remove Project Directory

```bash
rm -rf ~/path/to/voice-to-claude-cli
```

### Remove Claude Code Plugin

```bash
/plugin remove voice-transcription
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

## Additional Resources

- **[README.md](README.md)** - Main documentation
- **[CLAUDE.md](CLAUDE.md)** - Developer guide and architecture
- **[HANDOVER.md](HANDOVER.md)** - Development history
- **[GitHub Issues](https://github.com/aldervall/Voice-to-Claude-CLI/issues)** - Report bugs
