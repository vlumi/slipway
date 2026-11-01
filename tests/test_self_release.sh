# scripts/release.sh, slipway's own release, on a copy of this repo with a
# local origin and the fake gh.

# shellcheck shell=bash

# A copy of the slipway working tree in ./slipway, committed and pushed to a
# bare ./origin.git, with the given lines under ## [Unreleased].
slipway_copy() {
    git init --quiet --bare origin.git
    mkdir slipway
    (cd "$SLIPWAY_ROOT" && git ls-files -co --exclude-standard | tar -cf - -T -) | tar -xf - -C slipway
    cd slipway || exit 1
    awk -v entries="$1" '/^## \[Unreleased\]/ { print; print ""; if (entries != "") print entries; skip = 1; next }
        skip && /^## \[/ { skip = 0; print ""; print; next } skip { next } { print }' CHANGELOG.md >c && mv c CHANGELOG.md
    git init --quiet
    git remote add origin ../origin.git
    git add -A
    git commit --quiet -m "Initial"
    git push --quiet -u origin main
}

test_release_tags_the_commit_with_the_heading() {
    slipway_copy "- **Something new**: it does a thing."
    scripts/release.sh 9.9.9 >/dev/null

    git --git-dir=../origin.git rev-parse --verify --quiet v9.9.9 >/dev/null || fail "no v9.9.9 on origin"
    tagged="$(git --git-dir=../origin.git show v9.9.9:CHANGELOG.md)"
    assert_contains "$tagged" "## [Unreleased]

## [9.9.9] — ${TODAY}

- **Something new**: it does a thing."
    log="$(cat "$STUB_LOG")"
    assert_contains "$log" "gh release create v9.9.9 --verify-tag --title slipway 9.9.9 --notes - **Something new**: it does a thing."
    assert_contains "$log" "make slipway-update V=v9.9.9"
}

test_rerun_after_release_does_nothing_new() {
    slipway_copy "- A thing."
    scripts/release.sh 9.9.9 >/dev/null
    out="$(scripts/release.sh 9.9.9)"
    assert_contains "$out" "v9.9.9 already tagged"
    assert_contains "$out" "GitHub release v9.9.9 already exists"
    assert_eq 1 "$(grep -c '^gh pr create' "$STUB_LOG")"
}

test_nothing_unreleased_is_refused() {
    slipway_copy ""
    assert_fails scripts/release.sh 9.9.9
    assert_contains "$OUT" "nothing under ## [Unreleased] to release"
}

test_version_must_be_semver() {
    slipway_copy "- A thing."
    assert_fails scripts/release.sh v9.9
    assert_contains "$OUT" "usage: scripts/release.sh X.Y.Z"
}
