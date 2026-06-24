---
name: backup-home
description: Syncs $HOME to S3 (win11-wsl-backups bucket) using the minecraft-admin profile. Runs a dry-run first, shows a confirmation prompt, then performs the real sync with a status summary.
---

# backup-home - Sync $HOME to S3

Backs up the user's home directory to S3 using `aws s3 sync`.

```
BUCKET="win11-wsl-backups-690712292635-us-east-2-an"
PROFILE="minecraft-admin"
DEST="s3://${BUCKET}/DevEnv_Sync/"
```

## Step 1: Dry-run

Run the sync in dry-run mode and capture the output:

```bash
BUCKET="win11-wsl-backups-690712292635-us-east-2-an"
PROFILE="minecraft-admin"

aws s3 sync "$HOME" "s3://${BUCKET}/DevEnv_Sync/" \
  --profile "$PROFILE" \
  --exclude ".cache/*" \
  --exclude ".local/share/containers/*" \
  --dryrun 2>&1 | tee /tmp/backup-home-dryrun.txt
```

After the dry-run completes, summarize what would happen:

- Count `(dryrun) upload:` lines - these are files that would be uploaded
- Count `(dryrun) delete:` lines - these are remote files that would be removed

Show the user:

```
Dry-run complete.
  Would upload: N files
  Would delete: N files

Top files to upload (first 10):
  <list>
```

If the dry-run itself fails (non-zero exit, AWS auth error, bucket not found), stop and show the raw error. Do not proceed to Step 2.

## Step 2: Confirmation prompt

Ask the user explicitly:

> Proceed with the real sync? This will upload/delete the files listed above. (yes/no)

Wait for the user's response. If they say anything other than "yes" or "y", abort and say: "Backup cancelled."

## Step 3: Real sync

Run the sync for real, capturing output:

```bash
BUCKET="win11-wsl-backups-690712292635-us-east-2-an"
PROFILE="minecraft-admin"

aws s3 sync "$HOME" "s3://${BUCKET}/DevEnv_Sync/" \
  --profile "$PROFILE" \
  --exclude ".cache/*" \
  --exclude ".local/share/containers/*" \
  2>&1 | tee /tmp/backup-home-sync.txt
SYNC_EXIT=${PIPESTATUS[0]}
```

## Step 4: Status summary

Parse `/tmp/backup-home-sync.txt` and report:

```bash
UPLOADED=$(grep -c '^upload:' /tmp/backup-home-sync.txt 2>/dev/null || echo 0)
DELETED=$(grep -c '^delete:' /tmp/backup-home-sync.txt 2>/dev/null || echo 0)
```

Show the user:

```
Backup complete.
  Uploaded: N files
  Deleted:  N files
  Exit code: 0 (success)
  Destination: s3://win11-wsl-backups-690712292635-us-east-2-an/DevEnv_Sync/
```

If `SYNC_EXIT` is non-zero, flag it clearly:

```
Backup finished with errors (exit code: N).
Check /tmp/backup-home-sync.txt for details.
```

Clean up temp files when done:

```bash
rm -f /tmp/backup-home-dryrun.txt /tmp/backup-home-sync.txt
```
