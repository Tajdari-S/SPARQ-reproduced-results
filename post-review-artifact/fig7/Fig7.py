import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import gmean
from matplotlib.patches import Patch
import numpy as np
from matplotlib.ticker import LogLocator, ScalarFormatter
import matplotlib as mpl
import matplotlib.font_manager as fm
import matplotlib.ticker as ticker

# # Download and register the Times New Roman font
!wget -O TimesNewRoman.ttf https://github.com/justrajdeep/fonts/raw/master/Times%20New%20Roman.ttf
font_dirs = ["/content/"]
font_files = fm.findSystemFonts(fontpaths=font_dirs, fontext='ttf')
for font_file in font_files:
    if 'TimesNewRoman' in font_file:
        print(font_file)
    fm.fontManager.addfont(font_file)

# Font setup
plt.rcParams['font.family'] = 'Times New Roman'
plt.rcParams['font.size'] = 32


# -------------------------
# Data Setup
# -------------------------
# Times in ms. Organized by table -> scale factor -> PIM, DuckDB, C++ (in that order).
# For clarity, I'm storing them separately and then merging.
# You can also store them in a single 3D array if you prefer.

# 3 scale factors: SF1, SF10, SF100
scale_labels = ['SF1', 'SF10', 'SF100']
# 3 tables
table_labels = ['Customer', 'Part', 'Supplier']

# PIM latencies [table][scale]
pim_latencies = [
    [743997.5/1000,   8472425/1000,   74653817.5/1000],   # Customer
    [1076788.75/1000, 12407645/1000,  101314633.125/1000], # Part
    [968215/1000,     9333137.5/1000, 101365995/1000]      # Supplier
]

# DuckDB latencies [table][scale]
# Post-review: re-measured with no numactl (both sockets, 112 threads), DuckDB v1.1.3,
# local disk, COPY (...) TO '/dev/null', median of 3 runs (SF100: 2).
# Source: results/fig7_free.csv. Published values were
#   [328, 4726, 46291], [436, 5473, 55760], [302, 4274, 51596] ms.
duckdb_latencies = [
    [414000000/1000, 1791000000/1000, 13753000000/1000],  # Customer
    [541000000/1000, 2012000000/1000, 17346000000/1000],  # Part
    [351000000/1000, 1432000000/1000, 15247000000/1000]   # Supplier
]

# C++ latencies [table][scale]
cpp_latencies = [
    [12515100000/1000, 131611000000/1000, 1383542200000/1000],  # Customer
    [18305200000/1000, 173763000000/1000, 1868384400000/1000],  # Part
    [15460800000/1000, 149114000000/1000, 1722059700000/1000]   # Supplier
]

pim_latencies = np.array(pim_latencies)
duckdb_latencies = np.array(duckdb_latencies)
cpp_latencies = np.array(cpp_latencies)

# Speedups: DuckDB/PIM, C++/PIM
duckdb_speedup = duckdb_latencies / pim_latencies
cpp_speedup    = cpp_latencies / duckdb_latencies

# -------------------------
# Plot Setup
# -------------------------
fig, (ax_time, ax_speedup) = plt.subplots(2, 1, figsize=(20, 8), sharex=False)

# We have 3 bars in each sub-group (PIM, DuckDB, C++).
# We have 3 scale factors in each group (SF1, SF10, SF100).
# We have 3 groups total (Customer, Part, Supplier).

bar_width = 0.18
bar_spacing = 0.02  # spacing between the bars in each sub-group
sf_group_spacing = 0.08  # extra horizontal spacing after each scale factor sub-group
table_group_spacing = 0.3  # extra spacing between tables
num_sf = len(scale_labels)   # 3
num_backends = 3            # PIM, DuckDB, C++

colors = ['green', 'lightblue', 'darkred']   # PIM, DuckDB, C++
hatches = ['///', '', '']                    # hatching for PIM, none for others

# -------------------------
# 1) Top Subplot: Execution Times
# -------------------------

# We'll create x-positions grouped by table (along the x-axis), and within each table
# there are scale factors, each sub-group having 3 bars (PIM, DuckDB, C++).
x_positions_time = []
latency_data_flat = []

# We'll define a function to compute the x-positions for the time bars
def compute_time_x_positions():
    group_positions = []  # will hold 1 group for each table
    # total sub-group width for each scale factor = (num_backends * bar_width) + (num_backends-1)*bar_spacing
    sub_group_width = num_backends*bar_width + (num_backends-1)*bar_spacing
    # each table has num_sf sub-groups, plus some spacing
    for t in range(len(table_labels)):
        table_start = t * (num_sf * (sub_group_width + sf_group_spacing) + table_group_spacing)
        # now for each SF:
        for s in range(num_sf):
            sub_group_start = table_start + s*(sub_group_width + sf_group_spacing)
            # 3 bars per sub-group
            bar_x = []
            for b in range(num_backends):
                bar_x.append(sub_group_start + b*(bar_width + bar_spacing))
            group_positions.append(bar_x)
    return group_positions

x_positions_time = compute_time_x_positions()

# Flatten data in the same order:
#   for each table (t) -> for each scale factor (s) -> bars: PIM, DuckDB, C++
for t in range(len(table_labels)):
    for s in range(num_sf):
        latency_data_flat.append(pim_latencies[t, s])
        latency_data_flat.append(duckdb_latencies[t, s])
        latency_data_flat.append(cpp_latencies[t, s])

x_positions_time_flat = [val for grp in x_positions_time for val in grp]

# Plot the time bars
for i, (xpos, height) in enumerate(zip(x_positions_time_flat, latency_data_flat)):
    ax_time.bar(xpos, height, width=bar_width,
                color=colors[i % num_backends],
                hatch=hatches[i % num_backends],
                edgecolor='black')

# Y-axis is log scale
ax_time.set_yscale('log')
ax_time.yaxis.set_major_locator(ticker.LogLocator(base=10.0, numticks=12))
ax_time.yaxis.set_minor_locator(ticker.LogLocator(base=10.0, subs='auto', numticks=10))
ax_time.yaxis.set_minor_formatter(ticker.NullFormatter())
ax_time.set_ylabel("Execution Time (µs)", fontsize=30)
ax_time.grid(True, axis='y', linestyle='--', alpha=0.7)

# We'll compute x-ticks (center each table)
time_ticks = []
time_tick_labels = []
sub_group_width = num_backends*bar_width + (num_backends-1)*bar_spacing
for t in range(len(table_labels)):
    # table_start is same calculation as above
    table_start = t * (num_sf * (sub_group_width + sf_group_spacing) + table_group_spacing)
    # center of the entire chunk for that table
    chunk_width = num_sf*(sub_group_width + sf_group_spacing) - sf_group_spacing
    center = table_start + chunk_width / 2
    time_ticks.append(center)
    time_tick_labels.append(table_labels[t])
ax_time.set_xticks(time_ticks)
ax_time.set_xticklabels(time_tick_labels, fontsize=25)

ax_time.set_ylim(10, 20e9)

# Next, add text above each sub-group for the scale factor labels
for idx, (bar_group) in enumerate(x_positions_time):
    # bar_group is a 3-element list for the 3 bars
    # we also know table = idx // num_sf, sf = idx % num_sf
    table_idx = idx // num_sf
    sf_idx = idx % num_sf
    # pick the middle bar as the anchor
    label_x = bar_group[1]
    # place SF label near top
    ax_time.text(label_x, 0.87, scale_labels[sf_idx],
                 ha='center', va='bottom',
                 fontsize=30, transform=ax_time.get_xaxis_transform())

# Legend for top subgraph (time)
legend_elements_time = [
    Patch(facecolor='green', hatch='///', edgecolor='black', label='PIM'),
    Patch(facecolor='lightblue', edgecolor='black', label='DuckDB'),
    Patch(facecolor='darkred', edgecolor='black', label='C++')
]
ax_time.legend(handles=legend_elements_time, loc='lower center', fontsize=27,ncol=3, bbox_to_anchor=(0.5, -0.29),
    labelspacing=0.1,   # vertical space between labels
    columnspacing=0.3,  # horizontal space between columns
    borderpad=0.01)       # space inside legend box)


# -------------------------
# 2) Bottom Subplot: Speedups
# -------------------------
# We'll do 2 bars in each sub-sub-group: (DuckDB / PIM), (C++ / PIM)
speedup_colors = ['rebeccapurple', 'mediumorchid']
speedup_hatches = ['///', '']
num_speedup_bars = 2

def compute_speedup_positions():
    group_positions = []
    sub_group_width_sp = num_speedup_bars*bar_width + (num_speedup_bars-1)*bar_spacing
    for t in range(len(table_labels)):
        table_start = t * (num_sf*(sub_group_width_sp + sf_group_spacing) + table_group_spacing)
        for s in range(num_sf):
            sub_group_start = table_start + s*(sub_group_width_sp + sf_group_spacing)
            bar_x = []
            for b in range(num_speedup_bars):
                bar_x.append(sub_group_start + b*(bar_width + bar_spacing))
            group_positions.append(bar_x)
    return group_positions

x_positions_speedup = compute_speedup_positions()
x_positions_speedup_flat = [v for grp in x_positions_speedup for v in grp]

speedup_data = []
for t in range(len(table_labels)):
    for s in range(num_sf):
        speedup_data.append(duckdb_speedup[t, s])
        speedup_data.append(cpp_speedup[t, s])

# Plot speedup bars
for i, (xpos, val) in enumerate(zip(x_positions_speedup_flat, speedup_data)):
    ax_speedup.bar(xpos, val, width=bar_width,
                   color=speedup_colors[i % 2],
                   hatch=speedup_hatches[i % 2],
                   edgecolor='black')

# Y-axis log scale
ax_speedup.set_yscale('log')
ax_speedup.yaxis.set_major_locator(ticker.LogLocator(base=10.0, numticks=12))
ax_speedup.yaxis.set_minor_locator(ticker.LogLocator(base=10.0, subs='auto', numticks=10))
ax_speedup.yaxis.set_minor_formatter(ticker.NullFormatter())
ax_speedup.set_ylabel("Speedup", fontsize=30)
ax_speedup.grid(True, axis='y', linestyle='--', alpha=0.7)

# X ticks: same approach as top for grouping
speedup_ticks = []
speedup_tick_labels = []
sub_group_width_sp = num_speedup_bars*bar_width + (num_speedup_bars-1)*bar_spacing
for t in range(len(table_labels)):
    table_start = t * (num_sf*(sub_group_width_sp + sf_group_spacing) + table_group_spacing)
    chunk_width = num_sf*(sub_group_width_sp + sf_group_spacing) - sf_group_spacing
    center = table_start + chunk_width / 2
    speedup_ticks.append(center)
    speedup_tick_labels.append(table_labels[t])

ax_speedup.set_ylim(10, 2000)


ax_speedup.set_xticks(speedup_ticks)
ax_speedup.set_xticklabels(speedup_tick_labels, fontsize=27)
# Automatically choose appropriate log ticks within your data range
ax_speedup.yaxis.set_major_locator(ticker.LogLocator(base=10, numticks=7))
ax_speedup.yaxis.set_minor_locator(ticker.LogLocator(base=10.0, subs='auto', numticks=10))

# Scale factors on top of each sub-group
for idx, bar_group in enumerate(x_positions_speedup):
    table_idx = idx // num_sf
    sf_idx = idx % num_sf
    label_x = bar_group[0] + (bar_group[-1] - bar_group[0]) / 2
    ax_speedup.text(label_x, 0.87, scale_labels[sf_idx],
                    ha='center', va='bottom',
                    fontsize=30, transform=ax_speedup.get_xaxis_transform())

# Legend for speedup
legend_elements_speedup = [
    Patch(facecolor='rebeccapurple', hatch='///', edgecolor='black', label='DuckDB / PIM'),
    Patch(facecolor='mediumorchid', edgecolor='black', label='C++ / DuckDB')
]
ax_speedup.legend(handles=legend_elements_speedup, loc='lower center', fontsize=27,ncol=2,    bbox_to_anchor=(0.5, -0.29),
    labelspacing=0.1,   # vertical space between labels
    columnspacing=0.3,  # horizontal space between columns
    borderpad=0.01 )      # space inside legend box)

# Adjust subplot spacing
plt.subplots_adjust(hspace=0.25, bottom=0.08, top=0.95)
plt.show()
