# The make surface: help lists what the project builds, and only that.

# shellcheck shell=bash

help_text() { make --no-print-directory help | sed $'s/\033\\[[0-9;]*m//g'; }

test_help_for_ios_only_has_no_mac_or_watch() {
    new_project ios
    out="$(help_text)"
    assert_contains "$out" "Demo App — available make targets:"
    assert_contains "$out" "build-ios"
    assert_not_contains "$out" "build-mac"
    assert_not_contains "$out" "build-watch"
    assert_not_contains "$out" "PLATFORM=all"
    assert_contains "$out" "release-distribute-retry"
}

test_help_for_three_platforms_lists_each() {
    new_project ios-macos-watchos
    out="$(help_text)"
    assert_contains "$out" "build-ios"
    assert_contains "$out" "build-mac"
    assert_contains "$out" "build-watch"
    assert_contains "$out" "PLATFORM=all (default) or one platform"
}

test_project_targets_join_slipway_sections() {
    new_project ios
    cat >>Makefile <<'EOF'

##@ Build & test
icon:  ## Regenerate the app icon

##@ Demo extras
fixture:  ## Rebuild the demo fixture
EOF
    out="$(help_text)"
    assert_eq 1 "$(echo "$out" | grep -c '^Build & test$')" "Build & test should appear once"
    build_section="$(echo "$out" | awk '/^Build & test$/ { f = 1; next } /^[A-Z]/ { f = 0 } f')"
    assert_contains "$build_section" "icon"
    assert_contains "$out" "Demo extras"
}

test_targets_for_unbuilt_platforms_dont_exist() {
    new_project ios
    assert_fails make --no-print-directory build-mac
    assert_contains "$OUT" "No rule to make target"
}

test_build_uses_the_platform_scheme() {
    new_project ios-macos-watchos
    make --no-print-directory build-watch >/dev/null
    assert_file_contains "$STUB_LOG" "xcodegen generate"
    assert_file_contains "$STUB_LOG" "-scheme Demo-watchOS -destination generic/platform=watchOS Simulator"
}

test_missing_config_stops_make() {
    new_project ios
    rm slipway.yml
    assert_fails make --no-print-directory help
    assert_contains "$OUT" "couldn't read slipway.yml"
}

test_release_sections_come_after_the_projects() {
    new_project ios
    printf '\n##@ Run\nrun:  ## Run it\n' >>Makefile
    sections="$(help_text | grep -vE '^( |$)' | sed 1d | xargs)"
    assert_eq "General Build & test Run Release App Store slipway" "$sections"
}
