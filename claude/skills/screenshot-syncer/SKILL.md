---
name: screenshot-syncer
description: Copy Windows screenshots into a WSL directory using a filter (today, all, by name, by date or range, or last-N recency). The cp runs inside WSL against /mnt/c/... so the slow \\wsl$\ path is avoided.
version: 1.0.1
---

# Windows → WSL Screenshot Sync

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill at `~/dotfiles/claude/skills/screenshot-syncer/`, bump its version, then re-pull it - never edit the copy where it landed.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

Triggered by an entry-point PowerShell script that selects matching files on the
Windows side, then shells into WSL to copy them from `/mnt/c/...` into the
target directory. Source, destination, and distro are all configurable per
machine — nothing host-specific is committed.

## Configuration

The script reads its defaults from environment variables and accepts CLI
overrides for everything.

| Variable | Required | Default | Notes |
|---|---|---|---|
| `SCREENSHOT_SYNC_SRC` | no | `$env:USERPROFILE\Pictures\Screenshots` | Windows source dir |
| `SCREENSHOT_SYNC_DEST` | **yes** | — | WSL destination, e.g. `/home/<your-wsl-user>/<dest-dir>` |
| `SCREENSHOT_SYNC_DISTRO` | no | first distro from `wsl -l -q` | Override only if you have multiple distros |

To set them durably in PowerShell:

```powershell
[Environment]::SetEnvironmentVariable('SCREENSHOT_SYNC_DEST', '/home/<your-wsl-user>/<dest-dir>', 'User')
[Environment]::SetEnvironmentVariable('SCREENSHOT_SYNC_DISTRO', '<your-distro>', 'User')
```

Open a fresh shell to pick them up.

## Filters

Pick exactly one filter mode per invocation:

| Filter | Flag | Example |
|---|---|---|
| Today's files | `-Today` | `./sync-screenshots.ps1 -Today` |
| Everything | `-All` | `./sync-screenshots.ps1 -All` |
| By name (substring, case-insensitive) | `-Name <pat>` | `./sync-screenshots.ps1 -Name "diagram"` |
| Specific date | `-Date YYYY-MM-DD` | `./sync-screenshots.ps1 -Date 2026-05-03` |
| Date range | `-Date YYYY-MM-DD..YYYY-MM-DD` | `./sync-screenshots.ps1 -Date 2026-05-01..2026-05-03` |
| Recency window | `-Since <N>{s,m,h,d}` | `./sync-screenshots.ps1 -Since 2h` |

Add `-DryRun` to preview without copying.

## Behavior

- **Copies**, does not move. Overwrites files in destination (same content
  assumption — see contract below).
- Creates the destination directory inside WSL if it doesn't exist.
- Prints the count synced and the destination on success.
- Exits non-zero with a clear error if `SCREENSHOT_SYNC_DEST` is unset, the
  source path is missing, or the distro can't be resolved.

## Contract

The script assumes any matching filename refers to the same content on both
sides — i.e. screenshots are write-once. If you start using the destination as
an editing target, switch to a hash-aware tool instead of this script.

## Files

- `scripts/sync-screenshots.ps1` — the entry-point script
