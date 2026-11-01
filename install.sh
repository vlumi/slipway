#!/usr/bin/env bash
# Copy slipway into a project as Scripts/slipway/, recording the version it
# came from (VERSION) and a checksum of every file (MANIFEST) so `make
# slipway-check` can tell an untouched copy from a locally edited one.
#
# Usage: install.sh <project-dir> [version]
#   version defaults to `git describe` of this checkout (a tag, or a commit
#   with -dirty when the working tree has changes).
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

src="$(cd "$(dirname "$0")" && pwd)"
[ $# -ge 1 ] || die "usage: install.sh <project-dir> [version]"
[ -d "$1" ] || die "no such directory: $1"
project="$(cd "$1" && pwd)"
version="${2:-$(git -C "$src" describe --tags --always --dirty 2>/dev/null || echo unknown)}"

dest="$project/Scripts/slipway"
staging="$project/Scripts/.slipway.new"
rm -rf "$staging"
mkdir -p "$staging"
cp -p "$src"/lib/* "$staging/"
cp -p "$src/README.md" "$staging/README.md"
printf '%s\n' "$version" >"$staging/VERSION"
(cd "$staging" && find . -type f ! -name MANIFEST ! -name .DS_Store | sed 's#^\./##' | LC_ALL=C sort | xargs shasum -a 256 >MANIFEST)

# Swap the whole directory in one rename: a script that is running from the old
# copy (update.sh, mid-update) keeps reading the file it opened.
rm -rf "$dest"
mv "$staging" "$dest"
echo "slipway ${version} → ${dest#"$project"/}"

if [ ! -f "$project/slipway.yml" ]; then
    echo
    echo "No slipway.yml yet — add one at the project root, e.g.:"
    echo "    name: MyApp"
    echo "    platforms: [ios, macos]"
    echo "and \`include Scripts/slipway/slipway.mk\` in the Makefile. See Scripts/slipway/README.md."
fi
