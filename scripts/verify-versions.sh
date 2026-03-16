#!/usr/bin/env bash
# Verify that lib/versions.nix matches what SP1 actually ships.
# Fetches authoritative source files from succinctlabs/sp1 on GitHub
# and compares against our local configuration.
#
# Usage: ./scripts/verify-versions.sh [version]
#   version: optional, e.g. "v6.0.2". If omitted, checks all versions.
#
# Requires: curl, jq, nix

set -euo pipefail

# When run via nix run, $0 is in the nix store; find the repo via git
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" || ! -f "$REPO_ROOT/lib/versions.nix" ]]; then
  # Fallback: script location
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
GITHUB_API="https://api.github.com"
ERRORS=0

red()   { printf '\033[1;31m%s\033[0m\n' "$*"; }
green() { printf '\033[1;32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[1;33m%s\033[0m\n' "$*"; }

# Load versions.nix as JSON
VERSIONS_JSON="$(nix eval --json --file "$REPO_ROOT/lib/versions.nix")"

# Get list of versions to check
if [[ $# -gt 0 ]]; then
  VERSION_LIST="$1"
else
  VERSION_LIST="$(echo "$VERSIONS_JSON" | jq -r 'keys[] | select(startswith("v"))')"
fi

# Fetch a file from GitHub (raw content)
gh_raw() {
  local owner="$1" repo="$2" ref="$3" path="$4"
  curl -sfL "https://raw.githubusercontent.com/${owner}/${repo}/${ref}/${path}"
}

# Fetch a submodule SHA from GitHub API
gh_submodule_sha() {
  local owner="$1" repo="$2" ref="$3" path="$4"
  curl -sfL "${GITHUB_API}/repos/${owner}/${repo}/contents/${path}?ref=${ref}" | jq -r '.sha'
}

# Resolve a tag to a commit SHA
gh_tag_commit() {
  local owner="$1" repo="$2" tag="$3"
  local response
  response="$(curl -sfL "${GITHUB_API}/repos/${owner}/${repo}/git/ref/tags/${tag}")"
  local obj_type obj_sha
  obj_type="$(echo "$response" | jq -r '.object.type')"
  obj_sha="$(echo "$response" | jq -r '.object.sha')"
  if [[ "$obj_type" == "tag" ]]; then
    # Annotated tag — dereference
    curl -sfL "${GITHUB_API}/repos/${owner}/${repo}/git/tags/${obj_sha}" | jq -r '.object.sha'
  else
    echo "$obj_sha"
  fi
}

check_field() {
  local field="$2" expected="$3" actual="$4"
  if [[ "$expected" == "$actual" ]]; then
    green "  $field: OK"
  else
    red "  $field: MISMATCH"
    echo "    versions.nix: $actual"
    echo "    upstream:      $expected"
    ERRORS=$((ERRORS + 1))
  fi
}

for VERSION in $VERSION_LIST; do
  echo ""
  echo "=== Checking $VERSION ==="

  # Extract our config
  LOCAL_TOOLCHAIN="$(echo "$VERSIONS_JSON" | jq -r ".\"$VERSION\".\"toolchain-version\"")"
  LOCAL_TARGET="$(echo "$VERSIONS_JSON" | jq -r ".\"$VERSION\".target")"
  LOCAL_RUST_REV="$(echo "$VERSIONS_JSON" | jq -r ".\"$VERSION\".\"succinct-rust\".rev")"
  LOCAL_BACKTRACE_REV="$(echo "$VERSIONS_JSON" | jq -r ".\"$VERSION\".\"backtrace-rs\".rev")"
  LOCAL_FLAGS="$(echo "$VERSIONS_JSON" | jq -c ".\"$VERSION\".\"build-flags\"")"

  # --- 1. Toolchain version ---
  CLI_SRC="$(gh_raw succinctlabs sp1 "$VERSION" crates/cli/src/lib.rs)"
  UPSTREAM_TOOLCHAIN_TAG="$(echo "$CLI_SRC" | grep -oP 'LATEST_SUPPORTED_TOOLCHAIN_VERSION_TAG.*?"succinct-\K[^"]+' || true)"
  # Fallback: try older constant name
  if [[ -z "$UPSTREAM_TOOLCHAIN_TAG" ]]; then
    UPSTREAM_TOOLCHAIN_TAG="$(echo "$CLI_SRC" | grep -oP 'TOOLCHAIN_TAG.*?"succinct-\K[^"]+' || true)"
  fi
  check_field "$VERSION" "toolchain-version" "$UPSTREAM_TOOLCHAIN_TAG" "$LOCAL_TOOLCHAIN"

  # --- 2. Target triple ---
  BUILD_SRC="$(gh_raw succinctlabs sp1 "$VERSION" crates/build/src/lib.rs)"
  # Try DEFAULT_TARGET (v6+) then BUILD_TARGET (v5)
  UPSTREAM_TARGET="$(echo "$BUILD_SRC" | grep -oP '(?:DEFAULT_TARGET|BUILD_TARGET).*?"\K[^"]+' || true)"
  check_field "$VERSION" "target" "$UPSTREAM_TARGET" "$LOCAL_TARGET"

  # --- 3. Succinct Rust fork commit ---
  UPSTREAM_RUST_REV="$(gh_tag_commit succinctlabs rust "succinct-${LOCAL_TOOLCHAIN}")"
  check_field "$VERSION" "succinct-rust.rev" "$UPSTREAM_RUST_REV" "$LOCAL_RUST_REV"

  # --- 4. backtrace-rs submodule ---
  UPSTREAM_BACKTRACE_REV="$(gh_submodule_sha succinctlabs rust "$LOCAL_RUST_REV" library/backtrace)"
  check_field "$VERSION" "backtrace-rs.rev" "$UPSTREAM_BACKTRACE_REV" "$LOCAL_BACKTRACE_REV"

  # --- 5. Build flags ---
  UTILS_SRC="$(gh_raw succinctlabs sp1 "$VERSION" crates/build/src/command/utils.rs)"

  # Extract the rust_flags array block
  FLAGS_BLOCK="$(echo "$UTILS_SRC" | sed -n '/let rust_flags = \[/,/\];/p')"

  # Determine which atomic pass flag is used
  # The code checks rustc version > 1.81.0; all current SP1 versions use > 1.81.0
  if echo "$UTILS_SRC" | grep -q 'passes=lower-atomic'; then
    ATOMIC_PASS="passes=lower-atomic"
  else
    ATOMIC_PASS="passes=loweratomic"
  fi

  # Build expected flags by parsing each line of the array
  EXPECTED_FLAGS=()
  while IFS= read -r line; do
    # Skip empty lines and the array delimiters
    line="$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/,$//')"
    [[ -z "$line" ]] && continue
    [[ "$line" == "let rust_flags = [" ]] && continue
    [[ "$line" == "];" ]] && continue
    [[ "$line" == "]" ]] && continue

    # Handle variable reference: atomic_lower_pass
    if [[ "$line" == "atomic_lower_pass" ]]; then
      EXPECTED_FLAGS+=("$ATOMIC_PASS")
      continue
    fi

    # Handle format! macro: &format!("link-arg=--image-base={}", sp1_primitives::consts::STACK_TOP)
    if echo "$line" | grep -q 'format!'; then
      CONSTS_SRC="$(gh_raw succinctlabs sp1 "$VERSION" crates/primitives/src/consts.rs)"
      STACK_TOP="$(echo "$CONSTS_SRC" | grep -oP 'STACK_TOP.*?=\s*\K0x[0-9a-fA-F]+' || true)"
      # Extract the format string pattern and substitute
      FMT_STR="$(echo "$line" | grep -oP 'format!\("\K[^"]+' || true)"
      if [[ -n "$FMT_STR" && -n "$STACK_TOP" ]]; then
        RESOLVED="${FMT_STR/\{\}/$STACK_TOP}"
        EXPECTED_FLAGS+=("$RESOLVED")
      fi
      continue
    fi

    # Handle plain string literal: "foo" or "foo\"bar\""
    if echo "$line" | grep -q '^"'; then
      # Remove surrounding quotes, unescape inner quotes
      VAL="$(echo "$line" | sed 's/^"//;s/"$//' | sed 's/\\"/"/g')"
      EXPECTED_FLAGS+=("$VAL")
      continue
    fi
  done <<< "$FLAGS_BLOCK"

  UPSTREAM_FLAGS="$(printf '%s\n' "${EXPECTED_FLAGS[@]}" | jq -R . | jq -sc .)"

  if [[ "$UPSTREAM_FLAGS" == "$LOCAL_FLAGS" ]]; then
    green "  build-flags: OK"
  else
    red "  build-flags: MISMATCH"
    echo "    versions.nix: $LOCAL_FLAGS"
    echo "    upstream:      $UPSTREAM_FLAGS"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""
if [[ $ERRORS -gt 0 ]]; then
  red "Found $ERRORS mismatch(es)!"
  exit 1
else
  green "All checks passed."
fi
