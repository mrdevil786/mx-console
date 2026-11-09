#!/bin/sh
# Install mx (MX Console) on macOS or Ubuntu/Debian.
#
#   curl -fsSL https://raw.githubusercontent.com/mrdevil786/mx-console/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --uninstall
#
# Re-running it upgrades an existing install. Windows uses install.ps1.

set -eu

REPO="${MX_REPO:-mrdevil786/mx-console}"
ASSET_URL="${MX_ASSET_URL:-}"
INSTALL_DIR="${MX_INSTALL_DIR:-$HOME/.local/share/matrix-stack}"
BIN_DIR="$HOME/.local/bin"
BIN="$INSTALL_DIR/mx"
LINK="$BIN_DIR/mx"

say() { printf '%s\n' "$*"; }
die() { printf 'mx: %s\n' "$*" >&2; exit 1; }

if [ "${1:-}" = "--uninstall" ]; then
    rm -f "$LINK"
    rm -f "$BIN"
    say "mx removed."
    say "Your settings and logs were kept in ~/.config/matrix-stack and ~/.local/state/matrix."
    exit 0
fi

case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)
        if ! grep -Eqi '^(ID|ID_LIKE)=.*(ubuntu|debian)' /etc/os-release 2>/dev/null; then
            die "this installer supports macOS and Ubuntu/Debian. This looks like another Linux distribution."
        fi
        OS=debian
        ;;
    *)
        die "this installer supports macOS and Ubuntu/Debian. On Windows use install.ps1 in PowerShell."
        ;;
esac

case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) ASSET=mx-macos-arm64 ;;
    Darwin-x86_64) ASSET=mx-macos-x64 ;;
    Linux-x86_64) ASSET=mx-linux-x64 ;;
    *) die "no prebuilt mx binary for $(uname -s)/$(uname -m)." ;;
esac

if [ -z "$ASSET_URL" ]; then
    ASSET_URL="https://github.com/$REPO/releases/latest/download/$ASSET"
fi

if ! command -v curl >/dev/null 2>&1; then
    if [ "$OS" = macos ]; then
        command -v brew >/dev/null 2>&1 || die "curl is missing. Reinstall macOS command line tools with: xcode-select --install"
        brew install curl || die "could not install curl."
    else
        sudo -v || die "admin rights are needed to install curl."
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl || die "could not install curl."
    fi
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

say "Downloading mx ($ASSET)..."
curl -fsSL "$ASSET_URL" -o "$tmp/mx" ||
    die "could not download $ASSET_URL. Check your internet connection, or set MX_ASSET_URL to a binary you built."
chmod +x "$tmp/mx"

# Sanity check the download before replacing the installed copy.
"$tmp/mx" --version >/dev/null 2>&1 ||
    die "the downloaded file is not a working mx binary."

mv -f "$tmp/mx" "$BIN"
chmod +x "$BIN"

ln -sf "$BIN" "$LINK"

version="$("$LINK" --version 2>&1)" ||
    die "mx was installed but did not start. Run '$LINK --version' to see why."

say ""
say "mx $version is installed."
say ""

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        shell_name="$(basename "${SHELL:-sh}")"
        case "$shell_name" in
            zsh) profile="$HOME/.zshrc" ;;
            bash) profile="$HOME/.bashrc" ;;
            *) profile="$HOME/.profile" ;;
        esac
        say "One last step: put $BIN_DIR on your PATH."
        say "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> $profile"
        say "Then open a new terminal."
        say ""
        ;;
esac

say "Start the control panel with: mx"
say "mx updates itself on the next launch; you can also run this installer again."
