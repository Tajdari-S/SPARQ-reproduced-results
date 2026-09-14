import matplotlib.pyplot as plt
import numpy as np
import matplotlib.ticker as ticker
from matplotlib.patches import Patch
import matplotlib.font_manager as fm

# -------------------------
# If Times New Roman is not installed:
# -------------------------
# On Ubuntu/Debian:
# sudo apt install ttf-mscorefonts-installer
# On MacOS: already installed
# On Windows: already available

# Force matplotlib to use Times New Roman
plt.rcParams['font.family'] = 'Times New Roman'
plt.rcParams['font.size'] = 42

# -------------------------
# Latency Data (in nanoseconds)
# -------------------------
scale_labels = ['SF1', 'SF10', 'SF100']
table_labels = ['customer', 'part', 'supplier', 'date']
device_labels = ['SPARQ', 'GPU', 'CPU']
colors = ['darkseagreen', 'goldenrod', 'mediumpurple']
hatches = ['///', '', '']

# Latency (ns) — will convert to ms
raw_latency_ns = {
        'customer': {
            'SPARQ': [743997.5, 8472425, 74653817.5],
            'GPU': [153500000, 1294100000, 76102600000],
            'CPU': [377000000, 4726000000, 46291000000]
        },
        'part': {
            'SPARQ': [1076788.75, 12407645, 101314633.125],
            'GPU': [238300000, 1562200000, 58814900000],
            'CPU': [436000000, 5473000000, 55760000000]
        },
        'supplier': {
            'SPARQ': [968215, 9333137.5, 101365995],
            'GPU': [114700000, 1665800000, 61521100000],
            'CPU': [455000000, 4274000000, 51596000000]
        },
        'date': {
            'SPARQ': [764128.125, 7642613.125, 76424375],
            'GPU': [124500000, 1704100000, 72252100000],
            'CPU': [425000000, 4174000000, 50596000000]
        }
    }



# Convert ns to ms
raw_latency = {
    table: {
        device: [v / 1e6 for v in values]
        for device, values in device_data.items()
    }
    for table, device_data in raw_latency_ns.items()
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
num_devices = len(device_labels)

# Compute x positions
def compute_x_positions():
    positions = []
    sub_group_width = num_devices * bar_width + (num_devices - 1) * bar_spacing
    for t in range(len(table_labels)):
        table_start = t * (num_sf * (sub_group_width + sf_group_spacing) + table_group_spacing)
        for s in range(num_sf):
            sub_group_start = table_start + s * (sub_group_width + sf_group_spacing)
            bars_x = [sub_group_start + i * (bar_width + bar_spacing) for i in range(num_devices)]
            positions.append(bars_x)
    return positions

x_positions = compute_x_positions()

# Flatten bar heights in the same order
bar_data = []
for table in table_labels:
    for i in range(num_sf):
        for device in device_labels:
            bar_data.append(raw_latency[table][device][i])

x_flat = [x for group in x_positions for x in group]

# -------------------------
# Plot Bars
# -------------------------
for i, (xpos, height) in enumerate(zip(x_flat, bar_data)):
    ax.bar(xpos, height, width=bar_width,
           color=colors[i % num_devices],
           hatch=hatches[i % num_devices],
           edgecolor='black', alpha=0.8)

# -------------------------
# Axis & Ticks
# -------------------------
ax.set_yscale('log')
ax.set_ylabel('Latency (ms)', fontsize=50)
ax.yaxis.set_major_locator(ticker.LogLocator(base=10.0, numticks=5))
ax.yaxis.set_minor_formatter(ticker.NullFormatter())
ax.grid(True, axis='y', linestyle='--', alpha=0.6)
ax.set_ylim(1e-1, 1e6)

# Group-level x-ticks
x_ticks = []
x_labels = []
sub_group_width = num_devices * bar_width + (num_devices - 1) * bar_spacing

for t in range(len(table_labels)):
    table_start = t * (num_sf * (sub_group_width + sf_group_spacing) + table_group_spacing)
    chunk_width = num_sf * (sub_group_width + sf_group_spacing) - sf_group_spacing
    center = table_start + chunk_width / 2
    x_ticks.append(center)
    x_labels.append(table_labels[t].capitalize())
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
    ax.text(center_x, 0.83, scale_labels[sf_idx],
            ha='center', va='bottom',
            fontsize=38, transform=ax.get_xaxis_transform())

# -------------------------
# Legend
# -------------------------
legend_elements = [
    Patch(facecolor=colors[i], hatch=hatches[i], edgecolor='black', label=device_labels[i])
    for i in range(num_devices)
]
ax.legend(handles=legend_elements, loc='upper center', ncol=3, fontsize=38,
          bbox_to_anchor=(0.5, 1.24), frameon=False, columnspacing=0.5)

# Layout and Save
plt.tight_layout()
plt.subplots_adjust(top=0.85)
plt.savefig("join_latency_ns_to_ms_grouped_style.png", dpi=300, bbox_inches='tight')
plt.show()
