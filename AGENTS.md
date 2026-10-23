# AGENTS.md

Guidance for coding agents working on **water-reminder**, a small Bash project
that sends hydration notifications on Linux through a systemd **user** timer.

Read `README.md` for user-facing behavior. This file covers the things an agent
cannot safely infer from the code: repository-specific invariants, validation
steps, and boundaries.

## Repository layout

- `bin/water` — short user-facing CLI (`status`, `now`, `reset`, `interval`,
  `on`, `off`, `config`, `logs`). This is the main entry point users interact
  with.
- `bin/water-reminder` — the notification script run by the service. Loads the
  user config, picks a random message, shows a notification, optionally plays a
  sound.
- `systemd/*.in` — templates rendered by the installer. Placeholders:
  `@INTERVAL@` and `@EXEC@`.
- `install.sh` — installs scripts to `~/.local/bin`, renders units to
  `~/.config/systemd/user`, enables the timer, and calls `water reset`.
- `uninstall.sh` — stops/removes units and scripts; `--purge` removes config
  and state.
- `config.example` — documented defaults copied to
  `~/.config/water-reminder/config` on first install only.
- `.github/workflows/lint.yml` — ShellCheck CI.

There is no build step and no test framework. Validation is syntax checks,
ShellCheck, and manual systemd testing.

## Critical invariants

1. **Never overwrite an existing user config.** The installer must only create
   `~/.config/water-reminder/config` when it does not exist.
2. **`water reset` must yield a full interval.** systemd anchors
   `OnUnitActiveSec` to the last service activation, so restarting the timer
   alone can schedule the next reminder too early. `silent_service_run()` runs
   the service once with `~/.local/state/water-reminder/skip-once` present,
   updating the anchor without showing a notification. Do not replace this
   with a bare `systemctl --user restart`.
3. **The skip flag is for no-argument service runs only.** `water-reminder`
   ignores it when an option such as `--test` is passed, and
   `silent_service_run()` must remove it if the service start fails.
4. **`water interval` must keep both timer lines in sync** (`OnActiveSec` and
   `OnUnitActiveSec`), run `systemctl --user daemon-reload`, and restart the
   timer with a refreshed anchor when active.
5. **Timers are monotonic, not calendar-based.** Behavior depends on when the
   timer/service last started; logout, reboot, or suspend may change timing.
6. **The installer is idempotent and preserves the current interval** when
   `--interval` is omitted, so re-running it does not undo `water interval`.
7. **No new runtime dependencies.** Notifications use the first available of
   `notify-send`, `kdialog`, or `zenity`. Sound is on by default but optional:
   `paplay` or `canberra-gtk-play` plus the freedesktop completion sound, and
   silence if unavailable.
8. **The config file is shell code** sourced by the reminder script. Treat it as
   user-owned; never rewrite it on upgrade.

## Setup and validation

Run these from the repository root.

```bash
bash -n install.sh uninstall.sh bin/water bin/water-reminder
shellcheck install.sh uninstall.sh bin/water bin/water-reminder   # CI uses this
```

Manual checks (these touch the developer's live systemd user session):

```bash
./install.sh --test          # installs/updates the user units and sends a test
./install.sh --no-start      # enable without starting
water                        # status, interval, next reminder
water now                    # immediate notification
water interval 45min         # must restart the countdown at 45min
water reset                  # next reminder must be a full interval away
water off && water status    # timer stops and reports "off"
water on                     # timer returns with a fresh interval
water logs | tail -20        # service runs are logged
systemctl --user list-timers water-reminder.timer --no-pager
```

After testing, restore the interval the user had before (`water interval 1h` by
default) and leave the timer **on** unless asked otherwise.

A useful regression check: note the time, run `water reset`, then confirm the
next reminder is approximately one full interval later — not the remainder of
the previous cycle.

## Code style

- Bash 4+, `set -euo pipefail`, two-space indentation.
- Keep the scripts dependency-free and readable; no Bash frameworks.
- New user-facing commands go in `bin/water` as `cmd_<name>()` and get a usage
  entry plus a README table row.
- Use `die` for fatal errors; keep user-facing messages short and plain (no
  color codes).
- Quote variables. The one intentional exception is `$editor "$CONFIG_FILE"` in
  `water config`, which allows `$EDITOR` to contain arguments; the ShellCheck
  suppression explains this.
- Do not add telemetry, network calls, or background daemons.
- Bump `VERSION` in both `bin/water` and `bin/water-reminder` for user-visible
  changes.

## Documentation

Update all affected places together:

- `README.md` — quick start, command table, config behavior, troubleshooting.
- `config.example` and the `water config` skeleton in `bin/water` — keep
  defaults and comments aligned with `bin/water-reminder`.
- `AGENTS.md` — when workflows, invariants, or validation commands change.

Keep the README centered on users; put implementation constraints here.

## Boundaries

**Always**

- Run `bash -n` on every changed shell script before finishing.
- Preserve existing config files and the user's configured interval.
- Keep install, uninstall, and reinstall idempotent.
- Test `water reset` semantics when touching timer or service logic.
- Commit and push only the intended files, with a short imperative message.

**Ask first**

- Running `./uninstall.sh` or `--purge` against a real installation.
- Changing the default interval, default sound setting, or notification
  dependencies.
- Adding files outside the repository or modifying the user's systemd units
  manually.
- Force-pushing, rewriting published history, or changing the LICENSE.

**Never**

- Commit tokens, SSH keys, credentials, or machine-specific paths.
- Overwrite `~/.config/water-reminder/config` or delete user state during an
  upgrade.
- Introduce root/sudo requirements or a long-running custom daemon.
- Replace the systemd user timer with cron by default; cron is only a documented
  fallback.

## Git

- Default branch: `main`
- Remote: `origin` → `git@github-personal:raphaeltony/water-reminder.git`
- Do not force-push `main`.
