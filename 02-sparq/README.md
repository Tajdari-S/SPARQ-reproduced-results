# 02 — SPARQ latency (PIM simulation)

Reproduces the SPARQ bars of Figure 7 at SF1. **Self-contained**: the probe
traces and the simulator config ship with the artifact, so this needs no
dataset, no GPU and no network.

```bash
bash ./reproduce.sh
```

~25 minutes, ~2 GB scratch in `/tmp`.

## What to expect

The simulation is **deterministic**: repeated runs of the same trace through the
same configuration produce identical cycle counts, so there is no run-to-run
variance to average out.

At SF1 the reproduced join latencies are:

| join | trace | completion cycle | latency |
|---|---|---:|---:|
| customer | C2 (`custkey`) | 971,000 | 606,875 ns |
| part | C3 (`partkey`) | 1,574,558 | 984,099 ns |
| supplier | C4 (`suppkey`) | 849,117 | 530,698 ns |

Same ordering and magnitude as the published Figure 7 values, within about a
factor of two. Absolute latency depends on the simulator configuration — the
`.ini` that produced these ships in `config/`, and `tCCD_S`, `tCCD_L`, the rank
count and `tCMP` all move it. Use the shipped configuration to compare against
these numbers.

Raw: [`results/sparq_latency_reproduction.csv`](results/).

## Step by step

### 1. Build the simulator — with `CMD_TRACE` on

```bash
cd SPARQ/sparq-sim/DRAMsim3
mkdir -p build_cmdtrace && cd build_cmdtrace
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMD_TRACE=ON
make -j$(nproc)
```

**`-DCMD_TRACE` is required, not optional.** The latency is read from
`dramsim3ch_<n>cmd.trace`, and that file is written only when the simulator is
compiled with this flag — it is a compile-time `#ifdef`, not a config setting. A
default build runs fine, writes `dramsim3.txt` and the JSON, never creates the
command trace, and the aggregation step then finds nothing and reports no error.

You should see this line when it runs:

```
Command Trace write to ./dramsim3ch_0cmd.trace
```

### 2. Unpack a trace

```bash
zcat 02-sparq/traces/lineorder_sf1_C2_x16.txt.gz > trace.txt
wc -l trace.txt        # 750000
```

Format is one memory request per line — address, operation, issue cycle:

```
0x10660 READ 0
0x18660 READ 0
```

`C<n>` is the `lineorder` column the probe key comes from: **C2 = `custkey`
(customer join), C3 = `partkey` (part), C4 = `suppkey` (supplier)**.

### 3. Simulate, from an empty working directory

```bash
mkdir -p work && cd work
../SPARQ/sparq-sim/DRAMsim3/build_cmdtrace/dramsim3main \
    ../02-sparq/config/SPARQ_DDR4_8Gb_x16_3200.ini \
    -c 999990000 \
    -t ../trace.txt
```

Config: `channels=1, rows=65536, columns=1024, BL=2, tCCD_S=1, tCCD_L=2, tCMP=0`.

Run each join in its own directory — the command trace is written to the CWD and
would otherwise be overwritten.

### 4. Read the completion cycle and convert

```bash
last_read_cycle=$(tac dramsim3ch_0cmd.trace | grep -m1 "read" | awk '{print $1}')
python3 -c "print($last_read_cycle * 0.625)"
```

```
latency (ns) = last_read_cycle x tCK          tCK = 0.625 ns for DDR4-3200
```

Worked example: `971000 x 0.625 = 606,875 ns`.

**Do not use `num_cycles` from `dramsim3.txt`.** `-c 999990000` is a cycle cap,
not a stop condition — the simulator runs to that limit whatever the trace
length, so `num_cycles` always reads 999,990,000.

**Do not use `average_read_latency` either.** It is a reordering-sensitive
per-request mean and moves non-monotonically; on the bundled trace it reads
391.8 / 419.1 / 364.8 / 350.6 cycles for tCMP 0/1/2/4 — *lower* than baseline at
2 and 4 — while the completion cycle rises monotonically
(216,235 / 229,146 / 240,117 / 248,455).

### 5. Repeat for the other two joins

Delete `dramsim3ch_0cmd.trace` between runs; each is roughly 1 GB.

## Trace length: one channel of eight

Each trace holds 750,000 probes at SF1 while `lineorder` has 6,001,171 rows.
That is **the relation divided by the eight PIM channels**, matching to within
0.02% at every scale factor:

| | rows | / 8 channels | trace limit |
|---|---:|---:|---:|
| SF1 | 6,001,171 | 750,146 | 750,000 |
| SF10 | 59,986,217 | 7,498,277 | 7,500,000 |
| SF100 | 600,037,902 | 75,004,738 | 75,000,000 |

The channels probe concurrently, so one channel's completion time is the join's
completion time. The config sets `channels = 1` because each trace *is* one
channel. **The latency must not be scaled by 8** — that would describe eight
channels running in series. `limit` is set in the generator at
`SPARQ/experiments/addrgen/.../8channel/morebankchange/Oldbetterrankdistribution_x16.py`,
and `10channel/` and `16channel/` hold the same sweep at other channel counts.

## Regenerating the traces (optional)

Only needed for SF10/SF100 or a different channel count. Requires the
dictionary-encoded `lineorder` (`/p/pd/pim/lineordersf{1,10,100}.tbl`):

```bash
python3 SPARQ/experiments/addrgen/newarchitecture/test_with_communication_to_cpu/\
8channel/morebankchange/Oldbetterrankdistribution_x16.py
```

Writes one trace per `lineorder` column (C0–C4) per scale factor.
