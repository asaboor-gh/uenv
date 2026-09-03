#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$HOME/.local/share/uenv"
REPOSITORY="${GITHUB_REPOSITORY:-asaboor-gh/uenv}"
SCRIPT_URL="https://raw.githubusercontent.com/$REPOSITORY/main/uenv.sh"

mkdir -p "$TARGET_DIR"

echo "Downloading uenv script from $REPOSITORY..."
curl -fsSL "$SCRIPT_URL" -o "$TARGET_DIR/uenv.sh"
chmod +x "$TARGET_DIR/uenv.sh"

shell_rc=""
if [ -n "${ZSH_VERSION:-}" ] || [ "${SHELL##*/}" = "zsh" ]; then
    shell_rc="${ZDOTDIR:-$HOME}/.zshrc"
elif [ -n "${BASH_VERSION:-}" ] || [ "${SHELL##*/}" = "bash" ]; then
    shell_rc="$HOME/.bashrc"
fi

source_line="source \"$TARGET_DIR/uenv.sh\""

if [ -n "$shell_rc" ]; then
    touch "$shell_rc"

    if ! grep -Fq "$source_line" "$shell_rc"; then
        {
            echo ""
            echo "# Load uenv utility"
            echo "$source_line"
        } >> "$shell_rc"

        echo "Added uenv loader to $shell_rc"
    else
        echo "uenv loader already exists in $shell_rc"
    fi

    echo "Installation successful. Restart your terminal or run: source $shell_rc"
else
    echo "Could not detect a supported shell profile automatically." >&2
    echo "Add this line to your shell config manually:" >&2
    echo "  $source_line" >&2
fi
