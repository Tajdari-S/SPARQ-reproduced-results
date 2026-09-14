# Figures with the post-review GPU baseline

Figure 10 and the GPU speedup figure, redrawn with the corrected GPU latencies
(median of three runs, [`../gpu/results/gpu_uniform_results.csv`](../gpu/results/gpu_uniform_results.csv)).
The SPARQ and CPU values are unchanged.

```bash
python3 Fig10.py              # -> join_latency_ns_to_ms_grouped_style.png
python3 GPUJOINSEPPEDUP.py    # -> join_improvements_grouped_style.png
```

| file | change against the original |
|---|---|
| `Fig10.py` | the four `'GPU'` arrays only (from `figures_generation/Fig10.py` in the full artifact) |
| `GPUJOINSEPPEDUP.py` | speedups computed from one latency table per device instead of hard-coded ratios; GPU latencies updated |

## Effect

PIM/CPU is unchanged. PIM/GPU and GPU/CPU move:

| | PIM/GPU before | PIM/GPU after | GPU/CPU before | GPU/CPU after |
|---|---:|---:|---:|---:|
| SF1 | 76-228x | 118-221x | 2.2-6.2x | 1.8-4.0x |
| SF10 | 148-255x | 126-223x | 2.1-3.0x | 2.5-3.7x |
| SF100 | 525-871x | 581-1019x | 0.90-1.15x | 0.70-0.98x |

At SF100 the GPU is now slower than DuckDB on all four joins, where before it was
faster on customer and part.

## Open: CPU values disagree between figure scripts

- **Customer SF100:** `GPUJOINSEPPEDUP.py` uses 74,739 ms; `Fig7.py` and `Fig10.py`
  use 46,291 ms. The script keeps 74,739 ms and exposes it as `CUSTOMER_SF100_CPU`.
  With 46,291 ms, customer SF100 PIM/CPU falls from 1001x to 620x and GPU/CPU from
  0.98x to 0.61x, and the PIM/CPU range becomes 405-662x instead of 405-1001x.
- **SF1 customer and supplier:** `Fig10.py` and `GPUJOINSEPPEDUP.py` use 377 and
  455 ms; `Fig7.py` uses 328 and 302 ms.
