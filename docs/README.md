# VoiceType

Local voice transcription using whisper.cpp. 100% private - no API keys or cloud services required. Type with your voice into any application!

> **Note:** This was previously called Voice-to-Claude-CLI. The new name reflects that this tool works with ANY application, not just Claude Code.

> **🎤 QUICK START:** Hover over Claude Code, hold **F12**, speak, release. Your transcribed text appears directly in the Claude CLI input!

## Installation

### Arch Linux (AUR)

```bash
yay -S voicetype-bin
```

Then enable the daemon:
```bash
sudo usermod -a -G input $USER  # Required for F12 hotkey
# Log out and back in
systemctl --user enable --now voicetype-daemon
```

**Optional dependencies:**
```bash
sudo pacman -S ydotool wl-clipboard  # For auto-paste
systemctl --user enable --now ydotool
```

---

### Other Linux (via Claude Code)

<details>
<summary>Click to expand Claude Code installation</summary>

#### Quick Install (3 steps!)

**Step 1: Add the marketplace in Claude Code**

Open Claude Code and run:
```bash
/plugin
```

Select "Add Marketplace" and enter:
```
aldervall/VoiceType
```

**Step 2: Enable the plugin**

After installation, go back to `/plugin`, select "Manage plugins", find `voice`, press **Space** to enable it (turns yellow), then click "Apply changes".

**Restart Claude Code** when prompted!

**Step 3: Run the installer**
```bash
/voicetype-install
```

That's it! The installer shows beautiful progress indicators and progress bars for the ~142MB model download.

#### Available Commands

Once installed, you have three slash commands available in Claude Code:

```bash
/voicetype-install    # Install voice transcription system
/voicetype-uninstall  # Complete removal of everything
/voicetype            # Quick voice input (one-shot transcription)
```

</details>

## Usage

**Simple 4-step process:**

1. **Hover over Claude Code window**
2. **Hold F12** - You'll hear a beep (first press starts whisper.cpp in ~213ms)
3. **Speak clearly**
4. **Release F12** - Text appears in Claude CLI input

**That's it!**

### Resource Management

The whisper.cpp server **auto-starts on first F12 press** and stays running until you stop it manually:

```bash
# Stop whisper.cpp to free up resources
voicetype-stop-server

# Check if whisper is running
curl http://127.0.0.1:2022/health
```

**Why manual shutdown?** Keeps your system lightweight - the server only runs when you're actively using voice input. Startup is nearly instant (~213ms) so there's no convenience trade-off!

### Uninstalling

Complete removal of everything:

```bash
# From Claude Code
/voicetype-uninstall

# Or from terminal (interactive - prompts for each item)
bash scripts/uninstall.sh

# Remove everything (nuclear option)
bash scripts/uninstall.sh --all

# Keep models and installation files (remove only system integration)
bash scripts/uninstall.sh --keep-data
```

**What gets removed:**
- ✅ Systemd services (daemon, whisper-server)
- ✅ Launcher scripts
- ✅ Installation directories
- ✅ Optional: whisper.cpp models (~142 MB)
- ✅ Optional: Project directory
- ✅ Optional: Claude Code plugin integration

## Features

- **🎤 F12 Hold-to-Speak** - System-wide hotkey for voice input
- **🔒 100% Private** - Your voice never leaves your computer
- **⚡ Fast** - Instant local transcription
- **🐧 Linux Support** - Arch, Ubuntu, Fedora, OpenSUSE
- **🖥️ Wayland & X11** - Works with all display servers
- **🤖 Claude Code Integration** - Zero configuration needed
- **📦 Self-Contained** - Everything bundled, works offline
- **🔑 No API Keys** - No cloud services required

## Documentation

- **📚 [Complete Documentation Index](docs/INDEX.md)** - Find everything you need
- **🔧 [Advanced Usage](docs/ADVANCED.md)** - Customization, hotkeys, scripting
- **💻 [Developer Guide](docs/CLAUDE.md)** - Architecture, troubleshooting, contributing
- **🐛 [GitHub Issues](https://github.com/aldervall/VoiceType/issues)** - Report bugs or request features

## License

MIT License - see [LICENSE](LICENSE) for details.
