# Brainstorming — Session Plan Convention

The `superpowers:brainstorming` skill is plugin-managed and cannot be edited directly (plugin updates overwrite it). This note documents the desired behavior for when the plugin is next updated or replaced.

## Desired behavior

After presenting a design and getting approval, the skill should ask:

> "Do you want this broken into sessions? If yes, I'll apply the standard naming convention: one plan file per session named after its feat branch, each plan feeding into the next."

- **If yes:** produce session plan files using the convention in the `session-workflow` skill. Save plan files to `<project-root>/claude-plans/<branch-name>.md`. Include the full Session Map table and an "Output for Session N+1" section in each plan.
- **If no:** produce a single design doc.

## Homelab standing rules to inject into every session plan

1. No hardcoded AWS account IDs, role ARNs, bucket names, or credentials in any git file — all values from Vault at `secret/<cluster-prefix>/`
2. IAM roles (Terraform) created before any cluster work that depends on them
3. Any new infra component deployed to the cluster gets a runbook in your cluster runbook repo under `runbooks/<component>/`
4. Last session of any multi-session project: architecture diagram + Project Brief handoff doc

## Action required

Update the `superpowers:brainstorming` plugin skill, or open a feature request with the plugin author, to incorporate the above behavior.
