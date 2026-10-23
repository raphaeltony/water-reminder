#!/usr/bin/env bash
#
# Remove water-reminder from the current user's account.
#
set -euo pipefail

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/water-reminder"
PURGE=0

usage() {
  cat <<EOF
Usage: ./uninstall.sh [OPTION]

Stop and remove the water reminder timer, service, and script.

Options:
  --bin-dir DIR   Directory the script was installed to (default: ~/.local/bin)
  --purge         Also delete your configuration directory
  -h, --help      Show this help and exit

EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --bin-dir)
      [[ $# -ge 2 && -n $2 ]] || die "missing value for --bin-dir"
      BIN_DIR=$2
      shift 2
      ;;
    --bin-dir=*)
      BIN_DIR=${1#*=}
      [[ -n $BIN_DIR ]] || die "--bin-dir cannot be empty"
      shift
      ;;
    --purge)
      PURGE=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1 (try --help)"
      ;;
  esac
done

BIN_DIR=$(realpath -m -- "$BIN_DIR")

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now water-reminder.timer >/dev/null 2>&1 || true
  systemctl --user reset-failed water-reminder.service >/dev/null 2>&1 || true
fi

rm -f "$UNIT_DIR/water-reminder.timer" "$UNIT_DIR/water-reminder.service"
rm -f "$BIN_DIR/water-reminder"

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload || true
fi

if [[ $PURGE -eq 1 ]]; then
  rm -rf "$CONFIG_DIR"
fi

printf 'water-reminder uninstalled.'
if [[ $PURGE -eq 1 ]]; then
  printf ' Configuration removed.'
fi
printf '\n'
