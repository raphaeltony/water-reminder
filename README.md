# water-reminder

A tiny, dependency-light hydration reminder for Linux desktops. It sends a
desktop notification every hour (or whatever interval you choose), using a
systemd **user** timer — no root, no background daemon of its own, and no
external services.

```
💧 Time to drink water
A glass of water now keeps the afternoon slump away.
```

## Features

- Hourly desktop notifications by default; any interval supported (`30min`, `1h`, `90min`, …)
- Runs entirely in your user session via `systemd --user`
- Works with `notify-send` (GNOME, KDE, XFCE, Sway, …), with `kdialog` and `zenity` fallbacks
- Random rotating messages, optional sound, configurable title/icon/urgency
- A short `water` command for status, resetting the countdown, changing the
  interval, and turning reminders on or off
- Clean installer and uninstaller; re-running the installer keeps your settings
- No root privileges and no runtime dependencies beyond your existing notification tool

## Requirements

- Linux with systemd (user instance) — most desktop distributions
- One notification tool: `notify-send` (package `libnotify-bin` on Debian/Ubuntu,
  `libnotify` on Fedora/Arch), `kdialog`, or `zenity`
- Optional: `paplay` or `canberra-gtk-play` if you want a sound

## Quick start

```bash
git clone https://github.com/YOUR_USERNAME/water-reminder.git
cd water-reminder
./install.sh
```

`install.sh` installs two short commands to `~/.local/bin` (`water` and
`water-reminder`), creates the systemd unit files, enables the timer, and
starts it. The first notification arrives one interval after installation.

## Everyday commands

Everything is available through the short `water` command:

| Command | What it does |
| --- | --- |
| `water` | Show whether reminders are on, the interval, and the next reminder |
| `water now` | Send a reminder immediately (`water test` also works) |
| `water reset` | Restart the countdown — the next reminder is a full interval away |
| `water interval` | Show the current interval |
| `water interval 45min` | Change the interval and restart the countdown |
| `water off` / `water on` | Turn reminders off or back on |
| `water config` | Open the config file in `$EDITOR` |
| `water logs` | Show recent reminder logs (`water logs -f` to follow) |

If `~/.local/bin` is not on your `PATH`, run `~/.local/bin/water` instead.

## Installer options

| Option | Description |
| --- | --- |
| `--interval TIME` | Reminder interval in systemd syntax (default `1h`). Examples: `30min`, `45min`, `90min`, `2h` |
| `--bin-dir DIR` | Install the script somewhere other than `~/.local/bin` |
| `--no-start` | Enable the timer but don't start it yet |
| `--test` | Send a test notification after installing |
| `-h`, `--help` | Show help |

If you omit `--interval`, the installer keeps the interval you already have.
You can change it at any time with `water interval 45min` — no reinstall
needed.

## Configuration

The installer creates `~/.config/water-reminder/config` from
[`config.example`](config.example) the first time. Open it with `water config`
to change the title, icon, urgency, sound, or message list. Example:

```bash
TITLE="💧 Time to drink water"
ICON="dialog-information"
URGENCY="normal"   # low | normal | critical
SOUND="off"        # "off", "on", or a path to a sound file

MESSAGES=(
  "Time for a glass of water."
  "Hydration check — take a sip."
)
```

The file is plain shell, sourced by the reminder script, so keep it readable by
you only (it should be `0600` if you put anything private in it — normally not
needed).

If you delete the config, the defaults in the script are used. Reinstall does
not overwrite an existing config.

## How it works

- `water-reminder.timer` fires `water-reminder.service` every interval while
  your session is active.
- `water-reminder.service` runs `~/.local/bin/water-reminder`, which shows a
  notification and exits.
- Because it uses a monotonic timer (`OnActiveSec=` + `OnUnitActiveSec=`), the
  countdown starts when the timer starts and resets if you log out, reboot, or
  run `water reset`. A reminder may be delayed or skipped while the machine is
  suspended.

Logs from the last run:

```bash
water logs
```

## Uninstall

```bash
./uninstall.sh          # keeps your config
./uninstall.sh --purge  # also removes ~/.config/water-reminder
```

If you installed to a custom directory, pass the same `--bin-dir` to the
uninstaller.

## Without systemd

If you're on a system without systemd, run the script from `cron`. For example,
this crontab entry reminds you at the top of every hour:

```cron
0 * * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus /home/you/.local/bin/water-reminder
```

Replace `1000` with your user ID (`id -u`) and `DISPLAY` with your session's
value. Some desktops (Wayland) may not expose `DISPLAY`; cron is best-effort —
systemd user timers are the recommended setup.

## Troubleshooting

**No notification appears**

1. Run `water now` (or `~/.local/bin/water-reminder --test`).
2. If that works, check the timer: `water status`
3. Ensure notifications aren't silenced by Do Not Disturb / Focus mode.
4. If `notify-send` is missing, install `libnotify-bin` (Debian/Ubuntu) or
   `libnotify` (Fedora/Arch).
5. In a systemd user service, the session bus is normally available. If you see
   D-Bus errors, verify `echo $DBUS_SESSION_BUS_ADDRESS` in your session.

**Timer is not running**

```bash
water on
water status
```

**I want an immediate first reminder**

The first reminder comes after one interval by design. Run `water now` whenever
you want one immediately, or `water reset` to start a fresh countdown.

## License

[MIT](LICENSE)
