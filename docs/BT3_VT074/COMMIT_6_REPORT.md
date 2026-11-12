# VT-074 — Commit 6: Final Evidence & Review

**READY FOR COMMIT 6 — hồ sơ/evidence sẵn sàng để sinh viên review.** Đây không phải kết luận toàn bài tập hoặc mọi NFR đạt; workload 3.600 frames vẫn FAIL, perk có ba baseline failures và các giới hạn bên dưới. Không stage/commit/push/PR/PDF.

## A. Repository và scope

Branch `feat/bt3-vt074-idempotent-run`; HEAD `becb7117eaf3c705e37946f556cc4dbe21d28c13`. Không có SHA Commit 6 vì chưa commit. Ban đầu có đúng hai saved human test edits; những lần chưa thấy diff trước đó không được ghi là hoàn thành. Production giữ nguyên bytes của C3/C4; không mutation/P-01 trong checkout.

## B. Tài liệu và code hỗ trợ

Tạo [README](README.md), [TRACEABILITY](TRACEABILITY.md), [AI_USAGE_LOG](AI_USAGE_LOG.md), [REFLECTION](REFLECTION.md), [HUMAN_TEST_EDIT_REVIEW](HUMAN_TEST_EDIT_REVIEW.md) và báo cáo này. Chỉ append phần C6 vào [AI_TEST_REVIEW](AI_TEST_REVIEW.md), giữ nguyên bản gốc v0/v1 và human decisions.

Hai test edits do sinh viên lưu: `tests/test_run_completion_contract.gd`, `tests/vt074/test_flaky_order.gd`. AI hỗ trợ runner hiện có bằng `--mode review` và selectors, dùng source/save copy cùng probe/capture cũ; legacy C4/C5 modes giữ guard và oracles lịch sử. `pairwise.py --check-only` mới chỉ tránh ghi đè evidence, không đổi model/oracle/CSV. Không tạo framework mới hoặc đổi gameplay/CI workflow.

Final file inventory, hashes, Git commands và check results ở [commit6_final_checks.json](evidence/commit6_final_checks.json). Thư mục `.godot/`, imports, bytecode và synthetic saves không thuộc danh sách commit.

## C. Human Test Review

**SATISFIED:** hai assertion call sites HT-01/HT-02 được sinh viên trực tiếp sửa/lưu, AI kiểm diff thật. Mọi original source line giữ đúng thứ tự; không delete/replace assertion. Diff có thêm snapshot/helper và một dòng trống đầu mỗi file. Original replay regression không đổi.

- HT-01 kiểm trực tiếp frozen envelope ngoài `_snapshot()`: **contract 41 PASS**, đủ CG-01…CG-40 +HT-01.
- HT-02 xác nhận replay fixture trước delete/clear: **wrapper31 PASS** mỗi full order, independent 3/14/7/5/2; original replay29 và nhóm 3/14/6/4/2 vẫn PASS.
- Vai trò được ghi đúng: AI đề xuất snippets/verification, sinh viên trực tiếp chỉnh/lưu; không nhận sinh viên tự nghĩ ra nội dung độc lập hoặc AI chứng kiến keystrokes.

[Before/after và trách nhiệm](HUMAN_TEST_EDIT_REVIEW.md), [diff thật](evidence/commit6_human_edits.patch), [source preservation JSON](evidence/commit6_human_edits_diff.json).

## D. Traceability

Matrix có AC-01…AC-05, NFR-01…NFR-03, pairwise, mutation, TIME/ORDER, negative/failure paths và integration/E2E. Các rows trỏ đúng source/evidence/SHA hoặc HEAD + working diff. 22 design cases không đồng nghĩa 22 automated executions; **14 pairwise rows chưa chạy engine**, chỉ verifier thiết kế 49/49 feasible pairs PASS. Exact writer byte cap/crash variants chưa full run; manual visual E2E NOT RUN; line/branch coverage NOT MEASURED.

## E. AI Usage Log

Log phân biệt summary prompt với prompt nguyên văn đã lưu (C1/C3), assumptions, output, student decisions và SHA. Có bốn ví dụ giới hạn có evidence: TR-01 thiếu oracle, TR-02 thiếu independence, P-01 cải thiện không đủ để giữ, và profiling copies bỏ docs làm thiếu import coverage của CSV cuối repository. Không tự nhận mọi AI output được student review line-by-line hoặc tạo transcript lịch sử giả.

## F. Reflection

Sinh viên gửi trực tiếp **343 từ** thân bài; AI lưu nguyên văn, chỉ thêm title/provenance và đếm theo whitespace, không tính tiêu đề/ghi chú. Nội dung nhất quán với RED/GREEN, R/TR và HT edits, mutation/flaky có giới hạn, heavy FAIL/P-01 REJECT, visual E2E/coverage chưa chứng minh. Test tiếp theo sinh viên chọn là manual player flow gồm restart/retry. Không tự viết reflection thay sinh viên.

## G. CI và reproducibility

GitHub xác nhận [run 43241670891](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43241670891) ở **CI-fix HEAD** PASS trên Ubuntu 26.04.1/Godot4.7.2; import 361 assets, không còn import 14 evidence CSV. Missing-font diagnostics vẫn xuất hiện. Native allocator root cause không có backtrace để chứng minh. [Remote verification](evidence/commit6_ci_check.json).

Workflow nhóm chạy original replay nhưng chưa VT74-02/contract/IT/wrapper. C6 working tree chưa push nên **C6 Actions: NOT RUN**. Smoke command đã kiểm chứng Windows, 5 suites/exit 0: [raw](evidence/commit6_55e9555814cf_smoke.json).

**Giữ `.github/workflows/ci.yml` nguyên trạng.** Log CI thực tế dùng checkout `--depth=1`; runner review cần ancestor `becb711`, nên wire ngay sẽ có nguy cơ setup failure trên shallow checkout. Runner C6 Linux chưa runtime-verified; không dùng continue-on-error để che lỗi. Proposal nhỏ cho bước review CI riêng, chưa apply:

```yaml
# Bổ sung với checkout hiện có để ancestry guard có đủ history:
with:
  fetch-depth: 0
# Sau setup Godot, thêm step riêng:
- name: VT-074 smoke with isolated saves
  run: python3 tests/vt074/run_ci_import_audit.py --godot "$(command -v godot)" --mode review --suite smoke
```

Proposal cần đánh giá chi phí fetch history và chạy Linux trước khi coi là CI-tested. Không thêm stress benchmark hoặc mutation vào CI thường xuyên.

## H. Actual results và giới hạn

| Kiểm chứng C6 | Actual | Engine / runner exit | Evidence |
| --- | --- | --- | --- |
| Review all | 30 suite invocations PASS: GREEN, contract41, IT1335, original replay8 invocations, wrapper8, boundary27, TIME20/340 | các engine0 / runner0 | [all JSON](evidence/commit6_369f4ec56761_all.json) |
| Order comparison | 124 wrapper assertions, 20 group observations; exact labels/outcomes/state bằng nhau theo group | 0 | all JSON `order_comparison` |
| Mutation copy | 27 PASS →19 PASS/8 behavioral FAIL đúng N128 →27 PASS; restore hash đúng | 0/1/0 / runner0 | [mutation JSON](evidence/commit6_6244dca6df9e_mutation.json) |
| Smoke cuối | GREEN, contract41, IT-forward445, replay29, wrapper31 đều PASS | engine0 / runner0 | smoke JSON |
| Pairwise check-only | 14 rows,49/49 feasible pairs;0 engine rows | Python0 | [pairwise JSON](evidence/commit6_pairwise_check.json) |
| Benchmark | 140 correctness-PASS batches,40 tasks/batch;4800 measured +800 warm-up; heavy FAIL | engine0 / runner1 do threshold FAIL | [benchmark JSON](evidence/commit6_77e74cc6c89b_benchmark.json) và ba raw CSV/batch files cùng prefix |

| Workload | C5 historical p95 ms | C6 fresh p95 ms | Target |
| --- | ---: | ---: | --- |
| Primary 2 frames |54.713|20.640|PASS|
| Secondary 2 frames |10.626|4.081|PASS|
| Primary 3600 frames |7235.233|5086.830|FAIL;30/30 measured batches vượt1500ms mỗi dataset|
| Secondary 3600 frames |4406.804|3773.023|FAIL;30/30 measured batches vượt1500ms mỗi dataset|

C6 giữ harness/source/workload,5 warm-up+30 measured mỗi family/frame và nearest-rank p95. 40 submissions overlap trước barrier release, xử lý tuần tự main thread; không network users/parallel writers. Chênh lệch giữa hai dataset không được quy thành optimization; P-01 vẫn REJECT và production hash không đổi. Benchmark thực tế367,52s, timeout tổng900s không thay latency threshold1500ms. C6 raw có tên mới; không sửa số đo, status hoặc logs C1–C5.

Historical mutation exits0/1/0, TIME20/340 và ORDER20 rounds/2320 vẫn nguyên. Perk **34/37 PASS,3 KNOWN BASELINE FAILURES, engine1**, đã có exact A/B C3; không rerun perk trong C6 hoặc báo whole regression PASS. Ba tên: `Player get_total_damage() increased by perk bonus`; `Berserk Frenzy raw damage scales +15% per missing HP (Expected: %.2f, Got: %.2f)`; `Completion callback invoked upon perk selection`.

Single-owner/process, finite128 receipt retention, token/digest collisions, RAM-only pending và local read-back durability còn giới hạn. Chưa chứng minh power-loss/external-writer/disk-full/crash matrix hoặc manual visual flow/line coverage. Test expected JSON parse diagnostic và inherited font import diagnostic được giữ nguyên, tách khỏi unexpected runtime/parser failures.

## I. Final readiness

**READY FOR COMMIT 6** cho gói tài liệu/evidence: human edits có diff + execution thật; reflection do sinh viên cung cấp đủ343 từ; traceability và AI log có nguồn; README có commands đã chạy và nhãn NOT VERIFIED phù hợp. Final checks kiểm scope/historical hashes/save/links/word count/Git whitespace; production không mutation/P-01, không new unexplained correctness regression. Known performance FAIL và perk baseline failures vẫn công khai; không kết luận toàn bài tập đạt mọi requirement.

Sinh viên review toàn bộ diff bằng VS Code/GitHub Desktop rồi tự quyết định commit. Message đề xuất: `docs(vt074): add reproducible evidence and AI usage report`. Không có stage/commit/push/PR/PDF/reset/merge/rebase trong phiên này.
