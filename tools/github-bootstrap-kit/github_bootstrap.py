#!/usr/bin/env python3
"""GitHub bootstrap for Ubuntu / Ubuntu Proot.

Creates local SSH Ed25519 and GPG signing keys, configures Git, optionally
registers PUBLIC keys with GitHub CLI, then optionally pushes this script to a
new feature branch in FebriCahyaa/myTermux and opens a pull request.

Private keys never leave the local machine. Requires Python 3 standard library
plus git, openssh-client, gnupg, and GitHub CLI (gh) for online GitHub actions.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Sequence

VERSION = "1.0.0"
DEFAULT_REPO = "FebriCahyaa/myTermux"
SCRIPT_REPO_PATH = "tools/github-bootstrap-kit/github_bootstrap.py"
README_REPO_PATH = "tools/github-bootstrap-kit/README-python.md"


def say(message: str) -> None:
    print(f"[INFO] {message}")


def good(message: str) -> None:
    print(f"[ OK ] {message}")


def warning(message: str) -> None:
    print(f"[WARN] {message}", file=sys.stderr)


def fail(message: str, code: int = 1) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(code)


def ask(prompt: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    try:
        answer = input(f"{prompt}{suffix}: ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        fail("Dibatalkan.", 130)
    return answer or default


def confirm(prompt: str, default: bool = False) -> bool:
    hint = "Y/n" if default else "y/N"
    answer = ask(f"{prompt} ({hint})", "y" if default else "n").lower()
    return answer in {"y", "yes", "ya"}


def run(
    args: Sequence[str],
    *,
    check: bool = True,
    capture: bool = False,
    timeout: int | None = None,
    env: dict[str, str] | None = None,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            list(args),
            cwd=str(cwd) if cwd else None,
            env=env,
            text=True,
            check=check,
            capture_output=capture,
            timeout=timeout,
        )
    except FileNotFoundError:
        fail(f"Perintah tidak ditemukan: {args[0]}")
    except subprocess.TimeoutExpired:
        fail(f"Perintah melewati batas waktu: {' '.join(args)}")
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip() if capture else ""
        if detail:
            print(detail, file=sys.stderr)
        fail(f"Perintah gagal (exit {exc.returncode}): {' '.join(args)}", exc.returncode or 1)


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def check_platform_and_dependencies() -> None:
    if not sys.platform.startswith("linux"):
        fail("Skrip ini ditujukan untuk Ubuntu/Linux (termasuk Ubuntu Proot).")
    if os.geteuid() == 0:
        fail("Jalankan sebagai user Ubuntu biasa (contoh: febricahyaa), bukan root/ubroot. Kunci harus tersimpan di HOME user.")
    required = ["git", "ssh", "ssh-keygen", "gpg"]
    missing = [name for name in required if not command_exists(name)]
    if missing:
        print("Dependensi belum lengkap: " + ", ".join(missing))
        print("Di Termux jalankan ubroot, lalu di shell root Ubuntu:")
        print("  apt update && apt install -y git openssh-client gnupg pinentry-curses ca-certificates curl")
        print("Keluar dari root dengan 'exit', masuk sebagai user biasa melalui 'ubuntu', lalu jalankan ulang skrip.")
        raise SystemExit(2)
    if not command_exists("gh"):
        print("GitHub CLI (gh) belum terpasang. Key lokal tetap dapat dibuat, tetapi upload dan push butuh gh.")
        print("Coba di Ubuntu: sudo apt install gh -y (atau ikuti panduan https://github.com/cli/cli/blob/trunk/docs/install_linux.md).")


def git_config(key: str) -> str:
    result = subprocess.run(["git", "config", "--global", "--get", key], text=True, capture_output=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def add_line_once(path: Path, line: str, marker: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    if marker in content:
        return
    with path.open("a", encoding="utf-8") as stream:
        if content and not content.endswith("\n"):
            stream.write("\n")
        stream.write("\n" + line + "\n")


def configure_pinentry() -> None:
    gnupg = Path.home() / ".gnupg"
    gnupg.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        gnupg.chmod(0o700)
    except OSError:
        pass
    tty = subprocess.run(["tty"], text=True, capture_output=True).stdout.strip()
    if tty and tty != "not a tty":
        os.environ["GPG_TTY"] = tty
    current = gnupg / "gpg-agent.conf"
    pinentry = next((shutil.which(p) for p in ("pinentry-curses", "pinentry-tty", "pinentry") if shutil.which(p)), None)
    if pinentry and not current.exists():
        current.write_text(f"pinentry-program {pinentry}\n", encoding="utf-8")
        current.chmod(0o600)
    for rc_name in (".zshrc", ".bashrc"):
        rc = Path.home() / rc_name
        if rc.exists():
            add_line_once(rc, 'export GPG_TTY="$(tty)"', "export GPG_TTY=\"$(tty)\"")


def gpg_fingerprint_for_email(email: str) -> str:
    proc = subprocess.run(
        ["gpg", "--batch", "--with-colons", "--list-secret-keys", email],
        text=True,
        capture_output=True,
        env=os.environ.copy(),
    )
    if proc.returncode != 0:
        return ""
    current_key_has_secret = False
    for line in proc.stdout.splitlines():
        fields = line.split(":")
        record = fields[0]
        if record in {"sec", "ssb"}:
            current_key_has_secret = record == "sec"
        elif record == "fpr" and current_key_has_secret and len(fields) > 9:
            return fields[9].upper()
        elif record == "uid" and len(fields) > 9 and email.lower() not in fields[9].lower():
            # Do not choose a key whose current UID record is unrelated.
            current_key_has_secret = False
    return ""


def ensure_ssh_key(email: str, title: str) -> Path:
    ssh_dir = Path.home() / ".ssh"
    ssh_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    ssh_dir.chmod(0o700)
    private = ssh_dir / "id_ed25519_github"
    public = Path(str(private) + ".pub")
    if private.is_file() and public.is_file() and private.stat().st_size and public.stat().st_size:
        good(f"SSH key yang ada akan dipakai ulang: {public}")
    elif private.exists() or public.exists():
        fail(f"Pasangan SSH key tidak lengkap di {private}; file tidak ditimpa. Cadangkan/perbaiki secara manual.")
    else:
        say("Membuat SSH Ed25519. Isi passphrase kuat saat diminta; boleh gunakan password manager.")
        run(["ssh-keygen", "-t", "ed25519", "-a", "100", "-C", email, "-f", str(private)])
    private.chmod(0o600)
    public.chmod(0o644)

    config = ssh_dir / "config"
    existing = config.read_text(encoding="utf-8", errors="replace") if config.exists() else ""
    if not re.search(r"(?mi)^\s*Host\s+[^\n]*\bgithub\.com\b", existing):
        with config.open("a", encoding="utf-8") as stream:
            if existing and not existing.endswith("\n"):
                stream.write("\n")
            stream.write(
                "\n# GitHub Bootstrap Kit\n"
                "Host github.com\n"
                "    HostName github.com\n"
                "    User git\n"
                f"    IdentityFile {private}\n"
                "    IdentitiesOnly yes\n"
                "    AddKeysToAgent yes\n"
            )
        config.chmod(0o600)
        good(f"SSH host config dibuat: {config}")
    else:
        warning("Host github.com sudah ada di ~/.ssh/config; konfigurasi yang ada dipertahankan.")
    return public


def ensure_gpg_key(name: str, email: str) -> tuple[str, Path]:
    configure_pinentry()
    fingerprint = gpg_fingerprint_for_email(email)
    if not fingerprint:
        say("Membuat GPG Ed25519 khusus signing. GPG akan meminta passphrase melalui pinentry.")
        env = os.environ.copy()
        if env.get("GPG_TTY"):
            env["GPG_TTY"] = env["GPG_TTY"]
        run(["gpg", "--quick-generate-key", f"{name} <{email}>", "ed25519", "sign", "2y"], env=env)
        fingerprint = gpg_fingerprint_for_email(email)
    if not re.fullmatch(r"[A-F0-9]{40,64}", fingerprint):
        fail("Fingerprint kunci rahasia GPG tidak berhasil ditemukan. Pastikan key memiliki kemampuan signing dan email UID cocok.")
    public_path = Path.home() / ".gnupg" / "github-public-key.asc"
    exported = run(["gpg", "--armor", "--export", fingerprint], capture=True).stdout
    if not exported.strip():
        fail("Ekspor public GPG key gagal.")
    public_path.write_text(exported, encoding="utf-8")
    public_path.chmod(0o644)
    good(f"GPG fingerprint: {fingerprint}")
    good(f"Public GPG key: {public_path}")
    return fingerprint, public_path


def configure_git(name: str, email: str, fingerprint: str) -> None:
    settings = {
        "user.name": name,
        "user.email": email,
        "gpg.format": "openpgp",
        "user.signingkey": fingerprint,
        "gpg.program": shutil.which("gpg") or "gpg",
        "commit.gpgsign": "true",
        "tag.gpgsign": "true",
    }
    for key, value in settings.items():
        run(["git", "config", "--global", key, value])
    good("Git identity dan GPG signing untuk commit/tag diaktifkan.")


def ensure_gh_auth() -> bool:
    if not command_exists("gh"):
        warning("GitHub CLI gh tidak terpasang; skip pendaftaran key dan push.")
        return False
    status = subprocess.run(["gh", "auth", "status", "--hostname", "github.com"], text=True, capture_output=True)
    if status.returncode != 0:
        if not confirm("Login GitHub CLI sekarang melalui browser/device flow?", True):
            return False
        result = subprocess.run(["gh", "auth", "login", "--hostname", "github.com", "--git-protocol", "ssh", "--web"], check=False)
        if result.returncode != 0:
            warning("Autentikasi gh belum berhasil.")
            return False
    proc = subprocess.run(["gh", "api", "user", "--jq", ".login"], text=True, capture_output=True)
    if proc.returncode != 0 or not proc.stdout.strip():
        warning("Tidak dapat memeriksa akun gh yang aktif.")
        return False
    good(f"GitHub CLI login: {proc.stdout.strip()}")
    return True


def gh_json(endpoint: str) -> list[dict] | None:
    proc = subprocess.run(["gh", "api", endpoint], text=True, capture_output=True)
    if proc.returncode != 0:
        warning(f"Tidak dapat membaca {endpoint}; mungkin perlu memperbarui permission gh.")
        return None
    try:
        obj = json.loads(proc.stdout)
        return obj if isinstance(obj, list) else None
    except json.JSONDecodeError:
        return None


def register_public_keys(ssh_public: Path, ssh_title: str, gpg_public: Path, fingerprint: str) -> None:
    if not ensure_gh_auth():
        return
    if confirm("Upload SSH PUBLIC key ke akun GitHub (private key tidak diunggah)?", True):
        ssh_line = ssh_public.read_text(encoding="utf-8").strip()
        records = gh_json("user/keys")
        if records is not None and any(str(item.get("key", "")).strip() == ssh_line for item in records):
            good("SSH public key sudah terdaftar di GitHub.")
        else:
            proc = subprocess.run(["gh", "ssh-key", "add", str(ssh_public), "--type", "authentication", "--title", ssh_title], check=False)
            if proc.returncode == 0:
                good("SSH public key berhasil didaftarkan.")
            else:
                warning("SSH key belum terdaftar. Periksa output gh dan permission admin:public_key.")
    if confirm("Upload GPG PUBLIC key untuk verified commit signature?", True):
        gpg_records = gh_json("user/gpg_keys")
        suffix = fingerprint[-16:].upper()
        found = False
        if gpg_records is not None:
            for item in gpg_records:
                key_id = str(item.get("key_id", "")).upper().removeprefix("0X")
                if key_id and (key_id == suffix or fingerprint.endswith(key_id)):
                    found = True
                    break
        if found:
            good("GPG public key sudah terdaftar di GitHub.")
        else:
            proc = subprocess.run(["gh", "gpg-key", "add", str(gpg_public), "--title", f"{ssh_title} GPG signing"], check=False)
            if proc.returncode == 0:
                good("GPG public key berhasil didaftarkan.")
            else:
                warning("GPG key belum terdaftar. Pastikan email UID cocok dengan email GitHub terverifikasi dan izin gh mencukupi.")


def verify_ssh_auth() -> bool:
    say("Menguji autentikasi SSH GitHub. Passphrase key mungkin diminta.")
    proc = subprocess.run(
        ["ssh", "-T", "-o", "StrictHostKeyChecking=accept-new", "git@github.com"],
        text=True,
        capture_output=True,
        timeout=45,
    )
    output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    if "successfully authenticated" in output.lower():
        good("Autentikasi SSH GitHub berhasil (GitHub tidak menyediakan shell interaktif; exit 1 normal).")
        return True
    if output.strip():
        print(output.strip())
    warning("Autentikasi SSH belum terkonfirmasi. Push via SSH akan dilewati agar tidak gagal diam-diam.")
    return False


def publish_script_to_mytermux(fingerprint: str) -> None:
    if not command_exists("gh") or not ensure_gh_auth():
        warning("Push dilewati karena GitHub CLI belum siap.")
        return
    login_proc = run(["gh", "api", "user", "--jq", ".login"], capture=True)
    login = login_proc.stdout.strip()
    if login.lower() != "febricahyaa" and not confirm(f"Login aktif adalah {login}, bukan FebriCahyaa. Lanjut mencoba push?", False):
        return
    if not verify_ssh_auth():
        warning("Tambahkan public SSH key di GitHub dan jalankan ulang script sebelum push.")
        return

    source_script = Path(__file__).resolve()
    dest_parent = Path.home() / "src"
    dest_parent.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    clone_dir = dest_parent / f"myTermux-github-bootstrap-{stamp}"
    say(f"Clone {DEFAULT_REPO} ke {clone_dir}")
    run(["gh", "repo", "clone", DEFAULT_REPO, str(clone_dir)])
    run(["git", "remote", "set-url", "origin", f"git@github.com:{DEFAULT_REPO}.git"], cwd=clone_dir)
    branch = f"feat/github-bootstrap-python-{stamp}"
    run(["git", "switch", "-c", branch], cwd=clone_dir)

    script_target = clone_dir / SCRIPT_REPO_PATH
    readme_target = clone_dir / README_REPO_PATH
    script_target.parent.mkdir(parents=True, exist_ok=True)
    script_target.write_bytes(source_script.read_bytes())
    script_target.chmod(0o755)
    readme = f"""# GitHub Bootstrap for Ubuntu Proot (Python 3)\n\nStandalone Python 3 bootstrap for Ubuntu and Ubuntu Proot. Generates SSH Ed25519 and GPG signing keys locally, configures Git signing, and uses GitHub CLI to register only public keys. It can publish this script to `{DEFAULT_REPO}` on a new feature branch.\n\n## Requirements\n\n`python3`, `git`, `openssh-client`, `gnupg`, `pinentry-curses`, and GitHub CLI (`gh`).\n\n## Run\n\n```bash\npython3 github_bootstrap.py\n```\n\nRun as the regular Ubuntu user, not root. Private SSH/GPG keys are never uploaded. GitHub login runs through the official `gh auth login` flow; uploads use `gh ssh-key add` and `gh gpg-key add`.\n\nThe script requests confirmation before uploading public keys and before pushing a signed commit to a separate feature branch. It never pushes directly to `main`.\n"""
    readme_target.write_text(readme, encoding="utf-8")
    run(["git", "add", "--", SCRIPT_REPO_PATH, README_REPO_PATH], cwd=clone_dir)
    say("Membuat commit bertanda tangan GPG.")
    proc = subprocess.run(
        ["git", "commit", "-S", "-m", "feat(github): add Ubuntu Python SSH and GPG bootstrap"],
        cwd=clone_dir,
        text=True,
    )
    if proc.returncode != 0:
        fail("Commit GPG signing gagal. Pastikan GPG key aktif dan passphrase/pinentry bekerja; tidak ada push dilakukan.")
    run(["git", "push", "-u", "origin", branch], cwd=clone_dir)
    good(f"Push sukses ke {DEFAULT_REPO}, branch {branch}")

    if confirm("Buat Pull Request ke main sekarang?", True):
        title = "feat(github): add Ubuntu Python SSH and GPG bootstrap"
        body = (
            "## Summary\n"
            "- Add standalone Python 3 bootstrap for Ubuntu/Ubuntu Proot.\n"
            "- Generate SSH/GPG keys locally and configure Git commit/tag signing.\n"
            "- Use GitHub CLI to register public keys only.\n"
            "- Keep private key material off GitHub and push via a separate feature branch.\n\n"
            "## Validation\n"
            "- Python standard-library only; uses local `git`, `ssh-keygen`, `gpg`, and `gh` commands.\n"
        )
        pr = subprocess.run(["gh", "pr", "create", "--repo", DEFAULT_REPO, "--base", "main", "--head", branch, "--title", title, "--body", body], cwd=clone_dir, text=True, capture_output=True)
        if pr.returncode == 0:
            good("Pull Request berhasil dibuat: " + pr.stdout.strip())
        else:
            warning("Branch sudah dipush, tetapi PR otomatis gagal. Buat PR dari branch ini secara manual.")
            if pr.stderr:
                print(pr.stderr.strip(), file=sys.stderr)
    print(f"Working copy: {clone_dir}")


def main() -> int:
    print(f"\nGitHub Bootstrap for Ubuntu / Proot v{VERSION}")
    print("SSH Ed25519 + GPG signing + optional GitHub registration/push\n")
    check_platform_and_dependencies()
    name_default = git_config("user.name") or "FEBRIAN RAHMAD CAHYA"
    email_default = git_config("user.email")
    name = ask("Nama author Git", name_default)
    email = ask("Email yang terverifikasi di GitHub", email_default)
    if not name:
        fail("Nama author tidak boleh kosong.")
    if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
        fail("Format email tidak valid; masukkan email yang terverifikasi pada akun GitHub.")
    title = ask("Label key perangkat", f"Ubuntu-Proot-{os.uname().machine}-{dt.datetime.now():%Y-%m}")

    ssh_public = ensure_ssh_key(email, title)
    fingerprint, gpg_public = ensure_gpg_key(name, email)
    configure_git(name, email, fingerprint)

    print("\nKey dibuat/siap digunakan:")
    print(f"  SSH public : {ssh_public}")
    print(f"  SSH private: {ssh_public.with_suffix('')}  [RAHASIA — jangan dibagikan]")
    print(f"  GPG public : {gpg_public}")
    print(f"  GPG fpr    : {fingerprint}")

    if command_exists("gh"):
        if confirm("Lanjutkan login/registrasi public keys ke GitHub?", True):
            register_public_keys(ssh_public, title, gpg_public, fingerprint)
        if confirm(f"Push script Python ini ke {DEFAULT_REPO} pada branch baru dan (opsional) buat PR?", True):
            publish_script_to_mytermux(fingerprint)
    else:
        warning("Kunci lokal siap, tetapi upload/push belum dilakukan karena gh tidak tersedia.")
        print("Install GitHub CLI lalu jalankan ulang untuk mendaftarkan public keys dan push.")

    print("\nVerifikasi yang bisa dijalankan kapan saja:")
    print(f"  ssh-keygen -lf '{ssh_public}'")
    print("  gpg --list-secret-keys --keyid-format LONG")
    print("  git config --global --get commit.gpgsign")
    print("  ssh -T git@github.com")
    print("\nSelesai. Private key tetap berada di HOME perangkat ini.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nDibatalkan.", file=sys.stderr)
        raise SystemExit(130)
