# BT3 VT-074 — AI Implementation Plan

- Sinh viên: Vũ Xuân Bắc — MSSV 23001833 — Team SE2026-T19.
- Project GAME-2D-02: Keep Fighting And Earning — Procedural Dungeon Roguelike.
- Ngày: 11/11/2026 (Asia/Saigon). Phạm vi thực hiện: chỉ Commit 1, tài liệu.
- Tool: Codex. Phiên được mô tả là dựa trên GPT-6; không xác định được model ID/deployment cụ thể, không suy đoán thêm.
- Branch đã xác minh: `feat/bt3-vt074-idempotent-run`.
- HEAD/baseline thực tế và baseline dự kiến: `56e97e1b5c621774423b9e06aede4b8b6bcc0b08`.
- Phân loại: **VERIFIED FACT** = quan sát source/Git; **ASSUMPTION** = tiền đề chưa kiểm chứng runtime; **PROPOSAL** = thiết kế dự kiến; **OPEN QUESTION** = cần giải quyết sau.
- Prompt gốc được lưu nguyên văn ở phụ lục trong file này. Tracker `BT3_23001833_VT-074_KE_HOACH_THEO_DOI.txt` (kể cả hậu tố `(1)`) chưa tìm thấy trong workspace; áp dụng prompt, không tuyên bố đã đọc tracker.

## ORIGINAL AI IMPLEMENTATION PLAN

Đây là bản ban đầu, được ghi xuống đĩa sau audit/source inspection, trước khi viết review và specification. Các mục O-01–O-15 là PROPOSAL trừ đoạn có nhãn khác. Giữ nguyên khối này sau khi review bắt đầu; revised plan bên dưới mới là hướng triển khai cuối.

### O-01. Problem analysis

VERIFIED FACT: `Scene/GameManager.gd:219–245`, `finish_run()`, tạo entry rồi `run_history.push_front(entry)` ở mọi lần gọi; không kiểm tra completion ID. Giới hạn history 15 và replay 10 nằm ở dòng 13–14. Callback lặp có thể ghi thêm record và kích hoạt save/signal/eviction thêm lần nữa. `BasePlayer.take_damage()` có `is_dead` guard (`Scene/Character/BasePlayer.gd:256–258,306–316`) nhưng guard tại caller không bảo vệ mọi lời gọi GameManager.

### O-02. Scope và out-of-scope

Chỉ bảo vệ completion, identity, persistence, replay/history liên quan trực tiếp. Không xây REST API, multiplayer server, network replication, distributed exactly-once, UI/gameplay redesign, balance hoặc dungeon generator. Commit 1 chỉ ghi đúng ba tài liệu; các thay đổi source/test/harness dưới đây đều dành cho Commit 2–6.

### O-03. Assumptions

ASSUMPTION: một process là chủ save, completion được xử lý trên main thread; không có writer ngoài process. Caller bình thường bắt đầu run trước khi kết thúc. Có thể tiêm ID generator, clock và save adapter cho test. Không giả định Godot Node thread-safe hoặc CI đã xanh. Cần kiểm tra fixture cũ khi áp contract mới.

### O-04. Request identity strategy

Sinh opaque token ngẫu nhiên độc lập seed và timestamp, dự kiến 32 ký tự hex thường từ 128 bit entropy; kiểm tra collision với active ID và registry còn giữ, phát hiện collision thì sinh lại. Test tiêm token cố định; không kiểm thử bằng xác suất hoặc timestamp. ID chỉ hợp lệ về quyền xử lý khi là run hiện hành hoặc đã có trong processed registry; ID đúng cú pháp nhưng không được nhận diện bị từ chối. Không dùng seed hay thời gian làm identity.

### O-05. Kiến trúc và contract

Giữ `finish_run(reason)` như adapter cho gameplay; dự kiến thêm boundary nội bộ nhận `run_id` và completion payload. Dữ liệu xử lý gồm active ID, completion snapshot và processed registry. Thứ tự: validate → tìm ID → đối chiếu payload → dựng candidate state → lưu → publish. Kết quả dự kiến: COMMITTED, DUPLICATE, CONFLICT, INVALID_REQUEST, UNKNOWN_RUN, SAVE_FAILED. Registry giữ fingerprint và receipt nhỏ, không giữ thêm bản sao frame lớn. Không cho signal observer thấy nửa transaction.

### O-06. Thời điểm tạo run_id

Tạo một ID ở `start_new_run()` và giữ qua các tầng; không tạo ID mỗi lần `finish_run()`. `replay_seed_run()` khởi đầu lượt chơi mới cùng seed nên nhận ID mới. Action replay cũng là một session mới, không tái sử dụng ID của run nguồn; giữ hành vi history hiện tại và không sinh thêm recorded replay khi đang playback. Fixture mô phỏng nhiều run phải bắt đầu đúng lifecycle.

### O-07. Nhận diện retry

Giữ ID và đóng băng snapshot lần completion đầu, gồm seed, hero index, floor, kills, reason, mode và frames. Fingerprint có serialization ổn định, không phụ thuộc thứ tự dictionary. Date/hero display name không thuộc identity; date chỉ được tạo một lần cho result. Retry dùng lại snapshot, không đọc lại stats/frame biến động. Boundary explicit payload vẫn cho phép kiểm tra conflict.

### O-08. Duplicate và conflict

ID đã xử lý + payload chuẩn hóa giống → DUPLICATE, trả receipt cũ, không ghi/save/emit/evict lại. ID giống + payload khác → CONFLICT, không sửa state. ID khác cùng seed/date vẫn độc lập nếu được lifecycle cấp. ID rỗng/sai kiểu/sai định dạng hoặc payload sai schema → INVALID_REQUEST; không tự sửa ID thành ID khác.

### O-09. Persistence và backward compatibility

Thêm schema version và processed registry vào cùng snapshot JSON với history; cập nhật cả save và load, validate trường mới. Save cũ thiếu ID/registry vẫn đọc được, không suy luận ID từ seed/date và không gộp entry cũ. Giữ sanitizer/cap cũ. Thêm ID vào history/last recorded run; thao tác xóa dùng ID cho entry mới, legacy entry cần fallback an toàn. Migration không thể chứng minh idempotency cho completion trước khi có ID.

### O-10. Retention

Dự kiến registry FIFO giữ 128 completion thành công gần nhất, độc lập history 15/replay 10. Chỉ prune khi số ID `> 128`; duplicate/conflict/failure không làm mới thứ tự hoặc chiếm slot. Giữ đúng 128 tại biên; lần thứ 129 loại oldest. Xóa history/replay không được xóa receipt. ID hết retention và không phải active run bị UNKNOWN_RUN, không được nhận như completion mới. Receipt không hứa khôi phục replay đã xóa.

### O-11. Save failure

`save_data_to_disk()` hiện trả void (`Scene/GameManager.gd:356–367`), không thể xem đó là xác nhận commit. Đề xuất adapter trả kết quả tường minh; ghi candidate ra file tạm rồi thay snapshot sau khi kiểm tra thành công; publish memory/receipt/signal chỉ sau xác nhận. Khi thất bại giữ state committed cũ và snapshot pending để retry cùng ID/payload. Không tuyên bố chống mọi power loss hay fsync bền vững khi chưa kiểm chứng nền tảng.

### O-12. Proposed files cho Commit 2–6

- `Scene/GameManager.gd`: lifecycle, completion guard, registry, save/load, delete matching.
- Dự kiến thêm `Scene/RunCompletionStore.gd` nếu cần cô lập persistence/failure injection, không tạo framework tổng quát.
- `tests/test_run_completion_idempotency.gd` và `.tscn`: contract và integration tests.
- `tests/test_replay_security.gd`: chỉnh fixture lifecycle/state isolation, giữ regression assertions.
- Dự kiến `tests/benchmark_run_completion.gd` và `.tscn`: harness 40 tác vụ ở Commit 5.
- `run_tests.bat`, `.github/workflows/ci.yml`: chỉ bổ sung suite sau, giữ bước replay hiện có.
- `docs/BT3_VT074/`: test strategy, evidence, traceability, AI log, reflection và README ở các commit sau.
- Chỉ cân nhắc caller `Scene/Character/BasePlayer.gd` nếu contract integration cần sửa; ưu tiên giữ adapter để tránh mở scope.

### O-13. Test-first RED → AI-assisted patch → GREEN

Commit 2: thiết kế tối thiểu 10 cases từ AC/risk; AI sinh test, sinh viên review và sửa/xóa ít nhất hai test yếu/duplicated, giữ before/after/reason; chạy trên baseline chưa patch và lưu RED có exit code/log. Không xem parse/setup error là behavioral RED. Commit 3: patch nhỏ rồi chạy GREEN cùng replay regression. Commit 4: bổ sung negative, failure, reload, compatibility và E2E phù hợp. Chưa làm các bước này ở Commit 1.

### O-14. Risks và trade-offs

Registry hữu hạn không phải lịch sử receipt vô hạn; không resume active gameplay qua restart. Token ngẫu nhiên cần nguồn entropy tốt, vẫn có rủi ro collision rất nhỏ ngoài retention. Single writer giảm race nhưng không hỗ trợ multi-process. JSON phải lưu nhất quán result và receipt; cap byte có thể khiến save bị từ chối. Digest phải chuẩn hóa giống nhau trước/sau reload và không dựa vào frames đã bị retention xóa. Không xóa test regression để né contract mới.

### O-15. Pairwise, mutation, flaky và performance

- Pairwise: phân loại ID (new/duplicate/conflict/invalid/unknown), seed (same/different), frames (empty/present), persistence (memory/reload), storage (success/failure), occupancy (below/exact/above cap). Commit 2 sẽ lập constraints, sinh covering array và kiểm tra mọi cặp khả thi; không gọi danh sách cases ngẫu nhiên là pairwise.
- Mutation: chọn điều kiện retention `size > 128`, đổi thành `>=`; test phải quan sát receipt oldest tại đúng 128 để phát hiện eviction sớm. Chạy bản gốc, mutant rồi phục hồi ở Commit 5; không chỉ đếm dòng đổi.
- Flaky: state/save path riêng mỗi case, teardown, ID/time provider cố định, không network/sleep oracle; chạy riêng và đổi thứ tự có seed ghi lại. Giữ evidence thực tế.
- Performance: 40 coroutine tasks được enqueue trước khi owner xử lý, main thread tuần tự hóa mutation/save; đo từ enqueue đến receipt, gồm queue và persistence. Đây là 40 tác vụ chồng lấn, không phải 40 worker threads hay 40 user mạng. Mục tiêu p95 <= 1500 ms. Ghi raw latency, môi trường, cỡ payload, workload và cách tính percentile ở Commit 5; chưa có kết quả đo.

<!-- END ORIGINAL AI IMPLEMENTATION PLAN — không sửa phần bên trên khi review -->

## Prompt gốc của phiên này (nguyên văn)

Nguồn: `C:\Users\ADMIN\.codex\attachments\8a868d72-869a-4646-a08d-77f2f617625d\Pasted text.txt`.
SHA-256 của file attachment gốc: `AB94771586BD537B29D1512253EA59BDC748832DFA024D7D9978BCA8E852022B`.
Bản dưới giữ nguyên nội dung Unicode và xuống dòng của attachment trong khối text; không cần attachment để đọc lại yêu cầu.

~~~~text
# CODEX TASK — BT3 VT-074 — COMMIT 1

## 0. VAI TRÒ VÀ MỤC TIÊU

Bạn là Senior Software Engineer, Software Testing Engineer và Coding Agent hỗ trợ thực hiện bài tập cá nhân Software Engineering 2026.

Nhiệm vụ hiện tại là **hoàn thành duy nhất COMMIT 1: SPECIFICATION & AI IMPLEMENTATION PLAN** của dự án.

Phải làm việc theo quy trình:

**Inspect Repository → Produce Original AI Plan → Review Plan Against Source → Finalize Specification → Verify Documents → Report**

Chỉ thực hiện Commit 1. Không tự ý làm Commit 2–6.

Ưu tiên tính đúng đắn, khả năng kiểm chứng, phạm vi thay đổi nhỏ và tài liệu có bằng chứng. Không chạy theo số lượng file hoặc số dòng.

## 1. THÔNG TIN DỰ ÁN

- Sinh viên: Vũ Xuân Bắc
- MSSV: 23001833
- Team ID: SE2026-T19
- Project ID: GAME-2D-02
- Variant: VT-074
- Project: Keep Fighting And Earning – Procedural Dungeon Roguelike
- Repository: https://github.com/Gumaisme2005/Keep-Fighting-And-Earning
- Engine: Godot 4 / GDScript
- Base branch: `development`
- Working branch: `feat/bt3-vt074-idempotent-run`
- Baseline dự kiến: `56e97e1b5c621774423b9e06aede4b8b6bcc0b08`

**Feature:** Idempotent Run Completion – Prevent Duplicate Run History.

**Change Request:** Cho phép người dùng gửi lại cùng một yêu cầu mà không tạo dữ liệu hoặc giao dịch trùng.

Các yêu cầu riêng của VT-074:

1. Risk trọng tâm: flaky tests phụ thuộc thời gian, network, thứ tự thực thi hoặc shared state.
2. Test technique bắt buộc: pairwise/combinatorial testing.
3. Mutation bắt buộc: đổi toán tử so sánh biên `>` thành `>=`.
4. Performance: 40 tác vụ đồng thời, p95 không vượt quá 1.500 ms.
5. AI sinh test cases; sinh viên phải sửa hoặc xóa ít nhất hai test yếu/duplicated.
6. Test-first workflow: RED → AI-assisted patch → GREEN.
7. Báo cáo phải có evidence thực tế, traceability, AI Usage Log và reflection.
8. PR cá nhân không được merge trước khi nhóm review.

Commit 1 chỉ chuẩn bị specification và plan cho các yêu cầu này. Không triển khai test, mutation hoặc benchmark ngay bây giờ.

## 2. TÀI LIỆU CHỈ ĐẠO

Nếu trong workspace có file:

`BT3_23001833_VT-074_KE_HOACH_THEO_DOI.txt`

hoặc bản cùng nội dung có hậu tố `(1)`, hãy đọc toàn bộ file trước.

Đặc biệt tuân thủ:

- Mục A: Các ràng buộc VT-074.
- Mục B: Vertical Slice, Contract và Acceptance Criteria.
- Mục C: Git Workflow và Evidence.
- Mục D: COMMIT 1.
- Mục I: Không đánh đồng kế hoạch với kết quả.

Nếu file tracker không nằm trong workspace, sử dụng đầy đủ các yêu cầu ghi trong prompt này và báo rằng chưa truy cập được bản tracker. Không tự khẳng định đã đọc file không tồn tại.

## 3. QUY TẮC BẮT BUỘC

**Git và quản lý thay đổi:**

- Chỉ làm việc trên `feat/bt3-vt074-idempotent-run`.
- Không checkout sang branch khác.
- Không sửa `main` hoặc `development`.
- Không merge, rebase, reset, cherry-pick hay force push.
- Không tự commit, stage hoặc push.
- Tôi sử dụng GitHub Desktop để kiểm tra và tạo commit.
- Không ghi đè thay đổi đã tồn tại mà chưa review.
- Không tạo PR trong nhiệm vụ này.

**Giới hạn phạm vi:**

- Chỉ tạo/cập nhật tài liệu trong `docs/BT3_VT074/`.
- Không sửa `Scene/GameManager.gd` hoặc bất kỳ gameplay code nào.
- Không sửa test, `.tscn`, `.gd`, `.github/workflows/ci.yml`.
- Không tự triển khai `run_id`.
- Không tạo performance harness.
- Không chạy mutation.
- Không mở rộng scope sang UI, Enemy AI, Inventory, Game Balance hoặc Dungeon Generator nếu không cần thiết cho việc phân tích.

**Tiêu chuẩn chất lượng:**

- Không suy đoán dữ liệu của repository.
- Phân biệt VERIFIED FACT, ASSUMPTION, PROPOSAL và OPEN QUESTION.
- Mọi kết luận về source phải có file path, function và số dòng hoặc đoạn code chứng minh.
- Không bịa kết quả test, commit SHA, PR URL, coverage hay p95.
- Tài liệu viết bằng tiếng Việt, sử dụng thuật ngữ tiếng Anh khi cần.
- Không tự tuyên bố hoàn thành khi vẫn còn lỗi quan trọng.

## 4. PHASE 1 — REPOSITORY & BASELINE AUDIT

Trước khi tạo hoặc chỉnh sửa file, thực hiện kiểm tra read-only:

```bash
git status --short
git branch --show-current
git rev-parse HEAD
git log -1 --oneline
```

Xác minh:

- Đúng repository.
- Đúng working branch.
- HEAD hiện tại và baseline chính xác.
- Working tree có sạch hay không.
- Có tài liệu VT-074 từ trước hay không.

Nếu branch sai hoặc thay đổi hiện có có nguy cơ bị ghi đè, dừng chỉnh sửa và báo blocker.

Nếu HEAD khác baseline dự kiến, ghi nhận SHA thật, giải thích sự khác biệt. Không tự reset.

Ghi kết quả audit vào tài liệu thích hợp.

## 5. PHASE 2 — PHÂN TÍCH SOURCE CODE

Đọc tối thiểu:

```text
Scene/GameManager.gd
Scene/Character/BasePlayer.gd
Scene/UI/character_select.gd
Menu/main menu/main_menu.gd
Menu/game over menu/game_over_menu.gd
tests/test_replay_security.gd
.github/workflows/ci.yml
project.godot
README.md
```

Tìm thêm những file và caller liên quan nếu cần.

Phân tích các hàm:

- `start_new_run()`
- `finish_run()`
- `save_data_to_disk()`
- `load_save_data()`
- `enforce_replay_limits()`
- `delete_replay()`
- `delete_run_history_entry()`
- `clear_all_replays()`
- `replay_seed_run()`
- `start_action_replay()`

Trả lời rõ:

1. Một lượt chơi được bắt đầu như thế nào?
2. Những nơi nào gọi `finish_run()`?
3. Khi nào lịch sử được lưu?
4. Gọi `finish_run()` hai lần có nguy cơ tạo duplicate không?
5. Hệ thống đang dùng seed, timestamp và replay ra sao?
6. Cách save/load JSON hoạt động thế nào?
7. Có cơ chế chống duplicate hiện tại không?
8. Các test replay hiện tại phụ thuộc state của nhau không?
9. Những regression nào có thể xảy ra nếu bổ sung `run_id`?
10. Có sẵn REST API hoặc multiplayer backend cho chức năng này không?

Chú ý các giới hạn:

```gdscript
MAX_RUN_HISTORY = 15
MAX_SAVED_REPLAYS = 10
```

Không được sử dụng seed làm request ID vì những lượt chơi khác nhau có thể cùng seed.

Không sử dụng timestamp để chứng minh request là duy nhất.

Đặc biệt xem xét hành vi của `delete_replay()` khi hai kết quả có cùng seed và timestamp.

## 6. PHASE 3 — TẠO ORIGINAL AI IMPLEMENTATION PLAN

**BẮT BUỘC thực hiện phase này trước khi viết Specification chính thức hoặc review plan.**

Trước tiên, với vai trò coding agent, tự xây dựng một implementation plan dựa trên yêu cầu và hiểu biết ban đầu từ source.

Lưu nguyên bản kế hoạch đó vào phần:

`ORIGINAL AI IMPLEMENTATION PLAN`

trong file `docs/BT3_VT074/AI_IMPLEMENTATION_PLAN.md`.

Không chỉnh sửa ngược kế hoạch gốc sau khi bước review bắt đầu.

Plan phải có:

1. Problem analysis.
2. Scope và out-of-scope.
3. Assumptions.
4. Request identity strategy.
5. Kiến trúc và contract.
6. Thời điểm tạo `run_id`.
7. Cách nhận diện retry.
8. Phân biệt duplicate với conflict.
9. Persistence và backward compatibility.
10. Retention của processed request IDs.
11. Cách xử lý save failure.
12. Các file dự kiến sửa trong Commit 2–6.
13. Test-first RED → GREEN workflow.
14. Risks và trade-offs.
15. Kế hoạch pairwise, mutation, flaky và performance.

Không viết implementation code.

## 7. PHASE 4 — REVIEW ORIGINAL AI PLAN

Sau khi lưu original plan, thực hiện review độc lập dựa trên source thật.

**Yêu cầu tối thiểu: sửa hoặc bác bỏ hai nhận định/đề xuất của AI bằng evidence.**

Các vấn đề cần kiểm tra kỹ:

**Review candidate A — Existing Replay Tests**

Kiểm tra xem `tests/test_replay_security.gd` có gọi `finish_run()` nhiều lần mà không gọi `start_new_run()` giữa các lần hay không.

Nếu AI plan đề xuất mỗi lần gọi `finish_run()` phải có `run_id` mới mà không xử lý fixture cũ, điều chỉnh kế hoạch.

Không xóa test regression để làm cho CI xanh.

**Review candidate B — Serialization and Reload**

Kiểm tra `load_save_data()` có tự động phục hồi những trường bổ sung hay không.

Nếu AI plan chỉ cập nhật save mà không cập nhật load, phải sửa kế hoạch.

**Review candidate C — Save Failure**

Đọc return type và nhánh lỗi của `save_data_to_disk()`.

Không được khẳng định dữ liệu đã commit bền vững nếu thao tác ghi không có xác nhận thích hợp.

**Review candidate D — Replay and History Deletion**

Kiểm tra việc xóa replay, history và logic đối chiếu bằng seed/timestamp.

Đánh giá việc bổ sung ID ảnh hưởng tới những thao tác hiện có như thế nào.

**Review candidate E — Concurrency**

Không mặc định Godot `GameManager` an toàn khi gọi từ 40 worker threads.

Phải phân biệt 40 lời gọi tuần tự, 40 tác vụ chồng lấn và 40 người dùng mạng thực sự.

**Review candidate F — Mutation**

Không chọn mutation chỉ đổi toán tử nhưng không làm khác kết quả quan sát được.

Ưu tiên thiết kế điều kiện retention có test boundary phân biệt rõ `>` và `>=`.

Mỗi review finding phải có:

- Review ID.
- Original AI statement.
- Source evidence.
- Vì sao chưa đúng hoặc chưa đủ.
- Decision: ACCEPT / MODIFY / REJECT.
- Revised decision.
- Tác động đến Commit 2–6.

Không tạo finding giả để đủ số lượng. Nếu original plan thực sự không có hai vấn đề cần sửa, ghi rõ và đề xuất hai cải tiến có bằng chứng, phân biệt chúng với lỗi AI thật.

## 8. PHASE 5 — SPECIFICATION CHÍNH THỨC

Tạo Specification cho vertical slice:

**Idempotent Run Completion – Prevent Duplicate Run History**

Specification phải có:

### 8.1 Problem statement

Giải thích vì sao callback hoặc request hoàn tất lượt chơi bị lặp có thể gây duplicate run history.

### 8.2 Scope

Chỉ triển khai hành vi chống ghi trùng của run completion và các thành phần trực tiếp cần thiết để bảo vệ contract.

### 8.3 Acceptance criteria

Viết đúng 5 acceptance criteria, kiểm thử được:

- AC-01: Một request ID mới, hợp lệ tạo đúng một kết quả.
- AC-02: Retry cùng ID/cùng payload không tạo thêm record hay side effect mới.
- AC-03: Hai ID khác nhau, cùng seed vẫn được lưu độc lập.
- AC-04: ID không hợp lệ hoặc cùng ID nhưng payload xung đột bị từ chối an toàn.
- AC-05: Retry sau reload không tạo duplicate trong phạm vi retention đã quy định; hành vi khi save thất bại được định nghĩa rõ.

Mỗi AC phải có điều kiện đầu vào và expected result cụ thể.

### 8.4 Invariant

```text
For every valid run_id:
count(committed results for run_id) <= 1
```

Đồng thời bảo vệ:

- Không có duplicate side effects.
- Không gộp những run khác nhau vì trùng seed.
- Không phá giới hạn history và replay.

### 8.5 Non-functional constraints

Tối thiểu:

- NFR-01: Test ổn định, cô lập state, không dùng thời gian thực làm oracle, không phụ thuộc thứ tự chạy.
- NFR-02: Kiểm chứng 40 concurrent tasks; mục tiêu p95 <= 1500 ms; phải nói rõ mô hình thực nghiệm.
- NFR-03: Backward compatibility cho save file cũ và không làm hỏng replay.

### 8.6 Request contract

Mô tả rõ:

- New request.
- Duplicate request.
- Conflicting request.
- Invalid request.
- Retry after reload.
- Save failure.
- Request ID retention boundary.

Không chốt những bảo đảm vượt khả năng kiến trúc hiện có.

### 8.7 Out-of-scope

Không phát triển:

- REST API mới.
- Multiplayer server.
- UI/gameplay redesign.
- Network replication.
- Distributed exactly-once processing.

## 9. PHASE 6 — FINALIZE IMPLEMENTATION PLAN

Dựa trên review, tạo revised implementation plan cho các commit tiếp theo.

Kế hoạch phải nhất quán với specification.

Phân chia:

**Commit 2 – RED**

- Risk-based test strategy.
- Ít nhất 10 test cases.
- Pairwise data.
- AI-generated tests.
- Sửa/xóa hai test yếu hoặc duplicated.
- Chạy và lưu evidence RED.

**Commit 3 – GREEN**

- Patch idempotency nhỏ.
- Request ID contract.
- Safe persistence.
- Chạy test GREEN và regression.

**Commit 4 – Integration**

- Negative tests.
- Failure-path test.
- Save/reload.
- Replay compatibility.
- E2E phù hợp.

**Commit 5 – Quality & Performance**

- Mutation `>` thành `>=`.
- Mutation bị phát hiện qua test.
- Coverage/risk coverage.
- Flaky risk checks.
- Performance harness 40 tasks và p95.

**Commit 6 – Evidence**

- README hướng dẫn chạy.
- Traceability.
- AI Usage Log.
- Reflection 250–350 từ.
- CI/final review.
- Chuẩn bị evidence cho PDF.

Đây là kế hoạch, không phải công việc cần triển khai trong Commit 1.

## 10. PHASE 7 — TẠO ĐÚNG 3 FILE

Tạo/cập nhật:

```text
docs/BT3_VT074/
├── SPECIFICATION.md
├── AI_IMPLEMENTATION_PLAN.md
└── AI_PLAN_REVIEW.md
```

### SPECIFICATION.md

Bắt buộc có:

- Metadata sinh viên/nhóm/biến thể.
- Baseline thực tế.
- Problem statement.
- Scope/out-of-scope.
- 5 AC.
- NFR.
- Invariant.
- Request contract.
- Persistence và retention.
- Backward compatibility.
- Assumptions, residual risks.

### AI_IMPLEMENTATION_PLAN.md

Bắt buộc có:

- AI tool/model nếu xác định được, không suy đoán.
- Prompt gốc của phiên này hoặc tham chiếu tới prompt được lưu nguyên văn.
- Original plan được giữ nguyên.
- Assumptions.
- Proposed files.
- Technical approach.
- Risks/trade-offs.
- Roadmap cho Commit 2–6.

### AI_PLAN_REVIEW.md

Bắt buộc có:

- Repository evidence.
- Bảng review plan.
- Ít nhất 2 điểm MODIFY/REJECT có chứng cứ thực tế nếu tìm được.
- Revised plan.
- Decision log.
- Open questions.
- Commit 1 readiness checklist.

Nếu đã có tài liệu nháp trong thư mục trên, hãy đọc, đối chiếu và hoàn thiện thay vì ghi đè mù quáng. Giữ khả năng truy vết original plan và các review decision.

Không tạo thêm file không cần thiết.

## 11. PHASE 8 — KIỂM TRA CHẤT LƯỢNG

Sau khi viết xong:

1. Đọc lại toàn bộ ba file.
2. Kiểm tra 5 AC nhất quán với invariant.
3. Kiểm tra original plan được lưu trước review.
4. Kiểm tra có hai điểm review thực chất hay không.
5. Kiểm tra evidence có file/function/line đúng không.
6. Kiểm tra danh sách file dự kiến thay đổi.
7. Xác nhận không sửa gameplay/test/CI.
8. Xác nhận không có kết quả thực thi bị bịa.
9. Xác nhận không triển khai công việc Commit 2–6.

Chạy:

```bash
git status --short
git diff --check
git diff -- docs/BT3_VT074/
```

Chú ý: file mới untracked có thể không xuất hiện trong `git diff`. Phải tự đọc và kiểm tra toàn bộ nội dung của các file mới.

Không stage, commit hoặc push.

Nếu có vấn đề, sửa ngay những lỗi nằm trong phạm vi Commit 1 rồi kiểm tra lại.

Không sửa những phần ngoài scope.

## 12. BÁO CÁO KẾT QUẢ

Sau khi hoàn tất, trả lời bằng tiếng Việt theo cấu trúc:

### A. REPOSITORY AUDIT

- Branch.
- HEAD/baseline SHA.
- Working tree ban đầu.
- Các file/hàm đã đọc.

### B. COMMIT 1 DELIVERABLES

Liệt kê ba file được tạo/sửa và chức năng từng file.

### C. SPECIFICATION CHECK

- Problem statement.
- 5 AC.
- NFR.
- Invariant.
- Các contract quan trọng.

### D. AI PLAN REVIEW

- Original plan đã lưu ở đâu?
- Hai điểm được sửa/bác bỏ là gì?
- Evidence file/dòng nào?
- Revised decisions.

### E. QUALITY VERIFICATION

- Các lệnh đã chạy.
- Kết quả.
- Các file thay đổi.
- Vấn đề còn tồn tại.
- Những bước chưa thực hiện.

### F. COMMIT READINESS

Kết luận một trong hai trạng thái:

**READY FOR COMMIT 1**

Chỉ khi tài liệu đầy đủ, evidence hợp lệ, không có thay đổi ngoài scope và không có blocker quan trọng.

Hoặc:

**NOT READY FOR COMMIT 1**

Nếu còn thiếu điều kiện; giải thích chính xác nguyên nhân.

Commit message đề xuất:

`docs(vt074): specify idempotent completion and review AI plan`

## 13. ĐIỀU KIỆN KẾT THÚC

Nhiệm vụ chỉ được coi là hoàn tất khi:

- Đã xác minh repository/branch/baseline.
- Đã phân tích các code path thực tế.
- Có Specification đúng VT-074.
- Có original AI implementation plan.
- Có review plan với ít nhất 2 cải tiến/phản biện thực chất và evidence.
- Có revised plan.
- Ba file tài liệu nhất quán.
- Không thay đổi code gameplay/test.
- Không có commit hoặc push tự động.

**DỪNG TẠI ĐÂY.**

Không thực hiện Commit 2.

Không tạo test RED.

Không sửa `GameManager.gd`.

Không tự commit hoặc push.

Tôi sẽ review kết quả trên VS Code và GitHub Desktop, sau đó mới quyết định tạo Commit 1.
~~~~

## REVISED IMPLEMENTATION PLAN

Phần này được viết sau review R-01–R-08 và specification; không sửa khối original. Tất cả đều là **PROPOSAL cho Commit 2–6**, chưa thực thi. Contract cuối là [SPECIFICATION.md](SPECIFICATION.md), evidence/decision log là [AI_PLAN_REVIEW.md](AI_PLAN_REVIEW.md).

### P-01. Luồng kỹ thuật cuối

1. Start cấp token mới và mode session bất biến; active OPEN. Không lấy seed/date làm ID và không dùng ID run nguồn cho action replay. Khi PENDING/storage blocked, từ chối start; guard caller trước khi đổi hero/state và chỉ chuyển scene sau start thành công, tránh tiếp tục vào world với run cũ. Test generator/clock/save adapter có thể thay bằng deterministic provider.
2. Adapter `finish_run(reason)` capture envelope/deep-copy frames/date một lần, chuyển PENDING; retry giữ snapshot. Reason canonical khác → CONFLICT. Boundary explicit giữ nguyên ID/payload của request, kể cả retry một run cũ khi run mới đã start.
3. Validate ID/schema → lookup ledger và fingerprint → active OPEN/PENDING admission. DUPLICATE trả receipt cũ, CONFLICT/INVALID_REQUEST/UNKNOWN_RUN không side effect; CLOSED không được nhận như new. Fingerprint canonical giữ riêng, không tái tạo từ frames/history đã mutate.
4. Dựng candidate gồm result, replay/history capped và FIFO ledger <=128. Prune chỉ khi `>128`; history/replay deletion giữ ledger. Update history và last-recorded loader đầy đủ run_id/date/reason; legacy không tự backfill hay dedup.
5. Writer chung kiểm tra byte/schema, ghi candidate temp, xác nhận write/replace/read-back rồi publish memory/signal một lần. Lỗi xác định → SAVE_FAILED; mơ hồ → STORAGE_UNCERTAIN và reconcile trước write tiếp. Không truncate save thật trước commit, không bỏ ledger khi size quá lớn. Startup load v2 lỗi phải fail closed, kể cả bootstrap saved seeds; không để `_ready()` tự ghi đè save lỗi qua `save_seed_entry()` (`Scene/GameManager.gd:58–63,300–322`).
6. Xóa entry có ID chỉ theo ID; legacy dùng object hiện hành hoặc match duy nhất, ambiguity trả false. Last recorded không clear theo date đơn lẻ. Delete/clear không khiến retry tái tạo replay/history. Playback kết thúc không biến session identity từ action_replay thành live.

### P-02. Proposed file map cuối

Các đường dẫn có nhãn **mới** chưa tồn tại, không phải file đã tạo ở Commit 1. Chỉ tạo khi được giao commit tương ứng.

| File dự kiến | Commit | Thay đổi phục vụ contract |
| --- | --- | --- |
| `tests/test_run_completion_idempotency.gd`, `.tscn` (**mới**) | 2–4 | Black-box duplicate RED trước, sau đó new/duplicate/conflict/invalid/unknown, retention, reload/failure, deletion và E2E. |
| `tests/test_replay_security.gd` | 2–3 | Start trước gán frames trong mỗi simulated run; từng nhóm tự setup/teardown; giữ mọi regression assertion hợp lệ. |
| `Scene/GameManager.gd` | 3 | ID/lifecycle/envelope, boundary/receipt, mode bất biến, ledger, save/load whitelist, safe delete, common writer và load error guard. |
| `Scene/UI/character_select.gd` | 3–4 | Guard hẹp: preflight trước set hero/start và kiểm tra start thành công trước chuyển world khi còn PENDING/storage blocked; không đổi UI layout hay gameplay. |
| `Scene/RunCompletionStore.gd` (**mới nếu cần**) | 3 | Adapter nhỏ: candidate commit, explicit error/reconcile, temp storage injection; không đẩy Node vào worker threads. Có thể giữ helper trong GameManager nếu vẫn cô lập/kiểm thử được. |
| `tests/benchmark_run_completion.gd`, `.tscn` (**mới**) | 5 | Gate/queue 40 pending tasks cùng owner, raw latency/p95, workload và environment metadata. |
| `run_tests.bat`, `.github/workflows/ci.yml` | 3–6 | Wire suite mới trong bước tương lai; giữ replay step và disposable save. Không thay file này ở Commit 1. |
| `docs/BT3_VT074/` | 2–6 | Strategy/pairwise data/evidence/traceability/AI log/reflection/README; tên và số artifact theo evidence thực có. |

Caller `Scene/Character/BasePlayer.gd` chỉ cần xem xét lại nếu adapter không giữ được callsite hiện tại; không lên kế hoạch mặc định sửa hero/scenes gameplay. Guard character select và guard trong `GameManager.replay_seed_run()/start_action_replay()` là phần trực tiếp cần thiết để từ chối start an toàn, không redesign UI. Các `.tscn` mới chỉ là test/harness tương lai. Không sửa Dungeon Generator/Enemy AI/Inventory/Balance. Không tự thêm thư viện hoặc framework.
### P-03. Commit 2 — RED (chưa thực hiện)

- Lập risk-based strategy: ưu tiên duplicate, save failure/reload, legacy identity và flaky state/time/order. Chuyển đúng năm AC sang **ít nhất 10 test cases** có ID/precondition/input/oracle/cleanup/AC/risk. Coverage targets dự kiến: first commit; retry ngay; burst duplicate; cùng seed/date khác ID; invalid format/type; unknown ID; payload conflict; canonical equivalent; reload duplicate/conflict; deterministic save failure rồi retry; storage uncertain/reconcile; ledger 127/128/129; history/replay prune; delete replay/history/clear rồi retry; legacy ambiguity; action replay/fallback/mode kết thúc. Đây là danh mục mục tiêu, chưa phải test code hoặc kết quả.
- AI tạo bản test đề xuất; sinh viên phải sửa/xóa ít nhất hai test yếu/duplicated với before/after và lý do riêng, ví dụ oracle chỉ kiểm tra không crash hoặc hai case không phân biệt contract. Chưa có hai test thật để đánh giá ở Commit 1; không dựng bằng chứng chỉnh sửa hoặc nhận là sinh viên đã review.
- Đảm bảo baseline có ít nhất một **behavioral RED** chạy qua `finish_run()` hiện có: hai callback cùng run mà record count tăng hai; thêm reload RED khi khả thi. Không gọi method mới chưa tồn tại rồi báo parser/missing-method error là RED nghiệp vụ. Cases dùng boundary mới có thể chưa chạy được trên baseline: ghi trạng thái rõ, không gộp chúng thành behavioral failures đã xác minh. Nếu cần adapter test, chỉ chuyển lời gọi, không cài idempotency thay SUT.
- Isolate save trước khi scene `_ready()` của autoload có thể load/seed mặc định; dùng disposable project/user-data hoặc adapter đúng phạm vi, xác minh path thực trên Windows. Fixture chỉ dùng data tổng hợp; không backup/restore đè save cá nhân. Rà migration fixture FIFO trước áp contract mới, không xóa assertions cho CI xanh.
- Chạy và lưu RED thực: command, Godot version, SHA/working tree diff, expected failure, actual assertion, exit code, stdout/stderr, isolated path. Phân biệt lỗi setup với behavioral RED.

### P-04. Pairwise/combinatorial design — dữ liệu sẽ sinh ở Commit 2

| Factor | Levels dự kiến |
| --- | --- |
| Identity relation | active-new / retained-same / retained-conflict / invalid / unknown-expired |
| Seed relation với fixture đã có | same / different |
| Frames | empty / present |
| State source | in-memory / reload |
| Writer outcome | success / definite-failure / uncertain |
| Ledger boundary | below-128 / at-128 / overflow-to-129 |

Constraints: active-new sau reload cần start mới (không resume active cũ); conflict phải có receipt/PENDING cùng ID; payload relation không có nghĩa với invalid; writer failure chỉ được exercise ở nhánh thực sự ghi, duplicate không được gọi writer; expired không thể đồng thời retained. Tách mô hình accept/write và mô hình retained/retry nếu constraints làm coverage khó đọc. Ghi constraint/seed/tool, covering array, expected status và mapping pair → row; kiểm tra **mọi cặp khả thi** được phủ, liệt kê cặp bị loại và lý do. Không tuyên bố pairwise-complete trước khi có array và verifier output. Boundary 127/128/129, unknown/CLOSED, shared state và failure/reconcile có directed tests bổ sung ngoài pairwise. Mode live/action_replay/fallback kiểm tra regression riêng để tránh inflate mô hình tổ hợp.

### P-05. Commit 3 — AI-assisted patch → GREEN (chưa thực hiện)

Patch nhỏ theo P-01 và R-01–R-07, giữ `finish_run(reason)` adapter. Cập nhật writer chung và load cùng lượt, không chỉ save thêm key. Bootstrap phải tôn trọng storage lỗi; không emit COMMITTED khi chưa xác nhận snapshot. Verify atomic replacement/error semantics trên Windows/Linux thực tế hoặc báo blocker, không tự hạ AC-05. Chạy lại RED thành GREEN, replay regression, sanitizer/cap regression và suite liên quan CI; ghi actual command/log/exit code và diff. Chỉ gọi GREEN khi behavioral assertions và required regression pass; không suy từ “không crash”.

### P-06. Commit 4 — Integration (chưa thực hiện)

Negative/failure-path: sai ID/schema, conflict từng field, deterministic open/write/replace failure, uncertain outcome/reconcile, oversized file, corrupt v2 fail closed. Save/reload: ID/digest/date/receipt round-trip, retained retry sau history prune/delete/clear, legacy duplicate seed/date không bị gộp, last recorded loader không mất identity. Replay: seed retry ID mới, action replay ID mới, no-frames fallback, mutable playback flag không đổi mode session, delete B khi A/B cùng seed/date không xóa A. E2E phù hợp: CharacterSelect → start → completion qua adapter → history/replay → reload → retry explicit; có thể headless scene integration, không ép gọi REST/network không tồn tại. Cô lập animation/timer game over: kiểm tra completion hook trực tiếp, không sleep 2 giây làm oracle. Thời gian timer baseline tại `Scene/Character/BasePlayer.gd`, `take_damage():321–324` không thuộc request identity.

### P-07. Commit 5 — Quality & Performance (chưa thực hiện)

- Mutation đúng yêu cầu `>` → `>=` tại processed-ledger cap sau GREEN. Setup 128 completed IDs, oldest không active và đã rời history 15; retry oldest/P phải DUPLICATE. Mutant prune ở 128 làm UNKNOWN_RUN và test phải fail; control tại 129 chứng minh prune đúng một oldest. Ghi vị trí/predicate/patch, baseline PASS, mutant FAIL đúng assertion, phục hồi PASS và diff phục hồi. Nếu mutant không đổi outcome thì chưa có evidence kill; chỉnh oracle/target, không báo thành công.
- Coverage: AC → test → risk → source branch → log, gồm nhánh hit/miss/conflict/invalid/expired/save-fail/reconcile và boundary. Nếu có công cụ coverage phù hợp thì báo command, denominator và hạn chế; nếu chỉ risk/requirement coverage phải ghi đúng tên, không bịa % line coverage.
- Flaky checks: tối thiểu 20 lượt lặp, chạy case độc lập và thứ tự shuffled với seed được ghi; setup/teardown state/save/counters/signals; ID/time cố định, network off, không sleep oracle. Báo failures và reruns nguyên trạng, không chỉ giữ lượt pass. Đây là kế hoạch chưa có pass rate.
- Harness đúng NFR-02: cả 40 coroutine tasks phải pending trước drain; pending-count witness >=40, xử lý tuần tự tại owner main thread. Primary 1 commit +39 same-payload duplicate mỗi burst; secondary hỗn hợp conflict/invalid/duplicate trên ID đã commit, báo riêng. Không dùng 40 worker threads gọi Node và không gọi loop sync 40 lần là concurrency.
- 5 warm-up +30 measured bursts/workload, 40 samples/burst; baseline payload 2 frames và stress 3600 frames, báo mỗi workload riêng. Đo monotonic enqueue → result, bao gồm queue/hash/save; loại setup khỏi interval và nói rõ. Nearest-rank sorted[ceil(0.95*N)-1], N=1200 mỗi workload, vị trí 1140. Không bỏ timeout/error khỏi samples để làm p95 đẹp; ghi raw status/latency và fail workload. Mục tiêu p95 <=1500 ms, chưa có số đo. Ghi hardware/OS/Godot/SHA/config/storage/bytes/clock và kết quả correctness cùng latency.

### P-08. Commit 6 — Evidence và review (chưa thực hiện)

Viết README lệnh chạy và prerequisites thực đã xác minh; traceability AC/NFR/risk → case/pairwise row → RED/GREEN → mutation/perf/CI evidence; AI Usage Log có prompt/model nếu biết, output, phần sinh viên chấp nhận/sửa/bác; reflection **250–350 từ** do sinh viên review và chịu trách nhiệm; chuẩn bị evidence cho PDF. Đánh dấu rõ plan vs actual và missing evidence. CI/final review gồm regression, source diff, scope, original provenance và kết quả chưa đạt. Không bịa commit SHA/PR URL/coverage/p95. PR cá nhân ở bước được giao sau không merge trước nhóm review. Người dùng stage/commit bằng GitHub Desktop; không tự stage/commit/push/tạo PR trong phiên Commit 1.

### P-09. Traceability dự kiến và gates

| Contract/risk | Review | Commit kiểm chứng chính | Gate/evidence phải có |
| --- | --- | --- | --- |
| AC-01/AC-02 — one commit/no duplicate effects | R-01/R-03/R-06 | 2 →3 →5 | Behavioral RED, GREEN, count/save/signal assertions, raw 40-task witness. |
| AC-03 — same seed/date independent + deletion | R-04 | 2–4 | Fixed-clock collision fixture, delete đúng ID, replay regression. |
| AC-04 — invalid/unknown/conflict | R-05 | 2–4 | Zero-side-effect negative tests và directed cases ngoài pairwise. |
| AC-05 — reload/failure/retention | R-02/R-03/R-05/R-08 | 2–5 | v2/legacy fixtures, injected failures/reconcile, 128/129 boundary mutant kill. |
| NFR-01 — flaky/shared state/time/order | R-01 | 2–5 | Per-case isolation, independent/shuffled repeat logs, deterministic providers. |
| NFR-02 — 40 tasks p95 target | R-06 | 5 | Pending witness, raw latency/status, environment, percentile và failures. |
| NFR-03 — backward/replay | R-02/R-04/R-07 | 3–4 | Round-trip/legacy/ambiguous delete/playback mode integration. |
| Pairwise và human test review | O-13/P-04 | 2/6 | Covering-array feasible-pair evidence; ít nhất hai human revisions thật. |

Không chuyển từ RED sang GREEN bằng xóa test; không xem log kế hoạch là log chạy; không nhận workload p95 đạt nếu correctness fail. Runtime gates còn mở không ngăn Commit 1 tài liệu, nhưng bắt buộc giải quyết trước tuyên bố hoàn thành commit tương ứng.

### P-10. AI usage của riêng Commit 1

| Hoạt động | Thực tế trong phiên | Human review |
| --- | --- | --- |
| AI đọc yêu cầu/source và audit Git | Đã làm bằng read-only tools, evidence trong REVIEW. | Chờ sinh viên đối chiếu. |
| AI sinh original plan rồi review | Original được ghi trước review/spec và giữ hash; MODIFY là cải tiến có evidence, không giả lập người review thứ hai. | Chờ sinh viên duyệt quyết định thiết kế. |
| AI chốt revised plan/spec | Chỉ ba file docs của Commit 1; các việc Commit 2–6 vẫn là kế hoạch. | Chưa có human approval/commit. |
| AI sinh tests, human sửa >=2 tests, RED/GREEN/mutation/perf | Chưa thực hiện trong Commit 1. | Chưa thực hiện, không ghi nhận thay sinh viên. |
