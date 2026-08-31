---
name: backup-home
description: Archives $HOME to a timestamped tar.gz and uploads it to S3 (win11-wsl-backups bucket, DevEnv_Internal prefix) using the minecraft-admin profile. Shows a pre-flight size estimate, requires confirmation, then runs the backup script with a status summary.
version: 1.0.3
---

# backup-home - Archive and Upload $HOME to S3

Backs up the user's home directory by creating a compressed archive and uploading it to S3.
The script lives at `scripts/backup-home.sh` relative to this skill's base directory.

```
BUCKET="win11-wsl-backups-690712292635-us-east-2-an"
PROFILE="minecraft-admin"
PREFIX="DevEnv_Internal"
```

Excludes: `.cache`, `.local/share/containers`, `.npm`, `.cargo/registry`

## Step 1: Pre-flight size estimate

Give the user a sense of what's about to be archived before touching anything:

```bash
echo "Estimating archive size (excluding caches)..."
du -sh \
  --exclude=".cache" \
  --exclude=".local/share/containers" \
  --exclude=".npm" \
  --exclude=".cargo/registry" \
  "$HOME" 2>/dev/null | cut -f1
```

Also show the S3 destination it will land in:

```
s3://win11-wsl-backups-690712292635-us-east-2-an/DevEnv_Internal/home_devenv_<timestamp>.tar.gz
```

If the `du` fails for any reason, skip it and proceed to Step 2 - the estimate is informational only.

## Step 2: Confirmation prompt

Ask the user explicitly:

> Ready to archive and upload ~/ to S3? This will create a tar.gz of approximately <size> and upload it. (yes/no)

Wait for the user's response. If they say anything other than "yes" or "y", abort and say: "Backup cancelled."

## Step 3: Run the backup script

Locate the script relative to this skill's base directory and run it:

```bash
SKILL_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
bash "$SKILL_DIR/scripts/backup-home.sh"
BACKUP_EXIT=$?
```

If the skill base directory is not available via `BASH_SOURCE`, use the known path:

```bash
bash ~/.claude/skills/backup-home/scripts/backup-home.sh
BACKUP_EXIT=$?
```

Stream the script's output directly to the user as it runs - do not suppress it. The script already prints step-by-step progress.

## Step 4: Status summary

After the script exits, report:

```
Backup complete.
  Exit code: 0 (success)
  Destination: s3://win11-wsl-backups-690712292635-us-east-2-an/DevEnv_Internal/
```

If `BACKUP_EXIT` is non-zero, flag it clearly:

```
Backup finished with errors (exit code: N).
The archive may not have been uploaded or cleaned up. Check /tmp/home_devenv_*.tar.gz for any leftover archive.
```
