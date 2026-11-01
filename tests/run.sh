#!/usr/bin/env bash
# Run the tests: every `test_*` function in tests/test_*.sh, each in its own
# bash process (with -e, which `if` would otherwise switch off) in a fresh temp
# directory. Usage: tests/run.sh [name-filter]
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
filter="${1:-}"
pass=0
failed=()

for file in "$here"/test_*.sh; do
    for t in $(sed -nE 's/^(test_[A-Za-z0-9_]+)\(\).*/\1/p' "$file"); do
        case "$t" in *"$filter"*) ;; *) continue ;; esac
        dir="$(mktemp -d)"
        if (cd "$dir" && bash -euo pipefail -c ". '$here/helpers.sh'; . '$file'; $t") >"$dir.log" 2>&1; then
            pass=$((pass + 1))
            printf '  ok    %s\n' "$t"
        else
            failed+=("$t")
            printf '  FAIL  %s\n' "$t"
            sed 's/^/        /' "$dir.log"
        fi
        rm -rf "$dir" "$dir.log"
    done
done

echo
echo "${pass} passed, ${#failed[@]} failed"
[ "${#failed[@]}" -eq 0 ]
