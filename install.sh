#!/usr/bin/env bash
#
# Install water-reminder as a systemd user timer.
#
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

INTERVAL="1h"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
START=1
SEND_TEST=0

usage() {
  cat <<EOF
Usage: ./install.sh [OPTION]

Install (or reconfigure) the hourly water reminder for the current user.

Options:
  --interval TIME   How often to remind, in systemd time syntax (default: 1h).
                    Examples: 30min, 45min, 1h, 90min, 2h
  --bin-dir DIR     Where to install the script (default: ~/.local/bin)
  --no-start        Install and enable the timer, but do not start it now
  --test            Send a test notification after installing
  -h, --help        Show this help and exit

The installer does not need root and only touches files in your home directory.
Re-run it with a different --interval to reconfigure an existing install.

EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_value() {
  [[ $# -ge 2 && -n $2 ]] || die "missing value for $1"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --interval)
      need_value "$@"
      INTERVAL=$2
      shift 2
      ;;
    --interval=*)
      INTERVAL=${1#*=}
      [[ -n $INTERVAL ]] || die "--interval cannot be empty"
      shift
      ;;
    --bin-dir)
      need_value "$@"
      BIN_DIR=$2
      shift 2
      ;;
    --bin-dir=*)
      BIN_DIR=${1#*=}
      [[ -n $BIN_DIR ]] || die "--bin-dir cannot be empty"
      shift
      ;;
    --no-start)
      START=0
      shift
      ;;
    --test)
      SEND_TEST=1
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

# BIN_DIR may be relative to the invocation directory; make it absolute so the
# generated systemd unit works regardless of the service's working directory.
BIN_DIR=$(realpath -m -- "$BIN_DIR")

# --- Preflight checks ------------------------------------------------------

command -v systemctl >/dev/null 2>&1 ||
  die "systemctl not found. A systemd-based distribution is required."

systemctl --user show-environment >/dev/null 2>&1 ||
  die "cannot talk to the systemd user instance. Are you in a graphical login session?"

[[ $INTERVAL =~ ^[0-9]+(us|ms|s|sec|min|m|h|hr|d|w)?$ ]] ||
  die "invalid interval '$INTERVAL'. Try 30min, 45min, 1h, or 90min."

if [[ $INTERVAL =~ ^0+(us|ms|s|sec|min|m|h|hr|d|w)?$ ]]; then
  die "interval must be greater than zero."
fi

if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze timespan "$INTERVAL" >/dev/null 2>&1 ||
    die "systemd cannot parse the interval '$INTERVAL'."
fi

[[ -f $SCRIPT_DIR/bin/water-reminder ]] ||
  die "bin/water-reminder not found next to install.sh."
[[ -f $SCRIPT_DIR/systemd/water-reminder.service.in ]] ||
  die "systemd/water-reminder.service.in not found next to install.sh."
[[ -f $SCRIPT_DIR/systemd/water-reminder.timer.in ]] ||
  die "systemd/water-reminder.timer.in not found next to install.sh."

if ! command -v notify-send >/dev/null 2>&1 &&
  ! command -v kdialog >/dev/null 2>&1 &&
  ! command -v zenity >/dev/null 2>&1; then
  printf 'warning: no notification tool found (notify-send, kdialog, or zenity).\n' >&2
  printf '         Install libnotify (e.g. "sudo apt install libnotify-bin") first.\n' >&2
fi

# --- Install files ---------------------------------------------------------

install -d "$BIN_DIR" "$UNIT_DIR"
install -m 0755 "$SCRIPT_DIR/bin/water-reminder" "$BIN_DIR/water-reminder"

render_unit() {
  local template=$1 output=$2 content
  content=$(<"$template")
  content=${content//@INTERVAL@/$INTERVAL}
  content=${content//@EXEC@/$BIN_DIR/water-reminder}
  printf '%s\n' "$content" >"$output"
}

render_unit "$SCRIPT_DIR/systemd/water-reminder.service.in" \
  "$UNIT_DIR/water-reminder.service"
render_unit "$SCRIPT_DIR/systemd/water-reminder.timer.in" \
  "$UNIT_DIR/water-reminder.timer"

# Install the example config without ever overwriting an existing one.
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/water-reminder"
if [[ ! -e $CONFIG_DIR/config && -f $SCRIPT_DIR/config.example ]]; then
  install -d "$CONFIG_DIR"
  install -m 0644 "$SCRIPT_DIR/config.example" "$CONFIG_DIR/config"
fi

systemctl --user daemon-reload
systemctl --user enable water-reminder.timer >/dev/null

if [[ $START -eq 1 ]]; then
  systemctl --user restart water-reminder.timer
fi

if [[ $SEND_TEST -eq 1 ]]; then
  "$BIN_DIR/water-reminder" --test || true
fi

# --- Done ------------------------------------------------------------------

cat <<EOF

water-reminder installed.

  Script:    $BIN_DIR/water-reminder
  Timer:     $UNIT_DIR/water-reminder.timer
  Config:    $CONFIG_DIR/config
  Interval:  every $INTERVAL

Check the schedule with:
  systemctl --user list-timers water-reminder.timer

Send a test notification with:
  $BIN_DIR/water-reminder --test

Uninstall with:
  $SCRIPT_DIR/uninstall.sh

EOF
