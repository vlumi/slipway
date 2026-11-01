# Test helpers (sourced by run.sh into each test's process, cwd a fresh temp dir).

# shellcheck shell=bash

SLIPWAY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034  # used by the tests
TODAY="$(date +%Y-%m-%d)"

# Git isolated from the machine's own config (signing, hooks, default branch).
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$PWD/.gitconfig"
git config --global user.name "Test"
git config --global user.email "test@example.com"
git config --global init.defaultBranch main
git config --global commit.gpgsign false
git config --global tag.gpgsign false

# The fake Apple/GitHub tools, logging to $STUB_LOG.
export PATH="$SLIPWAY_ROOT/tests/stubs:$PATH"
export STUB_LOG="$PWD/stub.log"
export STUB_STATE="$PWD/stub-state"
mkdir -p "$STUB_STATE"
: >"$STUB_LOG"

fail() {
    echo "FAILED: $*" >&2
    exit 1
}
assert_eq() { [ "$1" = "$2" ] || fail "${3:-expected '$1', got '$2'}"; }
assert_contains() {
    case "$1" in *"$2"*) ;; *) fail "${3:-expected to find '$2' in:}"$'\n'"$1" ;; esac
}
assert_not_contains() {
    case "$1" in *"$2"*) fail "${3:-did not expect '$2' in:}"$'\n'"$1" ;; esac
}
assert_file_contains() { grep -qF -- "$2" "$1" || fail "expected '$2' in $1:"$'\n'"$(cat "$1")"; }
# Run a command that must fail; its combined output is in $OUT.
assert_fails() {
    if OUT="$("$@" 2>&1)"; then fail "expected failure: $*"$'\n'"$OUT"; fi
}

# A project in ./work with a bare ./origin.git, slipway installed and committed
# on main. Shapes: ios | ios-macos | ios-macos-watchos. The heading style is
# the changelog's version heading template.
new_project() {
    local default_heading='## [{version}]'
    local shape="$1" heading="${2:-$default_heading}" plats targets="" p label
    case "$shape" in
        ios) plats="ios" ;;
        ios-macos) plats="ios, macos" ;;
        ios-macos-watchos) plats="ios, macos, watchos" ;;
        *) fail "unknown shape $shape" ;;
    esac
    git init --quiet --bare origin.git
    mkdir work
    cd work || exit 1
    git init --quiet
    git remote add origin ../origin.git

    cat >slipway.yml <<EOF
name: Demo
display_name: Demo App
platforms: [${plats}]
changelog_version_heading: "${heading}"
app_icon: Sources/Shared/icon-1024.png
EOF
    for p in ios macos watchos; do
        case " ${plats//,/} " in *" $p "*) ;; *) continue ;; esac
        case "$p" in ios) label=iOS ;; macos) label=macOS ;; watchos) label=watchOS ;; esac
        targets+="  Demo-${label}:
    type: application
    platform: ${label}
    settings:
      base:
        MARKETING_VERSION: \"1.0.0\"
        CURRENT_PROJECT_VERSION: \"5\"
"
    done
    cat >project.yml <<EOF
name: Demo
settings:
  base:
    DEVELOPMENT_TEAM: ABCDE12345
targets:
${targets}
EOF
    local old_heading="${heading//\{version\}/1.0.0}"
    cat >CHANGELOG.md <<EOF
# Changelog

Intro.

${old_heading}

### Unreleased (next build)

- A new thing.

### build 5 — 2026-01-02

- The first thing.
EOF
    printf 'include Scripts/slipway/slipway.mk\n' >Makefile
    mkdir -p Sources/Shared Scripts
    : >Sources/Shared/icon-1024.png
    printf 'ASC_KEY_ID=KEY\nASC_ISSUER_ID=ISSUER\n' >Scripts/.asc-config
    printf 'Scripts/.asc-config\n*.xcodeproj\ndist/\n' >.gitignore
    "$SLIPWAY_ROOT/install.sh" . test >/dev/null
    git add -A
    git commit --quiet -m "Initial"
    git push --quiet -u origin main
    # Build 5 shipped already: tagged, as a real project's current build is.
    git tag ios/v1.0.0-5
    case "$shape" in *macos*) git tag mac/v1.0.0-5 ;; esac
    git push --quiet origin --tags
}

# Tags as origin has them.
origin_tags() { git --git-dir="$(git rev-parse --show-toplevel)/../origin.git" tag --list | sort | xargs; }
