#!/usr/bin/env bash
# Install GIGABYTE GAMING A16 keyboard backlight support (HID LampArray)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="/usr/local/bin/gigabyte-kbd"
UDEV_RULES_DIR="/etc/udev/rules.d"
SYSTEMD_USER_DIR="/etc/systemd/user"
SYSTEMD_SYSTEM_DIR="/etc/systemd/system"
MACHINE_CONFIG="/etc/gigabyte-kbd.conf"

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root:  sudo $0" >&2
    exit 1
fi

install -Dm755 "$SCRIPT_DIR/scripts/gigabyte-kbd" "$BIN"
echo "Installed $BIN"

install -Dm644 "$SCRIPT_DIR/udev/99-gigabyte-kbd.rules" \
    "$UDEV_RULES_DIR/99-gigabyte-kbd.rules"
echo "Installed udev rule"
udevadm control --reload-rules
udevadm trigger
echo "Reloaded udev rules"

install -Dm644 "$SCRIPT_DIR/systemd/gigabyte-kbd.service" \
    "$SYSTEMD_USER_DIR/gigabyte-kbd.service"
echo "Installed user systemd unit (login restore)"

install -Dm644 "$SCRIPT_DIR/systemd/gigabyte-kbd-resume.service" \
    "$SYSTEMD_SYSTEM_DIR/gigabyte-kbd-resume.service"
if [[ ! -f "$MACHINE_CONFIG" ]]; then
    cat > "$MACHINE_CONFIG" <<'EOF'
# GIGABYTE GAMING A16 keyboard backlight default (used on resume)
color=ffffff
intensity=255
EOF
fi
echo "Installed resume hook (enable with: systemctl enable --now gigabyte-kbd-resume.service)"

if [[ -n "${SUDO_USER:-}" ]]; then
    uid="$(id -u "$SUDO_USER")"
    if [[ -d "/run/user/$uid" ]]; then
        XDG_RUNTIME_DIR="/run/user/$uid" \
            systemctl --user daemon-reload || true
        XDG_RUNTIME_DIR="/run/user/$uid" \
            systemctl --user enable gigabyte-kbd.service || true
        echo "Enabled login autostart for user $SUDO_USER"
    else
        echo "NOTE: no running session for $SUDO_USER; run later:"
        echo "      systemctl --user enable --now gigabyte-kbd.service"
    fi
fi

echo
echo "--- Testing ---"
"$BIN" info
"$BIN" color ffffff
echo "Backlight should be ON (white, host mode - autonomous NOT touched)."
echo "Try:"
echo "  $BIN color ff0000       # red (host mode, exact color)"
echo "  $BIN color ff0000 --auto   # red + autonomous (Fn+Space cycles)"
echo "  $BIN off"
echo "  $BIN restore"