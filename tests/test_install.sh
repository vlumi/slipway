# The per-project copy: installed with its version, checked against its
# manifest, and replaced by an update.

# shellcheck shell=bash

test_fresh_copy_checks_clean() {
    new_project ios
    assert_eq "test" "$(cat Scripts/slipway/VERSION)"
    out="$(make --no-print-directory slipway-check)"
    assert_contains "$out" "is slipway test, unmodified"
}

test_edited_copy_fails_the_check() {
    new_project ios
    echo "# local fix" >>Scripts/slipway/release-tag.sh
    assert_fails make --no-print-directory slipway-check
    assert_contains "$OUT" "release-tag.sh: FAILED"
}

test_added_file_fails_the_check() {
    new_project ios
    : >Scripts/slipway/extra.sh
    assert_fails make --no-print-directory slipway-check
    assert_contains "$OUT" "added: extra.sh"
}

test_finders_ds_store_is_not_an_edit() {
    new_project ios
    : >Scripts/slipway/.DS_Store
    out="$(make --no-print-directory slipway-check)"
    assert_contains "$out" "unmodified"
}

test_update_from_a_checkout_restores_the_copy() {
    new_project ios
    echo "# local fix" >>Scripts/slipway/release-tag.sh
    make --no-print-directory slipway-update SLIPWAY_SRC="$SLIPWAY_ROOT" >/dev/null
    make --no-print-directory slipway-check >/dev/null
    assert_not_contains "$(cat Scripts/slipway/release-tag.sh)" "# local fix"
}

test_update_needs_a_version() {
    new_project ios
    assert_fails make --no-print-directory slipway-update
    assert_contains "$OUT" "say which version"
}
