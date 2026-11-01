#!/usr/bin/env bash
# Cut a slipway release: file Unreleased under `## [X.Y.Z] — <date>` in a
# release PR, wait for it to merge, tag the merge commit vX.Y.Z (so the tagged
# CHANGELOG has the heading), and publish a GitHub release with that section
# as its notes.
#
# Usage: scripts/release.sh X.Y.Z
#
# Safe to re-run after an interruption: a merged release PR goes straight to
# tagging, an existing tag straight to the GitHub release, and an existing
# release is left alone.
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf '\033[36m▶︎ %s\033[0m\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

version="${1:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: scripts/release.sh X.Y.Z"
tag="v${version}"
branch="release-${version}"
heading_re="^## \[${version//./\\.}\]"

command -v gh >/dev/null || die "gh CLI not found."
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "release from main."
[ -z "$(git status --porcelain)" ] || die "working tree not clean."
git fetch --quiet origin main
git fetch --quiet --prune origin '+refs/tags/*:refs/tags/*'
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main differs from origin/main — pull first."

# The section under the version heading, for the GitHub release.
notes() {
    awk -v h="## [${version}]" 'index($0, h) == 1 { f = 1; next } f && /^## \[/ { exit } f' CHANGELOG.md \
        | sed -e '/./,$!d'
}

# ── The release PR: Unreleased → ## [X.Y.Z] ──────────────────────────────────
if ! grep -qE "$heading_re" CHANGELOG.md; then
    git rev-parse --verify --quiet "$tag" >/dev/null && die "$tag exists but CHANGELOG has no [${version}] — fix that by hand."
    # Anything to release: a list item between Unreleased and the next heading.
    awk '/^## \[Unreleased\]/ { f = 1; next } f && /^## / { exit 1 } f && /^- / { found = 1; exit 0 } END { exit !found }' CHANGELOG.md \
        || die "nothing under ## [Unreleased] to release."

    say "Filing Unreleased under ${version}…"
    git checkout -q -b "$branch"
    awk -v v="$version" -v today="$(date +%Y-%m-%d)" '
        !done && /^## \[Unreleased\]/ { print; print ""; print "## [" v "] — " today; done = 1; next }
        { print }
    ' CHANGELOG.md >CHANGELOG.md.new
    mv CHANGELOG.md.new CHANGELOG.md
    git commit --quiet -am "Release ${version}"
    git push --quiet -u origin "$branch"
    gh pr create --base main --head "$branch" --title "Release ${version}" \
        --body "Files Unreleased under ${version} in CHANGELOG.md. Its merge commit is tagged \`${tag}\` by \`scripts/release.sh\`." >/dev/null
    gh pr merge "$branch" --auto --merge >/dev/null

    # Right after `pr create`, gh reports "no checks" (and `--watch` returns at
    # once) until the workflow registers: wait for a check to exist first.
    say "Waiting for CI to register…"
    tries=0
    while true; do
        gh pr checks "$branch" >/dev/null 2>&1 && break
        rc=$?
        [ "$rc" -eq 8 ] && break
        tries=$((tries + 1))
        [ "$tries" -ge 24 ] && die "no CI checks after ~2 minutes — PR left open at $branch."
        sleep 5
    done
    say "Waiting for CI and the merge…"
    gh pr checks "$branch" --watch --fail-fast >/dev/null || die "CI failed — PR left open at $branch; nothing tagged."
    state=""
    for _ in $(seq 1 40); do
        state="$(gh pr view "$branch" --json state --jq .state)"
        [ "$state" = MERGED ] && break
        sleep 3
    done
    [ "$state" = MERGED ] || die "PR is '$state', not MERGED — once it merges, re-run to tag."
    git checkout -q main
    git pull --quiet --ff-only origin main
fi

# ── The tag, on a commit that has the heading ────────────────────────────────
grep -qE "$heading_re" CHANGELOG.md || die "main's CHANGELOG has no [${version}] — the release PR hasn't merged."
if git rev-parse --verify --quiet "$tag" >/dev/null; then
    echo "  $tag already tagged."
else
    git tag -a "$tag" -m "slipway ${version}"
    git push --quiet origin "$tag"
    echo "  tagged $tag → $(git rev-parse --short HEAD)"
fi

# ── The GitHub release ───────────────────────────────────────────────────────
if gh release view "$tag" >/dev/null 2>&1; then
    echo "  GitHub release $tag already exists."
else
    gh release create "$tag" --verify-tag --title "slipway ${version}" --notes "$(notes)

Update a project with \`make slipway-update V=${tag}\`." >/dev/null
    echo "  published GitHub release $tag"
fi
echo "✓ slipway ${version} released."
