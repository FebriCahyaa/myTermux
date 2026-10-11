# GitHub Bootstrap for Ubuntu Proot (Python 3)

Standalone Python 3 bootstrap for Ubuntu and Ubuntu Proot. Generates SSH Ed25519 and GPG signing keys locally, configures Git signing, and uses GitHub CLI to register only public keys. It can publish this script to `FebriCahyaa/myTermux` on a new feature branch.

## Requirements

`python3`, `git`, `openssh-client`, `gnupg`, `pinentry-curses`, and GitHub CLI (`gh`).

## Run

```bash
python3 github_bootstrap.py
```

Run as the regular Ubuntu user, not root. Private SSH/GPG keys are never uploaded. GitHub login runs through the official `gh auth login` flow; uploads use `gh ssh-key add` and `gh gpg-key add`.

The script requests confirmation before uploading public keys and before pushing a signed commit to a separate feature branch. It never pushes directly to `main`.
