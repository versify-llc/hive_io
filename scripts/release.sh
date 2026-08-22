#!/usr/bin/env bash
#
# Interactive release helper for the hive_io packages.
# Walks through the checklist in RELEASE.md for each package.
#
# `hive_io` is always handled first because `hive_generator_io` and
# `hive_flutter_io` depend on it; their `hive_io` constraint is bumped to
# match and they are only published after `hive_io` is live on pub.dev.
#
# The script edits every file up front, lets you review the diff, and only
# then publishes -- so a mistake can be caught (and `git checkout`-ed away)
# before anything is pushed to pub.dev.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

# Publish order matters: hive_io must come first.
PACKAGES=(hive_io hive_generator_io hive_flutter_io)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Parallel arrays, indexed the same as PACKAGES.
DO_RELEASE=()    # "1" to release, "0" to skip
NEW_VERSION=()   # version to release (read from CHANGELOG, or current if skipped)

# ---------------------------------------------------------------------------
# Pretty output helpers
# ---------------------------------------------------------------------------

if [[ -t 1 ]]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RESET="$(printf '\033[0m')"
  RED="$(printf '\033[31m')"; GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"; BLUE="$(printf '\033[34m')"; CYAN="$(printf '\033[36m')"
else
  BOLD=""; DIM=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""
fi

info()  { printf '%s\n' "${CYAN}==>${RESET} $*"; }
step()  { printf '\n%s\n' "${BOLD}${BLUE}### $*${RESET}"; }
ok()    { printf '%s\n' "${GREEN}OK${RESET} $*"; }
warn()  { printf '%s\n' "${YELLOW}!${RESET} $*"; }
err()   { printf '%s\n' "${RED}x $*${RESET}" >&2; }
die()   { err "$*"; exit 1; }

# ask_yes_no <prompt> <default: y|n>
ask_yes_no() {
  local prompt="$1" default="${2:-n}" reply hint
  if [[ "$default" == "y" ]]; then hint="[Y/n]"; else hint="[y/N]"; fi
  while true; do
    read -r -p "$(printf '%s %s ' "$prompt" "$hint")" reply || reply=""
    reply="${reply:-$default}"
    case "$reply" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) warn "Please answer yes or no." ;;
    esac
  done
}

# pkg_index <name> -> prints the index of a package in PACKAGES (or nothing)
pkg_index() {
  local name="$1" i
  for i in "${!PACKAGES[@]}"; do
    if [[ "${PACKAGES[$i]}" == "$name" ]]; then echo "$i"; return 0; fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Version helpers
# ---------------------------------------------------------------------------

# current_version <pkg> -> prints the version from its pubspec.yaml
current_version() {
  local pkg="$1"
  grep -E '^version:' "$pkg/pubspec.yaml" | head -n1 | sed -E 's/^version:[[:space:]]*//'
}

is_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.+-][0-9A-Za-z.+-]+)?$ ]]
}

# changelog_version <pkg> -> prints the version from the top `### X.Y.Z`
# heading of its CHANGELOG.md (empty if none found).
changelog_version() {
  local pkg="$1"
  grep -E '^###[[:space:]]+' "$pkg/CHANGELOG.md" 2>/dev/null \
    | head -n1 | sed -E 's/^###[[:space:]]+//' | tr -d '[:space:]'
}

# resolve_changelog_version <pkg> -> prints the confirmed release version.
# Reads the top CHANGELOG heading, validates it, and asks the user to confirm
resolve_changelog_version() {
  local pkg="$1" version
  version="$(changelog_version "$pkg")"
  if [[ -z "$version" ]]; then
    warn "No \`### <version>\` heading found at the top of $pkg/CHANGELOG.md." >&2
    exit 1;
  elif ! is_semver "$version"; then
    warn "Top CHANGELOG heading '$version' is not a valid semver version." >&2
    exit 1;    
  fi
  echo "$version"
}

# ---------------------------------------------------------------------------
# File edit helpers (portable in-place edits via a temp file)
# ---------------------------------------------------------------------------

# set_pubspec_version <pkg> <new_version>
set_pubspec_version() {
  local pkg="$1" new="$2" file tmp
  file="$pkg/pubspec.yaml"
  tmp="$(mktemp)"
  sed -E "s/^version:[[:space:]]*.*/version: ${new}/" "$file" >"$tmp"
  mv "$tmp" "$file"
  ok "$file -> version: $new"
}

# bump_dependency_constraint <file> <dep_name> <new_version>
# Rewrites `<dep>: ^X.Y.Z` to `<dep>: ^<new_version>` (only caret constraints).
bump_dependency_constraint() {
  local file="$1" dep="$2" new="$3" tmp
  [[ -f "$file" ]] || return 0
  grep -Eq "^[[:space:]]*${dep}:[[:space:]]*\^[0-9]" "$file" || return 0
  tmp="$(mktemp)"
  sed -E "s/^([[:space:]]*${dep}:[[:space:]]*\^)[0-9]+\.[0-9]+\.[0-9]+([.+-][0-9A-Za-z.+-]+)?/\1${new}/" \
    "$file" >"$tmp"
  mv "$tmp" "$file"
  ok "$file -> ${dep}: ^$new"
}

# ---------------------------------------------------------------------------
# Publishing
# ---------------------------------------------------------------------------

# publish_package <pkg> <version>
publish_package() {
  local pkg="$1" version="$2" tool
  tool="dart $pkg"

  step "Publishing $pkg $version with \`$tool pub publish\`"

  if ! command -v "$tool" >/dev/null 2>&1; then
    warn "\`$tool\` is not on your PATH. Publish $pkg manually:"
    warn "    (cd $pkg && dart pub publish)"
    return 0
  fi

  if ask_yes_no "Publish $pkg $version to pub.dev?" n; then
    ( cd "$pkg" && dart pub publish )
    ok "Published $pkg $version"
  else
    warn "Skipped publishing $pkg. Run \`dart pub publish\` in $pkg/ when ready."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  step "hive_io release helper"
  info "Packages (publish order): ${PACKAGES[*]}"

  # ---- Phase 1: gather decisions for every package --------------------------
  # For each package being released you edit its CHANGELOG; the version is read
  # from the top `### X.Y.Z` heading there.
  local i pkg
  for i in "${!PACKAGES[@]}"; do
    pkg="${PACKAGES[$i]}"
    step "Plan: $pkg"
    if ask_yes_no "Release $pkg? ($(resolve_changelog_version "$pkg"))" y; then
      DO_RELEASE[$i]=1
      NEW_VERSION[$i]="$(resolve_changelog_version "$pkg")"
      ok "$pkg will be released as ${BOLD}${NEW_VERSION[$i]}${RESET}"
    else
      DO_RELEASE[$i]=0
      NEW_VERSION[$i]="$(current_version "$pkg")"
      info "Skipping $pkg (staying on ${NEW_VERSION[$i]})."
    fi
  done

  # Resolve indices we reference by name.
  local idx_io idx_gen idx_flutter
  idx_io="$(pkg_index hive_io)"
  idx_gen="$(pkg_index hive_generator_io)"
  idx_flutter="$(pkg_index hive_flutter_io)"

  local any_release=0
  for i in "${!PACKAGES[@]}"; do
    [[ "${DO_RELEASE[$i]}" == "1" ]] && any_release=1
  done
  [[ "$any_release" == "1" ]] || die "Nothing selected for release. Exiting."

  # ---- Phase 2: apply all file edits ---------------------------------------
  step "Applying file changes"

  local hive_io_version="${NEW_VERSION[$idx_io]}"

  for i in "${!PACKAGES[@]}"; do
    [[ "${DO_RELEASE[$i]}" == "1" ]] || continue
    pkg="${PACKAGES[$i]}"

    # version in pubspec.yaml (taken from the CHANGELOG heading)
    set_pubspec_version "$pkg" "${NEW_VERSION[$i]}"

    # Dependents pin hive_io; keep their constraint aligned to the version
    # being released. Only touch packages we're actually releasing.
    if [[ "$pkg" == "hive_generator_io" || "$pkg" == "hive_flutter_io" ]]; then
      bump_dependency_constraint "$pkg/pubspec.yaml" "hive_io" "$hive_io_version"
    fi
  done

  # install versions in README.md.
  # hive_io/README.md documents the install version of all three packages, so
  # it always reflects the latest version of each (released or not).
  step "Updating README install versions"
  bump_dependency_constraint "hive_io/README.md" "hive_io" "${NEW_VERSION[$idx_io]}"
  bump_dependency_constraint "hive_io/README.md" "hive_flutter_io" "${NEW_VERSION[$idx_flutter]}"
  bump_dependency_constraint "hive_io/README.md" "hive_generator_io" "${NEW_VERSION[$idx_gen]}"

  # ---- Phase 3: review ------------------------------------------------------
  step "Review changes"
  printf '\n'
  ask_yes_no "Do these changes look correct?" y \
    || die "Aborted before publishing."

  # ---- Phase 4: publish in dependency order --------------------------------
  step "Publish"
  for i in "${!PACKAGES[@]}"; do
    [[ "${DO_RELEASE[$i]}" == "1" ]] || continue
    pkg="${PACKAGES[$i]}"
    publish_package "$pkg" "${NEW_VERSION[$i]}"

    # After hive_io, give pub.dev a moment before publishing dependents.
    if [[ "$pkg" == "hive_io" ]]; then
      if [[ "${DO_RELEASE[$idx_gen]}" == "1" || "${DO_RELEASE[$idx_flutter]}" == "1" ]]; then
        warn "hive_generator_io and hive_flutter_io depend on hive_io $hive_io_version."
        warn "Make sure it shows up on https://pub.dev/packages/hive_io before continuing."
        read -r -p "Press Enter once hive_io $hive_io_version is live on pub.dev..." _ || true
      fi
    fi
  done

  step "Done"
  ok "Release flow complete."
}

# Only run when executed directly (lets the functions be sourced for testing).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
