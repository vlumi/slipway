# Promoting "Unreleased (next build)" to a build heading, and opening a new
# version's section when the version changed.

# shellcheck shell=bash

promote() { bash -c ". Scripts/slipway/release-lib.sh && promote_changelog_build $*" >/dev/null; }

test_new_version_opens_its_section_bracket_style() {
    new_project ios
    promote 6 1.1.0
    assert_eq "# Changelog

Intro.

## [1.1.0]

### Unreleased (next build)

### build 6 — ${TODAY}

- A new thing.

## [1.0.0]

### build 5 — 2026-01-02

- The first thing." "$(cat CHANGELOG.md)"
}

test_new_version_opens_its_section_v_style() {
    new_project ios "## v{version}"
    promote 6 1.1.0
    assert_contains "$(cat CHANGELOG.md)" "Intro.

## v1.1.0

### Unreleased (next build)

### build 6 — ${TODAY}

- A new thing.

## v1.0.0

### build 5"
}

test_same_version_promotes_in_place() {
    new_project ios
    promote 6
    assert_eq "# Changelog

Intro.

## [1.0.0]

### Unreleased (next build)

### build 6 — ${TODAY}

- A new thing.

### build 5 — 2026-01-02

- The first thing." "$(cat CHANGELOG.md)"
}

test_old_version_keeps_its_blurb() {
    new_project ios
    sed -i '' 's/^## \[1.0.0\]$/## [1.0.0]\
\
The store release./' CHANGELOG.md
    promote 6 1.1.0
    assert_contains "$(cat CHANGELOG.md)" "- A new thing.

## [1.0.0]

The store release.

### build 5"
    assert_eq 1 "$(grep -c 'The store release' CHANGELOG.md)"
}

test_hand_written_new_heading_is_used_not_doubled() {
    new_project ios
    sed -i '' 's/^## \[1.0.0\]$/## [1.1.0]/' CHANGELOG.md
    promote 6 1.1.0
    assert_eq 1 "$(grep -c '^## \[1.1.0\]' CHANGELOG.md)"
    assert_contains "$(cat CHANGELOG.md)" "## [1.1.0]

### Unreleased (next build)

### build 6 — ${TODAY}"
}

test_first_version_gets_a_heading() {
    new_project ios
    printf '# Changelog\n\nIntro.\n\n### Unreleased (next build)\n\n- A new thing.\n' >CHANGELOG.md
    promote 6 1.1.0
    assert_contains "$(cat CHANGELOG.md)" "Intro.

## [1.1.0]

### Unreleased (next build)

### build 6 — ${TODAY}"
}

test_empty_unreleased_is_left_alone() {
    new_project ios
    printf '# Changelog\n\n## [1.0.0]\n\n### Unreleased (next build)\n\n### build 5 — 2026-01-02\n\n- The first thing.\n' >CHANGELOG.md
    before="$(cat CHANGELOG.md)"
    promote 6 1.1.0
    assert_eq "$before" "$(cat CHANGELOG.md)"
}
