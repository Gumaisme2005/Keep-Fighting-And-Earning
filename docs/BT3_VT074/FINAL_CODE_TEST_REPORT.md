# BT3 – VT-074: kết quả tiếp tục và gate cho commit cuối

Cập nhật ngày **14/11/2026, Asia/Saigon**. Branch `feat/bt3-vt074-idempotent-run`; HEAD `8db06a56720d7f2bbe359c908eb55950b8d208c8`. Khi tiếp tục có **20 file local chưa commit**; không bắt đầu từ working tree sạch. Không stage, commit, push, merge, tạo PR hoặc PDF. Phụ lục cuối giữ nguyên báo cáo trước; kết luận hiện tại ở A–G dưới đây thay thế kết luận cũ.

## A. Performance root cause và candidate diff

Duplicate heavy trước đây vẫn canonicalize/validate toàn bộ frames và serialize tuple để SHA-256 mỗi lần retry. Với 40 submissions chờ cùng barrier, service này tích lũy thành queue wait. Profiling lịch sử đo canonical inclusive khoảng 63,303 ms và fingerprint 26,488 ms; không cộng inclusive spans lồng nhau như self time.

Trial mới đo riêng 20 iterations sau 3 warm-up: canonicalization + fingerprint **71,138 ms**, structural equality **3,289 ms**, 87 assertions PASS. Số cũ 89,16/3,71 ms vẫn giữ trong [trial 4992759f992a](evidence/heavy_4992759f992a_compare.json); không trộn hai lần đo. Microbenchmark này chỉ chẩn đoán, không phải acceptance benchmark.

[Candidate patch](evidence/heavy_1a3b68d5d730_candidate.patch) thêm một cache owner-local chứa bản sao payload đã canonicalize và fingerprint. Dictionary payload, Array frames và mọi Dictionary frame đều read-only; không alias caller, envelope hoặc history; không persist cache. Cache bị xóa khi mở run mới hoặc load thành công. Fast path chỉ chạy với storage READY, writer không bận, run CLOSED, đúng active token/cache token, receipt còn trong ledger và fingerprint khớp, payload Dictionary bằng hoàn toàn cache. Các trường hợp khác vẫn dùng validation/canonicalization/hash gốc.

Giữ nguyên deep copies, tuple loop, sanitizer, receipt schema, frozen envelope và persistence. Không dùng P-01 đã bị loại. **Candidate chỉ nằm trong project copy `.godot/`; `Scene/GameManager.gd` production chưa đổi.** Original SHA-256 `ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe`; candidate `85f0aa28dca74f73c3c7f60cd023c83adbcce24754e1399d76d89343b93968de`.

## B. ABBA p95 BEFORE/AFTER

Godot `4.7.2.stable.official.ed1daf0bf`, Windows 11, không instrumentation. Thứ tự thực tế: **BEFORE_A → AFTER_A → AFTER_B → BEFORE_B**. Giữ nguyên harness/workload: 40 overlapping submissions, 5 warm-up + 30 measured batches cho mỗi workload trong mỗi lượt. Primary: 1 COMMITTED + 39 DUPLICATE; secondary: 20 DUPLICATE + 10 CONFLICT + 10 INVALID_REQUEST trên owner đã precommit. Không giảm frames, submissions hoặc validation để đạt target.

Tổng **560 batches, 19.200 measured + 3.200 warm-up records**. Mỗi ô pooled gồm 2.400 measured requests; p95 nearest-rank index 2279. P95 từng lượt dùng 1.200 requests/index 1139, từng batch dùng 40/index 37. Latency là **submit → finish, gồm barrier/queue wait, validation/hash và persistence**. Target 1.500 ms; kiểm cả pooled workload lẫn từng measured batch.

| Workload | Frames | BEFORE pooled p95 ms | AFTER pooled p95 ms | Giảm | AFTER batches vượt target /60 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Primary | 2 | 14,953 | 4,107 | 72,53% | 0 |
| Secondary | 2 | 2,612 | 1,189 | 54,48% | 0 |
| Primary | 3600 | 3785,490 | 621,627 | 83,58% | 0 |
| Secondary | 3600 | 3229,892 | 1207,852 | 62,60% | 0 |

| Workload / frames | BEFORE_A | AFTER_A | AFTER_B | BEFORE_B |
| --- | ---: | ---: | ---: | ---: |
| Primary / 2 | 16,164 | 3,989 | 4,247 | 6,534 |
| Secondary / 2 | 2,589 | 1,176 | 1,193 | 2,755 |
| Primary / 3600 | 3991,550 | 601,124 | 635,058 | 2991,642 |
| Secondary / 3600 | 3284,853 | 1196,772 | 1257,972 | 2201,660 |

Đơn vị ms. **Candidate p95 PASS cả bốn workloads, mọi measured batch PASS. Baseline heavy FAIL 60/60 batches mỗi family.** Baseline drift đáng kể giữa A/B; đây là phép đo trên workstation, không phải ước lượng nhân quả đã kiểm soát mọi background load. Cải thiện end-to-end vẫn rõ ở cả hai candidate runs so với cả hai baseline runs.

Raw evidence: [benchmark commands/stdout/stderr/metrics](evidence/heavy_1a3b68d5d730_benchmark.json), [verification](evidence/heavy_1a3b68d5d730_verification.json), 12 CSV/batch files và 4 snapshot archives mang prefix `heavy_1a3b68d5d730_`. Verifier đã giải nén lại **560 real saves** và đối chiếu 140 batch IDs: snapshot bytes tương ứng **giống nhau trên cả bốn lượt**. Không phụ thuộc việc giữ lại save trong ignored work directory để kiểm raw evidence.

## C. Correctness và regression

[Differential validation](evidence/heavy_1a3b68d5d730_validate.json): **26 scenarios / 1.051 assertions PASS, 0 FAIL**; canonical/alias suite thêm **94 cases / 284 assertions PASS**. Hai real GameManager scripts và real stores chạy cùng trace; so status, receipt/fingerprint, history, ledger, disk, counters, envelope và lifecycle.

Phủ exact heavy duplicates; scalar và frame đầu/giữa/cuối conflict; invalid identity/payload/types/NaN/Inf; unknown nested metadata và known nested invalid; caller mutation sau commit; returned receipt mutation; frozen adapter/recording mutation; retry sau reload kể cả 3.600 frames; open/replace save failure và safe retry; storage uncertain/reconciliation; writer busy; reentrant callback/new run; history deletion; legacy migration; FIFO tại 127/128/129. Cache không được dùng để vượt storage/validation guards.

| Phần | Checkout gốc | Candidate cô lập |
| --- | --- | --- |
| All VT-074 | 31 invocations PASS | 31 invocations PASS |
| Pairwise | 14 cases / 261 assertions PASS | 14 cases / 261 assertions PASS |
| Contract | 41 PASS, gồm HT-01 | 41 PASS, gồm HT-01 |
| Integration | forward/reverse 445 mỗi lượt, 8 IT riêng tổng 445 | cùng counts, PASS |
| Replay + HT-02 | đủ order/group, state comparison equal | cùng counts, PASS |
| Boundary | 27 PASS tại 127/128/129 | 27 PASS |
| TIME | 20 iterations / 340 assertions PASS | cùng counts, PASS |
| Mutation thủ công | evidence cũ giữ nguyên | 27 PASS → 19 PASS/8 FAIL → 27 PASS; oracle PASS |
| Perk | baseline lịch sử 34/37 | chạy lại 34/37; đúng 3 KNOWN BASELINE FAILURES |

[Checkout all](evidence/vt074_final_942e400cf5a4_all.json) runner exit 0; [candidate regression](evidence/heavy_1a3b68d5d730_regression.json) runner exit 0 với **34 oracle invocations PASS** và perk được phân loại riêng. Không có functional regression mới trong phạm vi đã chạy. Không tuyên whole-project regression PASS vì perk còn 3 lỗi baseline. IT-04 chỉ chấp nhận đúng diagnostic JSON hỏng kèm marker/assertion LOAD_ERROR; không bỏ qua lỗi tùy ý.

**Gate “không có regression mới” về performance chưa được xác lập:** heavy first-COMMITTED service mean **345,155 → 455,496 ms (+31,97%)**, service p95 **457,592 → 510,920 ms (+11,65%)**, 60 commits/variant. Secondary heavy CONFLICT service mean cũng tăng **88,378 → 103,005 ms** trong khi đi fallback gốc. Workstation drift có thể góp phần; không quy toàn bộ phần tăng cho cache. Cache thêm một deep copy khi đóng băng payload và giữ thêm một payload trong RAM; overhead bộ nhớ chưa đo. Vì vậy không đề xuất giữ fix vô điều kiện chỉ từ pooled p95 đẹp.

## D. Pairwise 14 cases và CI smoke

| Row | Expected = actual | Result |
| --- | --- | --- |
| PW-01 | COMMITTED | PASS |
| PW-02 | COMMITTED | PASS |
| PW-03 | DUPLICATE | PASS |
| PW-04 | INVALID_REQUEST | PASS |
| PW-05 | UNKNOWN_RUN | PASS |
| PW-06 | UNKNOWN_RUN | PASS |
| PW-07 | CONFLICT | PASS |
| PW-08 | INVALID_REQUEST | PASS |
| PW-09 | UNKNOWN_RUN | PASS |
| PW-10 | UNKNOWN_RUN | PASS |
| PW-11 | COMMITTED | PASS |
| PW-12 | DUPLICATE | PASS |
| PW-13 | INVALID_REQUEST | PASS |
| PW-14 | UNKNOWN_RUN | PASS |

Chạy GameManager thật, setup bằng completion thật, reload bằng owner mới, kiểm disk bytes và FIFO/eviction. `pairwise.py --check-only` cũng PASS **49/49 feasible pairs**; `engine_rows_executed: 0` trong structural verifier vẫn được giữ đúng nghĩa, không dùng làm kết quả behavioral test.

[Smoke Windows mới](evidence/vt074_final_9f75c585fc5c_smoke.json): **5/5 PASS**, gồm GREEN, contract 41, integration forward 445, replay 29, HT-02 wrapper 31. CI diff chỉ thêm `fetch-depth: 0` và bước VT-074 smoke; mọi bước test cũ giữ nguyên thứ tự/nội dung. Không stress benchmark/mutation trong CI mặc định. **Linux/GitHub Actions của patch mới NOT VERIFIED**; không dùng CI PASS lịch sử để khẳng định patch này PASS trên Linux.

## E. File nên giữ cho một commit bổ sung

Giữ toàn bộ 20 file local có từ đầu, bổ sung runner/verifier và raw evidence mới. Chưa stage bất kỳ file nào. Không có production file trong danh sách. Candidate giữ dưới dạng `.patch`; dữ liệu ZIP là real synthetic save witnesses cần cho portable verifier, không phải asset packs. `.gitignore` trong evidence chỉ mở ngoại lệ `heavy_*_snapshots.zip`. Không xóa attempt lỗi để che lịch sử.

<!-- FINAL_COMMIT_FILES -->

**48 files** (khong gom ignored cache/save):

- `.github/workflows/ci.yml`
- `docs/BT3_VT074/FINAL_CODE_TEST_REPORT.md`
- `docs/BT3_VT074/README.md`
- `docs/BT3_VT074/evidence/.gitignore`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_AFTER_A_performance_40.csv`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_AFTER_A_performance_batches.json`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_AFTER_A_performance_warmup.csv`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_AFTER_A_snapshots.zip`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_AFTER_B_performance_40.csv`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_AFTER_B_performance_batches.json`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_AFTER_B_performance_warmup.csv`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_AFTER_B_snapshots.zip`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_BEFORE_A_performance_40.csv`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_BEFORE_A_performance_batches.json`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_BEFORE_A_performance_warmup.csv`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_BEFORE_A_snapshots.zip`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_BEFORE_B_performance_40.csv`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_BEFORE_B_performance_batches.json`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_BEFORE_B_performance_warmup.csv`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_BEFORE_B_snapshots.zip`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_benchmark.json`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_candidate.patch`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_compare.json`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_regression.json`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_validate.json`
- `docs/BT3_VT074/evidence/heavy_1a3b68d5d730_verification.json`
- `docs/BT3_VT074/evidence/heavy_4992759f992a_candidate.patch`
- `docs/BT3_VT074/evidence/heavy_4992759f992a_compare.json`
- `docs/BT3_VT074/evidence/heavy_4992759f992a_validate.json`
- `docs/BT3_VT074/evidence/heavy_4992759f992a_validate_attempt2.json`
- `docs/BT3_VT074/evidence/heavy_ddd21c5696b8_compare.json`
- `docs/BT3_VT074/evidence/vt074_final_0084cf203d62_smoke.json`
- `docs/BT3_VT074/evidence/vt074_final_25f705a64d37_pairwise.json`
- `docs/BT3_VT074/evidence/vt074_final_315966019bc5_all.json`
- `docs/BT3_VT074/evidence/vt074_final_43b00db1e9d0_pairwise.json`
- `docs/BT3_VT074/evidence/vt074_final_942e400cf5a4_all.json`
- `docs/BT3_VT074/evidence/vt074_final_9f75c585fc5c_smoke.json`
- `docs/BT3_VT074/evidence/vt074_final_checks.json`
- `docs/BT3_VT074/evidence/vt074_final_d76dba213bfa_pairwise.json`
- `docs/BT3_VT074/evidence/vt074_final_e8bf00df8fd7_pairwise.json`
- `docs/BT3_VT074/evidence/vt074_final_pairwise.log`
- `docs/BT3_VT074/evidence/vt074_resume_final_checks.json`
- `tests/vt074/run_ci_import_audit.py`
- `tests/vt074/run_heavy_trial.py`
- `tests/vt074/test_heavy_comparison.gd`
- `tests/vt074/test_heavy_equivalence.gd`
- `tests/vt074/test_pairwise.gd`
- `tests/vt074/verify_heavy_trial.py`

<!-- END_FINAL_COMMIT_FILES -->

Các trial project, original/candidate `.gd` copies, probes, sentinel, import cache, temporary extraction và saves dưới ignored `.godot/` không đưa vào commit. Không xóa file tạm thuộc công việc trước. Attempt `heavy_ddd21c5696b8_compare.json` giữ lỗi sandbox certificate-store; rerun ngoài sandbox thành công. Các attempt pairwise cũ và validate đầu tiên vẫn được giữ cùng lý do trong phụ lục.

## F. Giới hạn và integrity

- Chưa áp dụng candidate production. Production hiện tại vẫn có heavy p95 FAIL theo baseline; PASS trong B chỉ thuộc candidate cô lập.
- First-commit/fallback service-time tăng quan sát được, baseline drift và memory overhead chưa tách rõ; chưa đáp ứng gate không regression performance để khuyến nghị giữ fix vô điều kiện.
- Linux/Actions mới, manual visual/gameplay E2E chưa chạy; line/branch coverage chưa đo. Perk vẫn 3 lỗi baseline.
- 40 overlapping submissions là single-process serialized main-thread execution, không phải 40 parallel network users. Không suy local single-writer/read-back thành power-loss durability hoặc distributed exactly-once.
- Mỗi Godot invocation có child APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP và isolation probe/sentinel trước autoload. Personal save giữ SHA-256 `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`.
- [Final resume checks](evidence/vt074_resume_final_checks.json) lưu branch/HEAD, index, danh sách file, hash/integrity, workflow preservation và whitespace checks. Giữ nguyên Commit 1–6, production, harness, CSV và evidence đã tracked từ HEAD. README/report chỉ cập nhật kết quả cuối; không viết lại evidence lịch sử.

## G. Kết luận

**NOT READY FOR FINAL COMMIT để tuyên bố kết thúc toàn bộ phát triển BT3.** Test/CI/evidence đã sẵn sàng review; heavy candidate đạt p95 target và correctness nhưng chưa được duyệt production, còn quan sát first-commit service tăng nên chưa thể xác nhận gate “không regression mới” về performance. Không tự áp dụng candidate hoặc tự nới tiêu chí. Cần người dùng quyết định chấp nhận trade-off, yêu cầu kiểm chứng/điều chỉnh thêm, hoặc chốt phạm vi test/CI/evidence với production heavy NFR còn FAIL.

Dừng ở diff và evidence cụ thể để người dùng kiểm tra. Chưa stage/commit/push/merge/tạo PR/PDF.

---

# Phụ lục: báo cáo trước khi tiếp tục (13/11/2026)

Nội dung dưới đây giữ nguyên provenance của 13 file pairwise/CI ban đầu. Các câu “không thử optimization mới”, “working tree ban đầu sạch” và READY trong phụ lục chỉ mô tả lượt trước, đã được cập nhật bằng kết quả A–G phía trên.

# VT-074 — Final code & test improvements

Ngày 13/11/2026 (Asia/Saigon). Branch `feat/bt3-vt074-idempotent-run`, HEAD giữ nguyên `8db06a56720d7f2bbe359c908eb55950b8d208c8`; working tree ban đầu sạch. Godot `4.7.2.stable.official.ed1daf0bf`, Python 3.14, Windows 11. Đây là diff cho tối đa một commit bổ sung, chưa stage/commit/push/merge/tạo PR.

## A. Files changed

- `tests/vt074/test_pairwise.gd`: runner Godot mới, tái sử dụng quality fixture và real counting store; không mô phỏng GameManager.
- `tests/vt074/run_ci_import_audit.py`: thêm suite pairwise vào `all`, kiểm đủ row/assertion/summary, copy cả test mới chưa stage, kiểm integrity nguồn đã copy, kiểm version trước import; evidence mới dùng prefix `vt074_final_`.
- `.github/workflows/ci.yml`: thêm `fetch-depth: 0` và một bước smoke VT-074; các bước cũ giữ nguyên.
- `docs/BT3_VT074/README.md` và báo cáo này: hướng dẫn chạy, kết quả và giới hạn hiện tại.
- Evidence mới: [all JSON](evidence/vt074_final_315966019bc5_all.json), [smoke JSON](evidence/vt074_final_0084cf203d62_smoke.json), [pairwise log](evidence/vt074_final_pairwise.log), [final checks](evidence/vt074_final_checks.json) và bốn JSON attempt bên dưới. Không có cache/temp trong diff.

Không đổi production, CSV lịch sử, specification, test gameplay hoặc evidence đã tracked ở HEAD.

## B. Pairwise

**14 PASS / 0 FAIL; 261 assertions PASS / 0 FAIL; engine exit 0, runner oracle PASS.** Python `pairwise.py --check-only` cũng exit 0, 49/49 feasible pairs; số `engine_rows_executed: 0` của verifier cấu trúc vẫn được giữ đúng chức năng lịch sử, không được dùng làm kết quả Godot.

| Row | Expected | Actual | Result |
| --- | --- | --- | --- |
| PW-01 | COMMITTED | COMMITTED | PASS |
| PW-02 | COMMITTED | COMMITTED | PASS |
| PW-03 | DUPLICATE | DUPLICATE | PASS |
| PW-04 | INVALID_REQUEST | INVALID_REQUEST | PASS |
| PW-05 | UNKNOWN_RUN | UNKNOWN_RUN | PASS |
| PW-06 | UNKNOWN_RUN | UNKNOWN_RUN | PASS |
| PW-07 | CONFLICT | CONFLICT | PASS |
| PW-08 | INVALID_REQUEST | INVALID_REQUEST | PASS |
| PW-09 | UNKNOWN_RUN | UNKNOWN_RUN | PASS |
| PW-10 | UNKNOWN_RUN | UNKNOWN_RUN | PASS |
| PW-11 | COMMITTED | COMMITTED | PASS |
| PW-12 | DUPLICATE | DUPLICATE | PASS |
| PW-13 | INVALID_REQUEST | INVALID_REQUEST | PASS |
| PW-14 | UNKNOWN_RUN | UNKNOWN_RUN | PASS |

Mỗi row đọc trực tiếp factors/expected từ CSV và có save riêng dưới `user://vt074_final/pairwise/PW-xx/`. Setup dùng 4/128/129 completion thật, kiểm FIFO chính xác và writer/signals. `overflow_129` thực hiện completion thứ 129, không inject ledger; PW-09/PW-10 kiểm oldest đã được cấp rồi bị eviction và không phải active token.

`after_reload` giải phóng owner cũ, tạo GameManager mới đọc lại cùng file, kiểm full snapshot, CLOSED/ID rỗng, không write/signal. PW-02 gọi `start_new_run()` sau reload để cấp token OPEN mới. Payload different tăng kills thực tế; các rejection/duplicate phải giữ full snapshot, buffers, disk hash, writer/temp/replace và signals. COMMITTED kiểm insertion/retention, payload trong history/receipt, last recording, một transaction/một signal, full disk bytes và immediate retry không side effects. Không sửa `PLANNED AFTER PATCH` trong CSV.

[Log từng assertion và PW-01…PW-14](evidence/vt074_final_pairwise.log) được trích nguyên stdout/stderr của step `pairwise` trong all JSON. Giá trị synthetic dài được so đầy đủ trước khi log digest, như integration hiện có; save fixture còn ở ignored work directory.

Các attempt mới không bị xóa/viết lại để che FAIL:

- [25f705a64d37](evidence/vt074_final_25f705a64d37_pairwise.json), [43b00db1e9d0](evidence/vt074_final_43b00db1e9d0_pairwise.json): console binary trong Downloads exit bất thường; isolation probe chặn trước test.
- [e8bf00df8fd7](evidence/vt074_final_e8bf00df8fd7_pairwise.json): binary Desktop đúng version nhưng sandbox không đọc được Windows certificate store; clean import bị chặn. Sau đó chạy ngoài sandbox với save cô lập.
- [d76dba213bfa](evidence/vt074_final_d76dba213bfa_pairwise.json): 14 statuses đúng nhưng 14 disk assertions FAIL do oracle mới so Dictionary JSON float với RAM int. Đã sửa oracle thành so toàn bộ bytes với serialized snapshot, đúng định dạng real writer; không đổi SUT hay bỏ kiểm tra disk. Kết quả PASS chỉ lấy từ lần chạy all sau sửa.

## C. CI smoke

Bước `VT-074 Smoke (GREEN, Contract, Integration, Replay HT-02)` chạy:

```bash
python3 tests/vt074/run_ci_import_audit.py --godot "$(command -v godot)" --mode review --suite smoke
```

`fetch-depth: 0` cung cấp history cho ancestry guard. Linux đặt child `XDG_DATA_HOME`, probe `OS.get_user_data_dir()`/sentinel trước autoload; mỗi invocation có user directory mới. Không thêm mutation/benchmark vào smoke, không `continue-on-error`, không xóa/sửa assertions CI cũ.

**Đã chạy cùng chế độ smoke trên Windows: 5/5 PASS, engine exits 0, runner exit 0.** GREEN, contract 41, integration forward 445, replay 29, HT-02 wrapper 31 đều được runner xác minh. **Linux và GitHub Actions cho patch này: NOT VERIFIED**; chờ Actions sau khi sinh viên review/push. Không dùng CI PASS lịch sử để tuyên bố patch mới đã PASS trên Linux.

## D. Performance review

**Giữ nguyên production và harness; không thử optimization mới, không chạy lại benchmark trong lượt bổ sung này.** Profiling cũ đo heavy duplicate canonical inclusive khoảng 63,303 ms, fingerprint khoảng 26,488 ms/request; queue tích lũy lớn. Các span inclusive lồng nhau, không cộng chúng như self time. Xem [profiling](evidence/profiling_bc35f2123463_summary.md).

[P-01 REJECT](P01_TRIAL_REPORT.md): primary-heavy ABBA p95 3100,156 → 2865,805 ms, cải thiện 7,56%, dưới tiêu chí giữ 10% đặt trước; heavy vẫn vượt target. Chưa có phương án mới đủ bằng chứng lợi ích/an toàn để thay đổi production trong phạm vi này.

Số đo thực tế gần nhất, giữ provenance [benchmark C6](evidence/commit6_77e74cc6c89b_benchmark.json), không phải số đo mới:

| Workload | Frames | Pooled p95 (ms) | Target ≤ 1500 ms |
| --- | ---: | ---: | --- |
| Primary | 2 | 20,640 | PASS |
| Secondary | 2 | 4,081 | PASS |
| Primary | 3600 | 5086,830 | FAIL |
| Secondary | 3600 | 3773,023 | FAIL |

**2 frames PASS; 3.600 frames FAIL; NFR-02 vẫn FAIL.** Giữ 40 overlapping submissions/batch, 5 warm-up + 30 measured batches/workload, đủ frames/tasks và submit→finish gồm barrier/queue/hash/persistence. Đây là single-process serialized main-thread execution, **không tương đương 40 parallel network users**. Không lấy correctness engine exit 0 để coi latency target đạt.

## E. Regression results

[All report](evidence/vt074_final_315966019bc5_all.json): **31 suite invocations PASS, runner exit 0**; [smoke](evidence/vt074_final_0084cf203d62_smoke.json): **5 invocations PASS, runner exit 0**. Mỗi suite có command, platform, source hashes, stdout/stderr và engine exit.

| Phần | Kết quả mới |
| --- | --- |
| Pairwise | 14 rows / 261 assertions PASS |
| VT74-02 | GREEN |
| Contract | 41 assertions PASS, gồm HT-01 |
| Integration | Forward/reverse 445 mỗi lượt; 8 IT độc lập tổng 445 |
| Replay gốc | Forward/reverse/shuffle 29 mỗi lượt; 5 nhóm độc lập tổng 29 |
| Replay HT-02 | Forward/reverse/shuffle 31 mỗi lượt; 5 nhóm độc lập tổng 31; state/order comparison equal |
| Boundary | 27 assertions tại 127/128/129 PASS |
| TIME | 20 iterations / 340 assertions PASS |

IT-04 vẫn yêu cầu đúng diagnostic JSON hỏng có marker và assertion LOAD_ERROR; không bỏ qua lỗi tùy ý. Mutation PASS → FAIL → PASS và flaky evidence Commit 1–6 giữ nguyên. Perk không bị tác động/không chạy lại trong lượt này: baseline lịch sử vẫn 34/37 với ba KNOWN BASELINE FAILURES; không xóa assertions/sửa gameplay hoặc tuyên whole-project regression PASS.

## F. Remaining limitations và integrity

- Linux smoke/workflow mới NOT VERIFIED; manual visual/gameplay E2E NOT RUN; line/branch coverage NOT MEASURED.
- NFR-02 heavy workload FAIL; chưa có optimization mới được chấp nhận.
- Local single-writer/read-back không chứng minh power-loss durability, external writers hay distributed exactly-once.
- `git diff --check` đạt; danh sách file/integrity lưu ở final checks. Production, CSV, harness, test baseline và evidence cũ không đổi; index rỗng. Các bản sao/cache/save synthetic nằm trong ignored `.godot/`, không có trong danh sách thay đổi.
- Hai runner thành công đều xác nhận personal save unchanged và không thay đổi nguồn trong lúc chạy. SHA-256 save cá nhân trước/sau: `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`. GameManager giữ SHA-256 `ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe`.

## G. Readiness

**READY FOR COMMIT trong phạm vi bổ sung test/CI**, với Linux NOT VERIFIED và NFR-02 FAIL đã công khai. Chưa xác nhận toàn bộ specification/NFR hoàn tất. Dừng để sinh viên review toàn diff bằng GitHub Desktop.

Commit message đề xuất:

```text
test(vt074): execute pairwise cases and extend CI smoke coverage
```
