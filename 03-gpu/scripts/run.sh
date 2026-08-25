#!/usr/bin/env bash
# GPU join baseline for Figure 10.
#
#   bash run.sh [SF ...]        # default: 1 10
#
# Needs a CUDA GPU with RAPIDS installed and the SSB .tbl files. Loads every
# table first, synchronises the device, and only then times the join - matching
# how the DuckDB baselines are measured. See README.md for why that matters.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${RAPIDS_PYTHON:-/myenv/rapids_env/bin/python}"
DATA_ROOT="${DATA_ROOT:-/p/pd/pim}"

if [ ! -x "$PY" ]; then
    echo "RAPIDS python not found at $PY"
    echo "Set RAPIDS_PYTHON to your environment, e.g.:"
    echo "  RAPIDS_PYTHON=\$(conda run -n rapids which python) bash run.sh"
    exit 1
fi

echo "[env] $PY"
"$PY" - <<'PYCHK' || exit 1
import cudf, cupy
print(f"[env] cudf {cudf.__version__}, device "
      f"{cupy.cuda.runtime.getDeviceProperties(0)['name'].decode()}")
PYCHK

DATA_ROOT="$DATA_ROOT" "$PY" "$HERE/gpu_join_bench.py" "$@"
