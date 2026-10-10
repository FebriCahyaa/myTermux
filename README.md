# myTermux — MacPro Dark Developer Environment

A polished, macOS-inspired developer environment for Termux, with a repeatable setup flow for shell dotfiles, a custom `user@host` prompt, and a full Ubuntu userspace through `proot-distro`.

> **What this changes:** terminal colors, font, shell configuration, prompt identity, developer utilities, and an optional Ubuntu userspace. It does not turn Android into macOS, change Android's real app UID, or provide root privileges to the Android host.

## Features

- **MacPro Dark terminal style:** graphite background, muted Catppuccin-like accents, Nerd Font, two-line Starship prompt, Git branch/status, and a compact cursor.
- **Interactive identity setup:** configure a Termux prompt user/host and a separate Ubuntu Linux account/host.
- **Safer dotfile deployment:** only touched files are backed up with a timestamp; unrelated files in `$HOME/.config` are preserved.
- **Zsh environment:** Oh My Zsh, autosuggestions, syntax highlighting, fzf history search, autocomplete, and Starship when installed.
- **Developer tools:** Git/Git LFS, SSH, Python, Clang/LLVM, CMake, Ninja, Make, Rust, Node.js LTS, ripgrep, fzf, tmux, Neovim, jq, rsync, shellcheck, and other packages where available.
- **Ubuntu proot setup:** creates a regular Linux account, configures the prompt host, and installs common source-build, Android, ROM, and kernel development dependencies available for the installed Ubuntu release and device architecture.
- **Convenience commands:** `ubuntu`, `ubroot`, `ubuntu-install`, `ubuntu-update`, and `mytermux-doctor`.
- **Repeatable installation:** safe to run again; existing changed files receive timestamped backups.

## Requirements

1. Install Termux from [F-Droid](https://f-droid.org/en/packages/com.termux/) or the [official GitHub releases](https://github.com/termux/termux-app/releases). Keep Termux and its add-ons from the same source.
2. Have a working network connection and enough free storage. Installing the Ubuntu root filesystem and development dependencies may consume several gigabytes; Android ROM builds can need much more space.
3. The optional `termux-api` package also requires the separate Termux:API Android application. Most core terminal features do not require it.

## Install

```bash
pkg update
pkg install -y git

git clone --depth=1 https://github.com/FebriCahyaa/myTermux.git
cd myTermux
chmod +x install.sh
./install.sh
```

The installer asks for four values. On later runs, it reuses the previously saved identity values as defaults, so pressing Enter does not reset your custom names:

- **Termux display username** — shown in the prompt; it does not change Android's managed app UID.
- **Termux host label** — shown in the prompt.
- **Ubuntu Linux username** — a real non-root account in the Ubuntu userspace.
- **Ubuntu prompt host** — the host label shown by Ubuntu's prompt.

The default Termux package installation includes development tools. Optional media and Termux:API utilities are offered separately. At the end, choose whether to install Ubuntu immediately; the default is **No** because the download and build dependencies can be large.

To install Ubuntu later (the script defaults to Ubuntu 24.04 LTS unless an existing Ubuntu container is already installed):

```bash
ubuntu-install
```

To install dotfiles without changing packages:

```bash
./install.sh --skip-packages --skip-ubuntu
```

## Ubuntu proot workflow

```bash
ubuntu            # Open Ubuntu as the configured non-root account
ubroot            # Open an explicit administration shell inside Ubuntu
ubuntu-update     # Update and upgrade Ubuntu packages
ubuntu-install    # Install/reapply Ubuntu and build dependencies
mytermux-doctor   # Check package availability, profile, rootfs, and storage
mytermux-setup    # Reconfigure the saved Termux/Ubuntu identities
```

The configured Ubuntu session also mounts the Termux home at `/mnt/termux-home` (including files under that home, so its SSH configuration is visible inside Ubuntu) and shares `/tmp`; use `cdtermux` to enter the mounted home. Android shared storage remains available through `/sdcard` and `/storage` when Termux has storage permission; grant it with `termux-setup-storage`. The Ubuntu bootstrap installs packages such as `build-essential`, Clang/LLVM, GCC/G++, CMake, Ninja, Meson, Python tooling, Java's default JDK, Git/Git LFS, common kernel build dependencies, and Android utilities when the current Ubuntu repositories and CPU architecture provide them. Package availability differs across Ubuntu releases, so unavailable optional packages are reported and skipped rather than treated as guaranteed.

Use `ubroot` for package management or system-level changes **inside the Ubuntu proot**. `sudo` is intentionally not required by the setup workflow because PRoot's simulated privileges do not behave exactly like a normal VM or physical Linux installation.

### Important PRoot limitations

- PRoot is a Linux userspace environment, **not a virtual machine and not real Android root**. It cannot grant access to Android kernel interfaces or load kernel modules on the host.
- The configured Ubuntu hostname is used for shell prompts and is recorded in `/etc/hostname`; PRoot cannot reliably change the Android host kernel's actual hostname.
- Android storage, RAM, thermal throttling, process limits, and kernel behavior still constrain builds. Large AOSP/ROM builds may be impractical on a phone, and some build systems or services may require a conventional Linux machine.
- The bootstrap installs system build dependencies; it does not automatically download every Android SDK/NDK image or all ROM-specific proprietary blobs. Fetch those according to each project's instructions.

## Prompt and terminal style

The Starship prompt is configured in `~/.config/starship.toml`; terminal colors and keyboard rows are configured in `~/.termux/colors.properties` and `~/.termux/termux.properties`. If colors or fonts do not refresh automatically, restart the Termux session. The font shipped with this repository is Nerd Font-compatible for prompt icons.

Android Termux remains a native Android app, so macOS-style red/yellow/green window controls are only a visual reference; these dotfiles style the terminal content, not Android's app chrome. The installer keeps external command launches disabled by default for a safer Termux setup. If you intentionally use an add-on that requires external `RUN_COMMAND` launches, review that add-on and the `allow-external-apps` setting before enabling it.

## Useful Zsh helpers

- `mkcd DIR` — create a directory and enter it.
- `extract ARCHIVE` — extract supported tar, zip, gzip, bzip2, xz, or zstd archives.
- `gst` — compact Git status.
- `gdiff` — colorized Git diff.
- `ub` / `ubr` — enter Ubuntu as the configured user / simulated root.
- `mtdoctor` — run environment diagnostics.

The existing color/font/theme selector utilities remain in `.scripts/` for users who want to keep exploring the original myTermux setup.

## Validation

Run local static checks from the project root:

```bash
bash tests/validate.sh
```

## Credits

This repository retains the original myTermux utilities and credit context, including work/inspiration from siduck/NvChad, owl4ce, adi1090x, bandithijo, nekonako, contributors, Dotfiles Indonesia, Vim Indonesia, and Bashid.org. See [LICENSE](./LICENSE) for the project's license terms.
