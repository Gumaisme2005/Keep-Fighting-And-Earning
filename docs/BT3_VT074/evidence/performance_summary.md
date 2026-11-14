# VT-074 — Performance evidence (C5)

Model: **40 overlapping submissions / single-process serialized execution**. No network users, parallel writers, worker-thread Node calls or multi-process guarantee.

Godot `4.7.2.stable.official.ed1daf0bf`, HEAD `001785ee52589094f2b096161a0be99d5e3c4003`. Environment: `Windows-11-10.0.26200-SP0`; hardware/volume details in quality_run.json.

5 warm-up +30 measured batches **per family/frame workload**. Exactly40 tasks each;4,800 measured rows,800 warm-up rows in separate CSV. Primary:1 COMMITTED +39 DUPLICATE. Secondary (precommitted control, separate):20 DUPLICATE +10 CONFLICT +10 INVALID_REQUEST,0 new commit.

Monotonic submit→finish includes barrier/queue wait, validation/hash and real file persistence. Setup, payload generation/import, verification and CSV logging excluded. Queue/service durations are separately recorded; service includes harness call/clock overhead, not instrumented JSON-vs-disk subphases.

| Workload | Frames | Samples | Min ms | Mean ms | Median ms | Max ms | Pooled p95 ms (rank1140) | Batch p95 failures /30 | Result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| primary | 2 | 1200 | 8.618 | 30.691 | 28.812 | 66.158 | 54.713 | 0 | PASS |
| primary | 3600 | 1200 | 377.005 | 3646.613 | 3464.838 | 10156.880 | 7235.233 | 30 | FAIL |
| secondary | 2 | 1200 | 0.311 | 4.236 | 3.996 | 14.745 | 10.626 | 0 | PASS |
| secondary | 3600 | 1200 | 96.854 | 2740.329 | 2915.314 | 4931.938 | 4406.804 | 30 | FAIL |

**NFR-02 target: FAIL** (threshold p95 <=1500ms; every measured batch checked separately, nearest rank38/40). Correctness/experiment validity is separate from threshold outcome. No sample dropped or pooled across frame workloads to hide tails.

## Actual measured outcomes

| Workload | Frames | COMMITTED | DUPLICATE | CONFLICT | INVALID_REQUEST | Unique newly committed IDs | Unique request IDs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| primary | 2 | 30 | 1170 | 0 | 0 | 30 | 30 |
| primary | 3600 | 30 | 1170 | 0 | 0 | 30 | 30 |
| secondary | 2 | 0 | 600 | 300 | 300 | 0 | 30 |
| secondary | 3600 | 0 | 600 | 300 | 300 | 0 | 30 |

Secondary persisted results are established by one setup commit per batch outside measurement; no rejection is counted as a new commit. Every batch retains exactly one persisted result/receipt; independently re-read by verifier.

## Queue/service observations

| Workload | Frames | Mean queue ms | Mean service ms | Service mean by request type ms |
| --- | ---: | ---: | ---: | --- |
| primary | 2 | 29.837 | 0.854 | first_completion: 25.968; retry: 0.210 |
| primary | 3600 | 3482.811 | 163.802 | first_completion: 649.927; retry: 151.337 |
| secondary | 2 | 4.101 | 0.135 | conflict: 0.146; duplicate: 0.195; invalid: 0.003 |
| secondary | 3600 | 2633.240 | 107.089 | conflict: 141.759; duplicate: 143.295; invalid: 0.007 |

Queue and service are measured separately from the CSV. Service includes canonicalization/hash and, on a commit, snapshot serialization/real IO; no finer CPU/JSON/disk instrumentation was run, so those subphases cannot be separated empirically. Larger payload cost and accumulated queue wait are candidates for a follow-up optimization study, not permission to weaken this workload or change production in C5.

## Per-batch measured metrics

| Batch | Min ms | Mean ms | Median ms | Max ms | p95 ms (rank38) | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| primary_0002_measured_06 | 20.056 | 22.627 | 22.378 | 25.361 | 25.111 | PASS |
| primary_0002_measured_07 | 22.707 | 24.976 | 24.873 | 27.718 | 27.415 | PASS |
| primary_0002_measured_08 | 10.074 | 15.617 | 13.967 | 24.854 | 23.482 | PASS |
| primary_0002_measured_09 | 10.063 | 16.445 | 15.925 | 22.565 | 22.158 | PASS |
| primary_0002_measured_10 | 36.631 | 39.941 | 40.040 | 43.337 | 42.987 | PASS |
| primary_0002_measured_11 | 48.402 | 52.114 | 52.076 | 55.111 | 54.807 | PASS |
| primary_0002_measured_12 | 19.770 | 22.046 | 22.128 | 24.151 | 23.922 | PASS |
| primary_0002_measured_13 | 8.618 | 16.252 | 15.407 | 23.835 | 23.574 | PASS |
| primary_0002_measured_14 | 9.030 | 17.662 | 18.526 | 24.921 | 24.506 | PASS |
| primary_0002_measured_15 | 15.253 | 18.699 | 18.877 | 21.573 | 21.213 | PASS |
| primary_0002_measured_16 | 28.203 | 32.060 | 31.428 | 41.905 | 36.307 | PASS |
| primary_0002_measured_17 | 19.370 | 24.836 | 24.966 | 27.710 | 27.347 | PASS |
| primary_0002_measured_18 | 15.898 | 19.254 | 19.353 | 22.721 | 22.366 | PASS |
| primary_0002_measured_19 | 16.457 | 24.019 | 24.509 | 27.136 | 26.858 | PASS |
| primary_0002_measured_20 | 17.901 | 20.764 | 20.788 | 23.652 | 23.377 | PASS |
| primary_0002_measured_21 | 33.138 | 35.600 | 35.578 | 38.148 | 37.871 | PASS |
| primary_0002_measured_22 | 27.547 | 33.824 | 34.615 | 37.893 | 37.640 | PASS |
| primary_0002_measured_23 | 39.145 | 41.856 | 41.834 | 44.415 | 44.263 | PASS |
| primary_0002_measured_24 | 24.607 | 27.291 | 27.157 | 30.209 | 29.900 | PASS |
| primary_0002_measured_25 | 30.240 | 33.153 | 32.587 | 36.520 | 36.365 | PASS |
| primary_0002_measured_26 | 17.068 | 22.374 | 23.627 | 26.848 | 26.536 | PASS |
| primary_0002_measured_27 | 37.344 | 45.435 | 48.024 | 51.067 | 50.681 | PASS |
| primary_0002_measured_28 | 28.105 | 30.245 | 30.294 | 32.302 | 32.109 | PASS |
| primary_0002_measured_29 | 30.306 | 38.392 | 40.944 | 44.468 | 43.886 | PASS |
| primary_0002_measured_30 | 28.271 | 30.580 | 30.589 | 33.071 | 32.797 | PASS |
| primary_0002_measured_31 | 61.182 | 63.738 | 63.633 | 66.158 | 65.983 | PASS |
| primary_0002_measured_32 | 27.692 | 31.905 | 32.105 | 35.078 | 34.809 | PASS |
| primary_0002_measured_33 | 26.040 | 28.728 | 28.840 | 30.890 | 30.616 | PASS |
| primary_0002_measured_34 | 33.200 | 36.127 | 36.234 | 38.452 | 38.255 | PASS |
| primary_0002_measured_35 | 49.288 | 54.161 | 54.161 | 57.302 | 57.028 | PASS |
| secondary_0002_measured_06 | 0.520 | 2.725 | 2.838 | 4.223 | 4.218 | PASS |
| secondary_0002_measured_07 | 0.311 | 2.336 | 2.330 | 3.914 | 3.908 | PASS |
| secondary_0002_measured_08 | 0.704 | 3.809 | 4.035 | 5.257 | 5.256 | PASS |
| secondary_0002_measured_09 | 0.664 | 3.111 | 3.432 | 4.413 | 4.409 | PASS |
| secondary_0002_measured_10 | 0.436 | 3.403 | 4.205 | 5.304 | 5.302 | PASS |
| secondary_0002_measured_11 | 0.538 | 3.374 | 3.979 | 5.340 | 5.339 | PASS |
| secondary_0002_measured_12 | 0.526 | 3.018 | 3.002 | 4.531 | 4.530 | PASS |
| secondary_0002_measured_13 | 1.492 | 4.529 | 4.766 | 6.411 | 6.410 | PASS |
| secondary_0002_measured_14 | 0.356 | 2.988 | 3.071 | 4.800 | 4.793 | PASS |
| secondary_0002_measured_15 | 0.703 | 4.143 | 4.539 | 6.244 | 6.243 | PASS |
| secondary_0002_measured_16 | 0.512 | 3.352 | 3.693 | 4.894 | 4.894 | PASS |
| secondary_0002_measured_17 | 0.652 | 3.648 | 3.821 | 5.353 | 5.351 | PASS |
| secondary_0002_measured_18 | 5.338 | 9.131 | 9.227 | 10.793 | 10.792 | PASS |
| secondary_0002_measured_19 | 0.436 | 3.401 | 3.683 | 5.049 | 5.043 | PASS |
| secondary_0002_measured_20 | 0.480 | 3.106 | 3.307 | 4.612 | 4.609 | PASS |
| secondary_0002_measured_21 | 4.863 | 12.226 | 13.095 | 14.745 | 14.457 | PASS |
| secondary_0002_measured_22 | 0.686 | 5.925 | 6.198 | 7.167 | 7.163 | PASS |
| secondary_0002_measured_23 | 0.497 | 3.143 | 3.413 | 4.663 | 4.660 | PASS |
| secondary_0002_measured_24 | 1.572 | 4.058 | 4.547 | 5.711 | 5.573 | PASS |
| secondary_0002_measured_25 | 0.432 | 3.588 | 3.293 | 6.068 | 6.066 | PASS |
| secondary_0002_measured_26 | 0.529 | 2.828 | 3.077 | 4.435 | 4.432 | PASS |
| secondary_0002_measured_27 | 0.357 | 2.295 | 2.438 | 3.652 | 3.651 | PASS |
| secondary_0002_measured_28 | 0.816 | 3.123 | 3.156 | 4.673 | 4.672 | PASS |
| secondary_0002_measured_29 | 0.716 | 5.660 | 4.076 | 11.173 | 11.172 | PASS |
| secondary_0002_measured_30 | 1.149 | 6.484 | 6.665 | 8.023 | 8.022 | PASS |
| secondary_0002_measured_31 | 0.427 | 3.519 | 3.872 | 5.199 | 5.193 | PASS |
| secondary_0002_measured_32 | 2.117 | 7.964 | 8.368 | 9.623 | 9.618 | PASS |
| secondary_0002_measured_33 | 0.680 | 3.275 | 3.506 | 4.252 | 4.252 | PASS |
| secondary_0002_measured_34 | 0.933 | 3.743 | 3.978 | 4.821 | 4.818 | PASS |
| secondary_0002_measured_35 | 0.376 | 3.179 | 3.589 | 4.808 | 4.802 | PASS |
| primary_3600_measured_06 | 818.581 | 4395.926 | 4340.359 | 8031.011 | 7653.006 | FAIL |
| primary_3600_measured_07 | 831.548 | 4275.057 | 4295.012 | 7711.952 | 7360.322 | FAIL |
| primary_3600_measured_08 | 695.546 | 4252.238 | 4289.891 | 7746.152 | 7341.514 | FAIL |
| primary_3600_measured_09 | 789.215 | 4769.598 | 4808.873 | 8739.244 | 8223.447 | FAIL |
| primary_3600_measured_10 | 997.397 | 4413.780 | 4411.059 | 7810.468 | 7454.112 | FAIL |
| primary_3600_measured_11 | 678.750 | 3958.436 | 4018.120 | 7145.520 | 6833.437 | FAIL |
| primary_3600_measured_12 | 692.221 | 3948.675 | 3888.977 | 7347.337 | 7006.950 | FAIL |
| primary_3600_measured_13 | 699.616 | 4154.247 | 4191.562 | 7465.523 | 7115.463 | FAIL |
| primary_3600_measured_14 | 900.829 | 4014.620 | 4109.730 | 7269.089 | 6846.952 | FAIL |
| primary_3600_measured_15 | 678.860 | 3988.035 | 3933.064 | 7557.385 | 7187.481 | FAIL |
| primary_3600_measured_16 | 705.872 | 4438.635 | 4500.461 | 8028.515 | 7698.339 | FAIL |
| primary_3600_measured_17 | 919.891 | 5558.872 | 5514.637 | 10156.880 | 9744.219 | FAIL |
| primary_3600_measured_18 | 863.659 | 5209.895 | 5447.008 | 8930.042 | 8563.447 | FAIL |
| primary_3600_measured_19 | 667.057 | 3595.041 | 3659.336 | 6056.466 | 5802.567 | FAIL |
| primary_3600_measured_20 | 627.535 | 3322.954 | 3384.500 | 5634.243 | 5459.963 | FAIL |
| primary_3600_measured_21 | 735.948 | 3458.336 | 3454.793 | 6135.120 | 5921.871 | FAIL |
| primary_3600_measured_22 | 552.430 | 4340.861 | 4220.497 | 7992.607 | 7703.477 | FAIL |
| primary_3600_measured_23 | 1045.658 | 4340.299 | 4608.972 | 6948.263 | 6737.479 | FAIL |
| primary_3600_measured_24 | 492.478 | 2960.593 | 2920.983 | 5406.170 | 5164.015 | FAIL |
| primary_3600_measured_25 | 613.958 | 3162.940 | 3101.405 | 5714.478 | 5473.093 | FAIL |
| primary_3600_measured_26 | 516.739 | 2870.653 | 2876.985 | 5226.483 | 4998.108 | FAIL |
| primary_3600_measured_27 | 446.008 | 2645.202 | 2686.969 | 4678.428 | 4464.170 | FAIL |
| primary_3600_measured_28 | 474.754 | 2674.207 | 2717.991 | 4839.362 | 4608.426 | FAIL |
| primary_3600_measured_29 | 513.349 | 2543.992 | 2533.776 | 4543.172 | 4350.082 | FAIL |
| primary_3600_measured_30 | 377.005 | 2522.526 | 2545.774 | 4637.528 | 4413.973 | FAIL |
| primary_3600_measured_31 | 445.494 | 2493.088 | 2525.833 | 4505.307 | 4301.002 | FAIL |
| primary_3600_measured_32 | 405.794 | 2466.357 | 2484.994 | 4455.931 | 4246.704 | FAIL |
| primary_3600_measured_33 | 441.348 | 2685.661 | 2703.528 | 4994.558 | 4761.218 | FAIL |
| primary_3600_measured_34 | 503.759 | 2856.180 | 2843.430 | 5193.412 | 4964.062 | FAIL |
| primary_3600_measured_35 | 475.048 | 3081.477 | 3016.564 | 5761.318 | 5507.866 | FAIL |
| secondary_3600_measured_06 | 96.854 | 1943.988 | 1943.291 | 3219.150 | 3219.150 | FAIL |
| secondary_3600_measured_07 | 140.134 | 2759.212 | 3003.593 | 4241.167 | 4241.162 | FAIL |
| secondary_3600_measured_08 | 199.986 | 2818.235 | 2971.074 | 4424.598 | 4424.594 | FAIL |
| secondary_3600_measured_09 | 202.327 | 2897.452 | 3100.010 | 4443.464 | 4443.459 | FAIL |
| secondary_3600_measured_10 | 139.323 | 2807.272 | 3052.090 | 4385.183 | 4385.172 | FAIL |
| secondary_3600_measured_11 | 141.420 | 2777.682 | 3001.279 | 4345.397 | 4345.397 | FAIL |
| secondary_3600_measured_12 | 151.859 | 2776.426 | 3013.808 | 4362.746 | 4362.743 | FAIL |
| secondary_3600_measured_13 | 153.788 | 2793.784 | 3048.892 | 4406.811 | 4406.798 | FAIL |
| secondary_3600_measured_14 | 138.560 | 2704.103 | 2924.192 | 4229.397 | 4229.397 | FAIL |
| secondary_3600_measured_15 | 133.898 | 2666.867 | 2897.846 | 4178.175 | 4178.170 | FAIL |
| secondary_3600_measured_16 | 142.991 | 2753.291 | 2920.945 | 4304.212 | 4304.202 | FAIL |
| secondary_3600_measured_17 | 150.789 | 2754.947 | 2962.997 | 4273.400 | 4273.392 | FAIL |
| secondary_3600_measured_18 | 147.116 | 2711.090 | 2882.436 | 4264.344 | 4264.302 | FAIL |
| secondary_3600_measured_19 | 145.391 | 2630.808 | 2833.142 | 4102.806 | 4102.805 | FAIL |
| secondary_3600_measured_20 | 152.159 | 2644.936 | 2844.294 | 4113.008 | 4113.004 | FAIL |
| secondary_3600_measured_21 | 140.710 | 2623.396 | 2821.352 | 4128.110 | 4128.101 | FAIL |
| secondary_3600_measured_22 | 158.452 | 2777.774 | 2962.011 | 4322.534 | 4322.524 | FAIL |
| secondary_3600_measured_23 | 141.169 | 2782.582 | 2995.355 | 4301.421 | 4301.421 | FAIL |
| secondary_3600_measured_24 | 144.221 | 2730.444 | 2954.698 | 4264.880 | 4264.870 | FAIL |
| secondary_3600_measured_25 | 145.031 | 2725.466 | 2901.914 | 4235.589 | 4235.582 | FAIL |
| secondary_3600_measured_26 | 135.113 | 2610.700 | 2812.006 | 4105.696 | 4105.686 | FAIL |
| secondary_3600_measured_27 | 139.037 | 2757.803 | 2936.506 | 4371.345 | 4371.339 | FAIL |
| secondary_3600_measured_28 | 153.755 | 2863.154 | 2979.963 | 4609.235 | 4609.228 | FAIL |
| secondary_3600_measured_29 | 192.910 | 2994.807 | 3235.760 | 4571.915 | 4571.914 | FAIL |
| secondary_3600_measured_30 | 165.451 | 2796.179 | 3024.601 | 4333.654 | 4333.645 | FAIL |
| secondary_3600_measured_31 | 131.735 | 2654.656 | 2840.718 | 4177.211 | 4177.210 | FAIL |
| secondary_3600_measured_32 | 214.136 | 3245.694 | 3487.958 | 4931.938 | 4931.935 | FAIL |
| secondary_3600_measured_33 | 162.447 | 2775.690 | 2970.544 | 4317.834 | 4317.830 | FAIL |
| secondary_3600_measured_34 | 130.088 | 2692.600 | 2839.846 | 4301.968 | 4301.964 | FAIL |
| secondary_3600_measured_35 | 118.566 | 2738.833 | 2951.470 | 4303.132 | 4303.121 | FAIL |

Raw per-task submit/dispatch/finish, latency, queue/service, run ID and status: performance_40.csv; warmups: performance_warmup.csv; barrier/commit/persistence/write/signal witnesses: performance_batches.json; actual commands/stdout/stderr/exits: performance_run.log. This is a local filesystem/read-back experiment, no fsync/power-loss durability claim.
