# Quick Installation Testing Checklist

## 5-Minute Smoke Test

Use this checklist to quickly verify the installation flow works after making changes.

### 1. Plugin Discovery (2 min)

```bash
# Add marketplace in Claude Code
/plugin
# → Add Marketplace → aldervall/Voice-to-Claude-CLI

# Enable plugin
/plugin → Manage plugins → voice → Space → Apply changes → Restart
```

**✓ Pass Criteria:**
- Marketplace adds successfully
- Plugin appears in list
- Can be enabled without errors
- Commands appear after restart

---

### 2. Commands Available (30 sec)

```bash
# Check commands exist
/voice:voice-install
/voice:voice
/help | grep voice
```

**✓ Pass Criteria:**
- Both commands autocomplete
- No MCP commands visible
- Commands listed in /help

---

### 3. Run Installer (2 min)

```bash
/voice:voice-install
```

Watch for:
- [ ] ASCII banner displays
- [ ] Progress indicators (1/7, 2/7, etc.)
- [ ] Color-coded messages
- [ ] All steps complete or show helpful errors

**✓ Pass Criteria:**
- Installation completes without crashes
- Error messages are actionable
- Progress is visible throughout

---

### 4. Verify Services (30 sec)

```bash
# Whisper server health
curl http://127.0.0.1:2022/health
# Expected: {"status":"ok"}

# Services running
systemctl --user status whisper-server ydotool
```

**✓ Pass Criteria:**
- Whisper server responds
- Services are active
- No error messages in logs

---

### 5. Quick Functional Test (30 sec)

```bash
# Test interactive mode
cd ~/.claude/plugins/marketplaces/voice-to-claude-marketplace
source venv/bin/activate
python -m src.voice_to_claude
# Press ENTER, speak "testing one two three", verify output
```

**✓ Pass Criteria:**
- Audio records successfully
- Transcription appears
- No Python errors

---

## Pass/Fail Decision

**PASS:** All 5 checks complete successfully
**FAIL:** Any check fails or produces unhelpful error messages

If FAIL, consult `docs/INSTALLATION_FLOW.md` for detailed troubleshooting.

---

## After-Change Testing Priority

**Priority 1 (Always Test):**
- Plugin discovery (if changed plugin.json/marketplace.json)
- Installation completion (if changed install scripts)
- Services start (if changed systemd configs)

**Priority 2 (Regression Test):**
- All commands still work
- Functional tests pass
- Error messages still helpful

**Priority 3 (Full Test):**
- Test on different distros
- Test on Wayland vs X11
- Test with missing dependencies

---

## Quick Fixes Reference

| Issue | Quick Fix |
|-------|-----------|
| Commands not found | Check plugin.json at root |
| Script not found | Verify CLAUDE_PLUGIN_ROOT fallbacks |
| Whisper won't start | Check ldd output, enable source build |
| Daemon crashes | Verify whisper server running first |
| Python import error | Check venv activated, requirements installed |

---

## One-Liner Health Check

```bash
curl -s http://127.0.0.1:2022/health && \
systemctl --user is-active whisper-server ydotool && \
ls ~/.local/bin/voiceclaudecli-* && \
echo "✓ System healthy"
```

If this succeeds, installation is likely working correctly.
