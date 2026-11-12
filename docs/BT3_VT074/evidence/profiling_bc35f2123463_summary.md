# C5 profiling raw-data verification

Run: `docs/BT3_VT074/evidence/profiling_bc35f2123463_run.json`; verifier exit 0.

Historical evidence unchanged. Three datasets each contain 140 batches (20 warm-up,120 measured),40 unique overlapping tasks per batch,4,800 measured +800 warm-up records. All140 persisted snapshot byte hashes match across historical/uninstrumented/instrumented runs. Nested self times reconcile exactly; duplicates/conflicts/invalid requests have no storage spans. Instrumented first commits execute four canonicalizations and three real file reads.

Instrumentation is diagnostic, never an optimization. All final baseline threshold results use uninstrumented CSV.

## historical

| Workload | Frames | Min | Mean | Median | p95 | Max | Queue mean | Service mean | Failed batches /30 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| primary | 2 | 8.618 | 30.691 | 28.812 | 54.713 | 66.158 | 29.837 | 0.854 | 0 |
| primary | 3600 | 377.005 | 3646.613 | 3464.838 | 7235.233 | 10156.880 | 3482.811 | 163.802 | 30 |
| secondary | 2 | 0.311 | 4.236 | 3.996 | 10.626 | 14.745 | 4.101 | 0.135 | 0 |
| secondary | 3600 | 96.854 | 2740.329 | 2915.314 | 4406.804 | 4931.938 | 2633.240 | 107.089 | 30 |

All times ms; nearest-rank indices37/40 and1139/1200. Full status counts, unique commits, batch wall times and per-batch statistics are in verification JSON.

## before

| Workload | Frames | Min | Mean | Median | p95 | Max | Queue mean | Service mean | Failed batches /30 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| primary | 2 | 3.168 | 7.768 | 6.575 | 12.114 | 14.319 | 7.542 | 0.226 | 0 |
| primary | 3600 | 279.961 | 2037.642 | 2014.819 | 3760.964 | 4295.831 | 1944.760 | 92.882 | 30 |
| secondary | 2 | 0.233 | 1.570 | 1.670 | 2.441 | 2.579 | 1.514 | 0.056 | 0 |
| secondary | 3600 | 69.373 | 1854.767 | 1973.107 | 2983.606 | 3125.652 | 1782.089 | 72.677 | 30 |

All times ms; nearest-rank indices37/40 and1139/1200. Full status counts, unique commits, batch wall times and per-batch statistics are in verification JSON.

## instrumented

| Workload | Frames | Min | Mean | Median | p95 | Max | Queue mean | Service mean | Failed batches /30 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| primary | 2 | 3.554 | 7.083 | 6.803 | 9.308 | 20.015 | 6.856 | 0.226 | 0 |
| primary | 3600 | 311.152 | 2184.006 | 2185.547 | 3876.540 | 4342.321 | 2083.945 | 100.061 | 30 |
| secondary | 2 | 0.276 | 2.409 | 2.567 | 3.823 | 4.126 | 2.321 | 0.088 | 0 |
| secondary | 3600 | 73.054 | 1788.960 | 1913.273 | 2911.953 | 3295.706 | 1718.545 | 70.415 | 30 |

All times ms; nearest-rank indices37/40 and1139/1200. Full status counts, unique commits, batch wall times and per-batch statistics are in verification JSON.

## Instrumented phase means

Nested inclusive times overlap; only self times may be added. Filesystem total sums fs_* self times, including nested flush once. These are elapsed wall times around CPU-side code/OS filesystem calls, not hardware CPU counters or physical disk latency.

| Workload | Frames | Status | Samples | Phase | Calls/request | Inclusive ms | Self ms |
| --- | ---: | --- | ---: | --- | ---: | ---: | ---: |
| primary | 2 | COMMITTED | 30 | candidate_build | 1.0 | 0.068733 | 0.023000 |
| primary | 2 | COMMITTED | 30 | canonical | 4.0 | 0.251700 | 0.128100 |
| primary | 2 | COMMITTED | 30 | entry_copy | 1.0 | 0.006600 | 0.006600 |
| primary | 2 | COMMITTED | 30 | envelope_copy | 1.0 | 0.006833 | 0.006833 |
| primary | 2 | COMMITTED | 30 | fingerprint | 1.0 | 0.040467 | 0.012033 |
| primary | 2 | COMMITTED | 30 | fingerprint_json | 1.0 | 0.014067 | 0.014067 |
| primary | 2 | COMMITTED | 30 | fingerprint_sha256 | 1.0 | 0.003067 | 0.003067 |
| primary | 2 | COMMITTED | 30 | fingerprint_tuple_build | 1.0 | 0.011300 | 0.011300 |
| primary | 2 | COMMITTED | 30 | frame_deep_copy | 4.0 | 0.013867 | 0.013867 |
| primary | 2 | COMMITTED | 30 | frame_validation_copy_loop | 4.0 | 0.079633 | 0.065767 |
| primary | 2 | COMMITTED | 30 | fs_flush | 1.0 | 0.107833 | 0.107833 |
| primary | 2 | COMMITTED | 30 | fs_read_bytes | 3.0 | 2.381200 | 2.381200 |
| primary | 2 | COMMITTED | 30 | fs_replace | 1.0 | 0.960233 | 0.960233 |
| primary | 2 | COMMITTED | 30 | fs_write_temp | 1.0 | 0.539633 | 0.431800 |
| primary | 2 | COMMITTED | 30 | history_ledger_update | 1.0 | 0.018767 | 0.011967 |
| primary | 2 | COMMITTED | 30 | id_validation | 5.0 | 0.042467 | 0.042467 |
| primary | 2 | COMMITTED | 30 | last_recorded_copy | 1.0 | 0.007900 | 0.007900 |
| primary | 2 | COMMITTED | 30 | ledger_lookup | 1.0 | 0.001433 | 0.001433 |
| primary | 2 | COMMITTED | 30 | replay_sanitize | 4.0 | 0.043967 | 0.043967 |
| primary | 2 | COMMITTED | 30 | request | 1.0 | 4.612900 | 0.074800 |
| primary | 2 | COMMITTED | 30 | snapshot_copy | 1.0 | 0.005633 | 0.005633 |
| primary | 2 | COMMITTED | 30 | snapshot_json_utf8 | 1.0 | 0.080400 | 0.080400 |
| primary | 2 | COMMITTED | 30 | snapshot_validation | 1.0 | 0.263567 | 0.060033 |
| primary | 2 | COMMITTED | 30 | state_publish | 1.0 | 0.009400 | 0.009400 |
| primary | 2 | COMMITTED | 30 | store_commit | 1.0 | 4.063867 | 0.102400 |
| primary | 2 | COMMITTED | 30 | summary_copy | 1.0 | 0.006800 | 0.006800 |
| primary | 2 | DUPLICATE | 1170 | canonical | 1.0 | 0.061095 | 0.027749 |
| primary | 2 | DUPLICATE | 1170 | fingerprint | 1.0 | 0.026998 | 0.008702 |
| primary | 2 | DUPLICATE | 1170 | fingerprint_json | 1.0 | 0.009426 | 0.009426 |
| primary | 2 | DUPLICATE | 1170 | fingerprint_sha256 | 1.0 | 0.002224 | 0.002224 |
| primary | 2 | DUPLICATE | 1170 | fingerprint_tuple_build | 1.0 | 0.006646 | 0.006646 |
| primary | 2 | DUPLICATE | 1170 | frame_deep_copy | 1.0 | 0.004018 | 0.004018 |
| primary | 2 | DUPLICATE | 1170 | frame_validation_copy_loop | 1.0 | 0.020902 | 0.016884 |
| primary | 2 | DUPLICATE | 1170 | id_validation | 1.0 | 0.005748 | 0.005748 |
| primary | 2 | DUPLICATE | 1170 | ledger_lookup | 1.0 | 0.001210 | 0.001210 |
| primary | 2 | DUPLICATE | 1170 | replay_sanitize | 1.0 | 0.012444 | 0.012444 |
| primary | 2 | DUPLICATE | 1170 | request | 1.0 | 0.112820 | 0.017768 |
| primary | 3600 | COMMITTED | 30 | candidate_build | 1.0 | 42.403467 | 0.093100 |
| primary | 3600 | COMMITTED | 30 | canonical | 4.0 | 190.794867 | 10.023400 |
| primary | 3600 | COMMITTED | 30 | entry_copy | 1.0 | 10.041567 | 10.041567 |
| primary | 3600 | COMMITTED | 30 | envelope_copy | 1.0 | 8.330400 | 8.330400 |
| primary | 3600 | COMMITTED | 30 | fingerprint | 1.0 | 26.038267 | 0.522367 |
| primary | 3600 | COMMITTED | 30 | fingerprint_json | 1.0 | 10.535433 | 10.535433 |
| primary | 3600 | COMMITTED | 30 | fingerprint_sha256 | 1.0 | 1.287100 | 1.287100 |
| primary | 3600 | COMMITTED | 30 | fingerprint_tuple_build | 1.0 | 13.693367 | 13.693367 |
| primary | 3600 | COMMITTED | 30 | frame_deep_copy | 4.0 | 30.317467 | 30.317467 |
| primary | 3600 | COMMITTED | 30 | frame_validation_copy_loop | 4.0 | 115.218333 | 84.900867 |
| primary | 3600 | COMMITTED | 30 | fs_flush | 1.0 | 0.088667 | 0.088667 |
| primary | 3600 | COMMITTED | 30 | fs_read_bytes | 3.0 | 10.916067 | 10.916067 |
| primary | 3600 | COMMITTED | 30 | fs_replace | 1.0 | 1.330100 | 1.330100 |
| primary | 3600 | COMMITTED | 30 | fs_write_temp | 1.0 | 1.235267 | 1.146600 |
| primary | 3600 | COMMITTED | 30 | history_ledger_update | 1.0 | 13.328100 | 3.369733 |
| primary | 3600 | COMMITTED | 30 | id_validation | 5.0 | 0.070767 | 0.070767 |
| primary | 3600 | COMMITTED | 30 | last_recorded_copy | 1.0 | 10.598933 | 10.598933 |
| primary | 3600 | COMMITTED | 30 | ledger_lookup | 1.0 | 0.003600 | 0.003600 |
| primary | 3600 | COMMITTED | 30 | replay_sanitize | 4.0 | 65.553133 | 65.553133 |
| primary | 3600 | COMMITTED | 30 | request | 1.0 | 364.773833 | 3.704433 |
| primary | 3600 | COMMITTED | 30 | snapshot_copy | 1.0 | 0.011367 | 0.011367 |
| primary | 3600 | COMMITTED | 30 | snapshot_json_utf8 | 1.0 | 80.359333 | 80.359333 |
| primary | 3600 | COMMITTED | 30 | snapshot_validation | 1.0 | 134.587667 | 6.813633 |
| primary | 3600 | COMMITTED | 30 | state_publish | 1.0 | 0.014967 | 0.014967 |
| primary | 3600 | COMMITTED | 30 | store_commit | 1.0 | 94.929833 | 1.089067 |
| primary | 3600 | COMMITTED | 30 | summary_copy | 1.0 | 9.958367 | 9.958367 |
| primary | 3600 | DUPLICATE | 1170 | canonical | 1.0 | 64.038117 | 3.404538 |
| primary | 3600 | DUPLICATE | 1170 | fingerprint | 1.0 | 25.833363 | 0.562362 |
| primary | 3600 | DUPLICATE | 1170 | fingerprint_json | 1.0 | 10.810512 | 10.810512 |
| primary | 3600 | DUPLICATE | 1170 | fingerprint_sha256 | 1.0 | 1.417954 | 1.417954 |
| primary | 3600 | DUPLICATE | 1170 | fingerprint_tuple_build | 1.0 | 13.042536 | 13.042536 |
| primary | 3600 | DUPLICATE | 1170 | frame_deep_copy | 1.0 | 10.358170 | 10.358170 |
| primary | 3600 | DUPLICATE | 1170 | frame_validation_copy_loop | 1.0 | 38.675536 | 28.317366 |
| primary | 3600 | DUPLICATE | 1170 | id_validation | 1.0 | 0.016207 | 0.016207 |
| primary | 3600 | DUPLICATE | 1170 | ledger_lookup | 1.0 | 0.005066 | 0.005066 |
| primary | 3600 | DUPLICATE | 1170 | replay_sanitize | 1.0 | 21.958044 | 21.958044 |
| primary | 3600 | DUPLICATE | 1170 | request | 1.0 | 93.269945 | 3.377192 |
| secondary | 2 | CONFLICT | 300 | canonical | 1.0 | 0.062337 | 0.028070 |
| secondary | 2 | CONFLICT | 300 | fingerprint | 1.0 | 0.026753 | 0.008720 |
| secondary | 2 | CONFLICT | 300 | fingerprint_json | 1.0 | 0.009117 | 0.009117 |
| secondary | 2 | CONFLICT | 300 | fingerprint_sha256 | 1.0 | 0.002190 | 0.002190 |
| secondary | 2 | CONFLICT | 300 | fingerprint_tuple_build | 1.0 | 0.006727 | 0.006727 |
| secondary | 2 | CONFLICT | 300 | frame_deep_copy | 1.0 | 0.004083 | 0.004083 |
| secondary | 2 | CONFLICT | 300 | frame_validation_copy_loop | 1.0 | 0.021613 | 0.017530 |
| secondary | 2 | CONFLICT | 300 | id_validation | 1.0 | 0.005733 | 0.005733 |
| secondary | 2 | CONFLICT | 300 | ledger_lookup | 1.0 | 0.001237 | 0.001237 |
| secondary | 2 | CONFLICT | 300 | replay_sanitize | 1.0 | 0.012653 | 0.012653 |
| secondary | 2 | CONFLICT | 300 | request | 1.0 | 0.111060 | 0.015000 |
| secondary | 2 | DUPLICATE | 600 | canonical | 1.0 | 0.061687 | 0.028202 |
| secondary | 2 | DUPLICATE | 600 | fingerprint | 1.0 | 0.027352 | 0.008835 |
| secondary | 2 | DUPLICATE | 600 | fingerprint_json | 1.0 | 0.009340 | 0.009340 |
| secondary | 2 | DUPLICATE | 600 | fingerprint_sha256 | 1.0 | 0.002263 | 0.002263 |
| secondary | 2 | DUPLICATE | 600 | fingerprint_tuple_build | 1.0 | 0.006913 | 0.006913 |
| secondary | 2 | DUPLICATE | 600 | frame_deep_copy | 1.0 | 0.004017 | 0.004017 |
| secondary | 2 | DUPLICATE | 600 | frame_validation_copy_loop | 1.0 | 0.021085 | 0.017068 |
| secondary | 2 | DUPLICATE | 600 | id_validation | 1.0 | 0.005893 | 0.005893 |
| secondary | 2 | DUPLICATE | 600 | ledger_lookup | 1.0 | 0.001233 | 0.001233 |
| secondary | 2 | DUPLICATE | 600 | replay_sanitize | 1.0 | 0.012400 | 0.012400 |
| secondary | 2 | DUPLICATE | 600 | request | 1.0 | 0.114848 | 0.018683 |
| secondary | 2 | INVALID_REQUEST | 300 | id_validation | 1.0 | 0.001110 | 0.001110 |
| secondary | 2 | INVALID_REQUEST | 300 | request | 1.0 | 0.006177 | 0.005067 |
| secondary | 3600 | CONFLICT | 300 | canonical | 1.0 | 64.583940 | 3.666100 |
| secondary | 3600 | CONFLICT | 300 | fingerprint | 1.0 | 26.937737 | 0.632180 |
| secondary | 3600 | CONFLICT | 300 | fingerprint_json | 1.0 | 11.379237 | 11.379237 |
| secondary | 3600 | CONFLICT | 300 | fingerprint_sha256 | 1.0 | 1.469143 | 1.469143 |
| secondary | 3600 | CONFLICT | 300 | fingerprint_tuple_build | 1.0 | 13.457177 | 13.457177 |
| secondary | 3600 | CONFLICT | 300 | frame_deep_copy | 1.0 | 10.510257 | 10.510257 |
| secondary | 3600 | CONFLICT | 300 | frame_validation_copy_loop | 1.0 | 38.841190 | 28.330933 |
| secondary | 3600 | CONFLICT | 300 | id_validation | 1.0 | 0.017143 | 0.017143 |
| secondary | 3600 | CONFLICT | 300 | ledger_lookup | 1.0 | 0.005407 | 0.005407 |
| secondary | 3600 | CONFLICT | 300 | replay_sanitize | 1.0 | 22.076650 | 22.076650 |
| secondary | 3600 | CONFLICT | 300 | request | 1.0 | 95.091047 | 3.546820 |
| secondary | 3600 | DUPLICATE | 600 | canonical | 1.0 | 63.302523 | 3.510643 |
| secondary | 3600 | DUPLICATE | 600 | fingerprint | 1.0 | 26.487565 | 0.609228 |
| secondary | 3600 | DUPLICATE | 600 | fingerprint_json | 1.0 | 11.131562 | 11.131562 |
| secondary | 3600 | DUPLICATE | 600 | fingerprint_sha256 | 1.0 | 1.433608 | 1.433608 |
| secondary | 3600 | DUPLICATE | 600 | fingerprint_tuple_build | 1.0 | 13.313167 | 13.313167 |
| secondary | 3600 | DUPLICATE | 600 | frame_deep_copy | 1.0 | 10.150343 | 10.150343 |
| secondary | 3600 | DUPLICATE | 600 | frame_validation_copy_loop | 1.0 | 37.911997 | 27.761653 |
| secondary | 3600 | DUPLICATE | 600 | id_validation | 1.0 | 0.016898 | 0.016898 |
| secondary | 3600 | DUPLICATE | 600 | ledger_lookup | 1.0 | 0.005432 | 0.005432 |
| secondary | 3600 | DUPLICATE | 600 | replay_sanitize | 1.0 | 21.879883 | 21.879883 |
| secondary | 3600 | DUPLICATE | 600 | request | 1.0 | 93.273942 | 3.461523 |
| secondary | 3600 | INVALID_REQUEST | 300 | id_validation | 1.0 | 0.001767 | 0.001767 |
| secondary | 3600 | INVALID_REQUEST | 300 | request | 1.0 | 0.009207 | 0.007440 |

## Observed instrumentation effect

Sequential timing, subject to background load/frequency/cache drift; detailed profiling results must not replace uninstrumented p95.

- primary/2: mean service +0.03%; p95 -23.16%.
- primary/3600: mean service +7.73%; p95 +3.07%.
- secondary/2: mean service +56.25%; p95 +56.62%.
- secondary/3600: mean service -3.11%; p95 -2.40%.
