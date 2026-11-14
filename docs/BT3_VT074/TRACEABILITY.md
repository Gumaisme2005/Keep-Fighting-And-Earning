# VT-074 — Requirement Traceability

**Cập nhật:** 14/11/2026  
**Branch:** `feat/bt3-vt074-idempotent-run`  
**Commit đã kiểm chứng:** `1b81031`  
**Trạng thái:** Technical verification completed; PR/PDF pending.

[Requirement audit và exact counters](PERSISTENCE_VERIFICATION.md) là nguồn tổng hợp kết quả. Mỗi trạng thái PASS chỉ áp dụng cho những test và trường hợp thực sự đã chạy. Không coi 22 test cases thiết kế là 22 automated tests độc lập.

## 1. AC/NFR → Test → Evidence → Result

| AC/NFR/risk | Executable witnesses | Kết quả và bằng chứng |
| --- | --- | --- |
| AC-01 — First completion | VT74-02, CG-03/37, IT-08, actual death path | **PASS** — Một result/receipt/signal sau commit. [Raw all](evidence/persistence_3744145f2646_all.json), [raw target](evidence/persistence_8b6288391db7_target.json). |
| AC-02 — Duplicate/frozen request | CG-04…08, HT-01, IT-02/03/06/07, long/codec reload-tail-conflict | **PASS** — Giữ nguyên ID, envelope, date và fingerprint; retry không tăng writer/signal hoặc đổi FIFO. [Raw all](evidence/persistence_3744145f2646_all.json), [raw target](evidence/persistence_8b6288391db7_target.json). |
| AC-03 — Distinct session IDs | CG-18…20/39, IT-05/08, replay source/fallback | **PASS** — Hai run có cùng seed/date nhưng khác ID vẫn độc lập. [Raw all](evidence/persistence_3744145f2646_all.json). |
| AC-04 — Invalid/unknown/conflict | IT-01/02, CG-07…12/40, secondary benchmark | **PASS** — Có kiểm tra 8 biến thể ID, 19 payload không hợp lệ, canonical conflicts và zero side effects. [Raw all](evidence/persistence_3744145f2646_all.json). |
| AC-05 — Persistence/failure | IT-03/04/06/07, CG-13…36, long-session/byte/codec tests | **PASS** — IO failure, size cap, restart/reload, pending retry và uncertainty. [Raw all](evidence/persistence_3744145f2646_all.json), [raw target](evidence/persistence_8b6288391db7_target.json). |
| AC-05 — Retention | Boundary N=127/128/129 và mutation | **PASS** — Chỉ prune ở 129; mutation bị phát hiện bằng 8 behavioral failures. [Raw all](evidence/persistence_3744145f2646_all.json). |
| NFR-01 — TIME/ORDER | test_flaky_time.gd, HT-02, independent replay order/groups | **PASS** — 20 lượt TIME và 20 lượt ORDER, có đối chiếu assertions và end-state. [Raw all](evidence/persistence_3744145f2646_all.json). |
| NFR-02 — Performance/C1 | performance_harness.gd, ownership và differential checks | **PASS** — Bốn workload đạt p95 ≤1.500 ms. [Raw benchmark](evidence/persistence_4a075bff8672_benchmark.json), [raw all](evidence/persistence_3744145f2646_all.json). |
| NFR-03 — Compatibility | legacy/v2, compact, varied controls, old-reader guard, IT-08 | **PASS synthetic/headless** — Kiểm tra backward compatibility và replay/retry. [Raw target](evidence/persistence_8b6288391db7_target.json), [raw all](evidence/persistence_3744145f2646_all.json). |
| Pairwise | PW-01…PW-14 và feasible-pair verifier | **PASS** — 14/14 rows, 261 assertions, 49/49 feasible pairs. [Raw all](evidence/persistence_3744145f2646_all.json). |
| Manual gameplay | Miya, ALOALO1234; trước fix Floor 5/307 kills; sau fix Floor 2/39 kills | **PASS short-run sau fix** — RUN SAVED, History khớp, restart được sinh viên xác nhận. Historical SAVE_FAILED vẫn giữ; human near-2-MiB NOT RUN. [Manual verification](MANUAL_E2E_VERIFICATION.md). |
| Measured line/branch coverage | Tool/instrumentation audit | **NOT MEASURED** — Không có coverage instrumentation đáng tin cậy. [Coverage audit](evidence/persistence_c269529dd090_smoke.json). |
| Perk regression | So khớp baseline errors và outcomes | **34/37 PASS, 3 KNOWN BASELINE FAILURES** — Không coi là whole-project PASS. [Raw all](evidence/persistence_3744145f2646_all.json). |
| CI | Original project tests, VT-074 Smoke, persistence/death/byte regression | **SUCCESS** — Local Windows checks PASS và GitHub Actions Linux SUCCESS trên commit `1b81031`. [Linux Actions](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43575655486), [local smoke](evidence/persistence_247b0a2dc1a4_smoke.json), [local groups](evidence/persistence_56eea881a687_groups.json). |

## 2. Human Review và AI Provenance

| Yêu cầu | Bằng chứng | Trạng thái |
| --- | --- | --- |
| Original AI plan | [AI_IMPLEMENTATION_PLAN.md](AI_IMPLEMENTATION_PLAN.md) | Có |
| Human plan review R-01/R-02 | [AI_PLAN_REVIEW.md](AI_PLAN_REVIEW.md) | MODIFY |
| Human test review TR-01/TR-02 | [AI_TEST_REVIEW.md](AI_TEST_REVIEW.md) | MODIFY |
| Student-edited tests HT-01/HT-02 | [Human edit review](HUMAN_TEST_EDIT_REVIEW.md), [before/after patch](evidence/commit6_human_edits.patch), [diff check](evidence/commit6_human_edits_diff.json) | PASS |
| Student Review persistence fix | [AI_USAGE_LOG.md](AI_USAGE_LOG.md), [review commit](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/commit/7c01d3ed14408e73d5d19691995754484db45245) | ACCEPT |
| Reflection | [REFLECTION.md](REFLECTION.md) | Đã cập nhật |
| AI usage disclosure | [AI_USAGE_LOG.md](AI_USAGE_LOG.md) | Đã cập nhật |

Nhận xét và Reflection có sự hỗ trợ soạn thảo của AI. Sinh viên xác nhận quyết định ACCEPT trên GitHub; không suy ra đã tự kiểm từng dòng code hoặc tự viết mọi nội dung không có hỗ trợ AI.

## 3. Giới hạn kiểm chứng

- 22 test cases là catalog thiết kế; số assertions và suite invocations được ghi riêng.
- Manual short-run đã PASS, nhưng lượt chơi dài tương đương Floor 5/307 kills chưa được thử lại thủ công sau fix.
- Hai ảnh Manual E2E được chụp trước restart; kết quả sau restart dựa trên xác nhận của sinh viên.
- Line/branch coverage chưa đo; AC/risk mapping là bằng chứng kiểm thử hành vi, không phải tỷ lệ source coverage.
- Ba Perk baseline failures vẫn tồn tại.
- Performance harness chạy 40 tác vụ chồng lấp trong một tiến trình, không phải 631 người dùng thực.
- Bằng chứng Linux CI được gắn với commit cụ thể; không tự động suy ra các commit tương lai cũng PASS.

[Exact suite matrix](evidence/persistence_20261114_suite_matrix.json) lưu kết quả theo từng invocation và raw exit code. [Verification tổng hợp](PERSISTENCE_VERIFICATION.md) giải thích số đo, failed experiments và cách tái lập.

**Kết luận:** Các AC/NFR và rủi ro trọng yếu của VT-074 đã có bằng chứng kiểm thử phù hợp trong phạm vi xác minh. Student Review và Reflection đã hoàn thành; PR và PDF còn cần thực hiện.
