# VT-074 — Coverage and Risk Analysis

**Cập nhật:** 14/11/2026  
**Branch:** `feat/bt3-vt074-idempotent-run`  
**Commit đã kiểm chứng:** `1b81031`

## 1. Coverage Status

**Line coverage = NOT MEASURED.**

**Branch coverage = NOT MEASURED.**

Chưa có numerator, denominator hoặc versioned source-coverage report đáng tin cậy. Godot 4.7.2 CLI help không cung cấp coverage command tương ứng, và repository chưa cấu hình GUT, gdUnit hoặc coverage instrumentation thích hợp.

Bằng chứng kiểm tra công cụ: [coverage audit](evidence/persistence_c269529dd090_smoke.json).

Không cài dependency mới hoặc sửa production chỉ để tạo một tỷ lệ phần trăm coverage không có cơ sở. Các test cases, số lượng assertions và kết quả PASS là **behavioral evidence**, không phải line/branch coverage.

Phạm vi source:

- [GameManager.gd](../../Scene/GameManager.gd)
- [RunCompletionStore.gd](../../Scene/RunCompletionStore.gd)
- [BasePlayer.gd](../../Scene/Character/BasePlayer.gd)
- [Game Over menu](../../Menu/game%20over%20menu/game_over_menu.gd)

Các yêu cầu AC-01…AC-05 và NFR-01…NFR-03 được liên kết với bài kiểm thử trong [TRACEABILITY.md](TRACEABILITY.md). Kết quả cụ thể trong [PERSISTENCE_VERIFICATION.md](PERSISTENCE_VERIFICATION.md) và [suite matrix](evidence/persistence_20261114_suite_matrix.json).

## 2. Risk-Based Testing

| Risk | Executed witnesses / result | Residual risk |
| --- | --- | --- |
| False success / missing history | Synthetic RED với candidate JSON hợp lệ 5.116.489 bytes; compact GREEN; actual death/UI retry, ledger/history/signal assertions | Không kiểm tra trực tiếp private save trước fix; short-run human PASS nhưng near-2-MiB human gameplay chưa chạy lại |
| Long replay / data loss | 18.000 varied frames, previous history, bit-exact double values, nonzero result, full snapshot/reload/receipt/fingerprint, history recording cap 3.600 | Legacy/v2 plain JSON vẫn có giới hạn precision lịch sử; không khôi phục được những bit đã mất từ trước |
| Physical byte boundary | Chấp nhận đúng 2.097.152 bytes; từ chối 2.097.153 bytes; kiểm UTF-8/encoded size, old/missing file và incompressible data | Không bảo đảm mọi payload tương lai đều có thể nén vừa giới hạn |
| Partial IO / orphan temp | Real open/replace failures, partial write, read-back mismatch, safe cleanup và uncertain old/candidate reconcile | Chưa kiểm exhaustive disk-full, power loss hoặc external writer; unresolved uncertainty có thể giữ temporary witness |
| Duplicate/conflict/invalid | Contract/integration tests, 94 canonical cases, 26 differential scenarios, 56 cache ownership assertions | Ledger retention hữu hạn 128 receipts; expired ID không thể tự tái dựng |
| Off-by-one retention | Boundary 127/128/129 và mutation `>` → `>=`, original/mutant/restored | Chỉ kiểm một targeted mutant; không phải mutation score cho toàn bộ source |
| Flaky TIME/ORDER | 20 TIME repetitions và 20 ORDER rounds; independent fixtures, fixed clock/seed và state comparisons | Không thể khẳng định loại bỏ mọi flaky risk |
| New format/security | Bounded decompression 32 MiB, encoded file cap 2 MiB, checksum, malformed/unknown/invalid-double rejection, old-reader guard | Checksum không phải authentication; Godot build cũ không đọc được compact saves |
| Latency/performance | Cả bốn original 40-task p95 workloads PASS; đo riêng first-COMMITTED và codec cost | Long completion vẫn có thể mất vài giây; memory allocation và power-loss durability chưa đo đầy đủ |
| Integration/regression | IT-08 scene integration, actual death callback, 24 project/group invocations, 30/144 FPS traces; CI Linux SUCCESS | Human replay playback/retry riêng chưa chạy; hai ảnh Manual E2E trước restart, kết quả restart do sinh viên xác nhận |

## 3. Test Evidence Summary

| Hạng mục | Kết quả |
| --- | --- |
| AC-01…AC-05 | PASS theo executable witnesses |
| NFR-01 TIME/ORDER | PASS |
| NFR-02 Performance | PASS |
| NFR-03 Compatibility | PASS synthetic/headless |
| Pairwise | 14/14 rows, 261 assertions |
| Feasible-pair coverage | 49/49 pairs |
| Mutation | Original PASS → mutant bị phát hiện → restored PASS |
| Manual short-run | PASS |
| GitHub Actions Linux | SUCCESS trên commit `1b81031` |
| Line coverage | NOT MEASURED |
| Branch coverage | NOT MEASURED |
| Perk inherited baseline | 34/37 PASS, 3 known failures |

[Linux CI result](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43575655486)

Các kết quả PASS được giới hạn trong test và môi trường đã thực thi. Không thay thế source coverage bằng assertion counts và không gọi toàn bộ test dự án PASS khi còn ba Perk baseline failures.

## 4. Manual E2E Evidence

**Trước fix — FAIL:**

- Hero: Miya
- Seed: `ALOALO1234`
- Floor: 5
- Kills: 307
- Game Over không tạo bản ghi History
- Remote Inspector ghi nhận `SAVE_FAILED`

**Sau fix — PASS short-run:**

- Hero: Miya
- Seed: `ALOALO1234`
- Floor: 2
- Kills: 39
- Game Over hiển thị `RUN SAVED`
- Expedition History có entry mới khớp
- Sinh viên xác nhận entry vẫn còn sau khi restart

Hai ảnh Game Over và History đã được đối chiếu, nhưng đều chụp trước restart. Không có ảnh sau restart hoặc lần manual gameplay dài gần 2 MiB tương đương trước fix.

Bằng chứng: [MANUAL_E2E_VERIFICATION.md](MANUAL_E2E_VERIFICATION.md).

## 5. Giới hạn và trách nhiệm

- Pending completion chưa commit chỉ được giữ trong RAM và có thể mất nếu game thoát/crash.
- Không có bằng chứng fsync/power-loss durability tuyệt đối.
- File quá lớn hoặc không nén vừa vẫn có thể trả `SAVE_FAILED` an toàn.
- Benchmark 40 tác vụ chạy trong một tiến trình, không mô phỏng thực tế 631 người dùng đồng thời.
- Source coverage chưa đo, nhưng AC/risk traceability và regression execution đã được ghi rõ.
- Student Review persistence fix đã được sinh viên ghi **ACCEPT** trong [AI_USAGE_LOG.md](AI_USAGE_LOG.md).
- [REFLECTION.md](REFLECTION.md) đã cập nhật theo kết quả cuối, có khai báo AI hỗ trợ.

## 6. Kết luận

Các rủi ro trọng yếu của VT-074 đã được kiểm tra bằng contract, integration, regression, mutation, pairwise, TIME/ORDER, performance và manual short-run E2E.

**Technical verification: COMPLETED trong phạm vi bằng chứng đã thu thập.**

**Line/branch coverage: NOT MEASURED.**

**GitHub Actions Linux: SUCCESS trên commit `1b81031`.**

Các giới hạn còn lại được ghi rõ thay vì mặc định coi là PASS. PR và PDF nộp bài vẫn là công việc tiếp theo.

[Integration review trước khi commit](EVIDENCE_INTEGRATION_REVIEW_20261114.md) được giữ làm snapshot lịch sử, không thay thế trạng thái hiện tại.
