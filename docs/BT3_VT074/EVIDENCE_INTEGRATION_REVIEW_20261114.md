# VT-074 — tích hợp evidence và review trước commit, 14/11/2026

**READY FOR COMMIT** — persistence fix, tests và historical evidence được bảo toàn; human observation và hai ảnh thật đã tích hợp và đối chiếu. Sinh viên tự review, commit/push bằng GitHub Desktop. Readiness này không tuyên toàn bộ submission hoàn thành hoặc human approval đối với patch/reflection.

## A. Branch và HEAD

Branch `feat/bt3-vt074-idempotent-run`; HEAD `476ff8efaec5e0c09b078e86468057d40dc7013e` + working diff. Index rỗng. Không stage/commit/push/merge/reset/rebase/PR/PDF.

## B. Manual E2E và giới hạn

Đã đọc [human observation](MANUAL_E2E_OBSERVATION_20261114.md), xem trực tiếp hai ảnh thật và tích hợp vào [manual verification](MANUAL_E2E_VERIFICATION.md): Miya, `ALOALO1234`, Floor 2, 39 kills; Game Over `RUN SAVED`; Expedition History có entry khớp. Sinh viên xác nhận entry còn sau restart. **Không có ảnh sau restart được cung cấp.** Không suy ra Inspector status, duplicate count, replay/retry hoặc patch approval từ lời báo này.

Short-run: **PASS (human gameplay; screenshots + restart confirmation)**. Human near-2-MiB sau fix: **NOT RUN**. Floor 5 / 307 kills / SAVE_FAILED: **FAIL trước fix**, giữ nguyên. Ba file human evidence đã đối chiếu và đưa vào manifest kèm SHA-256/bytes:

- `docs/BT3_VT074/MANUAL_E2E_OBSERVATION_20261114.md`
- `docs/BT3_VT074/evidence/manual_e2e_20261114_gameover_run_saved.png`
- `docs/BT3_VT074/evidence/manual_e2e_20261114_history_miya_floor2.png`

Ba file chưa có khi kiểm tra ban đầu, sau đó đã xuất hiện trong checkout trong lúc review. Ảnh [Game Over](evidence/manual_e2e_20261114_gameover_run_saved.png) thể hiện RUN SAVED, Miya, ALOALO1234, Floor 2 và 39 kills; ảnh [History](evidence/manual_e2e_20261114_history_miya_floor2.png) thể hiện entry trên cùng khớp. Cả hai ảnh đều trước restart. Sinh viên xác nhận entry còn sau restart và không báo duplicate mới; không có independent full-list audit. Human replay playback sau fix NOT RUN. Không dựng observation/ảnh hoặc student approval.

## C. Regression, CI smoke, performance và integrity

- `git diff --check`: exit 0. VT-074 smoke mới: **5/5 suite invocations PASS**, runner 0, coverage audit 0; [raw](evidence/persistence_247b0a2dc1a4_smoke.json). Sandbox probe đầu tiên bị chặn root certificate store, không phải behavioral FAIL; [raw setup](evidence/persistence_5a141fdf2ac0_smoke.json). Approved retry vẫn dùng child-only userdata.
- Final regression/performance reports giữ nguyên, mọi source hash ghi trong sáu final/current reports đều khớp checkout; đối chiếu 393 suite entries với raw engine/runner exits. Target 28/59/16/48 assertions PASS. Full matrix có expected mutant exit 1 và Perk 34/37 đúng ba baseline failures; không gọi whole-project PASS. Không chạy lại full/heavy benchmark vì source/tests không đổi.
- Verifier thực chạy lại exit 0: **5.600 samples, 140 batches/snapshot hashes PASS**, tái dùng canonical C1 ZIP. p95 primary/2 = 12.146 ms, secondary/2 = 1.217 ms, primary/3600 = 411.918 ms, secondary/3600 = 802.969 ms; giữ target ≤1.500 ms. Đây là tái tính dataset cũ, không phải lần đo latency mới. Long first-COMMITTED và codec microbenchmark vẫn giữ phạm vi/giới hạn trong [verification](PERSISTENCE_VERIFICATION.md). Không có duplicate archive.
- Pairwise check-only exit 0, 49/49 feasible pairs, 14 design rows; lần check này không chạy engine rows. Line/branch coverage vẫn **NOT MEASURED**; risk/AC mapping giữ nguyên.
- Persistence codec, physical cap 2.097.152 bytes, reload compact preference, retry frozen request, death→Game Over status vẫn nguyên hash. C1 fast path và fingerprint block so HEAD không đổi. Gỡ đúng added CI persistence step khỏi workflow sẽ khớp toàn bộ workflow HEAD; tất cả test team và smoke cũ vẫn enabled. Linux GitHub Actions cho diff này **NOT RUN**.
- Toàn bộ 239 evidence files có tại đầu review giữ nguyên byte/hash; hash 26 attempt records cũ vẫn khớp. HT-01/HT-02, original tests/plan/review/reflection và historical reports không đổi. Không truy cập save/backup cá nhân.

Kết quả cũ/stale được nêu rõ:

- `persistence_77bd94a52efe_target.json`: runner 1, hai codec field-roundtrip failures trên source cũ (5 source hashes khác hiện tại); giữ raw và đưa vào inventory. Final target `8b6288391db7` PASS trên source hiện tại thay thế nó.
- `persistence_ba441018ac89_smoke.json`: runner 0 nhưng 3 source hashes cũ; smoke mới thay thế. Cả hai report này đã có tại đầu review và đã nằm trong manifest 55-file; tiếp tục giữ nguyên trong inventory mới.
- Manifest 55-file cũ có 54/54 hash kiểm được khớp tại đầu review; self-hash cố ý bỏ. Sau cập nhật, đúng 7 current docs có hash khác. Các final-check/manifest/attempt-index/suite-matrix cũ được giữ nguyên làm snapshot lịch sử; manual PENDING trong snapshot và reflection review proposal cũ đã được supersede bởi manual verification hiện tại. Không sửa raw lịch sử để làm chúng trông như kết quả mới.

## D. Danh sách chính xác để commit và loại trừ

Inventory hoàn chỉnh hiện tại: **63 files**, gồm 55 files cũ và 8 files bổ sung (ba human files, hai raw smoke attempts, review/checks/manifest mới). [Manifest mới](evidence/persistence_integration_20261114_commit_manifest.json) ghi SHA-256/bytes từng file (bỏ self-hash), cùng danh sách loại trừ. Chưa stage file nào.

Danh sách chính xác các file dự kiến commit:

- `.github/workflows/ci.yml`
- `Menu/game over menu/game_over_menu.gd`
- `Scene/Character/BasePlayer.gd`
- `Scene/GameManager.gd`
- `Scene/RunCompletionStore.gd`
- `docs/BT3_VT074/AI_USAGE_LOG.md`
- `docs/BT3_VT074/COVERAGE_AND_RISKS.md`
- `docs/BT3_VT074/EVIDENCE_INTEGRATION_REVIEW_20261114.md`
- `docs/BT3_VT074/MANUAL_E2E_OBSERVATION_20261114.md`
- `docs/BT3_VT074/MANUAL_E2E_VERIFICATION.md`
- `docs/BT3_VT074/PERSISTENCE_VERIFICATION.md`
- `docs/BT3_VT074/README.md`
- `docs/BT3_VT074/REFLECTION_REVIEW_PROPOSAL.md`
- `docs/BT3_VT074/SAVE_FAILURE_FIX_REPORT.md`
- `docs/BT3_VT074/TEST_CASES.md`
- `docs/BT3_VT074/TRACEABILITY.md`
- `docs/BT3_VT074/evidence/.gitignore`
- `docs/BT3_VT074/evidence/manual_e2e_20261114_gameover_run_saved.png`
- `docs/BT3_VT074/evidence/manual_e2e_20261114_history_miya_floor2.png`
- `docs/BT3_VT074/evidence/persistence_0d3b5e74b5dd_red.json`
- `docs/BT3_VT074/evidence/persistence_0f291bfe9f40_groups.json`
- `docs/BT3_VT074/evidence/persistence_110301a54df2_target.json`
- `docs/BT3_VT074/evidence/persistence_1a2d5fe775c9_benchmark.json`
- `docs/BT3_VT074/evidence/persistence_1a2d5fe775c9_benchmark_performance_40.csv`
- `docs/BT3_VT074/evidence/persistence_1a2d5fe775c9_benchmark_performance_batches.json`
- `docs/BT3_VT074/evidence/persistence_1a2d5fe775c9_benchmark_performance_warmup.csv`
- `docs/BT3_VT074/evidence/persistence_1d8ce204784e_codec.json`
- `docs/BT3_VT074/evidence/persistence_20261114_attempt_index.json`
- `docs/BT3_VT074/evidence/persistence_20261114_commit_manifest.json`
- `docs/BT3_VT074/evidence/persistence_20261114_final_checks.json`
- `docs/BT3_VT074/evidence/persistence_20261114_performance_verification.json`
- `docs/BT3_VT074/evidence/persistence_20261114_suite_matrix.json`
- `docs/BT3_VT074/evidence/persistence_247b0a2dc1a4_smoke.json`
- `docs/BT3_VT074/evidence/persistence_3744145f2646_all.json`
- `docs/BT3_VT074/evidence/persistence_3be3750c9470_setup_failure.json`
- `docs/BT3_VT074/evidence/persistence_4a075bff8672_benchmark.json`
- `docs/BT3_VT074/evidence/persistence_4a075bff8672_benchmark_performance_40.csv`
- `docs/BT3_VT074/evidence/persistence_4a075bff8672_benchmark_performance_batches.json`
- `docs/BT3_VT074/evidence/persistence_4a075bff8672_benchmark_performance_warmup.csv`
- `docs/BT3_VT074/evidence/persistence_4ea7fc174e35_codec.json`
- `docs/BT3_VT074/evidence/persistence_5187c946fc71_codec.json`
- `docs/BT3_VT074/evidence/persistence_5290ad85dab8_codec.json`
- `docs/BT3_VT074/evidence/persistence_54b931c50351_red.json`
- `docs/BT3_VT074/evidence/persistence_56eea881a687_groups.json`
- `docs/BT3_VT074/evidence/persistence_5a141fdf2ac0_smoke.json`
- `docs/BT3_VT074/evidence/persistence_659092fe835d_codec_probe.json`
- `docs/BT3_VT074/evidence/persistence_77bd94a52efe_target.json`
- `docs/BT3_VT074/evidence/persistence_8aa0b1588005_groups.json`
- `docs/BT3_VT074/evidence/persistence_8b6288391db7_target.json`
- `docs/BT3_VT074/evidence/persistence_9267747c8374_red.json`
- `docs/BT3_VT074/evidence/persistence_92b87d673964_target.json`
- `docs/BT3_VT074/evidence/persistence_b1d3de0954dd_target.json`
- `docs/BT3_VT074/evidence/persistence_ba441018ac89_smoke.json`
- `docs/BT3_VT074/evidence/persistence_c269529dd090_smoke.json`
- `docs/BT3_VT074/evidence/persistence_integration_20261114_checks.json`
- `docs/BT3_VT074/evidence/persistence_integration_20261114_commit_manifest.json`
- `tests/vt074/run_persistence_review.py`
- `tests/vt074/test_codec_cost.gd`
- `tests/vt074/test_codec_recovery.gd`
- `tests/vt074/test_death_persistence.gd`
- `tests/vt074/test_long_persistence.gd`
- `tests/vt074/test_writer_bytes.gd`
- `tests/vt074/verify_persistence_performance.py`

Loại trừ nguyên trạng **32 generated untracked files**:

- `Scene/RunCompletionStore.gd.uid`
- `tests/test_run_completion_contract.gd.uid`
- `tests/test_run_completion_idempotency.gd.uid`
- `tests/test_vt074_integration.gd.uid`
- `tests/vt074/fixtures/integration_entry.gd.uid`
- `tests/vt074/fixtures/integration_store.gd.uid`
- `tests/vt074/pairwise_cases.csv.import`
- `tests/vt074/pairwise_cases.execution.translation`
- `tests/vt074/pairwise_cases.expected.translation`
- `tests/vt074/pairwise_cases.identity.translation`
- `tests/vt074/pairwise_cases.ledger.translation`
- `tests/vt074/pairwise_cases.payload.translation`
- `tests/vt074/pairwise_cases.storage.translation`
- `tests/vt074/pairwise_cases.test.translation`
- `tests/vt074/performance_harness.gd.uid`
- `tests/vt074/profile_trace.gd.uid`
- `tests/vt074/quality_entry.gd.uid`
- `tests/vt074/quality_fixture.gd.uid`
- `tests/vt074/test_boundary_mutation.gd.uid`
- `tests/vt074/test_codec_cost.gd.uid`
- `tests/vt074/test_codec_recovery.gd.uid`
- `tests/vt074/test_death_persistence.gd.uid`
- `tests/vt074/test_flaky_order.gd.uid`
- `tests/vt074/test_flaky_time.gd.uid`
- `tests/vt074/test_heavy_comparison.gd.uid`
- `tests/vt074/test_heavy_equivalence.gd.uid`
- `tests/vt074/test_heavy_tradeoff_ownership.gd.uid`
- `tests/vt074/test_heavy_tradeoff_profile.gd.uid`
- `tests/vt074/test_long_persistence.gd.uid`
- `tests/vt074/test_p01_equivalence.gd.uid`
- `tests/vt074/test_pairwise.gd.uid`
- `tests/vt074/test_writer_bytes.gd.uid`

Giữ local/ignored, không commit bốn verbose/superseded raw attempts:

- `docs/BT3_VT074/evidence/persistence_0491df7b9512_all.json`
- `docs/BT3_VT074/evidence/persistence_55abd199c630_all.json`
- `docs/BT3_VT074/evidence/persistence_9a72db772462_red.json`
- `docs/BT3_VT074/evidence/persistence_e3d38e6870b9_target.json`

Loại trừ mọi `.godot/`, `__pycache__/`, synthetic userdata/temp/helper scripts, save/backup cá nhân và duplicate archives. Không tạo ZIP mới. Không xóa các file bị loại trừ.

## E. Blockers và việc còn lại

**Không phát hiện blocker kỹ thuật hoặc thiếu evidence cho commit trong phạm vi review này.** Ba file human evidence đã có và đã đối chiếu. Source/tests/CI không đổi so với final regression; quick checks và verifier PASS. Index vẫn rỗng; sinh viên thực hiện commit/push bằng GitHub Desktop.

Các giới hạn còn công khai: human near-2-MiB NOT RUN; không có ảnh sau restart; human replay playback NOT RUN; Linux Actions cho patch chưa chạy; student reflection/review patch mới chưa được cung cấp. Không giả lập reflection/approval và không relabel các việc chưa chạy thành PASS. Đây là việc còn lại cho validation/submission, không phải kết quả đã hoàn thành trong review này.

## F. Quyết định

**READY FOR COMMIT** đối với persistence fix và gói evidence trong manifest 63-file. Chưa stage/commit/push/merge/reset/rebase/PR/PDF. Dừng sau review; sinh viên tự commit và push, rồi đối chiếu Actions với SHA mới. [Machine-readable checks](evidence/persistence_integration_20261114_checks.json).
