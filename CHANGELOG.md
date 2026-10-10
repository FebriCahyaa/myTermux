# Changelog

## MacPro Dark developer environment

- Replaced the narrow terminal-screen requirement with a modern, repeatable installer.
- Added separate interactive Termux display and Ubuntu Linux account/host configuration.
- Redesigned terminal colors, extra keys, prompt layout, and Starship configuration around a macOS-inspired graphite theme.
- Added base and optional Termux package manifests, including developer tooling.
- Added Ubuntu proot installation and idempotent bootstrap scripts for source, Android, and kernel development dependencies, with architecture/repository-aware package skipping.
- Added `ubuntu`, `ubroot`, `ubuntu-install`, `ubuntu-update`, and `mytermux-doctor` commands.
- Added lightweight startup behavior; system fetch output is now opt-in instead of running on every shell launch.
- Fixed several aliases that expanded positional parameters at definition time, and removed the recursive `exit` alias.
- Documented PRoot boundaries, storage expectations, and validation steps.
