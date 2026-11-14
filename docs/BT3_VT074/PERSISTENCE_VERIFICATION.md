# VT-074 — Final Persistence Verification

**Cập nhật:** 14/11/2026  
**Branch:** `feat/bt3-vt074-idempotent-run`  
**Commit đã kiểm chứng:** `1b81031b6742fc1670d37062903b477bbb7e13c0`  
**Trạng thái:** FINAL TECHNICAL VERIFICATION COMPLETED

Bản sửa persistence đã được commit và push. Các bài kiểm thử chức năng, regression, performance và Manual E2E cơ bản có bằng chứng tương ứng.

GitHub Actions Linux trên commit `1b81031` đã **SUCCESS**:

[GitHub Actions — successful run](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43575655486)

Sinh viên đã ghi quyết định **ACCEPT** đối với persistence fix tại [AI_USAGE_LOG.md](AI_USAGE_LOG.md), và [REFLECTION.md](REFLECTION.md) đã được cập nhật.

Phần code và testing kỹ thuật đã hoàn thành trong phạm vi kiểm chứng. Những giới hạn chưa đo hoặc chưa thử thủ công vẫn được ghi rõ. Các công việc nộp bài còn lại: mở PR vào `development` và hoàn thiện PDF.

## 1. Requirement Verification

| BT3 requirement | Status | Source / Evidence |
| --- | --- | --- |
| A — Specification | PASS | [SPECIFICATION](SPECIFICATION.md): AC-01…05, NFR-01…03, invariants và assumptions |
| B — AI plan/review | PASS | Original/revised plan và R-01/R-02 trong [AI_PLAN_REVIEW](AI_PLAN_REVIEW.md) |
| C — Risk strategy/negative/failure | PASS | [TEST_STRATEGY](TEST_STRATEGY.md), 22 designed catalog cases, contract/integration/failure witnesses |
| D — Pairwise execution | PASS | 14/14 rows, 261 assertions; 49/49 feasible pairs |
| E — Test-first | PASS | VT74-02 RED→GREEN và long-session behavioral RED→GREEN |
| F — Human test edits | PASS | HT-01/HT-02, before/after diff và execution evidence; persistence Student Review: ACCEPT |
| G — Mutation `>` → `>=` | PASS | Original 27 PASS → mutant 8 expected FAIL → restored 27 PASS |
| H — TIME/ORDER | PASS | TIME 20 repetitions/340 assertions; ORDER 20 rounds, 160 wrapper invocations/2.480 assertions và 160 original invocations/2.320 assertions |
| I — Measured line/branch coverage | NOT MEASURED | Không có instrumentation đáng tin cậy; có behavioral AC/risk mapping |
| J — Performance | PASS | Original 40-task harness, 4 workloads p95 ≤1.500 ms |
| K — Engineering verification | PASS trong phạm vi kiểm chứng | Source hashes, raw commands/exits, regression, reproducibility, Manual E2E short-run, Student Review, Reflection và Linux CI có bằng chứng |
| Submission | PENDING | Cần mở PR review và hoàn thiện PDF nộp bài |

22 test cases là catalog thiết kế; không coi chúng là 22 automated tests độc lập. Các PASS được gắn với executable witnesses và raw evidence.

## 2. Kết quả thực thi

| Suite | Actual | Engine / Runner Exit | Raw Evidence |
| --- | --- | --- | --- |
| VT74-02 | Behavioral GREEN oracle PASS | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Contract / HT-01 | 41/41 PASS | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Integration IT-01…08 | Forward/reverse 445 assertions mỗi lần; 8 independent groups tổng 445; actual scene flow IT-08 | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Replay gốc | Full forward/reverse/shuffle 29 assertions mỗi lần; groups 3/14/6/4/2 | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| HT-02 wrapper | Full orders 31 assertions mỗi lần; groups 3/14/7/5/2; giữ original assertions | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Pairwise | 14 rows, 261 assertions PASS | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Canonical/alias | 94 cases, 284 assertions | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| C1 differential/ownership | 26 scenarios, 1.051 assertions; ownership 56 assertions | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Retention | 127/128/129, 27 assertions | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Mutation | Original 27 PASS; mutant 19 PASS/8 expected FAIL; restored 27 PASS | 0→1→0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| TIME | 20 repetitions, 340 assertions | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| ORDER repeated | 20 rounds; wrapper 160 invocations/2.480 assertions; original 160/2.320 | 0 / 0 | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Long-session regression | 28 assertions, 0 failures | 0 / 0 | [Raw target](evidence/persistence_8b6288391db7_target.json) |
| Exact bytes/writer failures | 59 assertions, 0 failures | 0 / 0 | [Raw target](evidence/persistence_8b6288391db7_target.json) |
| Death→Game Over→retry | 16 assertions, 0 failures | 0 / 0 | [Raw target](evidence/persistence_8b6288391db7_target.json) |
| Codec/reload/old-reader guard | 48 assertions, 0 failures | 0 / 0 | [Raw target](evidence/persistence_8b6288391db7_target.json) |
| Project/group CI regression | 24 suite invocations; 30/144 FPS trace pairs khớp | 0 / 0 | [Raw groups](evidence/persistence_56eea881a687_groups.json) |
| Perk inherited baseline | 34/37, đúng 3 known baseline failures | 1 / 0 (baseline oracle matched) | [Raw all](evidence/persistence_3744145f2646_all.json) |
| Local CI smoke/coverage audit | 5 smoke invocations PASS; coverage chưa đo | 0 / 0 | [Raw smoke](evidence/persistence_247b0a2dc1a4_smoke.json) |

[Exact per-invocation matrix](evidence/persistence_20261114_suite_matrix.json) lưu counts, classification, engine exit và runner exit của từng suite, kể cả 320 repeated ORDER invocations.

Assertion executions, test cases, suite invocations và source coverage là những đơn vị khác nhau. Không dùng số lượng assertions để suy ra line/branch coverage.

IT-04 chỉ chấp nhận malformed-JSON diagnostic đã được xác định trước trong oracle; không bỏ qua runtime errors tùy ý.

## 3. SAVE_FAILED — Root Cause và Fix

[Root-cause/fix report](SAVE_FAILURE_FIX_REPORT.md) phân biệt rõ human observation và synthetic reproduction.

### 3.1. Behavioral RED

Trước fix, synthetic candidate có:

- Previous save: **1.936.384 bytes**
- Candidate JSON: **5.116.489 bytes**
- Full recording: **18.000 frames**
- Ba retained history entries
- Candidate schema: hợp lệ
- Temporary-file attempts: **0**
- Replace attempts: **0**
- Expected: `COMMITTED`
- Actual: `SAVE_FAILED`

Candidate bị từ chối ở physical size guard trước khi tạo temporary file.

[Raw behavioral RED](evidence/persistence_54b931c50351_red.json): engine exit 1, runner exit 0.

Nguyên nhân của lượt chơi riêng tư Floor 5/307 kills chưa được xác nhận trực tiếp từ save cá nhân; synthetic reproduction chứng minh cơ chế lỗi tương thích với triệu chứng, không phải kết quả phân tích file cá nhân.

### 3.2. Production Fix

Bản sửa sử dụng lossless compact storage khi snapshot vượt giới hạn, đồng thời:

- Giữ physical file cap **2.097.152 bytes**.
- Không xóa replay, history hoặc ledger chỉ để giảm kích thước.
- Bảo toàn exact canonical replay double values qua codec.
- Kiểm tra checksum và giới hạn giải nén.
- Giữ ID, envelope, fingerprint và receipt.
- Hỗ trợ legacy/v2 và compact format.
- Xử lý safe retry và uncertain storage reconciliation.
- Hiển thị đúng trạng thái lưu trên Game Over.

Byte-boundary regression chấp nhận **2.097.152 bytes** và từ chối **2.097.153 bytes**.

Compact reload giữ đúng 18.000 last-recorded frames, receipt/fingerprint và history frame cap 3.600. Duplicate sau reload không tạo thêm bản ghi hoặc save/signal mới; conflict ở tail frame được phát hiện.

Uncertain old/candidate reconciliation giữ đúng một committed result và dọn temporary file sau khi trạng thái đã xác định.

### 3.3. GREEN

Final target regression:

- Long-session: 28 PASS
- Byte/writer: 59 PASS
- Actual death/UI retry: 16 PASS
- Codec/reload: 48 PASS

Engine exit 0, runner exit 0.

[Raw GREEN](evidence/persistence_8b6288391db7_target.json)

Bản sửa không bảo đảm mọi dữ liệu tương lai đều nén vừa 2 MiB. Incompressible hoặc expanded data quá giới hạn vẫn phải fail explicit, giữ old save và pending state an toàn.

## 4. Performance Verification

Original harness không bị giảm workload hoặc thay acceptance threshold.

Cấu hình:

- 40 pending tasks trước release.
- Single-process main-thread owner.
- Primary và secondary mode.
- 2 frames và 3.600 frames.
- 5 warm-up + 30 measured batches cho mỗi workload.
- Tổng 140 batches.
- 4.800 measured + 800 warm-up request records.
- Queue-inclusive nearest-rank p95.
- 1.200 measured samples/workload; nearest-rank index 1.139.
- Không bỏ outlier hoặc giảm số lượng tasks.

### 4.1. Performance Results

| Workload | Frames | p95 (ms) | Failed Measured Batches | Target ≤1.500 ms |
| --- | ---: | ---: | ---: | --- |
| Primary | 2 | 12.146 | 0/30 | PASS |
| Primary | 3.600 | 411.918 | 0/30 | PASS |
| Secondary | 2 | 1.217 | 0/30 | PASS |
| Secondary | 3.600 | 802.969 | 0/30 | PASS |

**Kết quả: 4/4 workload PASS.**

[Raw benchmark](evidence/persistence_4a075bff8672_benchmark.json)

Các previous production references ở workstation run khác, theo thứ tự primary/2, secondary/2, primary/3600, secondary/3600: **10.415 / 1.162 / 403.425 / 782.408 ms**. Không dùng chênh lệch unmatched để kết luận tốc độ tăng/giảm do bản sửa.

### 4.2. Near-Cap First Completion

Đo first-COMMITTED riêng cho recording dài:

| Old Format | First `finish_run` (ms) | Raw Snapshot JSON Bytes | Actual Persisted Bytes |
| --- | ---: | ---: | ---: |
| Legacy | 1878.588 | 5833608 | 1079720 |
| V2 | 1790.409 | 5833608 | 1079720 |

Đây là thời gian lần completion thành công đầu tiên, không dùng duplicate retry latency thay thế.

Long scenario này không nằm trong original 2/3.600-frame NFR gate. Chi phí gần hai giây vẫn là residual responsiveness risk cần được ghi rõ.

### 4.3. Codec Cost

Đo writer/decoder của compact codec trên 18.000 varied frames với 5 warm-up và 30 measured samples. Raw benchmark giữ đủ 35 `[CODEC_COST_SAMPLE]` records.

| Operation | Mean (ms) | p95 (ms) | Max (ms) |
| --- | ---: | ---: | ---: |
| Compact commit | 597.353 | 631.385 | 634.423 |
| Compact decode | 539.072 | 564.341 | 595.142 |

Writer bao gồm serialization/copy/frame conversion/compression/hash/atomic IO.

Decoder bao gồm outer JSON parse, base64/decompression, hash, inner JSON parse và frame reconstruction; không bao gồm read IO hoặc GameManager validation.

Không áp original NFR p95 target cho microbenchmark này và không gọi đây là matched before/after experiment.

### 4.4. Performance Evidence Integrity

Không tạo duplicate snapshot archive. [Performance verifier](../../tests/vt074/verify_persistence_performance.py) dùng canonical C1 ZIP đã có để kiểm lại **5.600 CSV records và 140 persisted snapshot hashes**.

[Kết quả verifier](evidence/persistence_20261114_performance_verification.json): **PASS, exit 0**.

Những setup attempts bị chặn bởi certificate store hoặc temporary-directory ACL của Windows sandbox được giữ làm evidence riêng, không phân loại là behavioral regression.

## 5. GitHub Actions Linux

Các bước VT-074 đã được tích hợp vào CI cùng với những bài test sẵn có của nhóm.

**Verified successful runs:**

- [Persistence fix — commit 879b8b4](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43573367776)
- [Student Review — commit 7c01d3e](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43574884891)
- [Reflection — commit a76ec7b](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43575207435)
- [AI Usage Log — commit 1b81031](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43575655486)

**Trạng thái tại thời điểm kiểm tra: SUCCESS.**

CI bao gồm VT-074 Smoke và Persistence/Byte Boundary/Player Death Regression. Không dùng `continue-on-error` để che behavioral failures. Mutation và heavy benchmark vẫn được kiểm tra riêng, không phải CI mặc định.

## 6. Manual E2E

### 6.1. Historical Failure — Before Fix

Ngày 14/11/2026:

- Character: Miya
- Seed: `ALOALO1234`
- Floor: 5
- Enemies killed: 307
- Game Over xuất hiện
- Expedition History không có bản ghi tương ứng
- Remote Inspector: `last_completion_result.status = SAVE_FAILED`
- Storage state: `READY`

Kết quả: **FAIL trước fix**.

Private save và backup không được mở, parse, hash hoặc upload để phục vụ test. Không khẳng định đã biết chính xác syscall/stage của lượt chơi cá nhân.

### 6.2. Post-Fix Manual Short-Run

Ngày 14/11/2026:

- Character: Miya
- Seed: `ALOALO1234`
- Floor: 2
- Enemies killed: 39
- Game Over: `RUN SAVED`
- History: Entry mới đúng hero/seed/floor/kills
- Restart: Sinh viên xác nhận entry vẫn tồn tại

Kết quả: **PASS short-run**.

Hai ảnh Game Over và History được kiểm tra và đưa vào evidence. Ảnh đều được chụp trước khi restart; không có ảnh sau restart. Sinh viên đã trực tiếp xác nhận dữ liệu vẫn còn sau restart.

**Human near-2-MiB: NOT RUN sau fix.**

**Human replay playback/retry riêng: NOT RUN.**

Các synthetic/headless regressions đã kiểm tra failure/retry/long recording, nhưng không thay thế gameplay trực tiếp cho những trường hợp chưa chạy.

[Manual E2E evidence](MANUAL_E2E_VERIFICATION.md)  
[Human observation](MANUAL_E2E_OBSERVATION_20261114.md)

## 7. Reproduction

Từ repository root, môi trường đã dùng gồm Python 3.14 và Godot 4.7.2.

```powershell
$Godot = 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
$Python = 'C:\Users\ADMIN\AppData\Local\Programs\Python\Python314\python.exe'

& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase target
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase all
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase groups
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase smoke

# Benchmark chạy riêng sau khi những test/benchmark khác đã dừng:
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase benchmark

& $Python tests/vt074/verify_persistence_performance.py --run docs/BT3_VT074/evidence/persistence_4a075bff8672_benchmark.json
& $Python tests/vt074/pairwise.py --check-only
```

Các đường dẫn Godot và Python là ví dụ từ môi trường đã kiểm tra, cần điều chỉnh khi chạy trên máy khác.

Mỗi child process được cô lập bằng APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP/TMP riêng; sentinel/probe xác nhận trước autoload.

Normal tests chạy trong working checkout, còn mutation dùng disposable copy. Không dùng các runner cũ có thể truy cập personal save.

Source hashes, commands, platform/version và exit codes có trong raw evidence.

## 8. Residual Risks

Các giới hạn còn lại:

1. Single-process/single-writer model, không phải hệ thống concurrent network users thực.
2. Ledger retention tối đa 128 receipts; expired ID không thể tự tái dựng.
3. Không có fsync/power-loss durability proof.
4. Pending completion trong RAM có thể mất nếu game thoát hoặc crash trước commit.
5. Dữ liệu incompressible hoặc expanded quá giới hạn có thể `SAVE_FAILED` dù dùng compact codec.
6. Older binaries không đọc compact saves; guard được kiểm tra để tránh overwrite sai.
7. Plain legacy/v2 JSON vẫn có giới hạn floating-decimal precision lịch sử.
8. Line/branch coverage **NOT MEASURED**.
9. Human gameplay dài gần 2 MiB sau fix chưa chạy lại.
10. Ba Perk baseline failures vẫn tồn tại trong test matrix lịch sử.

Các rủi ro này không bị ẩn hoặc tự động chuyển sang PASS.

## 9. Evidence Integrity và Student Review

[Final integrity checks trước tích hợp](evidence/persistence_20261114_final_checks.json) và [55-file manifest trước tích hợp](evidence/persistence_20261114_commit_manifest.json) được giữ làm historical snapshots.

[Integration review](EVIDENCE_INTEGRATION_REVIEW_20261114.md) và [63-file manifest](evidence/persistence_integration_20261114_commit_manifest.json) ghi trạng thái tại thời điểm review trước commit `879b8b4`.

Những dòng `READY FOR COMMIT`, `PENDING` hoặc `Actions NOT RUN` trong các historical snapshots không phải trạng thái hiện tại của branch đã push.

Failed/superseded experiments tiếp tục được lưu. [Attempt index](evidence/persistence_20261114_attempt_index.json) phân biệt setup errors, behavioral RED, failed trials và verbose artifacts giữ local/ignored.

**Student Review:** Sinh viên đã ghi quyết định **ACCEPT** đối với persistence fix tại [AI_USAGE_LOG.md](AI_USAGE_LOG.md).

**Reflection:** Đã cập nhật trong [REFLECTION.md](REFLECTION.md), có khai báo AI hỗ trợ. Không coi Student Review là bằng chứng sinh viên tự kiểm từng dòng patch.

## 10. Final Conclusion

**Implementation:** COMPLETED trong phạm vi VT-074.

**Automated Testing:** PASS đối với các suite mục tiêu, các regression và những kiểm tra rủi ro đã thực thi.

**Performance:** 4/4 original workloads đạt mục tiêu p95.

**Manual E2E:** Short-run PASS; long-run gần 2 MiB sau fix NOT RUN.

**Student Review:** ACCEPT.

**Reflection:** Đã cập nhật.

**GitHub Actions Linux:** SUCCESS trên commit đã kiểm chứng `1b81031`.

**Line/branch coverage:** NOT MEASURED.

**Submission:** PR và PDF còn cần hoàn thiện.

Bản triển khai đã đạt mục tiêu kỹ thuật chính của VT-074 trong phạm vi kiểm thử có bằng chứng. Không cần thêm thay đổi production chỉ để làm đẹp báo cáo. Các giới hạn được ghi rõ và historical raw evidence được giữ nguyên.
