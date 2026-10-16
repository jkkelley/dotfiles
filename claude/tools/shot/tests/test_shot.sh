#!/usr/bin/env bash
# name: test_shot.sh
# purpose: tests shot.sh with stub browsers: ok, wrong size, failing, timeout, missing html, no browser, bad size, make.
# inputs: none
# outputs: ok/FAIL lines, final pass=N fail=M, exit 1 on any failure
# writes-to: a mktemp dir, removed on exit
# cleanup: trap removes the temp dir
# shellcheck disable=SC2015  # "A && B || bad" is intended: bad runs on any failed check
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"; S="$HERE/shot.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" ARTIFACT_ROOT="$T/store" ARTIFACT_CONF=/dev/null; mkdir -p "$HOME"
pass=0 fail=0
ok() { echo "ok   $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }
echo '<html></html>' > "$T/p.html"
# stub browsers: parse --window-size and --screenshot, write a PNG header of W+$1 by H
mkstub() { # file extra
  cat > "$1" <<STUB
#!/usr/bin/env bash
for a in "\$@"; do case "\$a" in --window-size=*) ws=\${a#*=};; --screenshot=*) out=\${a#*=};; esac; done
w=\$(( \${ws%,*} + $2 )); h=\${ws#*,}
be() { printf "\\\\x%02x\\\\x%02x\\\\x%02x\\\\x%02x" \$((\$1>>24&255)) \$((\$1>>16&255)) \$((\$1>>8&255)) \$((\$1&255)); }
{ printf '\\x89PNG\\r\\n\\x1a\\n\\x00\\x00\\x00\\x0dIHDR'; printf "\$(be \$w)\$(be \$h)"; } > "\$out"
STUB
  chmod +x "$1"
}
mkstub "$T/ok" 0; mkstub "$T/big" 1
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bad"; printf '#!/usr/bin/env bash\nsleep 5\n' > "$T/slow"; chmod +x "$T/bad" "$T/slow"

out=$(CHROME_BIN="$T/ok" bash "$S" --html "$T/p.html" --name t1 --size 20x10 2>/dev/null); rc=$?
if [ $rc = 0 ] && [[ $out == "$ARTIFACT_ROOT"/screenshot/* ]] && [ "$(od -An -tx1 -N8 "$out" | tr -d ' \n')" = 89504e470d0a1a0a ] \
  && jq -e '.key=="screenshot"' "$out.meta.json" >/dev/null; then ok "t1 ok"; else bad "t1 ok rc=$rc out=$out"; fi

err=$(CHROME_BIN="$T/big" bash "$S" --html "$T/p.html" --name t2 --size 20x10 2>&1 >/dev/null); rc=$?
n=$(find "$ARTIFACT_ROOT/screenshot" -name '*-t2.png' 2>/dev/null | wc -l)
[ $rc = 4 ] && [[ $err == *SHOT-RENDER* ]] && [ "$n" = 0 ] && ok "t2 wrong size" || bad "t2 wrong size rc=$rc"

err=$(CHROME_BIN="$T/bad" bash "$S" --html "$T/p.html" --name t3 2>&1 >/dev/null); rc=$?
[ $rc = 4 ] && [[ $err == *SHOT-RENDER* ]] && ok "t3 failing browser" || bad "t3 failing browser rc=$rc"

err=$(SHOT_TIMEOUT_S=1 CHROME_BIN="$T/slow" bash "$S" --html "$T/p.html" --name t4 2>&1 >/dev/null); rc=$?
[ $rc = 4 ] && [[ $err == *SHOT-RENDER* ]] && ok "t4 timeout" || bad "t4 timeout rc=$rc"

err=$(bash "$S" --html "$T/none.html" --name t5 2>&1 >/dev/null); rc=$?
[ $rc = 3 ] && [[ $err == *SHOT-SRC* ]] && ok "t5 missing html" || bad "t5 missing html rc=$rc"

err=$(CHROME_BIN=/nonexistent bash "$S" --html "$T/p.html" --name t6 2>&1 >/dev/null); rc=$?
[ $rc = 4 ] && [[ $err == *SHOT-NOBROWSER* ]] && ok "t6 no browser" || bad "t6 no browser rc=$rc"

err=$(CHROME_BIN="$T/ok" bash "$S" --html "$T/p.html" --name t7 --size 10by10 2>&1 >/dev/null); rc=$?
[ $rc = 2 ] && [[ $err == *SHOT-USAGE* ]] && ok "t7 bad size" || bad "t7 bad size rc=$rc"

out=$(CHROME_BIN="$T/ok" make -s -f "$HERE/shot.mk" shot HTML="$T/p.html" NAME=t8 SIZE=20x10 2>/dev/null); rc=$?
[ $rc = 0 ] && [[ $out == "$ARTIFACT_ROOT"/screenshot/* ]] && ok "t8 make" || bad "t8 make rc=$rc out=$out"

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
