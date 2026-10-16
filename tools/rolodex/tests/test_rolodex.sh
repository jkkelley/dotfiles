#!/usr/bin/env bash
# name: test_rolodex.sh
# purpose: Prove rolodex.py fails a headerless script (AC2), drafts headers that then pass, and builds writing only its two outputs (AC3).
# inputs: none; runs inside the container with the repo at /repo, read-only.
# outputs: one PASS line per check, FAIL and exit 1 on the first broken one.
# writes-to: a mktemp scratch directory only.
# cleanup: removes the scratch directory on exit.
set -euo pipefail
R=/repo/scripts/rolodex.py
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# A fixture tree: one headerless script, one with a full header.
mkdir -p "$tmp/fx/scripts"
printf '#!/usr/bin/env bash\n# does a thing\necho hi > "$HOME/.local/state/x/out.log"\n' > "$tmp/fx/scripts/bare.sh"
cat > "$tmp/fx/scripts/ok.sh" <<'EOS'
#!/usr/bin/env bash
# name: ok.sh
# purpose: stays quiet
# inputs: none
# outputs: none
# writes-to: nothing
# cleanup: none needed
true
EOS

# AC2: a headerless script fails the check, and the message names the missing keys.
if python3 "$R" check --root "$tmp/fx" scripts/bare.sh 2>"$tmp/err"; then fail "headerless script passed"; fi
grep -q 'lacks header keys: name, purpose' "$tmp/err" || fail "message does not name the keys: $(cat "$tmp/err")"
pass "check fails a headerless script"
python3 "$R" check --root "$tmp/fx" scripts/ok.sh >/dev/null || fail "headed script failed"
pass "check passes a headed script"

# Dry run writes nothing; --write drafts a header the check then accepts; a second run is a no-op.
cp "$tmp/fx/scripts/bare.sh" "$tmp/before"
python3 "$R" headers --root "$tmp/fx" scripts/bare.sh >/dev/null
cmp -s "$tmp/before" "$tmp/fx/scripts/bare.sh" || fail "dry run changed the file"
python3 "$R" headers --root "$tmp/fx" --write scripts/bare.sh >/dev/null
python3 "$R" check --root "$tmp/fx" scripts/bare.sh >/dev/null || fail "drafted header does not pass"
head -1 "$tmp/fx/scripts/bare.sh" | grep -q '^#!' || fail "shebang moved"
grep -q '^# writes-to: .*out.log' "$tmp/fx/scripts/bare.sh" || fail "writes-to not drafted from the redirect"
cp "$tmp/fx/scripts/bare.sh" "$tmp/once"
python3 "$R" headers --root "$tmp/fx" --write scripts/bare.sh >/dev/null
cmp -s "$tmp/once" "$tmp/fx/scripts/bare.sh" || fail "second headers run changed the file"
pass "headers dry run is inert, --write drafts a passing header, rerun is a no-op"

# AC3: build writes only its two outputs, and the same scan gives the same bytes.
mkdir -p "$tmp/home/projects/demo/.git" "$tmp/state/zenith-x" "$tmp/bin"
printf '# Demo\n\nA demo repository for the rolodex test.\n' > "$tmp/home/projects/demo/README.md"
printf '#!/usr/bin/env bash\n# purpose: a tool\ntrue\n' > "$tmp/bin/mytool"; chmod +x "$tmp/bin/mytool"
cat > "$tmp/c.conf" <<EOC
repo_root: $tmp/home/projects
bin_dir: $tmp/bin
state_root: $tmp/state
EOC
mkdir -p "$tmp/out"
find "$tmp" -type f ! -name 'snap*' -printf '%p %T@\n' | sort > "$tmp/snap1"
python3 "$R" build --config "$tmp/c.conf" --out-md "$tmp/out/S.md" --out-json "$tmp/out/s.json" >/dev/null
find "$tmp" -type f ! -name 'snap*' -printf '%p %T@\n' | sort > "$tmp/snap2"
new=$(diff "$tmp/snap1" "$tmp/snap2" | grep '^>' | awk '{print $2}' | sort || true)
[ "$new" = "$(printf '%s\n%s' "$tmp/out/S.md" "$tmp/out/s.json" | sort)" ] || fail "build touched other files: $new"
cp "$tmp/out/S.md" "$tmp/S1"; python3 "$R" build --config "$tmp/c.conf" --out-md "$tmp/out/S.md" --out-json "$tmp/out/s.json" >/dev/null
cmp -s "$tmp/S1" "$tmp/out/S.md" || fail "build is not idempotent"
grep -q 'zenith-x' "$tmp/out/S.md" && grep -q 'mytool' "$tmp/out/S.md" && grep -q 'demo' "$tmp/out/S.md" || fail "rows missing"
python3 -c "import json,sys; d=json.load(open('$tmp/out/s.json')); assert d['schema']=='system-rolodex/1' and d['repos'][0]['name']=='demo'" || fail "json shape"
sed -n 3,4p "$tmp/out/S.md" | grep -q doctoc || fail "contents list not at the top"
grep -q 'GOLDEN-RULES:START' "$tmp/out/S.md" || fail "golden rules block missing"
pass "build writes only its two outputs, is idempotent, carries contents list and golden rules"
