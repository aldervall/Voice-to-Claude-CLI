# Voice-to-Claude-CLI

Local voice transcription for Claude Code using whisper.cpp. 100% private - no API keys or cloud services required.

> **🎤 QUICK START:** Hover over Claude Code, hold **F12**, speak, release. Your transcribed text appears directly in the Claude CLI input!

## Installation

### Quick Install (3 steps!)

**Step 1: Add the marketplace in Claude Code**

Open Claude Code and run:
```bash
/plugin
```

Select "Add Marketplace" and enter:
```
aldervall/Voice-to-Claude-CLI
```

![Add Marketplace](docs/images/Plugin.AddMarket.png)

**Step 2: Enable the plugin**

After installation, go back to `/plugin`, select "Manage plugins", find `voice`, press **Space** to enable it (turns yellow), then click "Apply changes".

![Enable Plugin](docs/images/Plugin.Enable.png)

**Restart Claude Code** when prompted!

**Step 3: Run the installer**
```bash
/voice:voice-install
```

That's it! The installer shows beautiful progress indicators and progress bars for the ~142MB model download.

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
voiceclaudecli-stop-server

# Check if whisper is running
curl http://127.0.0.1:2022/health
```

**Why manual shutdown?** Keeps your system lightweight - the server only runs when you're actively using voice input. Startup is nearly instant (~213ms) so there's no convenience trade-off!

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

- **📚 [Complete Documentation Index](INDEX.md)** - Find everything you need
- **🔧 [Advanced Usage](ADVANCED.md)** - Customization, hotkeys, scripting
- **💻 [Developer Guide](CLAUDE.md)** - Architecture, troubleshooting, contributing
- **🐛 [GitHub Issues](https://github.com/aldervall/Voice-to-Claude-CLI/issues)** - Report bugs or request features

## License

MIT License - see [LICENSE](LICENSE) for details.
