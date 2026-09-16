# SSB data generation, post-review

## Reviewer comment

> The ssb-dbgen commit pinned in the instructions does not exist in the linked
> repository, and that repository does not build on current Linux/glibc without
> patches. Every non-simulator result depends on the SSB data, so a working,
> documented generator is needed.

## Summary

Both points are correct, and there was a third problem.

1. **Wrong repository.** The full artifact pinned commit `0741e06` on
   `electrum/ssb-dbgen`, where `git checkout` fails ("reference is not a tree").
   The commit exists only in the `vadimtk/ssb-dbgen` fork.
2. **Does not build with GCC 14.** `gets()`, `getopt()`, `getpid()` are used
   without declarations and two functions have implicit `int` return types; GCC 14
   makes all of these errors. Verified with the `gcc:14` image (GCC 14.4.0):
   unpatched fails in `bm_utils.c`, patched builds.
3. **Intermittent crash.** `tbl_open()` tests an uninitialized `struct stat` when
   the output file does not exist yet. On hardened glibc (Ubuntu 22.04) this aborts
   with `invalid open call: O_CREAT or O_TMPFILE without mode` in 3 of 40 table
   generations in our test.

[`patches/ssb-dbgen-linux.patch`](patches/ssb-dbgen-linux.patch) fixes all three
(8 insertions, 2 deletions). It changes no generated data: SF1 output is byte-identical with and
without it, and between GCC 11.4 and GCC 14.4.

We do not recommend upstream `electrum/ssb-dbgen`: besides the same issues, its
lineorder generation overflows a buffer (`strcpy` of `"4-NOT SPECIFIED"`, 16
bytes, into an 11-byte field) and aborts on every run under hardened glibc.

## Recipe

From this directory:

```bash
bash scripts/build_ssb_dbgen.sh            # clone vadimtk fork, pin, patch, build
cd ssb-dbgen
./dbgen -s 1 -T a                          # SF1; -s 10 and -s 100 for the others
tr -d '-' < lineorder.tbl > lo && mv lo lineorder.tbl   # YYYYMMDD dates, as in our SF100 copy
bash ../../../tools/validate_data.sh . 1
```

The fork writes comma-separated, quoted CSV with ISO dates (`"1995-02-18"`). Our
SF100 copy is exactly that format with the dashes removed from `lineorder.tbl`
only (the other tables keep them, e.g. phone numbers), so the last step matches
it. Every loader accepts this: `01-duckdb/scripts/load_ssb.sh` and the GPU scripts
detect `|` or `,` per file.

Tested end to end at SF1: the corrected GPU baseline returns 6,001,171 rows for all
four joins, and `load_ssb.sh` reports the same count for the date join.

## How this relates to the data behind the paper

| copy | used for | format | generator |
|---|---|---|---|
| `/p/pd/pim/sf1`, `sf10` | all SF1 and SF10 measurements | `\|`-separated, `YYYYMMDD` | not identified. Same format as upstream dbgen, not byte-identical to it (city suffixes and date flag columns differ); lineorder has 6,001,173 rows at SF1 against 6,001,171 for a clean generation |
| `/p/pd/ssb-dbgen/sf100` | SF100 | comma CSV, `YYYYMMDD` in lineorder | this recipe: the checkout is `vadimtk` @ `0741e06`, and its SF1 `date.tbl` matches a fresh build byte for byte |

So SF100 can be regenerated as used. SF1 and SF10 can be regenerated with the
same schema, but not byte for byte, and our copies carry two extra lineorder rows
and one extra date row at SF1. Row counts and
fingerprints for all our copies are in the full artifact's
`duckdb_versions/dataset/MANIFEST.md`.

## Files

| | |
|---|---|
| `scripts/build_ssb_dbgen.sh` | clone, pin, patch and build |
| `patches/ssb-dbgen-linux.patch` | the fix (also applies cleanly to `electrum/ssb-dbgen`) |
