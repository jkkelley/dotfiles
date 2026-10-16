#!/usr/bin/env bash
# artifact.sh - the artifact store: files that never go in a git repo, written by script, linked in like packages.
#
# Owner order, 2026-10-16 UTC (Design principles 101, item 23): "any files we ever need to create, they never go in
# the git repo, artifacts get smartly linked to the outside like packages do on linux, use format
# <key name>/YYYY/MM/YYYYMMDD-HHMMSS-<descriptive name under 55 chars completely with the prefix included>.<whatever ext>
# scripted too with frontmatter that makes sense".
#
#   new    $ROOT/<key>/YYYY/MM/YYYYMMDD-HHMMSS-<name>.<ext>, frontmatter written, absolute path printed
#   link   <repo>/.artifacts -> $ROOT/repos/<repo>, gitignored; new files with a repo get a relative link there
#   find   list a key's files by date, newest last
#   check  exit 1 on any tracked file that belongs in the store (CI runs this)
#   clean  dry run by default; --apply deletes, then prunes dangling repo links and empty dirs
#
# Why the 55-char limit counts "YYYYMMDD-HHMMSS-<name>" and not the extension: the owner said "the prefix included";
# an extension says nothing about content and counting it would punish .json against .md for the same name.
# Why name collisions refuse instead of suffixing: a suffix breaks the format, and two seats writing the same name in
# the same second is a bug worth surfacing, not hiding.
# Docs: README.md beside this file. Inputs: artifact.conf, environment, arguments (arguments win).
set -euo pipefail

SELF=artifact.sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit "${2:-1}"; }

# ── configuration: defaults < conf < user conf < environment (captured first) < arguments ─────────────────────────
_env_root="${ARTIFACT_ROOT-}" _env_keys="${ARTIFACT_KEYS-}"
_env_pat="${ARTIFACT_CHECK_PATTERNS-}" _env_allow="${ARTIFACT_CHECK_ALLOW-}"
ARTIFACT_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/zenith"
ARTIFACT_KEYS="backup brief result log context screenshot report state trace"
ARTIFACT_CHECK_PATTERNS='\.log$|\.out$|(^|/)nohup\.out$|\.pid$|\.trace$|-result\.json$|(^|/)screenshots?/|(^|/)[0-9]{8}-[0-9]{6}-'
ARTIFACT_CHECK_ALLOW='templates/'
conf="${ARTIFACT_CONF:-$HERE/artifact.conf}"
[ -f "$conf" ] && . "$conf"
[ -f "$HOME/.config/zenith/artifact.conf" ] && . "$HOME/.config/zenith/artifact.conf"
[ -n "$_env_root" ] && ARTIFACT_ROOT="$_env_root"
[ -n "$_env_keys" ] && ARTIFACT_KEYS="$_env_keys"
[ -n "$_env_pat" ] && ARTIFACT_CHECK_PATTERNS="$_env_pat"
[ -n "$_env_allow" ] && ARTIFACT_CHECK_ALLOW="$_env_allow"

usage() {
  cat <<'EOF'
usage: artifact.sh <command> [options]
  new   --key K --name N --ext E [--what TEXT] [--repo R] [--branch B] [--session S] [--by WHO]
  link  [--dir D] [--exclude]
  find  --key K [--since YYYY-MM-DD] [--repo R]
  check [--dir D]
  clean --key K --older-than DAYS [--apply]
common: [--root DIR] [--keys "k1 k2"]
EOF
}

json_str() { # $1 -> JSON string literal
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\t'/\\t}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}
  printf '"%s"' "$s"
}
yaml_str() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '"%s"' "${s//$'\n'/ }"; }
git_in() { git -C "$1" "${@:2}" 2>/dev/null || true; }
key_ok() { case " $ARTIFACT_KEYS " in *" $1 "*) return 0 ;; esac; return 1; }

cmd_new() {
  local key="" name="" ext="" what="" repo="" branch="" session="" by=""
  while [ $# -gt 0 ]; do
    case $1 in
      --key) key=$2; shift 2 ;; --name) name=$2; shift 2 ;; --ext) ext=${2#.}; shift 2 ;;
      --what) what=$2; shift 2 ;; --repo) repo=$2; shift 2 ;; --branch) branch=$2; shift 2 ;;
      --session) session=$2; shift 2 ;; --by) by=$2; shift 2 ;;
      *) die "new: unknown option $1" 2 ;;
    esac
  done
  [ -n "$key" ] && [ -n "$name" ] && [ -n "$ext" ] || die "new needs --key, --name and --ext" 2
  key_ok "$key" || die "unknown key '$key' (configured: $ARTIFACT_KEYS)" 2
  [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "name '$name' must be a lowercase slug [a-z0-9-]" 2
  [[ $ext =~ ^[a-z0-9]+(\.[a-z0-9]+)*$ ]] || die "ext '$ext' must be lowercase [a-z0-9.]" 2

  local now stamp base dir path
  now=$(date -u +%Y%m%dT%H%M%SZ)
  stamp="${now:0:8}-${now:9:6}"
  base="$stamp-$name"
  [ ${#base} -lt 55 ] || die "file name '$base' is ${#base} chars; it must be under 55 with the prefix (name <= 38)" 2
  dir="$ARTIFACT_ROOT/$key/${now:0:4}/${now:4:2}"
  path="$dir/$base.$ext"
  mkdir -p "$dir"
  [ -e "$path" ] && die "refusing to overwrite $path"

  local top=""; top=$(git_in . rev-parse --show-toplevel)
  [ -z "$repo" ] && [ -n "$top" ] && repo=$(basename "$top")
  [ -z "$branch" ] && [ -n "$top" ] && branch=$(git_in . rev-parse --abbrev-ref HEAD)
  [ -z "$session" ] && session="${ARTIFACT_SESSION:-${CLAUDE_SESSION_ID:-}}"
  [ -z "$by" ] && by="${ARTIFACT_BY:-${USER:-unknown}}"
  [ -z "$what" ] && what="${name//-/ }"
  local created="${now:0:4}-${now:4:2}-${now:6:2}T${now:9:2}:${now:11:2}:${now:13:2}Z"
  local -a f=(key "$key" name "$name" what "$what" by "$by" repo "$repo" branch "$branch"
              session "$session" created "$created" path "$path")

  local yaml="" i
  for ((i = 0; i < ${#f[@]}; i += 2)); do yaml+="${f[i]}: $(yaml_str "${f[i+1]}")"$'\n'; done
  set -o noclobber
  case $ext in
    md|txt|log) printf -- '---\n%s---\n\n' "$yaml" > "$path" ;;
    sh|py|yaml|yml|toml|conf|mk) { echo '# ---'; printf '%s' "$yaml" | sed 's/^/# /'; echo '# ---'; } > "$path" ;;
    html|xml|svg) printf -- '<!--\n---\n%s---\n-->\n' "$yaml" > "$path" ;;
    *) : > "$path"
       { printf '{'; for ((i = 0; i < ${#f[@]}; i += 2)); do
           [ $i -gt 0 ] && printf ','; printf '%s:%s' "$(json_str "${f[i]}")" "$(json_str "${f[i+1]}")"; done
         printf '}\n'; } > "$path.meta.json" ;;
  esac
  set +o noclobber

  if [ -n "$repo" ]; then # the package-style link: repos/<repo>/<key>/YYYY/MM/<file> -> ../../../../../<key>/...
    local ldir="$ARTIFACT_ROOT/repos/$repo/$key/${now:0:4}/${now:4:2}"
    mkdir -p "$ldir"
    ln -s "../../../../../$key/${now:0:4}/${now:4:2}/$base.$ext" "$ldir/$base.$ext"
  fi
  printf '%s\n' "$path"
}

cmd_link() {
  local dir=. exclude=0
  while [ $# -gt 0 ]; do
    case $1 in --dir) dir=$2; shift 2 ;; --exclude) exclude=1; shift ;; *) die "link: unknown option $1" 2 ;; esac
  done
  local top; top=$(git_in "$dir" rev-parse --show-toplevel)
  [ -n "$top" ] || die "link: $dir is not inside a git repository"
  local repo target; repo=$(basename "$top"); target="$ARTIFACT_ROOT/repos/$repo"
  mkdir -p "$target"
  if [ -L "$top/.artifacts" ]; then ln -sfn "$target" "$top/.artifacts"
  elif [ -e "$top/.artifacts" ]; then die "link: $top/.artifacts exists and is not a symlink"
  else ln -s "$target" "$top/.artifacts"; fi
  local ign="$top/.gitignore"
  [ $exclude = 1 ] && ign="$(git -C "$top" rev-parse --absolute-git-dir)/info/exclude" && mkdir -p "$(dirname "$ign")"
  if ! grep -qxF '/.artifacts' "$ign" 2>/dev/null; then
    printf '\n# artifact store link (claude/tools/artifact): the repo points, the store holds\n/.artifacts\n' >> "$ign"
    [ $exclude = 1 ] || printf '%s: added /.artifacts to %s - commit it once\n' "$SELF" "$ign" >&2
  fi
  printf '%s -> %s\n' "$top/.artifacts" "$target"
}

cmd_find() {
  local key="" since="" repo=""
  while [ $# -gt 0 ]; do
    case $1 in --key) key=$2; shift 2 ;; --since) since=${2//-/}; shift 2 ;; --repo) repo=$2; shift 2 ;;
      *) die "find: unknown option $1" 2 ;; esac
  done
  [ -n "$key" ] || die "find needs --key" 2
  local base="$ARTIFACT_ROOT/$key"; [ -n "$repo" ] && base="$ARTIFACT_ROOT/repos/$repo/$key"
  [ -d "$base" ] || return 0
  find "$base" -mindepth 3 -maxdepth 3 \( -type f -o -type l \) ! -name '*.meta.json' -print | sort -t/ -k1 |
    while IFS= read -r p; do
      local b=${p##*/}
      [[ $b =~ ^[0-9]{8}-[0-9]{6}- ]] || continue
      [ -n "$since" ] && [[ ${b:0:8} < $since ]] && continue
      printf '%s\n' "$p"
    done
}

cmd_check() {
  local dir=.
  while [ $# -gt 0 ]; do case $1 in --dir) dir=$2; shift 2 ;; *) die "check: unknown option $1" 2 ;; esac; done
  git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1 || die "check: $dir is not inside a git repository"
  local hits
  hits=$(git -C "$dir" ls-files | grep -E -- "$ARTIFACT_CHECK_PATTERNS" | { if [ -n "$ARTIFACT_CHECK_ALLOW" ]; then
    grep -vE -- "$ARTIFACT_CHECK_ALLOW"; else cat; fi; } || true)
  if [ -n "$hits" ]; then
    printf '%s: tracked files that belong in the artifact store (make artifact-new, then point to them):\n' "$SELF" >&2
    printf '%s\n' "$hits" | sed 's/^/  /' >&2
    return 1
  fi
  printf '%s: no tracked artifacts\n' "$SELF"
}

cmd_clean() {
  local key="" days="" apply=0
  while [ $# -gt 0 ]; do
    case $1 in --key) key=$2; shift 2 ;; --older-than) days=$2; shift 2 ;; --apply) apply=1; shift ;;
      *) die "clean: unknown option $1" 2 ;; esac
  done
  [ -n "$key" ] && [[ $days =~ ^[0-9]+$ ]] || die "clean needs --key and --older-than DAYS" 2
  key_ok "$key" || die "unknown key '$key'" 2
  local cutoff n=0 p b; cutoff=$(date -u -d "-$days days" +%Y%m%d%H%M%S)
  while IFS= read -r p; do
    b=${p##*/}; [ "${b:0:8}${b:9:6}" \< "$cutoff" ] || continue
    n=$((n + 1))
    if [ $apply = 1 ]; then rm -f -- "$p" "$p.meta.json"; printf 'removed %s\n' "$p"; else printf 'would remove %s\n' "$p"; fi
  done < <(cmd_find --key "$key")
  if [ $apply = 1 ]; then
    [ -d "$ARTIFACT_ROOT/repos" ] && find "$ARTIFACT_ROOT/repos" -xtype l -delete
    # repos/<repo> itself stays: it is the target of each repo's .artifacts link, so pruning starts one level below it.
    find "$ARTIFACT_ROOT/$key" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    [ -d "$ARTIFACT_ROOT/repos" ] && find "$ARTIFACT_ROOT/repos" -mindepth 2 -type d -empty -delete 2>/dev/null || true
    printf '%s: removed %d\n' "$SELF" "$n"
  else
    printf '%s: dry run, %d would be removed; rerun with --apply (APPLY=1)\n' "$SELF" "$n"
  fi
}

[ $# -gt 0 ] || { usage >&2; exit 2; }
cmd=$1; shift
args=()
while [ $# -gt 0 ]; do
  case $1 in --root) ARTIFACT_ROOT=$2; shift 2 ;; --keys) ARTIFACT_KEYS=$2; shift 2 ;; *) args+=("$1"); shift ;; esac
done
case $cmd in
  new|link|find|check|clean) "cmd_$cmd" ${args[@]+"${args[@]}"} ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
