# The App Store Connect sync: which screenshots it uploads, keeps and drops, and
# the runner and targets around it. Nothing here talks to App Store Connect.

# shellcheck shell=bash

# A PNG header of the given size, with a tag so files of one size differ.
png() {
    python3 - "$@" <<'PY'
import struct, sys
path, w, h, tag = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR"
                       + struct.pack(">II", w, h) + tag.encode())
PY
}

# Python against the installed copy, as asc.sh runs it.
asc_py() { PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=Scripts/slipway python3 -c "$1"; }

# A venv whose python only logs how it was called.
fake_venv() {
    mkdir -p venv/bin
    printf '#!/bin/sh\necho "python $* bytecode=${PYTHONDONTWRITEBYTECODE:-on}" >>"$STUB_LOG"\n' >venv/bin/python
    chmod +x venv/bin/python
    cp Scripts/slipway/asc-requirements.txt venv/.slipway-requirements
    export SLIPWAY_ASC_VENV="$PWD/venv"
}

test_unchanged_shots_stay_and_only_the_changed_go_up() {
    new_project ios
    mkdir -p shots
    png shots/a.png 1320 2868 a
    png shots/b.png 1320 2868 b-new
    png shots/c.png 1320 2868 c
    out="$(asc_py '
import hashlib
from asc_screenshots import plan_set
md5 = lambda p: hashlib.md5(open(p, "rb").read()).hexdigest()
shot = lambda i, s, state="COMPLETE": {"id": i, "attributes": {
    "sourceFileChecksum": s, "assetDeliveryState": {"state": state}}}
existing = [shot("C", md5("shots/c.png")), shot("A", md5("shots/a.png")),
            shot("B", "old"), shot("D", "gone")]
files = ["shots/a.png", "shots/b.png", "shots/c.png"]
print(plan_set(existing, files, False))
print(plan_set(existing, files, True))
print(plan_set([shot("A", md5("shots/a.png"), "FAILED")], files[:1], False))
')"
    assert_contains "$out" "(['A', None, 'C'], ['B', 'D'])"
    assert_contains "$out" "([None, None, None], ['C', 'A', 'B', 'D'])"
    assert_contains "$out" "([None], ['A'])"
}

test_store_order_follows_shots_json_per_platform() {
    new_project ios
    out="$(asc_py '
from asc_screenshots import store_order
doc = {"store": ["read", "watch-face", "study"],
       "shots": {"watch-face": {"platforms": ["watch"]}, "study": {"platforms": ["iphone", "mac"]}}}
print(store_order(doc, "iphone"), store_order(doc, "watch"), store_order(doc, "ipad"))
')"
    assert_eq "['read', 'study'] ['read', 'watch-face'] ['read']" "$out"
}

test_captures_by_language_or_one_folder() {
    new_project ios
    mkdir -p shots/iphone/en shots/iphone/ja shots/ipad
    png shots/iphone/en/study-iphone.png 1320 2868 s
    png shots/iphone/en/read-iphone.png 1320 2868 r
    png shots/iphone/en/old-iphone.png 1320 2868 o
    png shots/ipad/read-ipad.png 2064 2752 r
    out="$(asc_py '
from asc_screenshots import languages, ordered_files
print(languages("shots/iphone"), languages("shots/ipad"))
print(ordered_files("shots/iphone/en", "iphone", ["read", "study", "phrase"]))
')"
    assert_contains "$out" "[('en', 'shots/iphone/en'), ('ja', 'shots/iphone/ja')] [('en', 'shots/ipad')]"
    assert_contains "$out" "(['shots/iphone/en/read-iphone.png', 'shots/iphone/en/study-iphone.png'], ['old-iphone.png'])"
}

test_a_wrong_sized_capture_stops_the_run() {
    new_project ios
    mkdir -p shots
    png shots/a.png 1290 2796 a
    assert_fails asc_py 'from asc_screenshots import check_sizes; check_sizes(["shots/a.png"], "iphone")'
    assert_contains "$OUT" "expected 1320x2868"
}

test_targets_run_the_venv_without_bytecode() {
    new_project ios
    fake_venv
    make --no-print-directory asc-listing-apply asc-screenshots >/dev/null
    make --no-print-directory asc-screenshots-apply ALL=1 >/dev/null
    assert_file_contains "$STUB_LOG" "asc_listing.py --apply bytecode=1"
    assert_file_contains "$STUB_LOG" "asc_screenshots.py bytecode=1"
    assert_file_contains "$STUB_LOG" "asc_screenshots.py --apply --all bytecode=1"
    assert_contains "$(make --no-print-directory slipway-check)" "unmodified"
}

test_help_lists_the_app_store_targets() {
    new_project ios
    out="$(make --no-print-directory help | sed $'s/\033\\[[0-9;]*m//g')"
    assert_contains "$out" "App Store"
    assert_contains "$out" "asc-screenshots-apply"
    assert_contains "$out" "asc-listing"
}
