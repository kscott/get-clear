#!/usr/bin/env bash
# Get Clear — shell installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kscott/get-clear/main/install.sh | bash
#
# Or to install to a different directory:
#   GET_CLEAR_BIN_DIR=/usr/local/bin curl -fsSL ... | bash

set -euo pipefail

TOOLS=(reminders calendar contacts mail sms)
BIN_DIR="${GET_CLEAR_BIN_DIR:-$HOME/.local/bin}"
ZSH_COMPLETIONS_DIR="${GET_CLEAR_ZSH_COMPLETIONS_DIR:-$HOME/.local/share/zsh/site-functions}"
BASE="https://github.com/kscott"
RAW="https://raw.githubusercontent.com/kscott/get-clear/main"

echo "Get Clear"
echo ""

mkdir -p "$BIN_DIR"

for tool in "${TOOLS[@]}"; do
    printf "  %-12s" "$tool"
    url="$BASE/${tool}-cli/releases/latest/download/${tool}-bin"
    dest="$BIN_DIR/$tool"
    if curl -fsSL -o "$dest" "$url" 2>/dev/null; then
        chmod +x "$dest"
        echo "installed"
    else
        echo "failed — check https://github.com/kscott/${tool}-cli/releases"
    fi
done

echo ""

# zsh completions
if [[ -n "${ZSH_VERSION:-}" ]] || command -v zsh &>/dev/null; then
    mkdir -p "$ZSH_COMPLETIONS_DIR"
    for tool in "${TOOLS[@]}"; do
        curl -fsSL -o "$ZSH_COMPLETIONS_DIR/_${tool}" "$RAW/completions/_${tool}" 2>/dev/null || true
    done

    SHELL_RC="$HOME/.zshrc"
    if [[ -f "$SHELL_RC" ]] && ! grep -q "get-clear.*site-functions\|site-functions.*get-clear" "$SHELL_RC"; then
        FPATH_LINE="fpath=($ZSH_COMPLETIONS_DIR \$fpath)"
        if grep -q "^compinit" "$SHELL_RC"; then
            # Insert fpath before the existing compinit call so it's in scope
            sed -i '' "/^compinit/i\\
# Get Clear — zsh completions\\
$FPATH_LINE" "$SHELL_RC"
        else
            {
                echo ""
                echo "# Get Clear — zsh completions"
                echo "$FPATH_LINE"
                echo "autoload -Uz compinit && compinit"
            } >> "$SHELL_RC"
        fi
        echo "  zsh completions installed — restart your shell to activate"
    else
        echo "  zsh completions installed to $ZSH_COMPLETIONS_DIR"
    fi
    echo ""
fi

# PATH check
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    SHELL_RC="$HOME/.zshrc"
    [[ ! -f "$SHELL_RC" && -f "$HOME/.bash_profile" ]] && SHELL_RC="$HOME/.bash_profile"

    {
        echo ""
        echo "# Get Clear"
        echo "export PATH=\"$BIN_DIR:\$PATH\""
    } >> "$SHELL_RC"

    echo "  Added $BIN_DIR to PATH in $SHELL_RC"
    echo "  Run: source $SHELL_RC  (or open a new terminal)"
    echo ""
fi

echo "Installed to $BIN_DIR."
echo ""
echo "Next steps:"
echo ""
echo "  1. Connect mail"
echo "     Fastmail → Settings → Privacy & Security → API tokens → New token (JMAP scope)"
echo "     Then: mail setup <your-token>"
echo ""
echo "  2. Set up calendar"
echo "     Run: calendar calendars  (to see your calendar names)"
echo "     Then create: ~/.config/calendar-cli/config.toml"
echo "     Example:"
echo "       [subsets]"
echo "       work     = [\"Work\", \"Meetings\"]"
echo "       personal = [\"Home\", \"Family\"]"
echo ""
echo "  3. First-run permissions"
echo "     Each tool asks once — just approve:"
echo "     reminders list · calendar today · contacts lists · sms open"
echo ""
echo "  https://github.com/kscott/get-clear"
