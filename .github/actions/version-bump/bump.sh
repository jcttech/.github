#!/usr/bin/env bash
#
# bump.sh — deterministically bump the project version across every manifest
# present in the repo, in lockstep.
#
# Usage:
#   bump.sh <patch|minor|major|X.Y.Z> [--dry-run]
#
# Version source of truth: the latest `v*` git tag (semver-sorted); falls back
# to the first manifest found if no tags exist. Given a bump level it computes
# the next version; given an explicit X.Y.Z it uses that verbatim.
#
# Manifests updated when present:
#   - Cargo.toml            ([package] version)
#   - Cargo.lock            ([[package]] block whose name matches Cargo.toml)
#   - .claude-plugin/plugin.json        (.version)
#   - .claude-plugin/marketplace.json   (.plugins[] with source "./" -> .version)
#   - pyproject.toml        ([project] or [tool.poetry] version)
#   - package.json          (.version)
#
# Prints the resolved new version (bare X.Y.Z) as the final line of stdout so a
# caller can capture it; all diagnostics go to stderr. JSON edits require `jq`.
#
set -euo pipefail

log()  { printf '%s\n' "$*" >&2; }
die()  { printf 'bump.sh: error: %s\n' "$*" >&2; exit 1; }

BUMP="${1:-}"
DRY_RUN=0
if [ "${2:-}" = "--dry-run" ] || [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi
[ "$BUMP" = "--dry-run" ] && BUMP="${2:-}"
[ -n "$BUMP" ] || die "usage: bump.sh <patch|minor|major|X.Y.Z> [--dry-run]"

# --- extract a quoted value from a `key = "value"` line on stdin ---
quoted_value() { sed -nE 's/.*"([^"]*)".*/\1/p' | head -n1; }

# --- read the first JSON "version" value from a file ---
json_version() { sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$1" | head -n1; }

# --- current version: latest v* tag, else a manifest ---
detect_current() {
  local v=""
  if git rev-parse --git-dir >/dev/null 2>&1; then
    v="$(git tag --list 'v[0-9]*' --sort=-v:refname 2>/dev/null | head -n1 | sed 's/^v//')"
  fi
  if [ -z "$v" ] && [ -f Cargo.toml ]; then
    v="$(awk '/^\[package\]/{p=1;next} /^\[/{p=0} p&&/^[[:space:]]*version[[:space:]]*=/{print;exit}' Cargo.toml | quoted_value)"
  fi
  if [ -z "$v" ] && [ -f .claude-plugin/plugin.json ]; then v="$(json_version .claude-plugin/plugin.json)"; fi
  if [ -z "$v" ] && [ -f package.json ]; then v="$(json_version package.json)"; fi
  printf '%s' "$v"
}

# --- compute next version ---
compute_next() {
  local cur="$1" kind="$2"
  case "$kind" in
    major|minor|patch)
      local core="${cur%%-*}"; core="${core%%+*}"
      local MA MI PA
      IFS=. read -r MA MI PA <<<"$core"
      [[ "$MA" =~ ^[0-9]+$ && "$MI" =~ ^[0-9]+$ && "$PA" =~ ^[0-9]+$ ]] \
        || die "cannot parse current version '$cur' as X.Y.Z"
      case "$kind" in
        major) MA=$((MA+1)); MI=0; PA=0 ;;
        minor) MI=$((MI+1)); PA=0 ;;
        patch) PA=$((PA+1)) ;;
      esac
      printf '%s.%s.%s' "$MA" "$MI" "$PA" ;;
    [0-9]*.[0-9]*.[0-9]*)
      [[ "$kind" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid explicit version '$kind'"
      printf '%s' "$kind" ;;
    *) die "invalid bump '$kind' (use patch|minor|major|X.Y.Z)" ;;
  esac
}

# --- apply new file content: diff on dry-run, write otherwise ---
CHANGED=()
apply() {
  local file="$1" new="$2"
  if ! [ -f "$file" ]; then rm -f "$new"; return; fi
  if diff -q "$file" "$new" >/dev/null 2>&1; then
    log "  = $file (already $NEW)"; rm -f "$new"; return
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  ~ $file (would change):"
    diff -u "$file" "$new" | sed 's/^/      /' >&2 || true
    rm -f "$new"
  else
    mv "$new" "$file"
    log "  + $file -> $NEW"
  fi
  CHANGED+=("$file")
}

# --- section-aware TOML version edit ([section] ... version = "..") ---
edit_toml_section() {
  local file="$1" section="$2" ver="$3" out="$4"
  awk -v want="$section" -v ver="$ver" '
    /^\[/   { insec = ($0 == want); print; next }
    insec && !done && /^[[:space:]]*version[[:space:]]*=/ {
      sub(/"[^"]*"/, "\"" ver "\""); done=1
    }
    { print }
  ' "$file" >"$out"
}

# --- Cargo.lock [[package]] block matching a name ---
edit_cargo_lock() {
  local file="$1" name="$2" ver="$3" out="$4"
  awk -v name="$name" -v ver="$ver" '
    /^\[\[package\]\]/ { inblk=1; isit=0; print; next }
    /^\[/ && !/^\[\[package\]\]/ { inblk=0; isit=0 }
    inblk && $0 == ("name = \"" name "\"") { isit=1 }
    isit && !done && /^version = / { sub(/"[^"]*"/, "\"" ver "\""); done=1; isit=0 }
    { print }
  ' "$file" >"$out"
}

# --- surgical JSON version edit: replace the value of the "version" key,
#     preserving all other bytes/formatting. mode=first (top-level) | all ---
edit_json_version() {
  local file="$1" ver="$2" out="$3" mode="${4:-first}"
  if [ "$mode" = "all" ]; then
    sed -E 's/("version"[[:space:]]*:[[:space:]]*)"[^"]*"/\1"'"$ver"'"/' "$file" >"$out"
  else
    sed -E '0,/("version"[[:space:]]*:[[:space:]]*)"[^"]*"/ s//\1"'"$ver"'"/' "$file" >"$out"
  fi
}

# ---------------------------------------------------------------------------
CURRENT="$(detect_current)"
[ -n "$CURRENT" ] || die "could not determine current version (no v* tag or manifest)"
NEW="$(compute_next "$CURRENT" "$BUMP")"
log "current: $CURRENT  ->  new: $NEW  (bump: $BUMP)"
[ "$DRY_RUN" -eq 1 ] && log "-- dry run: no files will be written --"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

if [ -f Cargo.toml ]; then
  edit_toml_section Cargo.toml "[package]" "$NEW" "$tmp/Cargo.toml"
  apply Cargo.toml "$tmp/Cargo.toml"
  if [ -f Cargo.lock ]; then
    pkg="$(awk '/^\[package\]/{p=1;next} /^\[/{p=0} p&&/^[[:space:]]*name[[:space:]]*=/{print;exit}' Cargo.toml | quoted_value)"
    [ -n "$pkg" ] && { edit_cargo_lock Cargo.lock "$pkg" "$NEW" "$tmp/Cargo.lock"; apply Cargo.lock "$tmp/Cargo.lock"; }
  fi
fi

if [ -f pyproject.toml ]; then
  # try [project] first, then [tool.poetry]
  edit_toml_section pyproject.toml "[project]" "$NEW" "$tmp/pyproject.toml"
  if diff -q pyproject.toml "$tmp/pyproject.toml" >/dev/null 2>&1; then
    edit_toml_section pyproject.toml "[tool.poetry]" "$NEW" "$tmp/pyproject.toml"
  fi
  apply pyproject.toml "$tmp/pyproject.toml"
fi

# Top-level version manifests: replace the first "version" key only.
for jf in .claude-plugin/plugin.json package.json; do
  [ -f "$jf" ] && { edit_json_version "$jf" "$NEW" "$tmp/$(basename "$jf")" first; apply "$jf" "$tmp/$(basename "$jf")"; }
done
# marketplace.json lists this repo's own plugin(s); bump every plugin entry's version.
if [ -f .claude-plugin/marketplace.json ]; then
  edit_json_version .claude-plugin/marketplace.json "$NEW" "$tmp/marketplace.json" all
  apply .claude-plugin/marketplace.json "$tmp/marketplace.json"
fi

if [ "${#CHANGED[@]}" -eq 0 ]; then
  log "no manifests changed"
else
  log "updated ${#CHANGED[@]} file(s): ${CHANGED[*]}"
fi

# final line of stdout = the resolved version (for callers to capture)
printf '%s\n' "$NEW"
