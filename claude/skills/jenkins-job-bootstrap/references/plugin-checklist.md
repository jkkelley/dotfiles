# Jenkins Plugin Checklist

Plugins required for `jenkins-job-bootstrap` skill to work end-to-end.

## Required

| Plugin | Why | Verify |
|--------|-----|--------|
| `job-dsl` | The seed script itself | `https://<jenkins-host>/manage/pluginManager/installed?filter=job-dsl` |
| `workflow-aggregator` (Pipeline) | Declarative pipeline syntax in seed-pipeline.groovy | Search "Pipeline" in plugin manager |
| `workflow-multibranch` | The `multibranchPipelineJob {}` Job DSL block | Auto-installed with workflow-aggregator |
| `github-branch-source` | The `branchSources { github { } }` block | Search "GitHub Branch Source" |
| `git` | `checkout scm` + Git URL in seed job's SCM config | Always installed |
| `credentials` + `credentials-binding` | Reading the SCM credential by ID | Always installed |

## Already in use (confirmed from existing Jenkinsfiles)

| Plugin | Used by |
|--------|---------|
| `kubernetes` | Pod-template agents in every Jenkinsfile |
| All of the above | Existing prospector-* multibranch jobs |

## Script Security — first-run gotcha

The Job DSL plugin runs Groovy in a sandbox by default. The first time `seed-job.groovy` runs, you'll see errors like:

```
Scripts not permitted to use staticMethod groovy.yaml.YamlSlurper parseText java.lang.String
```

**Fix:**
1. Manage Jenkins → "In-process Script Approval"
2. Approve each pending signature one at a time
3. Re-run the seed job
4. Repeat until the build is green (typically 2-3 rounds for a YAML-parsing seed)

This is a one-time setup per Jenkins instance. After approval, future seed runs are zero-touch.

## Verifying the install (one-shot)

```bash
JENKINS=https://<jenkins-host>
USER=<your-github-username>
TOKEN=$(cat ~/.config/jenkins/token)

for p in job-dsl workflow-aggregator github-branch-source kubernetes; do
  STATUS=$(curl -s -u "$USER:$TOKEN" \
    "$JENKINS/pluginManager/api/json?depth=1&tree=plugins[shortName,enabled]" \
    | jq -r ".plugins[] | select(.shortName==\"$p\") | .enabled")
  echo "$p: ${STATUS:-NOT INSTALLED}"
done
```

Expected: every line ends with `true`.
