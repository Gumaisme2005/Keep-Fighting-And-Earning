# VT-074 — verification hiện tại, 14/11/2026

**READY FOR COMMIT** sau review tích hợp. Short-run sau fix PASS với human observation, hai ảnh đã đối chiếu và restart do sinh viên xác nhận; xem [review tích hợp mới](EVIDENCE_INTEGRATION_REVIEW_20261114.md). HEAD `476ff8efaec5e0c09b078e86468057d40dc7013e`, branch `feat/bt3-vt074-idempotent-run` cộng working diff. Readiness này cho commit persistence fix/evidence; student reflection/review và submission vẫn cần sinh viên, không tuyên toàn bộ bài tập hoàn thành. Không stage/commit/push/PR/PDF. Các kết quả dưới đây là Windows local / Godot 4.7.2, không phải một Linux Actions run mới.

| BT3 requirement | Status | Source / evidence |
| --- | --- | --- |
| A — specification | PASS | [SPECIFICATION](SPECIFICATION.md): AC-01…05, NFR-01…03, invariant và assumptions |
| B — plan/review AI | PASS | [Original plan](AI_IMPLEMENTATION_PLAN.md) giữ nguyên; R-01/R-02 trong [review](AI_PLAN_REVIEW.md) |
| C — risk strategy / negative / failure | PASS | [Strategy](TEST_STRATEGY.md), 22 designed catalog cases; contract/integration + new failure assertions có execution, không gọi 22 cases là 22 automated tests |
| D — pairwise execution | PASS | 14/14 rows, 261 assertions; design verifier 49/49 feasible pairs; raw all |
| E — test-first | PASS | Original VT74-02 RED→GREEN giữ nguyên; long-session behavioral RED engine 1 → GREEN engine 0; raw RED và target |
| F — hai human test edits | PASS | HT-01/HT-02 diff và before/after gốc giữ nguyên; snippets có AI hỗ trợ, student edit theo provenance đã ghi; human review patch mới PENDING |
| G — mutation >→>= | PASS | Copy-only original 27 PASS/0 → mutant 19 PASS+8 expected FAIL/1 → restored 27 PASS/0 |
| H — TIME / ORDER | PASS | TIME 20 repetitions/340 assertions; ORDER 20 rounds, 160 wrapper invocations/2.480 assertions, 160 original invocations/2.320 assertions; labels/end-state so khớp |
| I — measured line/branch coverage | NOT MEASURED | Không có dependable configured instrumentation; denominator/numerator NOT MEASURED. Behavioral AC/risk mapping đã mở rộng |
| J — performance | PASS | Original harness giữ 40 tasks, 5 warm-up+30 measured/workload, cả 2/3600 frames, bốn p95 đạt; codec cost đo riêng |
| K — engineering / submission completion | PARTIAL | Source hashes, raw commands/exits, reproducibility, provenance và limits có evidence; short-run human PASS, hai ảnh và observation đã tích hợp; near-2-MiB human NOT RUN, student reflection/review và GitHub Actions của patch mới còn pending |

## Kết quả thực thi cuối

| Suite | Actual | Engine / runner exit | Raw |
| --- | --- | --- | --- |
| VT74-02 | behavioral GREEN oracle PASS | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| Contract / HT-01 | 41/41 | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| Integration IT-01…08 | forward/reverse 445 mỗi lần; 8 independent groups tổng 445; actual scene flow IT-08 | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| Replay gốc | full forward/reverse/shuffle 29 mỗi lần; groups 3/14/6/4/2 | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| HT-02 wrapper | full orders 31 mỗi lần; groups 3/14/7/5/2; original assertions giữ nguyên | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| Pairwise | 14 rows, 261 assertions | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| Canonical / alias | 94 cases /284 assertions | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| C1 differential / ownership | 26 scenarios /1.051 assertions; ownership 56 assertions | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| Retention | 127/128/129; 27 assertions | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| Mutation | original 27 PASS; mutant 19 PASS/8 expected FAIL; restored 27 PASS | 0→1→0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| TIME | 20 repetitions /340 assertions | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| ORDER repeated | 20 rounds; wrapper 160 invocations/2.480 assertions; original 160/2.320 | 0 / 0 | [raw all](evidence/persistence_3744145f2646_all.json) |
| Long-session regression | 28 assertions, 0 failures | 0 / 0 | [raw target](evidence/persistence_8b6288391db7_target.json) |
| Exact bytes / writer failures | 59 assertions, 0 failures | 0 / 0 | [raw target](evidence/persistence_8b6288391db7_target.json) |
| Actual take_damage→death timer→Game Over→retry | 16 assertions, 0 failures | 0 / 0 | [raw target](evidence/persistence_8b6288391db7_target.json) |
| Codec/reload/varied controls/old-reader guard | 48 assertions, 0 failures | 0 / 0 | [raw target](evidence/persistence_8b6288391db7_target.json) |
| Project/group CI regression | 24 suite invocations, bốn 30/144 FPS trace pairs bằng nhau; chi tiết counter theo suite trong JSON | 0 / 0 | [raw groups](evidence/persistence_56eea881a687_groups.json) |
| Perk inherited baseline | 34/37; đúng 3 KNOWN BASELINE FAILURES và diagnostic cũ; không relabel whole suite PASS | 1 / 0 (baseline oracle matched) | [raw all](evidence/persistence_3744145f2646_all.json) |
| Local CI smoke / coverage audit | 5 smoke invocations PASS; feature source không có measured line/branch coverage; smoke rerun trong review tích hợp | 0 / 0 | [raw smoke mới](evidence/persistence_247b0a2dc1a4_smoke.json) |

[Exact per-invocation matrix](evidence/persistence_20261114_suite_matrix.json) chứa counts/summary, classification, engine exit và enclosing runner exit cho **mọi suite**, kể cả 320 repeated ORDER invocations. Assertion executions, cases, suite invocations và source coverage là các đơn vị riêng. IT-04 chỉ chấp nhận đúng intentional malformed-JSON diagnostic theo oracle cũ, không bỏ qua runtime errors tùy ý.

## SAVE_FAILED và byte policy

[Root-cause/fix report](SAVE_FAILURE_FIX_REPORT.md) phân biệt human observation và synthetic proof. Pre-fix raw candidate **5.116.489 bytes**, schema hợp lệ, temp/replace attempts **0/0**, expected COMMITTED nhưng actual SAVE_FAILED. [Raw behavioral RED](evidence/persistence_54b931c50351_red.json) engine 1/runner 0; final target GREEN engine 0/runner 0. Previous save synthetic **1.936.384 bytes**, ba retained history entries, live recording 18.000 frames. Writer không tăng limit, không bớt frames/history/ledger để vừa file.

Byte layer nhận đúng **2.097.152**, từ chối **2.097.153** bytes. Kiểm previous/missing save, partial write, read-back mismatch, cleanup, safe retry, original bytes, valid schema, no receipt/history/ledger/signal publication trên encoded-cap failure. Compact reload giữ exact canonical values, receipt/fingerprint, 18.000 last-recorded frames và history cap 3.600. Conflict ở tail frame và duplicate sau reload không ghi lại file. Uncertain old/candidate reconcile giữ đúng một result và dọn temp khi đã resolve.

## Performance

Original harness không sửa: 40 pending trước release; main-thread owner; primary/secondary ×2/3.600 frames; 5 warm-up+30 measured batches/workload. 140 batches; 4.800 measured+800 warm-up request records. Queue-inclusive nearest-rank p95, N=1.200/workload, index 1.139. Không loại samples/outliers, không giảm tasks. Raw CSV/batch files và verifier kiểm status/count/queue arithmetic/persisted hashes.

| Workload | Frames | p95 ms | Failed measured batches | Target ≤1.500 ms |
| --- | ---: | ---: | ---: | --- |
| primary | 2 | 12.146 | 0/30 | PASS |
| primary | 3600 | 411.918 | 0/30 | PASS |
| secondary | 2 | 1.217 | 0/30 | PASS |
| secondary | 3600 | 802.969 | 0/30 | PASS |

Raw: [raw benchmark](evidence/persistence_4a075bff8672_benchmark.json). Previous production references theo thứ tự primary/2, secondary/2, primary/3600, secondary/3600: 10,415 /1,162 /403,425 /782,408 ms thuộc workstation run khác; không dùng chênh lệch unmatched để kết luận causal regression/speedup.

Near-cap first-COMMITTED (n=1 mỗi old format, không warm-up cho request này):

| Old format | First finish_run ms | Raw snapshot JSON bytes | Actual persisted bytes |
| --- | ---: | ---: | ---: |
| legacy | 1878.588 | 5833608 | 1079720 |
| v2 | 1790.409 | 5833608 | 1079720 |

Đây là first successful completion, không lấy retry latency thay thế. Long scenario không phải payload 2/3.600-frame của original NFR gate; chi phí vài giây vẫn cần human retest về responsiveness. Số đo là entire finish pipeline, không tách causal codec overhead khỏi validation/hash/IO.

Đo writer/decoder thực của compact codec trên 18.000 varied frames riêng: 5 warm-up+30 measured; giữ đủ 35 records `[CODEC_COST_SAMPLE]` trong raw benchmark. Writer gồm serialization/copy/frame conversion/compression/hash/atomic IO; decoder gồm outer JSON parse/base64/decompress/hash/inner JSON parse/frame reconstruction, không gồm read IO hoặc GameManager validation. Commit mean/p95/max **597.353/631.385/634.423 ms**; decode **539.072/564.341/595.142 ms**. Không áp target original NFR cho microbenchmark này hoặc gọi đây là matched before/after comparison.

Không tạo duplicate snapshot archive: [verifier](../../tests/vt074/verify_persistence_performance.py) dùng canonical C1 ZIP đã có để kiểm lại 5.600 CSV records và 140 persisted hashes. [Kết quả verifier thực tế](evidence/persistence_20261114_performance_verification.json): PASS, exit 0. Windows sandbox đã chặn certificate store/temporary-directory ACL ở các setup attempts; chạy qua approval bên ngoài sandbox vẫn giữ nguyên child-path isolation. Đây không phải lỗi nghiệp vụ hoặc Linux CI result.

## Tái lập và giới hạn

Từ repository root, Python 3.14 / Godot 4.7.2 đã dùng:

```powershell
$Godot = 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
$Python = 'C:\Users\ADMIN\AppData\Local\Programs\Python\Python314\python.exe'
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase target
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase all
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase groups
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase smoke
# Chạy benchmark riêng khi các test/benchmark khác đã dừng:
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase benchmark
& $Python tests/vt074/verify_persistence_performance.py --run docs/BT3_VT074/evidence/persistence_4a075bff8672_benchmark.json
& $Python tests/vt074/pairwise.py --check-only
```

Mỗi child có APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP/TMP riêng; probe/sentinel xác nhận trước autoload. Không đọc/hash/copy save hay backup cá nhân. Normal tests tại working checkout; chỉ mutation dùng copy. Không dùng old runners main() có personal-save hashing. Các source hashes/commands/platform/version/exits nằm trong raw reports. `--ci --phase target` được thêm vào workflow bên cạnh smoke cũ; không đưa mutation/heavy benchmarks vào mặc định CI, không dùng continue-on-error. Linux Actions cho patch này **NOT RUN**, chưa push.

Manual E2E: **historical FAIL trước fix 14/11/2026; post-fix short-run PASS với human observation và hai ảnh thật đã đối chiếu** (Miya / ALOALO1234 / Floor 2 / 39 kills; RUN SAVED, History khớp; restart human-confirmed, không có ảnh sau restart). Ba file observation/ảnh đã có trong manifest hiện tại với SHA-256; human near-2-MiB vẫn **NOT RUN**, theo [manual checklist](MANUAL_E2E_VERIFICATION.md). Reflection/human patch review còn cần sinh viên; [proposed edits](REFLECTION_REVIEW_PROPOSAL.md) không phải human approval. Original plan, R/TR decisions, HT before/after patch và Commit1–8 reports/evidence giữ nguyên.

Residual risks: single writer/process, finite ledger retention, no fsync/power-loss proof, pending RAM mất nếu quit/crash trước commit; unresolved uncertainty giữ blocked. Incompressible hoặc expanded >32 MiB phải fail explicit, giữ old save/pending; safe retry không hứa có thể làm mọi dữ liệu vừa fixed cap. Older binaries không đọc compact saves; guard ngăn overwrite. Plain legacy/v2 JSON có historical floating-decimal precision limits; codec mới giữ exact double values, không thể phục hồi precision đã mất trong save cũ. Line/branch coverage **NOT MEASURED**, không có denominator/numerator đáng tin cậy.

[Final integrity trước tích hợp](evidence/persistence_20261114_final_checks.json) và [manifest 55-file trước tích hợp](evidence/persistence_20261114_commit_manifest.json) được giữ nguyên như snapshot lịch sử; trạng thái manual PENDING trong đó đã cũ. [Review tích hợp](EVIDENCE_INTEGRATION_REVIEW_20261114.md) chứa checks và inventory hiện tại; không có commit đã tạo. Sinh viên chỉ commit sau review/retest phù hợp. Các failed/superseded attempts được giữ nguyên; [attempt index](evidence/persistence_20261114_attempt_index.json) nêu rõ setup error, behavioral RED và verbose artifacts giữ local/ignored.
