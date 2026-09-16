#!/usr/bin/env bash
# Build the SSB generator used for the paper's datasets.
#
#   bash build_ssb_dbgen.sh [DEST]          # default: ./ssb-dbgen
#   cd ssb-dbgen && ./dbgen -s 1 -T a       # SF1 (use -s 10 / -s 100 for larger)
#
# Fork and commit: vadimtk/ssb-dbgen @ 0741e06d4c3e811bcec233378a39db2fc0be5d79.
# The commit exists only in that fork; electrum/ssb-dbgen (the usual upstream)
# does not contain it. The fork sets MACHINE = LINUX; upstream defaults to MAC.
#
# The patch (8 insertions, 2 deletions) changes no generated data. It fixes:
#   - gets() -> fgets(): gets() is not declared by glibc >= 2.16, which GCC 14
#     turns into an error (implicit function declaration).
#   - #include <unistd.h> for getopt/getpid, and explicit int return types:
#     same GCC 14 errors.
#   - tbl_open() tested an uninitialized `struct stat` when the output file did
#     not exist yet, and could take the FIFO branch and call open(O_CREAT) with
#     no mode; hardened glibc aborts ("invalid open call ... without mode").
#     This made dbgen crash intermittently (3 of 40 table generations in our test,
#     Ubuntu 22.04).
set -euo pipefail

DEST="${1:-ssb-dbgen}"
COMMIT=0741e06d4c3e811bcec233378a39db2fc0be5d79
PATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../patches" && pwd)/ssb-dbgen-linux.patch"

if [ ! -d "$DEST/.git" ]; then
    git clone https://github.com/vadimtk/ssb-dbgen "$DEST"
fi
cd "$DEST"
git checkout -q "$COMMIT"
if git apply --check "$PATCH" 2>/dev/null; then
    git apply "$PATCH"
    echo "[patch] applied $(basename "$PATCH")"
else
    git apply --reverse --check "$PATCH" 2>/dev/null \
        && echo "[patch] already applied" \
        || { echo "[patch] does not apply to this tree"; exit 1; }
fi
make -s clean >/dev/null 2>&1 || true
make -s
echo "built $(pwd)/dbgen  ($(gcc --version | head -1))"
echo "next: ./dbgen -s 1 -T a    # writes *.tbl here; then tools/validate_data.sh"
