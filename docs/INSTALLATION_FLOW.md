# Installation Flow Verification Guide

## Overview

This document provides a comprehensive checklist for verifying the Voice-to-Claude-CLI installation flow works correctly from start to finish. Use this when testing changes to installation scripts or plugin configuration.

## Prerequisites Check

Before starting installation testing:

- [ ] Fresh Claude Code instance (or clean plugin state)
- [ ] Plugin not already installed
- [ ] No previous `.whisper/` directory in plugin location
- [ ] System has required build tools (git, make, gcc)

## Installation Flow Phases

### Phase 1: Marketplace Addition

**User Actions:**
1. Run `/plugin` in Claude Code
2. Select "Add Marketplace"
3. Enter `aldervall/Voice-to-Claude-CLI`
4. Press Enter/Submit

**Expected Results:**
- [ ] Marketplace added successfully
- [ ] `voice-to-claude-marketplace` appears in marketplace list
- [ ] `voice` plugin visible in available plugins
- [ ] No errors in Claude Code console

**Screenshot Reference:** `docs/images/Plugin.AddMarket.png`

**Common Issues:**
- **Marketplace not found:** Check GitHub repository is public
- **Invalid marketplace.json:** Verify `.claude-plugin/marketplace.json` exists and is valid JSON
- **Plugin not discovered:** Verify `plugin.json` exists at repository root

---

### Phase 2: Plugin Installation

**User Actions:**
1. Find `voice` plugin in marketplace
2. Press `i` to install
3. Wait for installation to complete

**Expected Results:**
- [ ] Installation completes without errors
- [ ] Prompt to restart Claude Code appears
- [ ] Plugin files copied to `~/.claude/plugins/marketplaces/voice-to-claude-marketplace/`

**Verify Files Exist:**
```bash
ls ~/.claude/plugins/marketplaces/voice-to-claude-marketplace/
# Expected: commands/, skills/, scripts/, src/, plugin.json, etc.
```

**Common Issues:**
- **Installation timeout:** Repository too large or slow network
- **Permission denied:** Check file permissions on plugin directory
- **Incomplete download:** Verify all files present in plugin directory

---

### Phase 3: Plugin Enable & Restart

**User Actions:**
1. Restart Claude Code (when prompted)
2. Run `/plugin` again
3. Select "Manage plugins"
4. Find `voice` in plugin list
5. Press **Space** to enable (turns yellow)
6. Click "Apply changes"
7. Restart Claude Code again

**Expected Results:**
- [ ] Plugin appears in "Manage plugins" list
- [ ] Plugin can be enabled (Space key works)
- [ ] Apply button becomes active
- [ ] Restart prompt appears
- [ ] After restart, plugin is active

**Screenshot Reference:** `docs/images/Plugin.Enable.png`

**Common Issues:**
- **Plugin not listed:** plugin.json not found at root
- **Can't enable:** Plugin validation failed (check JSON syntax)
- **Apply button disabled:** No changes detected
- **Still disabled after restart:** Check Claude Code logs for errors

---

### Phase 4: Slash Commands Available

**User Actions:**
1. Type `/voice` and check autocomplete
2. Run `/help` and search for voice commands

**Expected Results:**
- [ ] `/voice:voice-install` command available
- [ ] `/voice:voice` command available
- [ ] Commands appear in `/help` output
- [ ] No MCP commands (e.g., `/mcp__voicemode__*`) present

**Verify Command Discovery:**
```bash
# Check command files exist
ls ~/.claude/plugins/marketplaces/voice-to-claude-marketplace/commands/
# Expected: voice-install.md, voice.md
```

**Common Issues:**
- **Commands not found:** Check `commands/` directory exists at root
- **Wrong command names:** Plugin name affects prefix (should be `/voice:`)
- **Old MCP commands visible:** Remove old voicemode MCP server

---

### Phase 5: Run Installation (/voice:voice-install)

**User Actions:**
1. Run `/voice:voice-install`
2. Watch installation progress

**Expected Results:**
- [ ] Beautiful ASCII art banner displays
- [ ] Progress indicators show (1/7, 2/7, etc.)
- [ ] Color-coded status messages appear
- [ ] All steps complete or provide helpful errors

**Installation Steps (7 total):**

**Step 1/7: System Dependencies**
- [ ] Detects Linux distribution correctly
- [ ] Shows package install commands for distro
- [ ] Installs: python3, pip, ydotool, wl-clipboard/xclip, etc.
- [ ] Provides troubleshooting if install fails

**Step 2/7: Python Virtual Environment**
- [ ] Creates `venv/` in plugin directory
- [ ] Activates virtual environment
- [ ] Shows venv location

**Step 3/7: Python Packages**
- [ ] Installs requirements.txt packages
- [ ] Shows pip progress
- [ ] Verifies all imports work

**Step 4/7: User Groups (ydotool)**
- [ ] Checks if user in `input` group
- [ ] Adds user to group if needed
- [ ] Warns about logout/login requirement

**Step 5/7: Launcher Scripts**
- [ ] Creates `~/.local/bin/voiceclaudecli-input`
- [ ] Creates `~/.local/bin/voiceclaudecli-daemon`
- [ ] Makes scripts executable
- [ ] Verifies `~/.local/bin` in PATH

**Step 6/7: Systemd Services**
- [ ] Creates daemon service: `~/.config/systemd/user/voiceclaudecli-daemon.service`
- [ ] Reloads systemd daemon
- [ ] Service file has correct paths

**Step 7/7: whisper.cpp Installation**
- [ ] Shows whisper installer banner
- [ ] Checks for pre-built binary
- [ ] Tests binary with `ldd` for shared libraries
- [ ] Falls back to source build if libs missing
- [ ] Downloads ggml-base.en.bin model (~142MB with progress bar)
- [ ] Tests whisper server startup
- [ ] Creates whisper-server systemd service
- [ ] Asks to start server (or auto-starts in non-interactive mode)
- [ ] Asks to enable auto-start

**Common Issues:**
- **Script not found:** CLAUDE_PLUGIN_ROOT not set, fallback paths fail
- **Permission denied:** Package install requires sudo
- **Python import errors:** Missing system dependencies
- **Whisper server fails:** Check missing shared libraries
- **Model download hangs:** Network issue or disk space

---

### Phase 6: Post-Installation Verification

**User Actions:**
Run verification commands to ensure everything works.

**Health Checks:**

1. **Whisper Server Running**
```bash
curl http://127.0.0.1:2022/health
# Expected: {"status":"ok"}
```

2. **Services Active**
```bash
systemctl --user status whisper-server
systemctl --user status ydotool
```

3. **Python Environment Works**
```bash
source ~/.claude/plugins/marketplaces/voice-to-claude-marketplace/venv/bin/activate
python -c "from src.voice_to_claude import VoiceTranscriber; print('✓ Imports work')"
```

4. **Platform Detection Works**
```bash
cd ~/.claude/plugins/marketplaces/voice-to-claude-marketplace
source venv/bin/activate
python -m src.platform_detect
# Expected: Shows distro, display server, tools found
```

5. **Daemon Can Start**
```bash
systemctl --user start voiceclaudecli-daemon
systemctl --user status voiceclaudecli-daemon
# Expected: Active (running)
```

**Expected Results:**
- [ ] Whisper server responds to health check
- [ ] All services active
- [ ] Python imports successful
- [ ] Platform detection shows correct info
- [ ] Daemon starts without errors

**Common Issues:**
- **Whisper not responding:** Check `journalctl --user -u whisper-server`
- **Daemon crashes:** Check daemon logs for missing whisper server
- **Import errors:** Virtual environment not activated
- **Platform tools missing:** Rerun system dependency install

---

### Phase 7: Functional Testing

**User Actions:**
Test actual voice transcription functionality.

**Test 1: Interactive Mode**
```bash
cd ~/.claude/plugins/marketplaces/voice-to-claude-marketplace
source venv/bin/activate
python -m src.voice_to_claude
# Press ENTER, speak, verify transcription appears
```

**Test 2: One-Shot Mode**
```bash
voiceclaudecli-input
# Should record 5s, type transcription into active window
```

**Test 3: Daemon Mode (F12 Hold-to-Speak)**
1. Ensure daemon running: `systemctl --user status voiceclaudecli-daemon`
2. Hover over any text field
3. Hold F12, speak, release
4. Verify transcription appears in text field

**Test 4: Claude Skill (via Claude Code)**
Ask Claude: "Please record my voice and transcribe it"
- [ ] Claude activates voice skill
- [ ] Recording happens
- [ ] Transcription appears in conversation

**Expected Results:**
- [ ] All four modes work correctly
- [ ] Audio recorded successfully
- [ ] Transcription accurate
- [ ] Text appears in correct location
- [ ] No crashes or errors

**Common Issues:**
- **No audio recorded:** Check microphone permissions
- **Empty transcription:** Whisper server not running or wrong model
- **Can't type text:** ydotool not running or wrong user groups
- **F12 not detected:** User not in `input` group (logout required)
- **Skill not working:** Whisper server not available

---

## Success Criteria

Installation flow is considered successful when:

✅ **Plugin Discovery:** All commands visible after installation
✅ **Installation Completes:** All 7 steps finish successfully
✅ **Services Running:** whisper-server and ydotool active
✅ **Health Checks Pass:** All verification commands succeed
✅ **Functional Tests Pass:** All 4 modes transcribe correctly
✅ **Error Handling:** Helpful messages provided for all failures
✅ **Visual Polish:** Progress indicators and colors display correctly
✅ **Documentation:** Screenshots and docs match actual UI

---

## Troubleshooting Matrix

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Commands not visible | plugin.json not at root | Move plugin.json to repository root |
| Installation script not found | CLAUDE_PLUGIN_ROOT empty | Update command to check multiple paths |
| Package install fails | Wrong package names for distro | Update distro detection in install.sh |
| Python import errors | Missing system dependencies | Install python3-dev, portaudio |
| Whisper server won't start | Missing shared libraries | Enable build-from-source fallback |
| Daemon crashes | Can't connect to whisper | Verify whisper-server systemd service |
| F12 not detected | User not in input group | Add user to group, logout/login |
| Empty transcriptions | Microphone not detected | Check `python -c "import sounddevice as sd; print(sd.query_devices())"` |
| Can't type text | ydotool not running | `systemctl --user start ydotool` |
| Model download fails | Network or disk space | Check connectivity and `df -h` |

---

## Testing Checklist Summary

**Quick Test (5 minutes):**
- [ ] Add marketplace
- [ ] Install & enable plugin
- [ ] Verify commands appear
- [ ] Run `/voice:voice-install`
- [ ] Check whisper server: `curl http://127.0.0.1:2022/health`

**Full Test (15 minutes):**
- [ ] Complete all 7 installation phases
- [ ] Run all post-installation health checks
- [ ] Test all 4 functional modes
- [ ] Verify error messages helpful for common failures

**Regression Test (after code changes):**
- [ ] Plugin discovery still works
- [ ] Installation completes without new errors
- [ ] All existing functionality still works
- [ ] New features documented in this guide

---

## Developer Notes

**After Making Changes:**

1. **Plugin Changes (plugin.json, marketplace.json):**
   - Test plugin discovery from scratch
   - Verify command names correct

2. **Installation Script Changes (install.sh, install-whisper.sh):**
   - Test on clean system (no previous installation)
   - Test with missing dependencies
   - Verify error messages helpful

3. **Python Code Changes (src/*):**
   - Restart daemon: `systemctl --user restart voiceclaudecli-daemon`
   - Test all modes work
   - Check no import errors

4. **Documentation Changes (docs/*):**
   - Verify screenshots still accurate
   - Update version numbers
   - Test all code examples work

**Testing Environments:**

Ideally test on:
- [ ] Arch Linux (pacman)
- [ ] Ubuntu/Debian (apt)
- [ ] Fedora (dnf)
- [ ] Wayland environment
- [ ] X11 environment
- [ ] Fresh Claude Code install

**Git Flow:**
1. Make changes locally
2. Test installation flow completely
3. Commit with descriptive message
4. Push to GitHub
5. Test plugin refresh in Claude Code
6. Verify changes propagated correctly

---

## Appendix: File Locations

**Plugin Directory Structure:**
```
~/.claude/plugins/marketplaces/voice-to-claude-marketplace/
├── commands/
│   ├── voice-install.md
│   └── voice.md
├── skills/
│   └── voice/
│       ├── SKILL.md
│       └── scripts/transcribe.py
├── scripts/
│   ├── install.sh
│   └── install-whisper.sh
├── src/
│   ├── voice_to_claude.py
│   ├── platform_detect.py
│   ├── voice_holdtospeak.py
│   └── voice_to_text.py
├── .whisper/
│   ├── bin/
│   │   └── whisper-server-linux-x64
│   ├── models/
│   │   └── ggml-base.en.bin
│   └── scripts/
│       ├── start-server.sh
│       └── download-model.sh
├── venv/
├── plugin.json
└── .claude-plugin/marketplace.json
```

**User-Installed Files:**
```
~/.local/bin/
├── voiceclaudecli-input
└── voiceclaudecli-daemon

~/.config/systemd/user/
├── voiceclaudecli-daemon.service
└── whisper-server.service
```

**Critical Files for Installation Flow:**
- `plugin.json` - Must be at repository root for discovery
- `.claude-plugin/marketplace.json` - Enables trusted installation
- `commands/*.md` - Slash command definitions
- `scripts/install.sh` - Main installer (7 steps)
- `scripts/install-whisper.sh` - Whisper.cpp installer
- `.whisper/bin/whisper-server-linux-x64` - Pre-built binary

---

## Version History

**v1.2.0 (Current):**
- Created comprehensive installation flow documentation
- Added ldd test for pre-built binary shared library dependencies
- Fallback to source build if libraries missing
- Improved error messages with troubleshooting steps
- Visual polish: ASCII banners, progress indicators, colors
- Added installation screenshots to docs

**v1.1.0:**
- Fixed plugin discovery (moved plugin.json to root)
- Shortened plugin name from "voice-transcription" to "voice"
- Restored marketplace.json for trusted installation
- Fixed CLAUDE_PLUGIN_ROOT empty issue
- Removed `set -e` for graceful error handling

**v1.0.0:**
- Initial release
