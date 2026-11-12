# BT3 VT-074 — Test Strategy, Commit 2 (RED)

Ngày: 12/11/2026, Asia/Saigon. MSSV 23001833; SE2026-T19; GAME-2D-02.
Branch `feat/bt3-vt074-idempotent-run`; start SHA `be8e39d3e5d8b3bdce9f815ab93966e3bcf51fde` (Commit 1). Working tree sạch trước thay đổi. Audit dùng Git của GitHub Desktop vì Git không có trong PATH. Không checkout/merge/rebase/reset/stage/commit/push/PR.

## 1. Scope và nguồn contract

Kiểm tra invariant một run completion chỉ được commit một lần, retry không nhân history/save/signal/eviction, ID khác không bị gộp bởi seed/date, validate/conflict, reload/failure/retention. Nguồn đích: [SPECIFICATION.md §4–8](SPECIFICATION.md) với đúng AC-01…AC-05; [revised plan P-03/P-04](AI_IMPLEMENTATION_PLAN.md#p-03-commit-2--red-chưa-thực-hiện). Đây là test-first; production hiện chưa có run_id/ledger/receipt hay writer trả kết quả. Không sửa implementation, UI, gameplay, balance, Enemy AI, dungeon hoặc CI.

R-01/R-02 đã được sinh viên xác nhận MODIFY nguyên văn tại [Human Review](AI_PLAN_REVIEW.md#8-human-review--student-verification). Sau đó sinh viên trực tiếp xác nhận TR-01/TR-02 MODIFY, chấp nhận hai revisions v1; bản gốc/lý do/bản sửa/quyết định nguyên văn ở [AI_TEST_REVIEW.md](AI_TEST_REVIEW.md). Hai revisions đã áp dụng vào thiết kế 03/11, execution vẫn PLANNED AFTER PATCH.

## 2. Risk-based testing và levels

| Ưu tiên/risk | Hậu quả | Cách kiểm tra/level |
| --- | --- | --- |
| P0 duplicate completion | Thêm record, ghi save, phát signal, evict replay hợp lệ | Integration headless qua autoload thật, hai callback một lifecycle; VT74-02 RED. Sau patch thêm receipt/save counters và deletion retry. |
| P0 mất ID/digest khi reload (R-02) | Retry sau restart bị nhận như new | Integration snapshot v2 round-trip, history đã prune hoặc frames đã delete; giữ fingerprint gốc. |
| P0 save failure/uncertain | RAM báo thành công trong khi disk chưa commit hoặc retry mù | Unit writer fault injection + integration candidate/disk/signals; lỗi open/write/replace trước commit, reconcile sau uncertainty. Chưa có injection seam, planned. |
| P0 sai admission/conflict | ID lạ hoặc payload khác ghi đè result | Unit boundary + integration zero-side-effect snapshots; invalid/unknown/conflict/canonical-equivalent. |
| P1 retention 128 độc lập cap 15/10 | Evict sớm hoặc tái tạo completion expired | Directed 127/128/129, oldest không active và không còn history; kiểm receipt/FIFO, không chỉ đếm history. |
| P1 identity collision/delete nhầm | Cùng seed/date bị gộp hoặc xóa nhầm frames | Clock fixture T, IDs A/B khác nhau, hai result và receipt, delete B bảo toàn A. |
| P1 legacy/replay compatibility | Hỏng save cũ, mất frames/phím, sai mode | Integration legacy và v2, giữ cap/FIFO/delete/idle assertions; live/playback/fallback. |
| P1 shared state/order/time (R-01) | False pass/fail và flaky | Mỗi case/process/save riêng; setup tự đủ dữ liệu; test độc lập/đảo thứ tự khi harness có. |

Unit đích: validation, ordered canonical tuple/hash (không phụ thuộc Dictionary order), ledger lookup/retention, failure adapter. Không gọi API chưa tồn tại để tạo RED. Integration hiện thực: `start_new_run()` → fixture stats/frames → `finish_run()` hai lần → kiểm RAM, signal và JSON disk. Dùng SUT nguyên bản, không fake chức năng idempotency.

E2E Godot đích: CharacterSelect → start → completion adapter → Expedition History → reload → explicit retry; assertions trên số dòng/identity/frames, không chỉ không crash. Headless scene integration có thể thay animation/input để ổn định; UI rendering/manual E2E ở Commit 4, NOT RUN ở đây. Completion hook gọi trực tiếp tránh chờ timer game-over. Không có REST completion backend trong source audit; thêm REST API test không kiểm tra đường code JSON/Node thực tế và nằm ngoài scope.

## 3. Test-first và phân biệt RED

1. Giữ nguyên original plan và production; lưu cases AI sinh trước review.
2. Thiết kế oracle từ năm AC; generate và verify covering array; nhận human review cho ít nhất hai case yếu trước khi ghi là sinh viên đã sửa/xóa.
3. Baseline RED chỉ dùng API hiện có. Fixture start đúng lifecycle, sau đó gán seed/stats/frames xác định; gọi finish hai lần mà không start giữa chúng. Oracle: RAM history=1, JSON history=1, completion signals=1. Lần đầu phải tạo đúng một result với seed/hero/floor/kills/reason/frames đúng để loại lỗi setup.
4. Behavioral RED cần engine thực chạy assertion, marker `[BEHAVIORAL FAIL VT74-02]`, actual=2, Godot exit=1, không có parser/missing-method/setup/runtime error. Exit=2 hoặc timeout/log ERROR là lỗi setup, không phải RED nghiệp vụ. Log setup thất bại giữ riêng.
5. GREEN/patch, full receipt/save-call instrumentation và required regression thuộc Commit 3 trở đi. Không chuyển test sang GREEN trong phiên này. Control VT74-01 chỉ kiểm baseline subset; không phải PASS đầy đủ AC-01 vì chưa có ID/receipt.

## 4. Save isolation trước mọi autoload

Chỉ chạy bằng [tests/vt074/run_red.py](../../tests/vt074/run_red.py), không chạy scene trực tiếp trên project cá nhân: GameManager `_ready()` có thể load/bootstrap save trước scene test `_ready()`.

Launcher tạo UUID mới dưới `.godot/vt074_red/<uuid>/`, child-only `APPDATA`, `LOCALAPPDATA`, `TEMP`, `TMP`, không thay env của shell cha. Probe project không autoload, cùng project name/default user-dir settings, in `OS.get_user_data_dir()` và `ProjectSettings.globalize_path("user://roguelike_save_data.json")`. Require đúng expected path nằm dưới disposable APPDATA, rồi Python ghi sentinel và Godot đọc lại qua user://. Chỉ sau cả hai probe thành công mới copy project và chạy import/autoload. Không dựa vào XDG_DATA_HOME của Linux CI để suy luận Windows.

Project tạm copy tất cả tracked resources và test mới, không junction/symlink tới save thật; `GameManager.gd`, regression và `project.godot` có hash trùng bản gốc trước chạy. Chỉ seed imported fontdata vì ThemeDB cần custom font trước lần import đầu; script class/UID caches không dùng lại; engine import đầy đủ và bắt buộc không ERROR trước behavioral test. Launcher không thay file config/source production. Tài liệu [Godot data paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html) mô tả default Windows path; runtime probe và sentinel mới là evidence isolation trên binary local.

Save cá nhân theo project config đã audit: `%APPDATA%/Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json`. Chỉ hash read-only trước/sau, không xuất nội dung, không backup/restore đè dữ liệu. Path thực và hashes nằm trong log. Save test và temporary cache được giữ lại dưới `.godot/` để kiểm tra; không xóa tự động. Mỗi lần chạy tạo project/process/save riêng; kết thúc process giải phóng global state, signals disconnect sau assertion. Engine có thể bootstrap synthetic seeds trong đường dẫn tạm; test reset arrays/last recorded/playback, start rồi gán frames; counters chỉ kết nối sau setup. Nếu probe/isolation/import fail, dừng trước test và ghi NOT RUN/SETUP ERROR.

## 5. Flaky risks

Clock: baseline finish vẫn lấy system timestamp, nhưng RED không so sánh timestamp, không sleep và không dùng seed/date để nhận diện run. Cùng lifecycle chứng minh bằng một start và hai finish; input nghiệp vụ không đổi. Fixed ID generator/clock seam cho same-time collision là contract tương lai, không thay OS clock thật.

Execution order/shared state: suite mới một case integration trong process mới; VT74-01 control là precondition của VT74-02, không phải test độc lập lấy state từ suite khác. Không dùng state của `test_replay_security.gd`; không sửa/xóa suite đó trong Commit 2. R-01 migration sau patch sẽ cho từng nhóm FIFO/manual/clear fixture riêng, start trước frames, reset active/ledger/flags/counters/provider và teardown. VT74-11 v1 được sinh viên duyệt: chạy từng group độc lập, forward/reverse và shuffle seed 23001833; so assertion outcomes và end-state theo từng group, giữ nguyên regression assertions. Thiết kế này vẫn PLANNED AFTER PATCH. Chạy 20 lần/flaky evidence và concurrency performance thuộc Commit 5, chưa có pass rate/p95 ở đây.

## 6. Traceability AC → tests

| Contract | Cases dự kiến | Quan sát hiện có / giới hạn |
| --- | --- | --- |
| AC-01 | 01, 12 | 01 control subset chạy cùng 02; full ID/receipt và UI E2E planned. |
| AC-02 | 02, 03, 14, 17 | 02 baseline adapter behavioral assertion runnable; receipt/deletion/40 pending tasks planned. |
| AC-03 | 06, 13, 21 | Fixed-clock ID/deletion và replay mode planned. |
| AC-04 | 04, 05, 15, 16, 18 | Negative cases đầy đủ oracle status + zero mutations; API boundary chưa có. |
| AC-05 | 07, 08, 09, 10, 19, 20, 22 | Reload/failure/retention/corrupt/oversize planned; whitelist và legacy protection R-02. |
| NFR-01 | 11, 13 | Per-process isolation có probe evidence; independence/shuffle/fixed-clock toàn suite chưa chạy. |
| NFR-02 | 14 | 40 tasks cùng owner; witness pending>=40, không gọi loop sync là concurrency; benchmark Commit 5. |
| NFR-03 | 06, 07, 17, 20, 21 | Giữ legacy, replay/caps/sanitizer; không suy PASS từ docs. |

Cases: [TEST_CASES.md](TEST_CASES.md). Pairwise factors/constraints/row mapping: [PAIRWISE.md](PAIRWISE.md). Phần lớn AC đích cần API ở patch sau; Commit 2 chỉ chứng minh một lỗi duplicate thực và chuẩn bị các oracle khác. Kết quả chạy và readiness được ghi riêng ở [COMMIT_2_REPORT.md](COMMIT_2_REPORT.md), không coi kế hoạch là kết quả.
