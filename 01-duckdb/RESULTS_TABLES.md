# Re-measured results, both DuckDB versions

Every latency below was measured with the database on **local disk**. The plotted values for Figures 8 and 9 were measured with it on NFS, which inflates a cold query - see [`NOTES.md`](NOTES.md) #0.


## 1. Version comparison — v0.8.0 against v1.1.3

| Figure | Parameter | v0.8.0 (ms) | v1.1.3 (ms) | Verdict |
|---|---|---:|---:|---|
| Fig 7 | customer SF1 | 488 | 405 | v1.1.3 1.21x faster |
| Fig 7 | customer SF10 | 1,980 | 3,212 | v0.8.0 1.62x faster |
| Fig 7 | customer SF100 | 38,712 | 28,156 | v1.1.3 1.37x faster |
| Fig 7 | part SF1 | 706 | 549 | v1.1.3 1.29x faster |
| Fig 7 | part SF10 | 4,776 | 3,592 | v1.1.3 1.33x faster |
| Fig 7 | part SF100 | 41,794 | 32,204 | v1.1.3 1.30x faster |
| Fig 7 | supplier SF1 | 406 | 348 | v1.1.3 1.17x faster |
| Fig 7 | supplier SF10 | 3,540 | 2,921 | v1.1.3 1.21x faster |
| Fig 7 | supplier SF100 | 38,650 | 29,406 | v1.1.3 1.31x faster |
| Fig 8 | self-join SF1 | 146 | 128 | v1.1.3 1.14x faster |
| Fig 8 | self-join SF10 | 980 | 892 | v1.1.3 1.10x faster |
| Fig 8 | self-join SF100 | 14,810 | 11,000 | v1.1.3 1.35x faster |
| Fig 9 | distinct 6-col total SF1 | 402 | 170 | v1.1.3 2.35x faster |
| Fig 9 | distinct 6-col total SF10 | 2,366 | 1,249 | v1.1.3 1.89x faster |
| Fig 9 | distinct 6-col total SF100 | 18,374 | 13,796 | v1.1.3 1.33x faster |
| Fig 9 | where 6-col total SF1 | 318 | 264 | v1.1.3 1.21x faster |
| Fig 9 | where 6-col total SF10 | 3,126 | 1,987 | v1.1.3 1.57x faster |
| Fig 9 | where 6-col total SF100 | 27,582 | 16,224 | v1.1.3 1.70x faster |
| Fig 10 | date SF1 | 563 | 456 | v1.1.3 1.23x faster |
| Fig 10 | date SF10 | 4,740 | 4,490 | v1.1.3 1.06x faster |
| Fig 10 | date SF100 | 44,912 | 36,308 | v1.1.3 1.24x faster |
| Fig 11 | Q1.1 cold | 513 | 479 | v1.1.3 1.07x faster |
| Fig 11 | Q1.1 warm | 221 | 147 | v1.1.3 1.50x faster |
| Fig 11 | Q1.2 cold | 447 | 360 | v1.1.3 1.24x faster |
| Fig 11 | Q1.2 warm | 232 | 94 | v1.1.3 2.47x faster |
| Fig 11 | Q1.3 cold | 365 | 359 | equivalent |
| Fig 11 | Q1.3 warm | 233 | 96 | v1.1.3 2.43x faster |
| Fig 11 | Q2.1 cold | 448 | 874 | v0.8.0 1.95x faster |
| Fig 11 | Q2.1 warm | 193 | 328 | v0.8.0 1.70x faster |
| Fig 11 | Q2.2 cold | 357 | 625 | v0.8.0 1.75x faster |
| Fig 11 | Q2.2 warm | 194 | 284 | v0.8.0 1.47x faster |
| Fig 11 | Q2.3 cold | 233 | 695 | v0.8.0 2.98x faster |
| Fig 11 | Q2.3 warm | 121 | 302 | v0.8.0 2.49x faster |
| Fig 11 | Q3.1 cold | 848 | 1,688 | v0.8.0 1.99x faster |
| Fig 11 | Q3.1 warm | 512 | 758 | v0.8.0 1.48x faster |
| Fig 11 | Q3.2 cold | 446 | 1,034 | v0.8.0 2.32x faster |
| Fig 11 | Q3.2 warm | 214 | 513 | v0.8.0 2.39x faster |
| Fig 11 | Q3.3 cold | 360 | 1,060 | v0.8.0 2.95x faster |
| Fig 11 | Q3.3 warm | 124 | 523 | v0.8.0 4.22x faster |
| Fig 11 | Q3.4 cold | 239 | 472 | v0.8.0 1.98x faster |
| Fig 11 | Q3.4 warm | 118 | 167 | v0.8.0 1.41x faster |
| Fig 11 | Q4.1 cold | 766 | 1,125 | v0.8.0 1.47x faster |
| Fig 11 | Q4.1 warm | 539 | 671 | v0.8.0 1.24x faster |
| Fig 11 | Q4.2 cold | 731 | 1,095 | v0.8.0 1.50x faster |
| Fig 11 | Q4.2 warm | 437 | 520 | v0.8.0 1.19x faster |
| Fig 11 | Q4.3 cold | 633 | 544 | v1.1.3 1.16x faster |
| Fig 11 | Q4.3 warm | 258 | 377 | v0.8.0 1.46x faster |

## 2. How different from the plotted values

Each figure is compared against the binary it was plotted with: v0.8.0 for Figure 8, v1.1.3 for the rest.

| Figure | Parameter | plotted (ms) | reproduced (ms) | reproduced/plotted |
|---|---|---:|---:|---:|
| Fig 7 | customer SF1 | 328 | 405 | 1.23x |
| Fig 7 | customer SF10 | 4,726 | 3,212 | 0.68x |
| Fig 7 | customer SF100 | 46,291 | 28,156 | 0.61x |
| Fig 7 | part SF1 | 436 | 549 | 1.26x |
| Fig 7 | part SF10 | 5,473 | 3,592 | 0.66x |
| Fig 7 | part SF100 | 55,760 | 32,204 | 0.58x |
| Fig 7 | supplier SF1 | 302 | 348 | 1.15x |
| Fig 7 | supplier SF10 | 4,274 | 2,921 | 0.68x |
| Fig 7 | supplier SF100 | 51,596 | 29,406 | 0.57x |
| Fig 8 | self-join SF1 | 249 | 146 | 0.59x |
| Fig 8 | self-join SF10 | 2,071 | 980 | 0.47x |
| Fig 8 | self-join SF100 | 20,929 | 14,810 | 0.71x |
| Fig 9 | distinct 6-col SF1 | 981 | 170 | 0.17x |
| Fig 9 | distinct 6-col SF10 | 8,190 | 1,249 | 0.15x |
| Fig 9 | distinct 6-col SF100 | 101,760 | 13,796 | 0.14x |
| Fig 9 | where 6-col SF1 | 6,336 | 264 | 0.04x |
| Fig 9 | where 6-col SF10 | 44,406 | 1,987 | 0.04x |
| Fig 9 | where 6-col SF100 | 406,591 | 16,224 | 0.04x |
| Fig 10 | date SF1 | 425 | 456 | 1.07x |
| Fig 10 | date SF10 | 4,174 | 4,490 | 1.08x |
| Fig 10 | date SF100 | 50,596 | 36,308 | 0.72x |
| Fig 11 | Q1.1 cold | 662 | 479 | 0.72x |
| Fig 11 | Q1.1 warm | 148 | 147 | 1.00x |
| Fig 11 | Q1.2 cold | 351 | 360 | 1.03x |
| Fig 11 | Q1.2 warm | 95 | 94 | 0.99x |
| Fig 11 | Q1.3 cold | 349 | 359 | 1.03x |
| Fig 11 | Q1.3 warm | 104 | 96 | 0.92x |
| Fig 11 | Q2.1 cold | 851 | 874 | 1.03x |
| Fig 11 | Q2.1 warm | 214 | 328 | 1.54x |
| Fig 11 | Q2.2 cold | 881 | 625 | 0.71x |
| Fig 11 | Q2.2 warm | 183 | 284 | 1.55x |
| Fig 11 | Q2.3 cold | 565 | 695 | 1.23x |
| Fig 11 | Q2.3 warm | 169 | 302 | 1.79x |
| Fig 11 | Q3.1 cold | 1,051 | 1,688 | 1.61x |
| Fig 11 | Q3.1 warm | 422 | 758 | 1.79x |
| Fig 11 | Q3.2 cold | 1,148 | 1,034 | 0.90x |
| Fig 11 | Q3.2 warm | 276 | 513 | 1.86x |
| Fig 11 | Q3.3 cold | 719 | 1,060 | 1.47x |
| Fig 11 | Q3.3 warm | 305 | 523 | 1.71x |
| Fig 11 | Q3.4 cold | 509 | 472 | 0.93x |
| Fig 11 | Q3.4 warm | 190 | 167 | 0.88x |
| Fig 11 | Q4.1 cold | 1,241 | 1,125 | 0.91x |
| Fig 11 | Q4.1 warm | 422 | 671 | 1.59x |
| Fig 11 | Q4.2 cold | 1,272 | 1,095 | 0.86x |
| Fig 11 | Q4.2 warm | 370 | 520 | 1.41x |
| Fig 11 | Q4.3 cold | 1,063 | 544 | 0.51x |
| Fig 11 | Q4.3 warm | 243 | 377 | 1.55x |

## Not re-measured

* **Figure 2** needs Intel Advisor; **Figure 3** needs the instrumented v1.4.0-dev build. Neither is a plain latency measurement.

* **Figure 10's GPU series** needs RAPIDS and an A100. Note also that `BestGPU.py` materialises lazily inside its timed region, so it includes CSV parsing that the DuckDB bars exclude - see NOTES.md #7b.

* **Figure 1** shares Figure 11's data.

