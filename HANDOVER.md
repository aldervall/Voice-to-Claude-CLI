# Handover - VoiceType

**Last Updated:** 2025-11-24 (Session 38)
**Current Status:** ✅ Production Ready - v1.5.0
**Repository:** https://github.com/aldervall/Voicetype
**AUR Package:** https://aur.archlinux.org/packages/voicetype-bin

---

## 🔧 Development Workflow

### Software Updates (GitHub)

```bash
cd ~/aldervall/Voice-to-Claude-CLI

# Edit Python source code
vim src/voice_holdtospeak.py

# Test changes
source venv/bin/activate
systemctl --user restart voicetype-daemon

# Commit and push to GitHub
git add -A
git commit -m "feat: your feature"
git push origin main
```

### AUR Package Updates

```bash
cd ~/aldervall/Voice-to-Claude-CLI/aur

# Update version and sha256sum
vim PKGBUILD

# For new releases, get sha256:
curl -sL https://github.com/aldervall/Voicetype/archive/v1.6.0.tar.gz | sha256sum

# Regenerate metadata
makepkg --printsrcinfo > .SRCINFO

# Test locally
makepkg -si

# Push to AUR
git add PKGBUILD .SRCINFO
git commit -m "Update to v1.6.0"
git push origin master
```

**Note:** The `aur/` directory is a separate git repository that pushes directly to AUR.

---

## 🎯 Current Session (Session 38 - 2025-11-24)

### Mission: FIX AUR PACKAGE IMPORT ERROR 🔧

**Problem:** AUR package installed but daemon failed with:
```
ImportError: attempted relative import with no known parent package
```

**Root Cause:**
- Python files used relative imports (`from .voice_type import ...`)
- But PKGBUILD installed to `/usr/lib/voicetype/` and ran as `python -m voice_holdtospeak`
- Relative imports require proper package structure in site-packages

### What We Did

1. ✅ **Diagnosed the issue** - Checked systemd logs, found ImportError
2. ✅ **Fixed PKGBUILD** - Install to `site-packages/voicetype/` as proper Python package
3. ✅ **Updated launchers** - Changed to `python -m voicetype.voice_holdtospeak`
4. ✅ **Fixed whisper paths** - Install to `site-packages/.whisper/` to match code expectations
5. ✅ **Created models directory** - For first-use download
6. ✅ **Pushed to AUR** - Package now works correctly
7. ✅ **Separated aur/ into own git repo** - Direct AUR pushes without subtree complexity

### Key Changes

#### **1. PKGBUILD Restructure**

**Before (broken):**
```bash
install -Dm644 src/*.py -t "$pkgdir/usr/lib/voicetype/"
exec python -m voice_holdtospeak
```

**After (working):**
```bash
site_packages="$pkgdir$(python -c 'import site; print(site.getsitepackages()[0])')"
install -Dm644 src/*.py -t "$site_packages/voicetype/"
exec python -m voicetype.voice_holdtospeak
```

#### **2. Repository Structure**

**Main repo:** `~/aldervall/Voice-to-Claude-CLI/`
- Contains Python source, whisper binary, venv
- Pushes to GitHub

**AUR repo:** `~/aldervall/Voice-to-Claude-CLI/aur/`
- Now its own git repository (separate `.git`)
- Contains only: PKGBUILD, .SRCINFO, voicetype.install
- Pushes directly to AUR with `git push origin master`

**Why separate?** AUR requires files at repo root with no subdirectories. Having aur/ as a subdirectory in the main repo caused "repository must not contain subdirectories" errors.

### Workflow Going Forward

**Main project development:**
```bash
cd ~/aldervall/Voice-to-Claude-CLI
# Edit code, test, commit
git push origin main
```

**AUR package updates:**
```bash
cd ~/aldervall/Voice-to-Claude-CLI/aur
vim PKGBUILD  # Update version, sha256sum
makepkg --printsrcinfo > .SRCINFO
git commit -am "Update to vX.Y.Z"
git push origin master
```

**For new releases:**
1. Tag on GitHub: `git tag v1.6.0 && git push origin v1.6.0`
2. Get new sha256: `curl -sL https://github.com/.../v1.6.0.tar.gz | sha256sum`
3. Update PKGBUILD and push to AUR

### Technical Details

**Package installation path:**
```
/usr/lib/python3.13/site-packages/
├── voicetype/
│   ├── __init__.py
│   ├── voice_type.py
│   ├── voice_holdtospeak.py
│   ├── voice_to_text.py
│   ├── platform_detect.py
│   └── config.py
└── .whisper/
    ├── bin/whisper-server-linux-x64
    ├── models/  (empty, downloads on first use)
    └── scripts/*.sh
```

**Model download (one-time, needs sudo):**
```bash
sudo bash /usr/lib/python3.13/site-packages/.whisper/scripts/download-model.sh base.en
```

---

## Previous Sessions Summary

### Session 37 (2025-11-24) - Automated Release Script
- Created `scripts/release.sh` for GitHub + AUR releases
- Automated version bumping, tagging, and sha256sum generation

### Session 36 (2025-11-24) - Initial AUR Upload
- First successful AUR package submission
- Version 1.4.0 → 1.5.0 with configurable hotkey support

### Session 35 (2025-11-24) - AUR Package Creation
- Created PKGBUILD, .SRCINFO, voicetype.install
- Researched AUR requirements and submission process
- Updated README with AUR installation instructions

### Sessions 20-34 - Core Development
- Cross-platform support (Wayland/X11, multiple DEs)
- Hold-to-speak daemon with F12 hotkey
- Claude Code integration (skills, slash commands)
- whisper.cpp pre-built binary system
- Comprehensive documentation

---

## Quick Reference

**Check daemon:**
```bash
systemctl --user status voicetype-daemon
journalctl --user -u voicetype-daemon -f
```

**Test locally before AUR:**
```bash
cd ~/aldervall/Voice-to-Claude-CLI/aur
makepkg -si
```

**AUR package URL:**
https://aur.archlinux.org/packages/voicetype-bin
