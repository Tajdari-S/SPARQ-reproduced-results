#!/usr/bin/env bash
# Render Fig7.py headless, the way the full artifact's run_all_figures.sh does:
# comment out the Colab `!` lines, register Times New Roman (the file Fig7.py's
# `!wget` fetches; set TNR_FONT to its path), use Agg, save the figure.
#   TNR_FONT=/path/TimesNewRoman.ttf bash render.sh ../Fig7.py fig7_updated.png
# The output format follows the extension (.png, .pdf).
set -euo pipefail
src="$1"; out="$2"; tmp="$(mktemp --suffix=.py)"
{
  echo "import matplotlib.font_manager as _fm, os as _os"
  echo "_f = _os.environ.get('TNR_FONT', '')"
  echo "if _f and _os.path.exists(_f): _fm.fontManager.addfont(_f)"
  sed 's/^!/#!/' "$src"
  echo "import matplotlib.pyplot as _plt"
  echo "_plt.gcf().savefig('$out', dpi=150, bbox_inches='tight')"
} > "$tmp"
MPLBACKEND=Agg python3 "$tmp" 2>&1 >/dev/null | grep -v findfont || true
rm -f "$tmp"
echo "wrote $out"
