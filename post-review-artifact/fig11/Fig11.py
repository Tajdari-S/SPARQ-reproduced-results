import matplotlib.pyplot as plt
import numpy as np
import matplotlib as mpl
import matplotlib.font_manager as fm
from scipy.stats import gmean
from matplotlib.patches import Patch

# # Download and register the Times New Roman font
!wget -O TimesNewRoman.ttf https://github.com/justrajdeep/fonts/raw/master/Times%20New%20Roman.ttf
font_dirs = ["/content/"]
font_files = fm.findSystemFonts(fontpaths=font_dirs, fontext='ttf')
for font_file in font_files:
    if 'TimesNewRoman' in font_file:
        print(font_file)
    fm.fontManager.addfont(font_file)

# Set font parameters (if needed)
plt.rcParams['font.family'] = 'Times New Roman'
plt.rcParams['font.size'] = 28

# Query labels
queries = [
    'Q1.1', 'Q1.2', 'Q1.3', 'Q2.1', 'Q2.2', 'Q2.3',
    'Q3.1', 'Q3.2', 'Q3.3', 'Q3.4', 'Q4.1', 'Q4.2', 'Q4.3'
]

# Add GeoMean label at the end
queries.append("GM")

x = np.arange(len(queries))
bar_width = 0.21
offsets = [-1.7, -0.6, 0.6, 1.7]

# Execution times (s)
# post-review, DuckDB v1.1.3, 2026-09-16 (fig11/README.md):
#   duckdb_*: unbound run; duckdb_*_join from that run
#   jspim_*: bound DuckDB (numactl --membind=1) - bound DuckDB join + SPARQ join
duckdb_cold = np.array([
    0.556226813, 0.350063259, 0.358500045,
    1.08299592, 0.844342056, 0.75547516,
    1.003353241, 0.919730564, 0.688652927,
    0.504462568, 1.241161303, 1.175122311,
    1.000316924
])
duckdb_warm = np.array([
    0.14373520325, 0.10483675675, 0.11099819,
    0.21288334825, 0.1894803215, 0.43609607499999997,
    0.45587125824999997, 0.29302272575, 0.5759796655,
    0.1810715395, 0.46393275775, 0.41968706925,
    0.4240769335
])
jspim_cold = np.array([
    0.2278056230229188, 0.15142534013780848, 0.12888848115454474,
    0.14513280134683326, 0.10487122005778356, 0.08771426210605643,
    0.25352744195257526, 0.07648015798802274, 0.1399274954543264,
    0.014288607730049694, 0.15232124225571378, 0.10938869861849257,
    0.025018375371302103
])
jspim_warm = np.array([
    0.14659908742817726, 0.08965132050068104, 0.10836604582297223,
    0.09562718626838103, 0.08969786911392923, 0.08451836843195384,
    0.22187277871971853, 0.06447920308270519, 0.12871464196598045,
    0.006326228131904142, 0.17686109578015916, 0.08521841119152315,
    0.02792617193711474
])

# Real join latencies
duckdb_cold_join = np.array([
    0.12443530526975022, 0.03576039167280478, 0.0354344792818019,
    1.061790868934553, 0.8288909516394827, 0.7478863512265922,
    0.8096289501391145, 0.9007803401143825, 0.6714079841335656,
    0.49525917509387735, 1.2109922346732953, 1.1499905770722074,
    0.9970505559714836
])
duckdb_warm_join = np.array([
    0.019498646476405847, 0.008369794816425661, 0.008491134737406215,
    0.2032712323891373, 0.18369465642132585, 0.42285901891700417,
    0.3773209925534432, 0.28491713551927006, 0.5165271793249825,
    0.17770796406737607, 0.44357523721685604, 0.39492176504670995,
    0.4177789586028933
])
jspim_cold_join = np.array([
    0.0015175297731125,0.0000536332252614584, 0.0000521960648895834,
    0.0859208417344857, 0.0827987392046108, 0.0820058833645087,
    0.139958143301651,0.0584083251703931, 0.125310021514597,
    0.00177243414969974, 0.114090822792311, 0.0385300965176815,0.0205878913079511
])
jspim_warm_join = np.array([
    0.0015175297731125,0.0000536332252614584, 0.0000521960648895834,
    0.0859208417344857, 0.0827987392046108, 0.0820058833645087,
    0.139958143301651,0.0584083251703931, 0.125310021514597,
    0.00177243414969974, 0.114090822792311, 0.0385300965176815,0.0205878913079511
]
)
# Calculate non-join time
duckdb_cold_rest = duckdb_cold - duckdb_cold_join
duckdb_warm_rest = duckdb_warm - duckdb_warm_join
jspim_cold_rest = jspim_cold - jspim_cold_join
jspim_warm_rest = jspim_warm - jspim_warm_join

# Compute speedups
cold_speedup = duckdb_cold / jspim_cold
warm_speedup = duckdb_warm / jspim_warm

# Append geomean values
def append_geomean(arr1, arr2):
    return np.append(arr1, gmean(arr1)), np.append(arr2, gmean(arr2))

duckdb_cold, duckdb_cold_join = append_geomean(duckdb_cold, duckdb_cold_join)
duckdb_warm, duckdb_warm_join = append_geomean(duckdb_warm, duckdb_warm_join)
jspim_cold, jspim_cold_join = append_geomean(jspim_cold, jspim_cold_join)
jspim_warm, jspim_warm_join = append_geomean(jspim_warm, jspim_warm_join)
cold_speedup = np.append(cold_speedup, gmean(cold_speedup))
warm_speedup = np.append(warm_speedup, gmean(warm_speedup))

# Recompute non-join
duckdb_cold_rest = duckdb_cold - duckdb_cold_join
duckdb_warm_rest = duckdb_warm - duckdb_warm_join
jspim_cold_rest = jspim_cold - jspim_cold_join
jspim_warm_rest = jspim_warm - jspim_warm_join

# Speedup bar positions
cold_x = [i - 0.25/2 for i in range(len(queries))]
warm_x = [i + 0.25/2 for i in range(len(queries))]

# Plotting
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(16, 9))

for i in range(1, len(queries)):
    ax1.axvline(i - 0.5, color='gray', linestyle='--', linewidth=1)
    ax2.axvline(i - 0.5, color='gray', linestyle='--', linewidth=1)


# Execution time bars
for i in range(len(queries)):
    xi = x[i]
    ax1.bar(xi + offsets[0]*bar_width, duckdb_cold[i], width=bar_width, color='lightblue', edgecolor='black')
    ax1.bar(xi + offsets[0]*bar_width, duckdb_cold_join[i], width=bar_width, color='lightblue', edgecolor='black', hatch='////')

    ax1.bar(xi + offsets[2]*bar_width, duckdb_warm[i], width=bar_width, color='royalblue', edgecolor='black')
    ax1.bar(xi + offsets[2]*bar_width, duckdb_warm_join[i], width=bar_width, color='royalblue', edgecolor='black', hatch='////')

    ax1.bar(xi + offsets[1]*bar_width, jspim_cold[i], width=bar_width, color='lightgreen', edgecolor='black')
    ax1.bar(xi + offsets[1]*bar_width, jspim_cold_join[i], width=bar_width, color='lightgreen', edgecolor='black', hatch='////')

    ax1.bar(xi + offsets[3]*bar_width, jspim_warm[i], width=bar_width, color='green', edgecolor='black')
    ax1.bar(xi + offsets[3]*bar_width, jspim_warm_join[i], width=bar_width, color='green', edgecolor='black', hatch='////')

# Speedup bars
ax2.bar(cold_x, cold_speedup, width=bar_width, color='rebeccapurple', edgecolor='black', label="Cold Speedup")
ax2.bar(warm_x, warm_speedup, width=bar_width, color='mediumorchid', edgecolor='black', label="Warm Speedup")

# Axis settings
ax1.set_xticks(x)
#ax1.set_xticklabels([])  # Hide on top
ax1.set_xticklabels(queries, ha='center')
ax1.set_ylabel('Execution Time (s)')

ax2.set_xticks(x)
ax2.set_xticklabels(queries, ha='center')
ax2.set_xlabel('SSB Queries')
ax2.set_ylabel("Speedup")

# Legends
legend_elements = [
    Patch(facecolor='lightblue', edgecolor='black', label='DuckDB Cold'),
    Patch(facecolor='lightgreen', edgecolor='black', label='PIM Cold'),
    Patch(facecolor='royalblue', edgecolor='black', label='DuckDB Warm'),
    Patch(facecolor='green', edgecolor='black', label='PIM Warm'),
    Patch(facecolor='white', edgecolor='black', hatch='////', label='Join'),
]
ax1.legend(handles=legend_elements, loc='upper left', fontsize=24, frameon=False, ncol=2)
ax2.legend(loc='upper left', fontsize=25, frameon=False)

# post-review: axis widened from 1-30; the new speedups run from 0.96x to 42.5x
ax2.set_ylim(bottom=0, top=45)
# Set y-ticks to cover the entire range of speedup values
ax2.yaxis.set_ticks(np.arange(0, 46, 10))
ax2.yaxis.grid(True, linestyle="--", alpha=0.7)

ax1.set_ylim(bottom=0, top=1.5)
# Set y-ticks to cover the entire range of speedup values
ax1.yaxis.set_ticks(np.arange(0, 1.5, 0.5))
ax1.yaxis.grid(True, linestyle="--", alpha=0.7)

# Add text above geomean speedup bars
ax2.text(cold_x[-1]+ 0.025, cold_speedup[-1] + 0.125, f'{cold_speedup[-1]:.1f}', ha='center', va='bottom', fontsize=25)
ax2.text(warm_x[-1]+0.12, warm_speedup[-1] + 0.125, f'{warm_speedup[-1]:.1f}', ha='center', va='bottom', fontsize=25)

# Geomean bar index
geomean_index = len(queries) - 1  # since 'GMean' is added as the last query

# Function to add text labels
def add_text_on_bar(ax, x_pos, height, label):
    ax.text(x_pos, height + 0.02 * height, f'{label:.2f}', ha='center', va='bottom', fontsize=25, fontweight='bold')

# Add labels on geomean bars
add_text_on_bar(ax1, geomean_index + offsets[0]*bar_width, duckdb_cold[-1], duckdb_cold[-1])
add_text_on_bar(ax1, geomean_index + offsets[2]*bar_width, duckdb_warm[-1], duckdb_warm[-1])
# Add text above the first 3 cold and warm speedup bars
for i in range(3):
    ax2.text(cold_x[i], cold_speedup[i] + 0.5, f'{cold_speedup[i]:.1f}', ha='center', va='bottom', fontsize=30)



# Adjust spacing between subplots
plt.subplots_adjust(hspace=-0.001)
plt.tight_layout()
plt.show()
