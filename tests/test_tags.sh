# Tag ordering: the previous release to diff notes against, the highest build,
# and project.yml's lock-step settings.

# shellcheck shell=bash

lib() { bash -c ". Scripts/slipway/release-lib.sh && $*"; }

tagged_project() {
    new_project ios-macos # tags ios/v1.0.0-5 and mac/v1.0.0-5
    git tag ios/v1.0.0-3
    git tag ios/v0.9.0-7
}

test_previous_tag_is_the_highest_not_newer() {
    tagged_project
    assert_eq "ios/v1.0.0-5" "$(lib previous_tag ios 1.0.0 6)"
    assert_eq "ios/v1.0.0-3" "$(lib previous_tag ios 1.0.0 5)"
    assert_eq "mac/v1.0.0-5" "$(lib previous_tag macos 1.1.0 8)"
}

test_previous_tag_on_an_old_version_line_stays_on_it() {
    tagged_project
    assert_eq "ios/v0.9.0-7" "$(lib previous_tag ios 0.9.0 8)"
    assert_eq "" "$(lib previous_tag ios 0.9.0 7)"
}

test_highest_build_spans_platforms_and_versions() {
    tagged_project
    assert_eq 7 "$(lib highest_tagged_build)"
}

test_newest_tag_orders_by_version_then_build() {
    tagged_project
    assert_eq "ios/v1.0.0-5" "$(lib newest_tag ios)"
}

test_read_unique_refuses_targets_out_of_step() {
    new_project ios-macos
    assert_eq "1.0.0" "$(lib read_unique MARKETING_VERSION)"
    assert_eq "ABCDE12345" "$(lib read_unique DEVELOPMENT_TEAM)"
    awk '!done && /MARKETING_VERSION/ { sub(/1\.0\.0/, "1.0.1"); done = 1 } { print }' project.yml >p && mv p project.yml
    assert_fails lib read_unique MARKETING_VERSION
    assert_contains "$OUT" "MARKETING_VERSION differs between targets"
}
