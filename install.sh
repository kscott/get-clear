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
BASE="https://github.com/kscott"

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
