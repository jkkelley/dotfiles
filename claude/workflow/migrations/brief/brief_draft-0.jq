# Upgrades a brief/draft-0 brief (from and to as strings, no envelope, done_token under output) to zenith.a2a.brief.v1.
# Everything the draft carried that the envelope has no field for moves into facts, so nothing is lost.
# Args: --arg at <utc>, --arg version <x.y.z>
{
  schema: "zenith.a2a.brief.v1",
  version: $version,
  id: .id,
  at: .at,
  kind: "request",
  status_code: "A2A-001",
  from: {name: .from, role: null},
  to: {name: .to, role: null},
  subject: (.subject // ("brief " + .id)),
  facts: ({owner_words, rules, worktree, branch, reuse} | with_entries(select(.value != null))),
  actions: (.build // []),
  reply: {required: true, format: "result JSON valid against zenith.a2a.result.v1 written to output.result_file"},
  refs: (.reuse // []),
  acceptance_criteria: .acceptance_criteria,
  done_token: (.output.done_token // .done_token),
  output: {result_file: .output.result_file}
}
