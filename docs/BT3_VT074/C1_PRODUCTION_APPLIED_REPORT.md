# BT3 – VT-074: Candidate C1 đã áp dụng production

Ngày 14/11/2026, Asia/Saigon. Branch `feat/bt3-vt074-idempotent-run`; HEAD giữ nguyên `8db06a56720d7f2bbe359c908eb55950b8d208c8`. Người dùng đã duyệt áp dụng C1 và chấp nhận trade-off first-COMMITTED service p95 tăng **7,637 ms (+2,49%)** từ matched review. Không thay target, workload hoặc acceptance criteria. Báo cáo này là kết quả hiện tại; các báo cáo trial trước giữ nguyên provenance.

## Production diff cuối

Đã `git apply` đúng [patch được duyệt](evidence/heavy_tradeoff_144f3df0463e_candidate.patch) vào [GameManager](../../Scene/GameManager.gd). Source sau áp dụng khớp **từng byte** với C1 trong [source artifact](evidence/heavy_tradeoff_144f3df0463e_sources.json):

```text
SHA-256: 097cfb2cfb99135759a18bd0a4f0bee6b2b1201d8eb1b8bc406934583198e2a7
git diff --numstat -- Scene/GameManager.gd: 29 additions, 0 deletions
```

Không thêm optimization khác. C1 nhận payload canonical cục bộ cho một cache, khóa Dictionary payload/Array frames/mọi frame Dictionary read-only, lưu token/fingerprint. Cache không alias caller/envelope/history. Fast path chỉ dùng khi READY, writer không bận, run CLOSED, active/cache token đúng, receipt còn trong ledger và fingerprint khớp, payload structural-equal. Input còn lại vẫn chạy canonicalization/validation/hash gốc. Cache không persist và bị xóa khi start run mới/load thành công. Receipt copying, frozen envelope, conflict/reload/retention và atomic persistence giữ nguyên.

Production code khác, test `test_flaky_order.gd`, pairwise CSV, harness và CI smoke files không bị sửa trong lượt áp dụng này. Ngoài GameManager, chỉ README và evidence `.gitignore` hiện có được cập nhật để chỉ kết quả mới và bỏ bản trùng khỏi commit; mọi historical evidence giữ nguyên bytes.

## Kiểm chứng trên checkout production thật

[Runner mới](../../tests/vt074/run_c1_production.py) thực thi Godot với `cwd` bằng repository root, không dùng candidate project copy cho test thông thường hoặc timing. Binary `4.7.2.stable.official.ed1daf0bf`, Python 3.14, Windows 11. Mỗi invocation có child-only APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP và probe/sentinel riêng trước autoload; không đổi môi trường parent hoặc save đang chơi.

Differential suites tái sử dụng nguyên test source, chỉ redirect đường dẫn baseline gốc sang `user://c1/original_manager.gd`. SUT vẫn preload `res://Scene/GameManager.gd` của checkout production; driver xác nhận hash C1 và in project root. Test source/redirect hashes được ghi trong [tests JSON](evidence/heavy_c1_production_a1b80b4f3c6b_tests.json).

**39 suite invocations trực tiếp trên ROOT PASS; 4.181 assertions có counter/marker PASS, 0 unexpected FAIL; thêm 2 VT74-02 behavioral oracles PASS.** Không gọi số assertion này là số independent test cases.

| Nhóm | Số thực tế sau áp dụng | Kết quả |
| --- | --- | --- |
| Canonical/alias | 94 cases, 284 assertions | PASS |
| Completion differential | 26 scenarios, 1.051 assertions | PASS |
| Cache ownership | 56 assertions, 2/3.600 frames | PASS |
| Pairwise | 14/14 rows, 261 assertions | PASS |
| VT74-02 | 2 behavioral oracles, all +smoke | PASS |
| Contract | 41 mỗi invocation ×2 =82 assertions | PASS, gồm HT-01 |
| Integration | all forward/reverse 445 mỗi lượt, 8 IT riêng tổng 445, smoke forward 445; tổng 1.780 assertions | PASS |
| Replay gốc | orders/groups +smoke, tổng 145 assertions | PASS |
| Replay/HT-02 ORDER wrapper | orders/groups +smoke, tổng 155 assertions; group-state comparisons equal | PASS |
| Boundary | 27 assertions tại 127/128/129 | PASS |
| TIME | 20 iterations, 340 assertions | PASS |
| Smoke Windows | 5/5 invocations trong bảng trên | PASS |

Cache/caller/nested mutation, original receipt/fingerprint, reload retry kể cả heavy, retention 128/FIFO eviction tại 129, save-open/replace failures, uncertain reconciliation, frozen envelope, reentrant/writer guards và legacy migration đều giữ hành vi gốc. Test ownership kiểm mọi frame cache read-only và các mutable containers caller/export vẫn độc lập.

**Mutation duy nhất chạy trong bản sao source C1**, không chèn mutant vào production. [Mutation JSON](evidence/vt074_final_c1prod_a1b80b4f3c6b_mutation.json): 27 PASS/exit 0 →19 PASS, 8 expected FAIL/exit 1 →27 PASS/exit 0; ba oracle invocations PASS, restored SHA đúng C1. Tổng mutation có 73 PASS và 8 lỗi chủ đích; không tính 8 lỗi này thành regression bất ngờ hoặc báo mutant exit 0.

Perk chạy lại trực tiếp trên ROOT: **34/37, đúng ba KNOWN BASELINE FAILURES**, names/errors khớp evidence baseline. Không sửa gameplay hoặc tuyên whole-project regression PASS. IT-04 vẫn chỉ chấp nhận đúng malformed-JSON diagnostic kèm marker/assertion LOAD_ERROR; không bỏ qua lỗi tùy ý.

## Benchmark production và p95

[Benchmark JSON](evidence/heavy_c1_production_a1b80b4f3c6b_benchmark.json): engine exit 0, runner exit 0, performance requirement PASS. Harness nguyên bản, không instrumentation, chạy trực tiếp tại ROOT sau khi test PASS.

Giữ **40 overlapping submissions/batch**, **5 warm-up +30 measured batches/workload**, **2 và 3.600 frames**, cả primary và secondary. Tổng **140 batches, 4.800 measured +800 warm-up records**. Mỗi workload có 1.200 measured requests; p95 nearest-rank `sorted[ceil(0.95*N)-1]`, index 1139; mỗi batch index 37/40. Đo submit →finish gồm barrier/queue wait, validation/hash và persistence. Không gộp workloads/frames; không bỏ outlier, tasks, frames hoặc validation.

| Workload | Frames | p95 ms | Max end-to-end ms | Failed measured batches /30 | Target ≤1500 ms |
| --- | ---: | ---: | ---: | ---: | --- |
| Primary | 2 | 10,415 | 10,740 | 0 | PASS |
| Secondary | 2 | 1,162 | 1,235 | 0 | PASS |
| Primary | 3600 | 403,425 | 473,789 | 0 | PASS |
| Secondary | 3600 | 782,408 | 812,072 | 0 | PASS |

Measured primary mỗi frames có **30 COMMITTED +1.170 DUPLICATE**; secondary có **600 DUPLICATE +300 CONFLICT +300 INVALID_REQUEST**. Verifier kiểm timestamps, pending-at-release=40/completed-before-release=0, queue/service arithmetic, mỗi batch đủ 40 task IDs, statuses, writer/signals và persisted snapshot; primary đúng một write/signal, secondary không side effects.

First-COMMITTED, 30 measured primary first requests/frames (secondary precommit vẫn ngoài timing như workload gốc):

| Frames | Mean service ms | p95 service ms | Max service ms | p95 submit→finish ms | Max submit→finish ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2 | 7,138 | 9,921 | 10,096 | 10,071 | 10,249 |
| 3600 | 289,303 | 307,078 | 309,493 | 307,298 | 309,725 |

Trade-off **+7,637 ms/+2,49%** được duyệt là số từ matched review C1, không thay bằng một so sánh khác thời điểm. Lượt post-apply không có baseline paired mới, nên không dùng các số ở đây để tuyên bố delta causal mới. Primary/2 p95 10,415 ms khác 4,058 ms trong review dù cùng C1 SHA; cả hai vẫn PASS, nhưng điều này cho thấy run/filesystem/workstation variation. Không che sự khác biệt bằng cách trộn hai datasets hoặc đo lại để tìm số đẹp hơn.

## Raw evidence, audit và bỏ dữ liệu trùng khỏi commit

[Verification JSON](evidence/heavy_c1_production_a1b80b4f3c6b_verification.json) đã tính lại **11 datasets /61.600 records**: bốn ABBA cũ, sáu trade-off runs, một production run. Một [archive canonical](evidence/heavy_c1_production_a1b80b4f3c6b_snapshots.zip) chứa 140 real synthetic saves có cùng batch IDs và bytes đúng mọi snapshot hashes của cả 11 datasets.

Giữ đủ CSV measured/warm-up, batch JSON, reports, source artifact, profile/correctness/regression evidence. Không sửa historical JSON/CSV/patch/ZIP. Mười ZIP snapshot lịch sử trùng nội dung và patch `heavy_4992759f992a_candidate.patch` byte-identical với `heavy_1a3b68d5d730_candidate.patch` vẫn giữ nguyên file tại chỗ, nhưng được ignore khỏi commit. Không xóa hoặc chuyển file cũ.

[Commit manifest](evidence/heavy_c1_production_a1b80b4f3c6b_commit_manifest.json) liệt kê **90 files cần commit**, paths/hashes/roles và **11 duplicates không commit** cùng aliases. Cache `.godot/`, temporary driver/baseline copies, disposable saves/imports và các dữ liệu trùng không nằm trong danh sách commit. Không stage file nào. Historical report có thể còn nêu archive paths cũ; dùng verifier production bên dưới để kiểm dữ liệu commit đã deduplicate, không gọi verifier lịch sử vốn khóa source/path tại thời điểm cũ.

Kiểm lại raw data mà không cần project/save tạm, và không cần mười duplicate ZIPs:

```powershell
py tests/vt074/run_c1_production.py --phase verify --run docs/BT3_VT074/evidence/heavy_c1_production_a1b80b4f3c6b_benchmark.json
```

Verifier giải nén archive canonical vào temporary child mới dưới `.godot/`, kiểm member/path/hash, tính lại đủ từng dataset rồi dọn đúng temporary child. Không dùng archive lịch sử bị loại khỏi commit. Mặc định không ghi evidence; `--output <new.json>` từ chối ghi đè.

## Integrity, CI và giới hạn

[Final checks](evidence/heavy_c1_production_a1b80b4f3c6b_final_checks.json) lưu branch/HEAD/index, source/evidence hashes, commit inventory, duplicate aliases, production equality và `git diff --check`. Personal save SHA-256 trước/sau: `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`.

`.github/workflows/ci.yml` và `run_ci_import_audit.py` giữ nguyên bytes so với đầu lượt áp dụng; CI smoke không bị đổi thêm, không thêm stress/profiling/mutation vào mặc định. Diff CI so HEAD vẫn chỉ có `fetch-depth: 0` và smoke đã duyệt; mọi bước test cũ giữ nguyên. Smoke Windows đã chạy lại 5/5 PASS. GitHub Actions/Linux cho patch mới chưa chạy trong lượt này; không mượn CI PASS lịch sử để khẳng định kết quả mới.

Giới hạn còn lại: benchmark là **single-process, main-thread serialized execution với 40 overlapping submissions**, không phải 40 parallel network users hoặc distributed writers; timing là workstation-specific. First-COMMITTED tail trade-off đã được người dùng chấp nhận; không tuyên mọi đường đi đều nhanh hơn. Peak RAM chưa đo. Perk còn ba lỗi baseline; manual visual/gameplay E2E và line/branch coverage chưa đo trong lượt này. Không suy read-back tests thành power-loss durability hoặc distributed exactly-once.

## Kết luận

**READY FOR FINAL COMMIT** trong phạm vi BT3 – VT-074 đã duyệt: production đúng C1, correctness/regression liên quan PASS, cả bốn workload thực tế PASS và trade-off đã được người dùng phê duyệt rõ. Các giới hạn/baseline failures trên vẫn được công khai.

Chưa stage, commit, push, merge hoặc tạo PR. Dừng để người dùng review production diff, manifest và evidence bằng GitHub Desktop.
