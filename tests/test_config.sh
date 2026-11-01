# slipway.yml: defaults, list and quoting rules, and the configs it refuses.

# shellcheck shell=bash

# A bare project with the given slipway.yml; `cfg key` reads from it.
config_project() {
    mkdir -p proj
    printf '%s\n' "$@" >proj/slipway.yml
    "$SLIPWAY_ROOT/install.sh" proj test >/dev/null
}
cfg() { proj/Scripts/slipway/config.sh "$1"; }

test_defaults_follow_the_name() {
    config_project "name: Demo"
    assert_eq "Demo" "$(cfg display_name)"
    assert_eq "DemoCore" "$(cfg core_package)"
    assert_eq "ios" "$(cfg platforms)"
    assert_eq "ios" "$(cfg release_platforms)"
    assert_eq "## [{version}]" "$(cfg changelog_version_heading)"
    assert_eq "" "$(cfg app_icon)"
}

test_lists_and_comments() {
    config_project "name: Demo   # the app" "platforms: [ios,  macos, watchos]  # all three"
    assert_eq "Demo" "$(cfg name)"
    assert_eq "ios macos watchos" "$(cfg platforms)"
}

test_release_platforms_default_leaves_out_the_watch() {
    config_project "name: Demo" "platforms: [ios, macos, watchos]"
    assert_eq "ios macos" "$(cfg release_platforms)"
}

test_quoted_value_keeps_its_hashes() {
    config_project "name: Demo" 'changelog_version_heading: "## v{version}"   # yomidori style'
    assert_eq "## v{version}" "$(cfg changelog_version_heading)"
}

test_refuses_an_unknown_key() {
    config_project "name: Demo" "platfroms: [ios]"
    assert_fails cfg name
    assert_contains "$OUT" "unknown key 'platfroms'"
}

test_refuses_a_missing_name() {
    config_project "platforms: [ios]"
    assert_fails cfg platforms
    assert_contains "$OUT" "'name' is required"
}

test_refuses_an_unknown_platform() {
    config_project "name: Demo" "platforms: [ios, tvos]"
    assert_fails cfg name
    assert_contains "$OUT" "unknown platform 'tvos'"
}

test_refuses_the_watch_as_a_release_platform() {
    config_project "name: Demo" "platforms: [ios, watchos]" "release_platforms: [ios, watchos]"
    assert_fails cfg name
    assert_contains "$OUT" "ships inside the iOS app"
}

test_refuses_a_watch_app_without_ios() {
    config_project "name: Demo" "platforms: [macos, watchos]"
    assert_fails cfg name
    assert_contains "$OUT" "watchos needs ios"
}

test_refuses_releasing_what_isnt_built() {
    config_project "name: Demo" "platforms: [ios]" "release_platforms: [ios, macos]"
    assert_fails cfg name
    assert_contains "$OUT" "release platform 'macos' isn't in platforms"
}
