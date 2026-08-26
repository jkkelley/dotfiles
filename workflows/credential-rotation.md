# Credential rotation

<!-- workflow-version: 1.0.0 -->

How a credential in AWS Parameter Store is replaced, and how the cluster is made
to serve the new value.

**This procedure exists because of a change to how often the cluster reads.**
The SSM-backed `ExternalSecret`s moved from `refreshInterval: 1h` to `168h` to
stop burning the KMS free tier. At one hour, a rotated credential propagated on
its own within the hour and nobody had to know this procedure existed. At a week,
it does not. Rotating a credential and walking away now leaves the cluster
serving the old value for up to seven days.

The KMS reasoning, the cost model and the ESO behaviour traps live in
`local-k8s-docs`, `runbooks/kms-cost-and-eso-refresh/`. This document is the
operating procedure only.

## The procedure

```
BEFORE YOU TOUCH ANYTHING
│
├─ credential-rotation.sh due                what is overdue, and how overdue
├─ credential-rotation.sh verify --id <id>   is the cluster in sync right now
│
AT THE PROVIDER - this part is human, and there is no flag for it
│
├─ mint the new value                        GitHub, Slack, Google, Anthropic, nsc
├─ write it to a file, mode 600              never paste it onto a command line
│
THE MECHANICAL HALF - this part is the driver's
│
├─ credential-rotation.sh rotate --id <id> --value-file <f> --dry-run
│     prints the parameter, the coexist policy, and every ExternalSecret in
│     the cluster that reads it. Writes nothing. Always run this first.
│
├─ credential-rotation.sh rotate --id <id> --value-file <f>
│     put-parameter, then force every consumer to re-read
│
├─ credential-rotation.sh verify --id <id>   every consumer back in sync
│
├─ restart anything holding the value as an environment variable
│
└─ shred the value file
   │
   ▼
AT THE PROVIDER, LAST
│
└─ revoke the old value                      only once verify is clean
```

## Why it is shaped like this

**The driver does not mint credentials, and no flag makes it.** A new GitHub
token, a new Slack webhook, a new Google API key - each is created by a human at
a provider with its own console, its own scopes and its own confirmation step.
Automating that would mean storing a credential capable of creating credentials,
which trades one rotation problem for a worse one. What the driver owns is the
half a human reliably gets wrong: writing the value without a trailing newline,
reaching **every** consumer rather than the one you were thinking about, and
proving afterwards that the cluster is actually serving the new value.

**The fan-out is discovered, never declared.** `rotate` asks the cluster which
`ExternalSecret`s read the parameter rather than reading a list out of the
manifest. A hand-maintained list goes stale the first time somebody adds a
consumer, and a stale list makes the driver miss one silently - which is the
single worst thing this tool could do. The GitHub PAT is the case that proves the
point: one parameter, read by four `ExternalSecret`s in four namespaces, three of
which template it into a `dockerconfigjson` rather than holding it as a plain
key.

**Nothing here reads a credential value.** `due` and `verify` compare two
timestamps - the parameter's `LastModifiedDate` and the `ExternalSecret`'s
`status.refreshTime`. If the cluster last refreshed before the parameter last
changed, the cluster is stale. That is a complete answer, it works for the
templated secrets where no plain key holds the raw value, and it costs nothing.
A verifier that read each parameter to compare it would spend one billable
`kms:Decrypt` per credential per run and quietly undo the thing the 168h change
bought. The whole run is two API calls and zero KMS requests.

**`--dry-run` is not optional in spirit.** It is the only step that shows you the
blast radius before anything is written, and for a `coexist: no` credential the
blast radius is "every consumer below is broken until it syncs".

**Revoke last, not first.** Revoking before `verify` is clean turns a rotation
into an outage with no way back.

## The two shapes of rotation

`coexist` in the manifest is the whole difference, and the driver prints it
before it writes anything.

| `coexist` | What it means                                                      | How to run it                                                                             |
| --------- | ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| `yes`     | The provider will issue a second value while the first still works | Unhurried. Mint, rotate, verify, restart, confirm the app is healthy, then revoke the old |
| `no`      | The moment the new value exists the old one is dead                | There is no overlap window. Every consumer is broken between the write and the sync       |

For `coexist: no`, do the whole sequence in one sitting, and check the consuming
workload afterwards rather than assuming. `rotate` forces the re-read
immediately, so the window is seconds rather than the 168 hours it would be if
you only wrote the parameter - but it is not zero.

## Where each new value comes from

The driver takes a file. This is what goes in it.

| Credential                     | Minted at                                                           |
| ------------------------------ | ------------------------------------------------------------------- |
| `github-pat`                   | GitHub, Settings → Developer settings → Personal access tokens      |
| `anthropic-api-key`            | The Anthropic Console, API keys                                     |
| `slack-webhook-url`            | The Slack app's Incoming Webhooks page - add a new one, do not edit |
| `pagespeed-api-key`            | Google Cloud Console, APIs & Services → Credentials                 |
| `job-hunter-postgres-password` | `ALTER USER ... PASSWORD` against the instance                      |
| `job-hunter-database-url`      | Rebuilt by hand from the new password - see below                   |
| `nats-*`                       | `nsc` re-issue - see below                                          |

The GitHub token needs the scopes the four consumers actually use: package read
for the three image-pull secrets, and repository read for the ArgoCD repository
credential. A token minted with less than that will pass `verify` - the cluster
holds the new bytes - and fail at the point of use, which is the one failure mode
this procedure cannot catch for you.

### The two that are one credential

`job-hunter-postgres-password` and `job-hunter-database-url` are separate
parameters holding the same secret twice, because the URL embeds the password.
Rotating one without the other leaves the application authenticating with a
connection string that no longer works.

Rotate them as a pair, password first, and run `verify` with no `--id` so both
appear in the same output.

That duplication is itself worth removing, and it is filed as its own piece of
work rather than fixed inside a rotation.

### The NATS chain is not a rotation

The five `nats-*` account and operator parameters are a signing chain: the
operator signs the account, the account signs each user credential. Replacing one
link invalidates everything below it, so "rotate the account nkey" really means
"re-issue the whole tree with `nsc` and write all eight parameters".

Treat it as a planned change with the applications stopped, not as a rotation.
The driver will happily write any one of them, which is exactly why this
paragraph is here.

## After the sync

`rotate` gets the new value into the Kubernetes `Secret`. It does not get it into
a running process.

A pod that read the value into an environment variable at startup holds the old
one until it restarts. A pod that mounts the `Secret` as a volume picks the
change up on its own, though not instantly. If you are not certain which shape
the consumer is, restart it.

```sh
kubectl --context homelab-admin get pods -n <ns> \
  -o custom-columns=NAME:.metadata.name,SECRETS:.spec.containers[*].envFrom[*].secretRef.name

kubectl --context homelab-admin rollout restart deploy/<name> -n <ns>
```

Then shred the value file. It is a plaintext credential sitting in a working
directory, and it is the last copy anybody has a reason to keep.

## Adding a credential to the manifest

`workflows/credential-rotation/credentials.tsv` is four columns: a stable id, the
parameter path, how many days a value may live, and whether the provider allows
two live values at once.

It holds pointers and policy. It holds no credential value, no account id, no
ARN and no cluster object name - the suite asserts every one of those, because
this repository is public and a manifest is exactly the kind of file that
accumulates a "just this once" real value.

Add the row, then run both suites. `due` will start reporting on it immediately;
`verify` will report `no ExternalSecret reads this parameter` until something in
the cluster actually consumes it, and that is a finding rather than noise.

## What it costs

Nothing, until `rotate` writes.

`due` is one `ssm describe-parameters`, which returns metadata and does not
decrypt. `verify` adds one `kubectl get`. Neither spends a KMS request, and the
offline suite asserts that no code path calls `get-parameter` at all - not that
no error appeared, that the call was never made.

`rotate` spends one `kms:GenerateDataKey` for the write, and one `kms:Decrypt`
per consumer as each `ExternalSecret` re-reads. Five requests for the shared
GitHub PAT with its four consumers. Against a 20,000-request monthly free tier
that is not a number worth optimising, and it is the reason `rotate` is the only
subcommand that costs anything.

## Verifying the procedure holds

The document is the explanation. The scripts are the enforcement, and there are
two of them because neither is sufficient alone.

| Suite                                       | Network | Credentials | Proves                                                           |
| ------------------------------------------- | ------- | ----------- | ---------------------------------------------------------------- |
| `credential-rotation/testing/run-tests.sh`  | none    | none        | the logic, the arithmetic, every refusal, and no KMS call        |
| `credential-rotation/testing/live-check.sh` | on      | mounted ro  | the queries are well-formed against the real account and cluster |

The offline suite stubs `aws` and `kubectl` so it can assert the property this
whole workflow rests on: that no code path ever spends a billable KMS request.
The cost of that isolation is that the `go-template` behind `verify` is never
rendered by a real `kubectl`, and a stub cannot prove a template renders. The
live check closes that one gap by running the read-only subcommands - `list`,
`due`, `verify` - against the real thing. It never runs `rotate` and there is no
flag that would let it.

The pattern is written up in `claude/skills/container-sandbox/`,
`references/skill-testing.md`, under "Verifying against live infrastructure".

The refusals are the cases worth reading. A validator that never rejects anything
is not a validator, and the one that matters most is the empty value file: the
mint step failed, the redirect created the file anyway, and without that check
`put-parameter` would write the empty string over a live credential.
