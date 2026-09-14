import matplotlib.pyplot as plt
import numpy as np
import matplotlib as mpl
import matplotlib.font_manager as fm
from matplotlib.patches import Patch
import matplotlib.ticker as ticker

# Set font globally (after downloading if needed)
plt.rcParams['font.family'] = 'Times New Roman'
plt.rcParams['font.size'] = 42

# -------------------------
# Data Setup
# -------------------------
scale_labels = ['SF1', 'SF10', 'SF100']
table_labels = ['Customer', 'Part', 'Supplier', 'Date']
metric_labels = ['PIM/GPU', 'PIM/CPU', 'GPU/CPU']
colors = ['darkseagreen', 'darkgoldenrod', 'purple']
hatches = ['///', '', '']

# Join latency per device, ns, [SF1, SF10, SF100]. Speedups are derived from these,
# so each device's value is written once.

# SPARQ: DRAMsim3, DDR4-3200 x8 (post-review-artifact/sparq). Unchanged.
PIM = {
    'Customer': [743997.5, 8472425, 74653817.5],
    'Part':     [1076788.75, 12407645, 101314633.125],
    'Supplier': [968215, 9333137.5, 101365995],
    'Date':     [764128.125, 7642613.125, 76424375],
}

# GPU: post-review baseline, dask-cuDF with 256 MiB partitions at every SF, inputs
# loaded before timing; median of three A100 runs
# (post-review-artifact/gpu/results/gpu_uniform_results.csv).
GPU = {
    'Customer': [153500000, 1294100000, 76102600000],
    'Part':     [238300000, 1562200000, 58814900000],
    'Supplier': [114700000, 1665800000, 61521100000],
    'Date':     [124500000, 1704100000, 72252100000],
}

# CPU: DuckDB, unchanged from the original script.
# NOTE: Customer SF100 is 74,739 ms here but 46,291 ms in Fig7.py and Fig10.py.
CUSTOMER_SF100_CPU = 74739000000   # set to 46291000000 to match Figures 7 and 10
CPU = {
    'Customer': [377000000, 4726000000, CUSTOMER_SF100_CPU],
    'Part':     [436000000, 5473000000, 55760000000],
    'Supplier': [455000000, 4274000000, 51596000000],
    'Date':     [425000000, 4174000000, 50596000000],
}

raw_data = {
    t: {
        'PIM/GPU': [g / p for g, p in zip(GPU[t], PIM[t])],
        'PIM/CPU': [c / p for c, p in zip(CPU[t], PIM[t])],
        'GPU/CPU': [c / g for c, g in zip(CPU[t], GPU[t])],
    }
    for t in table_labels
}

# -------------------------
# Layout and Plot Setup
# -------------------------
fig, ax = plt.subplots(figsize=(28, 6))

bar_width = 0.18
bar_spacing = 0.01
sf_group_spacing = 0.04
table_group_spacing = 0.26
num_sf = len(scale_labels)
num_metrics = len(metric_labels)

# Compute x positions
x_positions = []
bar_data = []

def compute_x_positions():
    positions = []
    sub_group_width = num_metrics * bar_width + (num_metrics - 1) * bar_spacing
    for t in range(len(table_labels)):
        table_start = t * (num_sf * (sub_group_width + sf_group_spacing) + table_group_spacing)
        for s in range(num_sf):
            sub_group_start = table_start + s * (sub_group_width + sf_group_spacing)
            bars_x = [sub_group_start + i * (bar_width + bar_spacing) for i in range(num_metrics)]
            positions.append(bars_x)
    return positions

x_positions = compute_x_positions()

# Flatten bar heights in the same order
for table in table_labels:
    for i in range(num_sf):
        for metric in metric_labels:
            bar_data.append(raw_data[table][metric][i])

x_flat = [x for group in x_positions for x in group]

# -------------------------
# Plot Bars
# -------------------------
for i, (xpos, height) in enumerate(zip(x_flat, bar_data)):
    ax.bar(xpos, height, width=bar_width,
           color=colors[i % num_metrics],
           hatch=hatches[i % num_metrics],
           edgecolor='black', alpha=0.8)

# -------------------------
# Axis & Ticks
# -------------------------
ax.set_yscale('log')
ax.set_ylabel('Speedup', fontsize=50)
ax.yaxis.set_major_locator(ticker.LogLocator(base=10.0, numticks=5))
ax.yaxis.set_minor_formatter(ticker.NullFormatter())
ax.grid(True, axis='y', linestyle='--', alpha=0.6)
ax.set_ylim(1e-1, 1e4)

# Group-level x-ticks
x_ticks = []
x_labels = []
sub_group_width = num_metrics * bar_width + (num_metrics - 1) * bar_spacing

for t in range(len(table_labels)):
    table_start = t * (num_sf * (sub_group_width + sf_group_spacing) + table_group_spacing)
    chunk_width = num_sf * (sub_group_width + sf_group_spacing) - sf_group_spacing
    center = table_start + chunk_width / 2
    x_ticks.append(center)
    x_labels.append(table_labels[t])
ax.set_xticks(x_ticks)
ax.set_xticklabels(x_labels, fontsize=50)

# Add vertical dashed lines to separate table groups
for t in range(1, len(table_labels)):
    table_sep = t * (num_sf * (sub_group_width + sf_group_spacing) + table_group_spacing) - table_group_spacing / 2
    ax.axvline(table_sep, linestyle=':', color='gray', linewidth=2)

# -------------------------
# Add Scale Factor Labels as Tags
# -------------------------
for idx, bar_group in enumerate(x_positions):
    sf_idx = idx % num_sf
    center_x = bar_group[1]
    ax.text(center_x, 0.81, scale_labels[sf_idx],
            ha='center', va='bottom',
            fontsize=38, transform=ax.get_xaxis_transform())

# -------------------------
# Legend
# -------------------------
legend_elements = [
    Patch(facecolor=colors[i], hatch=hatches[i], edgecolor='black', label=metric_labels[i])
    for i in range(num_metrics)
]
ax.legend(handles=legend_elements, loc='upper center', ncol=3, fontsize=38,
          bbox_to_anchor=(0.5, 1.24), frameon=False, columnspacing=0.5)

# Layout and Save
plt.tight_layout()
plt.subplots_adjust(top=0.85)
plt.savefig("join_improvements_grouped_style.png", dpi=300, bbox_inches='tight')
plt.show()
