# BT3 VT-074 — Idempotent Run Completion

## 1. Metadata và trạng thái

| Thuộc tính | Giá trị |
| --- | --- |
| Sinh viên / MSSV | Vũ Xuân Bắc / 23001833 |
| Team / Project / Variant | SE2026-T19 / GAME-2D-02 / VT-074 |
| Dự án | Keep Fighting And Earning — Procedural Dungeon Roguelike |
| Repository | https://github.com/Gumaisme2005/Keep-Fighting-And-Earning |
| Engine | Godot 4 / GDScript; config ghi 4.7 (`project.godot:15`), CI pin 4.7.2 (`.github/workflows/ci.yml:10–11`), chưa kiểm chứng binary local |
| Base / working branch | `development` / `feat/bt3-vt074-idempotent-run` |
| Baseline dự kiến / HEAD thực tế | Cùng `56e97e1b5c621774423b9e06aede4b8b6bcc0b08` |
| Ngày / trạng thái | 11/11/2026 (Asia/Saigon) / Specification cho Commit 1, chưa triển khai |

**VERIFIED FACT** là evidence source/Git; **ASSUMPTION** là tiền đề; **PROPOSAL** là contract thiết kế tương lai; **OPEN QUESTION** cần xác minh. Toàn bộ hành vi đích ở §3–8 là PROPOSAL, không mô tả tính năng đã có. Audit/source evidence và review R-01–R-08 ở [AI_PLAN_REVIEW.md](AI_PLAN_REVIEW.md); trình tự original → review → revised ở [AI_IMPLEMENTATION_PLAN.md](AI_IMPLEMENTATION_PLAN.md).

Không tìm thấy tracker `BT3_23001833_VT-074_KE_HOACH_THEO_DOI.txt` hoặc bản `(1)` trong workspace, nên áp dụng đầy đủ prompt được lưu nguyên văn trong plan. Không suy đoán nội dung tracker.

## 2. Problem statement — VERIFIED FACT

`Scene/GameManager.gd`, `finish_run():219–245`, tạo entry với seed, hero, floor, kills, reason, date rồi luôn `run_history.push_front(entry)` (240), enforce replay, save và emit. Không có completion ID/guard. Do đó gọi lại callback/request với cùng lượt chơi có thể tạo thêm history, save, signal và eviction (suy luận tĩnh, chưa chạy test). Guard `is_dead` ở `Scene/Character/BasePlayer.gd`, `take_damage():256–258,306–316`, chỉ chặn đường caller này, không tạo contract idempotency cho GameManager.

Seed dùng lại là hành vi hợp lệ: `Scene/GameManager.gd`, `replay_seed_run():333–338`, gọi `start_new_run(seed_str, false, [])`. Date chỉ là metadata lấy từ system clock tại `finish_run():221`; không chứng minh duy nhất. Đặc biệt `delete_replay():258–268` match entry đầu tiên theo equality HOẶC seed/date, có thể chọn nhầm khi hai run trùng seed/date; last recorded còn bị clear theo date đơn lẻ (264). Vì vậy không dùng seed/timestamp làm request ID.

Persistence hiện là JSON local: `save_data_to_disk():356–367`, `load_save_data():369–434` trong `Scene/GameManager.gd`; GameManager là autoload (`project.godot:17–21`). Search tracked source chưa tìm thấy backend cho completion (chi tiết phạm vi/lệnh tại REVIEW §2), không giả định có API hoặc server. Load dựng lại dictionary theo whitelist (`load_save_data():404–434`), nên chỉ thêm ID vào save là chưa đủ.

## 3. Scope, invariant và giới hạn bảo đảm

Vertical slice chỉ bảo vệ completion và những phần trực tiếp cần thiết: cấp identity ở lifecycle start, nhận diện retry/conflict, publish một result, persistence/retention, identity khi delete replay/history và test integration liên quan. Commit 1 chỉ có ba tài liệu; patch/test/harness thuộc Commit 2–6.

Invariant đích:

```text
For every valid run_id:
count(committed results for run_id) <= 1
```

`committed` nghĩa là result và processed receipt đã được xác nhận trong cùng snapshot local trước khi publish RAM/signal. `valid` gồm đúng định dạng VÀ được owner cấp theo lifecycle, không chỉ là một chuỗi hợp lệ cú pháp. Mỗi run_id không được cấp lại cho một lượt chơi khác. Registry giữ receipt hữu hạn (§6); ID đã hết retention không được tiếp nhận như new khi gửi lại, mà trả UNKNOWN_RUN. Do đó retention không phải quyền tái tạo record cũ. Không khẳng định exactly-once vô hạn trước hỏng/mất save, token collision hoặc writer ngoài process.

Invariant bổ sung: duplicate không thêm side effects; ID khác nhau không bị gộp vì seed/date; history <=15, replay có frames trong history <=10. Hai giới hạn là baseline thực tế tại `Scene/GameManager.gd:13–14`, được áp dụng trong `finish_run():240–243`, `enforce_replay_limits():248–256`. Ledger cap 128 là đề xuất mới, không nhầm với hai cap này. `last_recorded_run` giữ chính sách riêng baseline (full frames ở `finish_run():232–235`), không được diễn giải sai thành replay thứ 11 trong history.

## 4. Identity, payload và lifecycle contract

### 4.1. Identity và quyền tiếp nhận

- `run_id` là String đúng 32 ký tự hex thường `[0-9a-f]`, không trim/đổi case/tự sanitize ID sai. Sinh từ 128 bit entropy độc lập seed/clock tại `start_new_run()`. Kiểm tra va chạm active/ledger; sinh lại nếu thấy trùng. Test dùng generator xác định; không lấy system time làm oracle duy nhất.
- Chỉ một active run trong owner gameplay. Start bình thường hoặc `replay_seed_run()` cấp ID mới kể cả cùng seed/date. Chuyển tầng không cấp lại ID. `start_action_replay()` có frames cấp session ID mới, không dùng ID run nguồn; fallback không có frames vẫn là seed run mới. Cơ sở code path: `Scene/GameManager.gd`, `start_new_run():152–171`, `replay_seed_run():333–338`, `start_action_replay():340–354`.
- Active có trạng thái OPEN → PENDING → CLOSED. OPEN chưa có completion; PENDING có envelope đóng băng chưa commit; CLOSED đã commit, không mở lại. New request chỉ nhận active ID OPEN/PENDING. Ledger lookup diễn ra trước active lookup để retry run cũ vẫn dùng đúng ID dù run mới đã bắt đầu.
- `finish_run(reason)` giữ vai trò adapter cho caller hiện có, không sinh ID mới ở finish. Boundary nội bộ dự kiến `complete_run_request(run_id, payload)` trả status/receipt tường minh; tên/signature chính xác chốt khi RED, semantics giữ theo tài liệu này. Caller không phải sửa UI để dùng ID.
- Adapter lần đầu chụp envelope và date; gọi lại dùng envelope cũ, không đọc stats/frames global mới. Reason chuẩn hóa khác reason đã đóng băng → CONFLICT, không lặng lẽ coi là duplicate. Muốn retry sau reload phải có lại ID/payload gốc và dùng boundary explicit; không tự resume gameplay hoặc tự gửi lại bằng ID mới.
- Không bắt đầu run mới khi active PENDING chưa giải quyết: trả/ghi nhận SAVE_PENDING, giữ token/envelope; được retry save hoặc kết thúc process (có thể mất completion chưa commit). Caller phải kiểm tra quyền start trước khi đổi hero/state và chỉ chuyển scene khi start thành công: sửa guard hẹp trong character select và các hàm replay của GameManager, không thêm UI flow. Các callsite hiện chuyển scene sau start mà chưa kiểm tra kết quả (`Scene/UI/character_select.gd`, `_on_hero_selection_button_pressed():417–423`; `Scene/GameManager.gd`, `replay_seed_run():333–338`, `start_action_replay():347–354`); không được để start bị từ chối nhưng vẫn vào world. Trạng thái phải quan sát được qua result/diagnostic để integration test kiểm tra.

### 4.2. Payload canonical

Payload nghiệp vụ gồm seed đã sanitize và không rỗng, `hero_idx` trong roster, `floor` nguyên 1..9999, `kills` nguyên 0..999999, reason qua `sanitize_note` tối đa 80, `session_mode` live/action_replay, frames để gắn vào result được snapshot và sanitize tối đa 18000. Không nhận kiểu sai/NaN/Infinity hoặc field bắt buộc thiếu; không ép ID sai thành hợp lệ. Frames dùng schema/sanitizer baseline tại `Scene/GameManager.gd`, `_sanitize_replay_frames():89–127`, giữ các field replay hiện có.

Canonical encoding dùng tuple có thứ tự field cố định và phiên bản encoding, frame field order cố định, giữ thứ tự frame, chuẩn hóa các số frame cùng kiểu trước serialize/hash; không dựa vào iteration order của Dictionary. So sánh trên giá trị sau chuẩn hóa: hai input raw cho cùng payload canonical là duplicate; thay đổi một field canonical là conflict. Fingerprint SHA-256 của canonical payload được lưu riêng, không tái dựng từ history đã prune/frames bị xóa hoặc cắt còn 3600. Date, display hero name và các flag trình bày sau eviction không nằm trong fingerprint. Trả receipt nhỏ gồm run_id, fingerprint, committed date và kết quả tóm tắt; không trả mutable reference tới ledger.

`session_mode` chốt tại start, khác `is_replaying` đang thay đổi. `Scene/Character/BasePlayer.gd`, `_physics_process():156–170`, tắt `is_replaying` khi hết frames; dùng flag đó làm identity sẽ sai. Để giữ compatibility, việc gắn frames ở completion vẫn theo chính sách baseline `Scene/GameManager.gd`, `finish_run():231–238`: đang playback thì không ghi recorded replay; sau playback kết thúc giữ hành vi baseline. Kết quả quyết định này được chụp một lần vào envelope; không redesign playback/recording.

### 4.3. Request outcomes

| Trường hợp | Điều kiện | Expected result và side effects |
| --- | --- | --- |
| New request | ID active OPEN, payload hợp lệ, chưa có receipt | Dựng candidate, commit snapshot; COMMITTED + receipt. Một entry, một lần publish `last_recorded_run` nếu có frames, một lần enforce caps và một `saved_data_changed` sau commit. |
| Duplicate request | ID còn trong ledger, fingerprint giống | DUPLICATE + receipt cũ; không thêm entry, không đổi date/order/caps/last recorded/ledger, không gọi save hoặc emit completion signal. Không khôi phục dữ liệu đã delete. |
| Conflicting request | ID ledger/PENDING, payload hợp lệ nhưng fingerprint khác | CONFLICT; không ghi/sửa history/replay/ledger/save/signal; giữ envelope đầu. |
| Invalid request | ID sai kiểu/rỗng/định dạng hoặc payload sai schema | INVALID_REQUEST; không có completion side effect. Validation trước tra cứu payload conflict. |
| Unknown/expired request | ID đúng cú pháp nhưng không có ledger và không phải active OPEN/PENDING | UNKNOWN_RUN; không tạo entry, không suy luận identity từ seed/date. CLOSED không được đi lại nhánh new. |
| Retry after reload | Đọc được snapshot v2 hợp lệ có ledger cho ID | Cùng fingerprint → DUPLICATE; khác → CONFLICT; không phụ thuộc history/replay còn hay đã xóa. Không còn ledger → UNKNOWN_RUN. |
| Save thất bại xác định | Failure trước khi replace snapshot đích; xác nhận snapshot committed cũ còn nguyên | SAVE_FAILED; history/last recorded/ledger committed và signal count không đổi. Active PENDING giữ envelope/date, retry sau khắc phục chỉ commit một lần. |
| Retry PENDING | Cùng ID/envelope chưa commit sau lỗi xác định, storage đã sẵn sàng | Thử commit candidate cũ; thành công → COMMITTED một lần rồi CLOSED, còn lỗi → SAVE_FAILED/PENDING. Không tạo token/date/payload mới và không cho start mới làm mất envelope. |
| Kết quả storage chưa xác định | Replace hoặc xác nhận không cho biết chắc snapshot nào đang là đích | STORAGE_UNCERTAIN, không báo COMMITTED và không retry mù; chặn write tiếp tới reconcile/reload. Nếu đọc lại xác nhận candidate có result + receipt cùng ID/digest thì hoàn tất/publish một lần; nếu xác nhận bản cũ thì được retry; không phân giải được tiếp tục fail closed. |

## 5. Đúng năm acceptance criteria

| AC | Điều kiện đầu vào cụ thể | Expected result kiểm thử được |
| --- | --- | --- |
| AC-01 | Save isolated hợp lệ; start cấp ID A mới; seed S, hero hợp lệ, floor 2, kills 7, reason cố định; storage thành công. | COMMITTED; đúng một entry `run_id=A`, một receipt A, tối đa một cập nhật last recorded theo frames, một completion save và một signal. Snapshot reload có cùng ID/digest. Caps vẫn 15/10. |
| AC-02 | A đã COMMITTED với payload P, ID còn trong ledger; gửi lại A/P 2 lần và burst 40 tác vụ; lặp lại sau khi xóa replay hoặc history A. | Mọi retry DUPLICATE với receipt cũ; số record/frames/save/signal không tăng từ retry, không thay date/order/ledger và không tái tạo dữ liệu đã xóa. Đối chiếu state trước retry, không đòi history A còn tồn tại sau deletion. |
| AC-03 | Start và commit A; start và commit B khác A, cùng seed S, cùng clock fixture timestamp T, cả hai có frames, history còn chỗ. | Hai entry và hai receipt độc lập A/B; không dedup theo S/T. Xóa replay B chỉ xóa frames B, không ảnh hưởng A hoặc last recorded của A nếu đang trỏ A. |
| AC-04 | Trên state xác định: gửi ID rỗng/sai kiểu/sai định dạng; gửi ID đúng cú pháp chưa được cấp; gửi A đã commit với P' khác P ở một field canonical; gửi payload sai schema. | Tương ứng INVALID_REQUEST, UNKNOWN_RUN, CONFLICT, INVALID_REQUEST; không thêm/sửa record/frames/ledger, không save/signal. Không sanitize ID để biến thành A. |
| AC-05 | Commit A, reload snapshot v2 khi A nằm trong 128 receipts gần nhất; thử A/P và A/P'. Ở fixture khác, inject lỗi open/write/replace trước commit; rồi khắc phục và retry ID/envelope đang PENDING. Thử cả biên 128/129 và kết quả storage mơ hồ. | Reload: DUPLICATE/CONFLICT, không duplicate. Failure xác định: SAVE_FAILED, committed state/disk đích giữ nguyên, không signal; retry thành công đúng một result. Storage mơ hồ: STORAGE_UNCERTAIN, reconcile trước ghi lại. Đúng 128 giữ oldest receipt; thêm thứ 129 mới loại oldest, retry ID expired trả UNKNOWN_RUN không tạo lại. |

Các quan sát save/signal chỉ đếm phần completion sau setup; start/bootstrap/save-seed hoặc thao tác delete tự có side effect riêng, không đếm nhầm là duplicate. Định nghĩa test cases chi tiết/pairwise và chạy RED sẽ thực hiện ở Commit 2, chưa tạo test tại Commit 1.

## 6. Persistence, retention và save failure

- Snapshot đề xuất version 2 giữ các field baseline cùng `schema_version`, processed ledger FIFO (oldest → newest), fingerprint/receipt; history và last recorded giữ `run_id`. Load khôi phục rõ các key mới, date/reason cần cho matching, không dựa vào JSON tự gán member. Loader hiện phải sửa whitelist tại `Scene/GameManager.gd`, `load_save_data():404–434` (review R-02).
- Result và receipt phải nằm trong cùng snapshot transaction, không dùng hai file commit độc lập. Candidate deep-copy không làm mutate frames đã publish; kiểm tra schema/caps và byte UTF-8 <=2097152 trước replace. Không mở truncate file đích trước khi candidate được xác minh. Khi vượt cap trả SAVE_FAILED, không bỏ ledger âm thầm để vừa file.
- Một writer chung cho completion, seed save và deletion để mọi snapshot sau này vẫn mang ledger. Write candidate vào file tạm cùng thư mục, kiểm tra write/flush/error, thay đích, đọc lại xác nhận snapshot nhất quán rồi publish RAM/receipt/signal. Semantics atomic/flush trên platform phải kiểm chứng ở Commit 3; không hứa chống power loss hoặc distributed transaction. Không coi hàm void baseline là xác nhận.
- Retention theo **số completion thành công**, không TTL/thời gian thực: tối đa 128 receipt mới nhất. Chỉ prune khi count `> 128`. Tại 128 không prune; tại 129 loại đúng oldest. Duplicate/conflict/invalid/save failure không tăng count/đổi FIFO. Giữ receipt sau khi history (15) bị cắt hoặc replay (10) bị thu hồi; manual deletion/clear không xóa ledger.
- Sau retention, không hứa trả receipt hoặc phát hiện payload conflict cũ: trả UNKNOWN_RUN vì ID không còn được nhận diện; không nhận lại như new. Adapter active CLOSED cũng không được chèn lại. Token không tái sử dụng là tiền đề identity; random collision ngoài phần registry còn giữ là residual risk.
- Khi lỗi v2 (ledger thiếu/sai, ID trùng fingerprint bất nhất, schema không hỗ trợ, JSON hỏng hoặc file quá lớn), không tự reset ledger rồi nhận completion mới: fail closed/read-only cho tới khôi phục snapshot hợp lệ hoặc người dùng chủ động xử lý save. Không ghi đè save lỗi để giả vờ thành công. Reload thất bại không được nối dữ liệu half-loaded vào state cũ.
- PENDING chỉ ở RAM; không hứa recovery active/uncommitted envelope sau process crash. Nếu đã xác nhận snapshot commit và process dừng trước publish, reload đọc result+ledger và retry vẫn DUPLICATE. Nếu chưa commit và process dừng, có thể mất completion; đó là giới hạn persistence, không phải thành công bền vững.

## 7. Backward compatibility và replay/history deletion

Save legacy không có schema version/ID/ledger được đọc theo sanitizer/cap cũ, giữ mọi entry độc lập kể cả seed/date bằng nhau, khởi tạo ledger rỗng; không tự dedup/backfill ID hoặc gọi completion để migrate. Lần save thành công tiếp theo có thể ghi version 2 với entry legacy không ID. Không bảo đảm retry completion xảy ra trước migration vì chưa có token để chứng minh identity. Schema version 2 thiếu ledger là lỗi, khác legacy thiếu ledger hợp lệ.

Entry có ID được `delete_replay()` match bằng ID duy nhất, không fallback seed/date khi ID không match. Legacy ưu tiên đúng object trong run_history; dictionary copy chỉ dùng khi có đúng một candidate đầy đủ, nhiều candidate trả false không thay đổi. Last recorded chỉ clear khi chứng minh đúng run bằng ID hoặc legacy match đủ fields duy nhất; date-only bị loại. `delete_run_history_entry(index)` vẫn xóa đúng index; nếu last recorded cùng ID thì clear dữ liệu liên quan, không xóa receipt. `clear_all_replays()` giữ history/ledger, xóa frames theo baseline; retry completion không ghi lại replay đã xóa. Đây là thay đổi trực tiếp bảo vệ identity, không mở UI redesign.

Giữ cap frames baseline 18000 live và 3600 trên history disk (`Scene/GameManager.gd:15–16`, `finish_run():231–235`, `load_save_data():410–421`), giữ action replay/fallback và sanitizer. Regression cần bảo vệ ID/date sau load, legacy ambiguous deletion, các phím frame mở rộng, cap FIFO, idle compression và session kết thúc playback. Không suy diễn việc tải đầy đủ date/reason của last recorded là có sẵn: loader hiện không giữ chúng (`load_save_data():424–434`).

## 8. Non-functional constraints

| NFR | Ràng buộc và cách kiểm chứng dự kiến |
| --- | --- |
| NFR-01 | Test cô lập active/ledger/frames/flags/counters và save path/adapter từng case; ID generator/clock xác định, không network, không sleep/system timestamp làm oracle. Setup tự tạo fixture, teardown/disconnect signals. Chạy từng case và đảo thứ tự với seed ghi lại; tối thiểu 20 lượt lặp có logs ở Commit 5. Không suy ra “hết flaky” từ một lần pass. Evidence shared state baseline: `tests/test_replay_security.gd`, `_ready():19–23`, FIFO 37–67, manual 69–79. |
| NFR-02 | Mục tiêu p95 <=1500 ms với **40 concurrent tasks trong một process, cùng owner main thread**. Gate nhận đủ 40 task pending rồi mới drain queue; các request pending chồng lấn, xử lý save tuần tự. Primary burst cùng active ID/P: 1 COMMITTED +39 DUPLICATE; secondary burst đã commit gồm duplicate/conflict/invalid, báo riêng. Có pending-count witness >=40; không báo 40 lệnh sync liên tiếp là concurrency. Đo monotonic từ enqueue tới receipt, gồm queue/hash/persistence, không gồm sinh dữ liệu/import. Commit 5: 5 burst warm-up tách khỏi 30 burst đo, mỗi burst setup riêng; payload chính 2 active frames xác định và workload 3600 frames đo riêng; báo từng workload, không gộp che tail. Nearest-rank p95 = sorted[ceil(0.95*N)-1], N=1200 mỗi workload (vị trí 1140); timeout/failure phải ghi raw và làm workload fail, không loại bỏ. Ghi OS/CPU/RAM/Godot/SHA/byte size/storage/config và raw latencies. Đây không phải 40 threads truy cập Node hay 40 user mạng; chưa có kết quả p95. |
| NFR-03 | Save legacy đọc được và không gộp entries; v2 round-trip ID/digest/receipt/date; replay vẫn được xem, seed retry tạo run mới, caps 15/10 và sanitizer giữ nguyên. Kiểm chứng bằng fixture legacy/v2 và regression headless/E2E ở Commit 3–4; không xóa regression để làm CI xanh. |

Pairwise/combinatorial coverage là kỹ thuật bắt buộc trong test strategy, không thay thế boundary/failure tests. Mutation `>` → `>=` nhắm đúng retention 128 với observable oracle; planned workflow và traceability ở revised plan. Chưa chạy test/mutation/benchmark/coverage trong Commit 1.

## 9. Assumptions, residual risks và out-of-scope

**ASSUMPTION:** một process/single writer giữ save; không external writer; token generator hoạt động đúng; caller retry giữ ID/envelope; filesystem không bị chỉnh thủ công giữa commit và reload. 128 receipts là lựa chọn thiết kế của slice, không phải yêu cầu đã thấy trong source/tracker. OPEN QUESTION về platform durability và xác nhận mô hình concurrency với giảng viên được ghi ở REVIEW §6, là gate của giai đoạn triển khai.

**Residual risks:** random/digest collision, save tampering/corruption, size cap do full last replay, pending mất khi process dừng, out-of-band save overwrite, freeze/hash frame lớn và queue latency. Không khẳng định p95/coverage/CI PASS cho tới có evidence thực tế. Trước khi áp dụng trên save thật phải chạy isolated failure/reload checks. Pending diagnostic cần quan sát được; không giả định UI hiện tại đã có thông báo save lỗi.

**Out-of-scope:** REST API mới, multiplayer server, network replication, distributed exactly-once processing, UI/gameplay redesign, Enemy AI, Inventory, Game Balance, Dungeon Generator và bảo đảm khôi phục active gameplay sau crash. PR cá nhân tương lai không được merge trước nhóm review. Commit 1 không stage/commit/push/tạo PR, không sửa gameplay/test/CI và không triển khai Commit 2.
