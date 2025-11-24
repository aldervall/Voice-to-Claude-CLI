# AUR Package for VoiceType

This directory contains the files needed to publish VoiceType to the [Arch User Repository (AUR)](https://aur.archlinux.org/).

## Files

- `PKGBUILD` - Package build script
- `.SRCINFO` - Package metadata (generated from PKGBUILD)
- `voicetype.install` - Post-install/upgrade/remove messages

## Publishing to AUR

### One-Time Setup

1. **Create AUR Account**
   - Register at https://aur.archlinux.org/register/
   - Verify email

2. **Generate SSH Key**
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com" -f ~/.ssh/aur
   ```

3. **Add SSH Key to AUR**
   - Go to https://aur.archlinux.org/ → My Account → SSH Public Keys
   - Paste contents of `~/.ssh/aur.pub`

4. **Configure SSH**
   Add to `~/.ssh/config`:
   ```
   Host aur.archlinux.org
       IdentityFile ~/.ssh/aur
       User aur
   ```

### Initial Submission

1. **Test the package locally**
   ```bash
   cd aur/
   makepkg -si
   # Test that voicetype-daemon and voicetype-input work
   ```

2. **Generate proper checksums**
   ```bash
   # Download the source tarball
   wget https://github.com/aldervall/Voicetype/archive/v1.4.0.tar.gz
   sha256sum v1.4.0.tar.gz
   # Update sha256sums in PKGBUILD
   ```

3. **Regenerate .SRCINFO**
   ```bash
   makepkg --printsrcinfo > .SRCINFO
   ```

4. **Clone and push to AUR**
   ```bash
   git clone ssh://aur@aur.archlinux.org/voicetype-bin.git aur-repo
   cd aur-repo
   cp ../PKGBUILD ../voicetype.install ../.SRCINFO .
   git add PKGBUILD voicetype.install .SRCINFO
   git commit -m "Initial upload: voicetype-bin 1.4.0"
   git push
   ```

### Updating Package

When releasing a new version:

1. **Update PKGBUILD**
   - Change `pkgver=X.Y.Z`
   - Update checksums
   - Bump `pkgrel=1` (reset for new version)

2. **Regenerate .SRCINFO**
   ```bash
   makepkg --printsrcinfo > .SRCINFO
   ```

3. **Test locally**
   ```bash
   makepkg -si
   ```

4. **Push update**
   ```bash
   cd aur-repo
   git add PKGBUILD .SRCINFO
   git commit -m "Update to version X.Y.Z"
   git push
   ```

## Known Issues

### python-sounddevice Dependency

`python-sounddevice` is in AUR, not official repos. Users installing with `yay` or `paru` will automatically get this dependency, but plain `pacman` users will need to install it manually first.

### Model Download

The whisper model (~142MB) is downloaded on first use. This is intentional to keep the package small and allow users to choose when to download.

### Input Group Requirement

Users must be in the `input` group for the F12 hotkey to work. This is documented in post-install messages but cannot be automated due to security restrictions.

## Alternative: Chaotic-AUR

Once published to AUR, you can request inclusion in [Chaotic-AUR](https://aur.chaotic.cx/) for pre-built binary packages. This gives users:
- Faster installation (no build time)
- Automatic updates

## References

- [AUR Submission Guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- [PKGBUILD Documentation](https://wiki.archlinux.org/title/PKGBUILD)
- [Arch Package Guidelines](https://wiki.archlinux.org/title/Arch_package_guidelines)
- [Python Package Guidelines](https://wiki.archlinux.org/title/Python_package_guidelines)
