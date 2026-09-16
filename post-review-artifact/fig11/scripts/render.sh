#!/usr/bin/env bash
# Render a Fig11.py the way the full artifact's run_all_figures.sh does: comment out
# the Colab `!` lines, use the Agg backend, and save the figure it creates.
#   bash render.sh ../Fig11.py fig11_updated.png
set -euo pipefail
src="$1"; out="$2"; tmp="$(mktemp --suffix=.py)"
sed 's/^!/#!/' "$src" > "$tmp"
cat >> "$tmp" <<PY
import matplotlib.pyplot as _plt
_plt.gcf().savefig("$out", dpi=150, bbox_inches="tight")
PY
MPLBACKEND=Agg python3 "$tmp" > /dev/null
rm -f "$tmp"
echo "wrote $out"
