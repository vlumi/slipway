# The whole lane, `make release`, against a local origin with the Apple and
# GitHub tools faked: what gets bumped, stamped, tagged, built and uploaded.

# shellcheck shell=bash

test_release_all_on_ios_and_macos() {
    new_project ios-macos
    printf 'y\nm\n' | make --no-print-directory release >/dev/null

    assert_eq "ios/v1.0.0-5 ios/v1.1.0-6 mac/v1.0.0-5 mac/v1.1.0-6" "$(origin_tags)"
    assert_eq 2 "$(grep -c 'MARKETING_VERSION: "1.1.0"' project.yml)"
    assert_eq 2 "$(grep -c 'CURRENT_PROJECT_VERSION: "6"' project.yml)"
    assert_contains "$(cat CHANGELOG.md)" "## [1.1.0]

### Unreleased (next build)

### build 6 — ${TODAY}

- A new thing.

## [1.0.0]"
    assert_eq "$(git rev-parse HEAD)" "$(git rev-parse origin/main)" "left on the merged main"

    log="$(cat "$STUB_LOG")"
    assert_contains "$log" "gh pr create --title Release v1.1.0 build 6 (all)"
    assert_contains "$log" "gh release create ios/v1.1.0-6 --verify-tag --title iOS v1.1.0 (build 6) — Demo App"
    assert_contains "$log" "--latest=true"
    assert_contains "$log" "gh release create mac/v1.1.0-6 --verify-tag --title macOS v1.1.0 (build 6) — Demo App"
    assert_contains "$log" "xcodebuild archive -project Demo.xcodeproj -scheme Demo-iOS -destination generic/platform=iOS"
    assert_contains "$log" "xcodebuild archive -project Demo.xcodeproj -scheme Demo-macOS -destination generic/platform=macOS"
    assert_contains "$log" "xcrun altool --upload-app --type ios --file dist/ios/App.ipa --apiKey KEY --apiIssuer ISSUER"
    assert_contains "$log" "xcrun altool --upload-app --type macos --file dist/macos/App.pkg"
    assert_file_contains dist/ios/ExportOptions.plist "<string>ABCDE12345</string>"
    assert_eq 1 "$(grep -c -- '--latest=true' "$STUB_LOG")" "only iOS carries the latest badge"
}

test_release_ios_only_project() {
    new_project ios
    printf '\n' | make --no-print-directory release >/dev/null

    assert_eq "ios/v1.0.0-5 ios/v1.0.0-6" "$(origin_tags)"
    assert_not_contains "$(cat "$STUB_LOG")" "Demo-macOS"
    assert_contains "$(cat CHANGELOG.md)" "## [1.0.0]

### Unreleased (next build)

### build 6 — ${TODAY}"
}

test_release_one_platform_of_two() {
    new_project ios-macos
    printf '\n' | make --no-print-directory release PLATFORM=macos UPLOAD=0 >/dev/null

    assert_eq "ios/v1.0.0-5 mac/v1.0.0-5 mac/v1.0.0-6" "$(origin_tags)"
    assert_not_contains "$(cat "$STUB_LOG")" "Demo-iOS"
    assert_not_contains "$(cat "$STUB_LOG")" "altool" "UPLOAD=0 skips the upload"
    [ -f dist/macos/App.pkg ] || fail "the package is still built"
}

test_watch_rides_with_ios() {
    new_project ios-macos-watchos
    printf 'y\n\n' | make --no-print-directory release UPLOAD=0 >/dev/null
    assert_eq "ios/v1.0.0-5 ios/v1.0.0-6 mac/v1.0.0-5 mac/v1.0.0-6" "$(origin_tags)"
    assert_not_contains "$(cat "$STUB_LOG")" "Demo-watchOS"
    assert_eq 3 "$(grep -c 'CURRENT_PROJECT_VERSION: "6"' project.yml)" "the watch target's build moves too"
}

test_platform_not_released_is_refused() {
    new_project ios
    assert_fails make --no-print-directory release PLATFORM=macos
    assert_contains "$OUT" "platform must be all or one of: ios"
    assert_eq "ios/v1.0.0-5" "$(origin_tags)"
}

test_rerun_resumes_and_skips_whats_done() {
    new_project ios-macos
    printf 'y\n\n' | make --no-print-directory release UPLOAD=0 >/dev/null
    # The tag step again, alone: everything is tagged and released already.
    out="$(Scripts/slipway/release-tag.sh all 2>&1)"
    assert_contains "$out" "ios/v1.0.0-6 already tagged + released — skipping"
    assert_contains "$out" "mac/v1.0.0-6 already tagged + released — skipping"
    assert_eq "ios/v1.0.0-5 ios/v1.0.0-6 mac/v1.0.0-5 mac/v1.0.0-6" "$(origin_tags)"
}

test_merged_but_untagged_build_resumes_at_tagging() {
    new_project ios
    sed -i '' 's/CURRENT_PROJECT_VERSION: "5"/CURRENT_PROJECT_VERSION: "6"/' project.yml
    git commit --quiet -am "Release v1.0.0 build 6 (all)"
    git push --quiet origin main
    out="$(make --no-print-directory release UPLOAD=0 </dev/null 2>&1)"
    assert_contains "$out" "publish already done, skipping to tag"
    assert_eq "ios/v1.0.0-5 ios/v1.0.0-6" "$(origin_tags)"
    assert_not_contains "$(cat "$STUB_LOG")" "gh pr create"
}

test_code_without_notes_asks_first() {
    new_project ios
    printf '# Changelog\n\n## [1.0.0]\n\n### Unreleased (next build)\n\n### build 5 — 2026-01-02\n\n- The first thing.\n' >CHANGELOG.md
    echo "code" >Sources/Shared/code.swift
    git add -A && git commit --quiet -m "Change code" && git push --quiet origin main
    assert_fails bash -c "printf '\nn\n' | make --no-print-directory release"
    assert_contains "$OUT" "1 code commits since ios/v1.0.0-5 but no Unreleased notes"
    assert_contains "$OUT" "aborted — write the notes first"
    assert_eq "ios/v1.0.0-5" "$(origin_tags)"
}

test_dirty_tree_stops_preflight() {
    new_project ios
    echo change >>README.txt
    assert_fails make --no-print-directory release
    assert_contains "$OUT" "working tree not clean"
}

test_transparent_icon_stops_preflight() {
    new_project ios
    assert_fails env STUB_ICON_ALPHA=yes make --no-print-directory release
    assert_contains "$OUT" "app icon has an alpha channel"
}

test_distribute_retry_needs_the_tag() {
    new_project ios
    git push --quiet origin :refs/tags/ios/v1.0.0-5
    assert_fails make --no-print-directory release-distribute-retry
    assert_contains "$OUT" "no ios/v1.0.0-5 tag"
}
