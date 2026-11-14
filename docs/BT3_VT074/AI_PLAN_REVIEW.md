# BT3 VT-074 — Review AI plan và repository evidence

Vũ Xuân Bắc — 23001833 — SE2026-T19 — GAME-2D-02 — VT-074. Ngày 11/11/2026 (Asia/Saigon).

## 1. Repository/baseline audit — VERIFIED FACT

| Kiểm tra read-only | Kết quả quan sát |
| --- | --- |
| `git rev-parse --show-toplevel` | `C:/Users/ADMIN/Documents/GitHub/Keep-Fighting-And-Earning` |
| `git remote -v` | origin fetch/push: `https://github.com/Gumaisme2005/Keep-Fighting-And-Earning.git` |
| `git status --short` trước chỉnh sửa | Không có output; working tree sạch |
| `git branch --show-current` | `feat/bt3-vt074-idempotent-run` |
| `git rev-parse HEAD` | `56e97e1b5c621774423b9e06aede4b8b6bcc0b08` |
| `git log -1 --oneline` | `56e97e1 Merge pull request #71 from Gumaisme2005/feat/enemy-tactical-ai` |
| `git rev-parse development` | Cùng SHA với HEAD/baseline dự kiến |
| `git log --oneline 56e97e1b5c621774423b9e06aede4b8b6bcc0b08..HEAD` | Không có commit chênh lệch |
| Tài liệu VT-074 ban đầu | Chưa có `docs/BT3_VT074/`; đã liệt kê docs hiện có trước khi tạo |
| Tracker và hướng dẫn | Tìm recursively cả hidden: không thấy `*KE_HOACH_THEO_DOI*` hoặc `AGENTS.md` trong workspace; kiểm tra cả các đường dẫn AGENTS.md ở thư mục cha, không có file được trả về |

Không có lệch baseline cần giải thích hoặc thay đổi cũ cần ghi đè. Không checkout/stage/commit/push/PR. Git không nằm trong PATH của PowerShell; các lệnh thực tế dùng `& 'C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe' ...`. Đây là cùng binary Git của GitHub Desktop; lỗi PATH ban đầu đã được khắc phục bằng đường dẫn này.

Tracker chưa truy cập được vì không tìm thấy trong workspace. Không coi các báo cáo/test output cũ dưới cache là evidence của phiên này. Phạm vi audit là checkout local, không fetch hoặc xác nhận trạng thái remote hiện thời.

## 2. Source evidence và trả lời các câu hỏi phân tích

Mọi số dòng dưới đây thuộc baseline SHA ở trên, không phải số dòng sau patch tương lai. Đã đọc toàn bộ chín file bắt buộc: `Scene/GameManager.gd`, `Scene/Character/BasePlayer.gd`, `Scene/UI/character_select.gd`, `Menu/main menu/main_menu.gd`, `Menu/game over menu/game_over_menu.gd`, `tests/test_replay_security.gd`, `.github/workflows/ci.yml`, `project.godot`, `README.md`.

| ID | VERIFIED FACT và ý nghĩa | File / function / dòng |
| --- | --- | --- |
| E-01 | Main menu mở CharacterSelect; chọn hero gọi start mới trước khi chuyển world. Start làm sạch seed, reset level/kills/time, đặt playback flag, reset frames và seed combat RNG. Không tạo completion ID. | `Menu/main menu/main_menu.gd`, `_on_start_button_pressed()`, 487–490; `Scene/UI/character_select.gd`, `_on_hero_selection_button_pressed()`, 414–423; `Scene/GameManager.gd`, `start_new_run()`, 152–171 |
| E-02 | Caller gameplay duy nhất tìm thấy gọi finish là nhánh chết của BasePlayer, có `is_dead` guard. Tests gọi trực tiếp; game over menu chỉ hiển thị/pause và các nút retry/replay, không gọi finish. | `Scene/Character/BasePlayer.gd`, `take_damage()`, 256–258,306–324; `tests/test_replay_security.gd`, `test_replay_limit_10_fifo_eviction()`, 43–52; `Menu/game over menu/game_over_menu.gd`, `_build_extra_gameover_controls()` 46–61, `pause()` 93–103 |
| E-03 | Mỗi finish tạo timestamp mới, entry mới, push_front, enforce replay, resize history, save và emit. Không có early return kiểm tra completed ID. Hai lời gọi cùng state vẫn tạo hai entry (suy luận tĩnh, chưa chạy tái hiện). | `Scene/GameManager.gd`, `finish_run()`, 219–245; đặc biệt 221,240–245 |
| E-04 | Cap history 15/replay 10; replay cap chỉ bỏ frames/has_replay ở các entry cũ, không gộp run. Idle input dedup là nén frame, không phải dedup completion. Saved seed dedup chỉ theo seed. | `Scene/GameManager.gd`, constants 13–17; `enforce_replay_limits()` 248–256; `record_frame_input()` 173–206; `save_seed_entry()` 300–322 |
| E-05 | Seed retry tạo run chơi mới (`false`); action replay có frames gọi start playback (`true`), không có frames thì fallback seed run. Source entry không được dùng làm identity duy nhất. | `Scene/GameManager.gd`, `replay_seed_run()` 333–338; `start_action_replay()` 340–354; nút tương ứng tại `Menu/main menu/main_menu.gd`, `_refresh_seed_lists()` 349–365 và `Menu/game over menu/game_over_menu.gd`, `_build_extra_gameover_controls()` 46–61 |
| E-06 | Save JSON chỉ có current seed, hero index, saved seeds, run history, last recorded run. Mở trực tiếp file đích WRITE; null open không báo lỗi; trả void, không kiểm tra lỗi write. Finish đã sửa RAM trước khi save và vẫn emit. | `Scene/GameManager.gd`, `save_data_to_disk()` 356–367; `finish_run()` 240–245; `SAVE_FILE_PATH` 7 |
| E-07 | Load bỏ file thiếu/không mở được/>2 MB/JSON không phải Dictionary. Dựng lại history theo whitelist; không tự giữ thêm key. Last-recorded loader còn không giữ date/reason/has_replay. Không có processed registry loader. | `Scene/GameManager.gd`, `load_save_data()` 369–434; history 404–423; last recorded 424–434 |
| E-08 | Delete replay dừng ở entry đầu thỏa dictionary equality HOẶC cùng date và seed; do đó có thể xóa entry khác trước target khi hai run trùng seed/date. Last recorded bị clear chỉ vì date bằng nhau. Đây là khả năng từ điều kiện code, chưa phải kết quả runtime. | `Scene/GameManager.gd`, `delete_replay()` 258–269, đặc biệt 260,264–265 |
| E-09 | Xóa history theo index, clear frames rồi remove entry; không clear last recorded. Clear all giữ history, xóa frames/flags và cả recording/playback/last recorded. Cả hai đều save và emit. Completion retry không được tái tạo dữ liệu đã xóa. | `Scene/GameManager.gd`, `delete_run_history_entry()` 271–280; `clear_all_replays()` 282–291 |
| E-10 | Fixture FIFO tạo 13 run bằng gán global rồi finish, không gọi start. Manual-deletion dựa vào state FIFO tạo trước; clear-all lại dùng state tiếp. Đây là shared state/order dependency giữa các test group, chưa có kết quả chạy đảo thứ tự. Các hàm clear/finish còn ghi thật vào user save. | `tests/test_replay_security.gd`, `_ready()` 19–23; `test_replay_limit_10_fifo_eviction()` 37–67; `test_replay_manual_deletion()` 69–79; `test_clear_all_replays()` 81–86; đối chiếu E-06/E-09 |
| E-11 | GameManager là Node autoload. CI có bước replay với XDG_DATA_HOME riêng; không giải quyết shared state trong cùng scene. Engine config ghi 4.7, CI pin 4.7.2; README đưa lệnh headless và các pass count lịch sử. Không suy ra executable local, CI hiện tại hoặc kết quả phiên này từ đó. | `Scene/GameManager.gd` 1; `project.godot`, `[application]` 13–15, `[autoload]` 17–21; `.github/workflows/ci.yml`, `env` 10–11, replay step 136–143; `README.md`, §5 143–170, §6 175–201 |
| E-12 | Playback flag có thể chuyển về false khi hết frames, dù session bắt đầu là action replay. Không thể dùng flag đang biến động làm thuộc tính identity bất biến. | `Scene/Character/BasePlayer.gd`, `_physics_process()` 147–170; `Scene/GameManager.gd`, `start_new_run()` 162–168, `finish_run()` 231–238 |

Về backend: chạy `git grep -n -E 'HTTPRequest|HTTPClient|ENet|WebSocket|multiplayer' -- '*.gd' '*.godot'` trên các file tracked trả exit 1 (không match). Kết hợp E-06 và E-11, **VERIFIED FACT** là completion path đã đọc dùng JSON local/Node singleton; chưa tìm thấy REST/multiplayer backend phục vụ feature này trong phạm vi tìm kiếm. Không lấy chữ “Multiplayer Ready” ở `README.md:30–33` hoặc comment `Scene/GameManager.gd:247` làm bằng chứng có server. Không khẳng định đã kiểm chứng hạ tầng bên ngoài repo. `git grep ... run_id ...` có match biến đặt tên output benchmark ở `benchmark/advanced/kiem_tra_seed_doc_lap.gd:27–36,61`; đó không phải completion identity trong GameManager (E-01/E-03/E-07).

Tổng hợp 10 câu hỏi: E-01 trả lời start; E-02 trả lời caller; E-03/E-06 trả lời thời điểm lưu và duplicate; E-04/E-05 trả lời seed/time/replay và phân biệt dedup hiện có; E-06/E-07 trả lời JSON; E-10 trả lời test state; E-07–E-12 chỉ ra regression khi thêm ID (mất key sau reload, fixture collapse, delete nhầm, playback mode, save failure); đoạn search trên trả lời backend. Tất cả là phân tích tĩnh.

## 3. Provenance và phương pháp review

Original plan đã được ghi vào [AI_IMPLEMENTATION_PLAN.md](AI_IMPLEMENTATION_PLAN.md), mục `ORIGINAL AI IMPLEMENTATION PLAN`, trước file review/specification. Sau đó mới đọc lại có trọng tâm completion/deletion/save/load và playback flag để review. Đây là lượt review độc lập về bước công việc do cùng coding agent thực hiện, không phải human review hoặc một agent thứ hai.

Khối bất biến từ `## ORIGINAL AI IMPLEMENTATION PLAN` tới hết comment `END ORIGINAL...` có SHA-256 UTF-8: `A328C1684B71C3A7EF52C0E8F23C7AABD096B81597A000E2FE47F056EB4C8791`. Dùng hash để kiểm tra original không bị viết lại sau review; hash không phải chữ ký phê duyệt của sinh viên.

Original đã dự liệu các nhóm rủi ro chính, nên không tìm thấy hai khẳng định sai hoàn toàn để REJECT một cách trung thực. Các MODIFY dưới đây là **cải tiến cụ thể có evidence cho đề xuất còn thiếu chi tiết**, không ngụy tạo lỗi AI hoặc tuyên bố sinh viên đã sửa test. Các câu trích ở cột original lấy từ O-xx, không phải statement bịa ra cho review.

## 4. Bảng review plan

| Review ID | Original AI statement | Source evidence | Vì sao chưa đủ | Decision | Revised decision | Tác động Commit 2–6 |
| --- | --- | --- | --- | --- | --- | --- |
| R-01 | O-06: “Fixture mô phỏng nhiều run phải bắt đầu đúng lifecycle.” | E-10: `tests/test_replay_security.gd`, FIFO 43–52, manual 69–79, clear 81–86 | Chỉ thêm start vào loop chưa tách manual/clear khỏi thứ tự FIFO; start cũng clear frames nên đặt sai chỗ sẽ mất fixture. | MODIFY (cải tiến) | Mỗi vòng start trước khi gán stats/frames; manual và clear tự tạo dữ liệu riêng, setup/teardown đủ active ID, registry, flags, frames và save adapter. Giữ cap/FIFO/delete/idle assertions, không xóa regression. | C2: kế hoạch fixture và RED; C3: migrate fixture khi contract đổi; C4/C5: chạy riêng/đảo thứ tự. |
| R-02 | O-09: “cập nhật cả save và load, validate trường mới.” | E-07: `Scene/GameManager.gd`, `load_save_data()` 404–434 | Chưa liệt kê whitelist thực tế; sửa mỗi history vẫn làm mất ID và date của last recorded. Không thể tái dựng digest từ frames đã bị cắt/xóa. | MODIFY (cải tiến) | Load rõ schema, FIFO ledger/fingerprint/receipt, `run_id` của history và last recorded, date/reason cần đối chiếu; fingerprint giữ riêng bất biến. Validate toàn snapshot trước publish, legacy không ID giữ nguyên, không backfill bằng seed/date. | C2: round-trip contract; C3: save/load đồng bộ; C4: retry reload sau prune/delete + legacy. |
| R-03 | O-11: “ghi candidate ra file tạm rồi thay snapshot sau khi kiểm tra thành công” | E-06: `save_data_to_disk()` 356–367; E-07: load cap 375–383 | Chưa phân biệt thất bại chắc chắn trước replace với tình trạng không biết replace đã thành công chưa; size cap hiện chỉ ở loader. Các writer khác vẫn có thể ghi snapshot thiếu ledger nếu không dùng chung writer. | MODIFY (cải tiến) | Chung một writer cho mọi save; deep-copy candidate, kiểm tra byte <=2 MB, write/flush/error/replace + read-back xác nhận result và ledger cùng tồn tại. Lỗi trước replace → SAVE_FAILED; kết quả mơ hồ → STORAGE_UNCERTAIN, reconcile trước ghi tiếp. Không báo durable commit từ void. | C2: failure injection; C3: transaction adapter; C4: lỗi open/write/replace/reconcile. |
| R-04 | O-09: “legacy entry cần fallback an toàn.” | E-08: `delete_replay()` 258–268; E-09: history delete 271–280/clear 282–291 | Chưa định nghĩa fallback khi có nhiều entry cùng seed/date; date-only có thể clear nhầm last recorded. | MODIFY (cải tiến) | Entry có ID chỉ match ID, không OR với seed/date. Legacy ưu tiên đúng object trong memory; bản sao chỉ được dùng khi match duy nhất, nếu mơ hồ trả false không xóa. Last recorded đối chiếu ID hoặc legacy match duy nhất đủ fields; không clear chỉ vì date. Delete không xóa ledger và duplicate không phục hồi replay/history. | C2: regression collision; C3/C4: delete matching + reload compatibility. |
| R-05 | O-10: “ID hết retention và không phải active run bị UNKNOWN_RUN” | E-01: `Scene/GameManager.gd`, start 152–171; E-03: finish 219–245; E-09: delete 271–291; E-01/E-05: `Scene/UI/character_select.gd`, selection 417–423, `Scene/GameManager.gd`, seed/action replay 333–354 | Cần quyết định active đã hoàn tất có được trở lại nhánh new không; baseline chưa có lifecycle state. Khi thêm rule chặn start lúc PENDING, callsite hiện vẫn chuyển scene sau start mà không kiểm tra kết quả. | MODIFY (cải tiến) | New chỉ nhận active OPEN/PENDING; CLOSED không mở lại. Hết receipt → UNKNOWN_RUN kể cả last active CLOSED. Reload chỉ retry ledger, không resume active. Lookup ledger trước active. PENDING/storage blocked từ chối start; guard trước đổi hero/state, chỉ chuyển world khi start thành công trong character select và các hàm replay; không mở UI redesign. Đây là hoàn thiện integration cho rule PENDING của revised contract. | C2: expired/closed cases; C3: lifecycle/start guard và caller guard hẹp; C4: reload/deletion, kiểm tra start bị từ chối không đổi scene. |
| R-06 | O-15: “40 coroutine tasks được enqueue trước khi owner xử lý” | E-11: Node autoload `project.godot:19`; E-03/E-06: mutable arrays, file write, signal | Mô hình đúng hướng nhưng chưa có witness và workload tái lập; 40 synchronous calls tự thân không chứng minh overlap. | MODIFY (cải tiến) | Gate/drain queue sau khi cả 40 tasks pending, chứng minh max pending >=40; primary workload là 40 cùng ID/payload (1 commit +39 duplicate), secondary gồm conflict/invalid; tất cả qua cùng owner. Đo queue đến reply bằng monotonic clock, nêu sample/nearest-rank. Không gọi worker thread trực tiếp Node. | C5: harness và raw metrics; C6: giới hạn mô hình trong báo cáo. |
| R-07 | O-07: “đóng băng snapshot lần completion đầu ... mode và frames” | E-12: `BasePlayer._physics_process()` 156–170; E-05: action replay 340–354 | Nếu capture mode từ `is_replaying` tại finish, session playback vừa hết frames bị nhận thành live. Không nên đổi gameplay recording sau playback để giải quyết identity. | MODIFY (cải tiến) | Lưu `session_mode` bất biến ngay start; giữ `is_replaying` cho playback hiện tại. Identity dùng session_mode; điều kiện gắn recorded frames giữ hành vi baseline, được snapshot một lần. Test cả playback đang chạy và kết thúc; không tái dùng ID nguồn. | C2: contract/fixture; C3: mode metadata; C4: playback/fallback E2E. |
| R-08 | O-15: “chọn điều kiện retention `size > 128`, đổi thành `>=`” | E-04: history/replay cap đã có `>` tại `Scene/GameManager.gd:242,253` | Baseline chưa có ledger cap 128. Mutation chỉ là kế hoạch cho predicate mới, không được báo mutant đã bị kill. | ACCEPT | Sau GREEN, ở đúng 128 receipt oldest phải DUPLICATE; mutant eviction sớm làm UNKNOWN_RUN. Ở 129 oldest mới hết retention. Chọn lại target nếu implementation không có predicate tương đương quan sát được. | C2: boundary oracle; C5: mutation log bản gốc/mutant/phục hồi. |

## 5. Revised decisions và decision log

Tất cả dưới đây là **PROPOSAL đã chốt cho specification**, chưa triển khai:

| Decision | Nội dung cuối | Truy vết |
| --- | --- | --- |
| D-01 | Token opaque 32 hex, sinh tại start; active lifecycle OPEN/PENDING/CLOSED và ledger lookup trước active; seed/date không phải khóa. | O-04/O-06; R-05; SPEC §4 |
| D-02 | Payload canonical + fingerprint riêng; đóng băng envelope và date; mode session bất biến; adapter giữ snapshot khi retry. | O-07/O-08; R-02/R-07; SPEC §4–5 |
| D-03 | Snapshot version 2 gồm result và FIFO ledger tối đa 128; writer chung, xác nhận commit mới publish; lỗi mơ hồ fail closed. | R-02/R-03; SPEC §6 |
| D-04 | History <=15, replay <=10; deletion giữ ledger; identity matching an toàn cả legacy ambiguity; không hồi sinh dữ liệu đã xóa. | R-04; SPEC §7 |
| D-05 | Test isolation từng case, test-first, AI proposals cần sinh viên review hai test; 40 overlapping tasks cùng owner, không có network benchmark. | R-01/R-06; PLAN revised roadmap |
| D-06 | Ngày/seed trùng vẫn là hai run; playback session ID mới; không hứa resume active run, crash-proof distributed exactly-once hoặc receipt vô hạn. | R-05/R-07; SPEC assumptions/risks |

Revised implementation plan chi tiết và phân công file/commit nằm tại [AI_IMPLEMENTATION_PLAN.md](AI_IMPLEMENTATION_PLAN.md), mục `REVISED IMPLEMENTATION PLAN`. Contract cuối nằm tại [SPECIFICATION.md](SPECIFICATION.md); original là artifact review, không dùng để ghi đè quyết định revised.

## 6. Open questions và residual risks

- **OPEN QUESTION OQ-01:** Khi có tracker ngoài workspace, sinh viên cần đối chiếu lại định nghĩa retention/concurrency với giảng viên. Hiện lấy 128 completions và 40 local overlapping tasks làm PROPOSAL cụ thể; không tuyên bố đã được giảng viên chấp thuận.
- **OPEN QUESTION OQ-02:** Godot/file system thực tế xác nhận atomic replacement/flush/error ra sao trên Windows và Linux CI? Commit 3 phải kiểm chứng trước khi tuyên bố mức durability; không hứa power-loss safety. Nếu không xác nhận được, phải báo NOT READY cho GREEN, không giảm âm thầm AC-05.
- **OPEN QUESTION OQ-03:** Đường dẫn user data tách biệt trên máy Windows và binary Godot local cần xác minh khi chạy Commit 2; XDG_DATA_HOME trong CI không tự chứng minh isolation trên Windows. Dùng adapter/temp storage riêng và không đụng save người dùng.
- **Residual risk:** Token collision ngoài registry, save corruption/tampering, concurrent external writer, migration không suy ra ID cho lịch sử cũ và digest collision không được giải quyết bằng lời hứa tuyệt đối. Schema v2 lỗi phải fail closed, không tự bỏ ledger rồi tiếp nhận lại old ID.
- Không câu hỏi nào ngăn việc review ba tài liệu Commit 1. Các vấn đề runtime là gate của commit triển khai/kiểm chứng sau; mục tiêu performance chưa được đo.

## 7. Commit 1 readiness checklist và evidence kiểm tra

- [x] Đúng repository/branch/baseline; working tree ban đầu sạch; không sửa nhánh khác.
- [x] Đọc source bắt buộc, phân tích đủ mười hàm GameManager và caller/test/CI; evidence E-01–E-12 có path/function/line.
- [x] Original ghi trước review/spec; prompt nguyên văn có trong plan; original bất biến có hash.
- [x] Review có cải tiến MODIFY thực chất và phân biệt với lỗi AI thật; revised decisions có traceability.
- [x] Specification có đúng 5 AC, invariant, NFR, contract, retention/save failure/legacy.
- [x] Đọc lại toàn bộ ba file; xác nhận hash original và prompt nguyên văn; kiểm tra links/số AC/whitespace.
- [x] `git status --short`, `git diff --check`, `git diff -- docs/BT3_VT074/` và kiểm tra riêng file untracked.
- [x] Xác nhận chỉ ba file tài liệu thay đổi, index/HEAD không đổi, không có gameplay/test/CI patch.
- [x] Không chạy RED/GREEN, mutation, benchmark, coverage hoặc tạo PR; không bịa số đo/pass count.

Verification đã thực hiện: `git diff --check` exit 0; `git diff -- docs/BT3_VT074/` rỗng vì cả ba file còn untracked; đọc lại file trực tiếp và kiểm tra riêng encoding, trailing whitespace, local Markdown links, đúng 5 AC/3 NFR, 18 source anchors đều PASS. `git diff --no-index --check -- /dev/null <file>` không in lỗi whitespace; exit 1 là khác biệt nội dung new-file so với file rỗng, không phải feature test failure. Hash original giữ nguyên, prompt so sánh nguyên văn với attachment khớp. Các kiểm tra này là document verification, không phải kết quả test Godot.

Status chỉ có ba file `?? docs/BT3_VT074/{AI_IMPLEMENTATION_PLAN,AI_PLAN_REVIEW,SPECIFICATION}.md`; diff tracked và cached rỗng, HEAD vẫn baseline. Không có blocker quan trọng cho **READY FOR COMMIT 1**; các runtime gates/OQ ở §6 vẫn thuộc commit sau. Không stage/commit/push/tạo PR. PR cá nhân ở giai đoạn sau phải đợi nhóm review trước merge. Commit message đề xuất: `docs(vt074): specify idempotent completion and review AI plan`.

## 8. Human Review – Student Verification

Ngày xác nhận: 12/11/2026 (Asia/Saigon). Nguồn: phản hồi trực tiếp của sinh viên trong phiên Commit 2, sau khi xem R-01/R-02 và source evidence. Đây là xác nhận của người dùng, không phải AI tự thực hiện human review. Nội dung quyết định được chép nguyên văn:

> Tôi đã xem xét hai điểm R-01 và R-02 cùng các bằng chứng source code được cung cấp.
>
> **Tôi xác nhận:**
>
> - **R-01: MODIFY** – Chấp nhận sửa fixture để các test độc lập, không phụ thuộc execution order hoặc shared state. Phải giữ nguyên các regression assertions hiện có.
> - **R-02: MODIFY** – Chấp nhận bổ sung cơ chế khôi phục `run_id`, processed ledger, fingerprint và metadata khi load dữ liệu. Không được làm hỏng save file cũ.
>
> Đây là hai quyết định review của tôi đối với AI Implementation Plan.

Traceability: R-01 → E-10, `tests/test_replay_security.gd:37–86` và `Scene/GameManager.gd:152–171`; R-02 → E-07, `Scene/GameManager.gd:404–434`. Chi tiết original, lý do MODIFY và revised proposal giữ nguyên ở §4. Original AI Implementation Plan không thay đổi.

Phạm vi thực hiện hiện tại: Commit 2 chỉ bổ sung strategy/test/data/evidence; xác nhận R-02 không có nghĩa loader đã được sửa. Production patch thuộc Commit 3, chưa được thực hiện. Việc sinh viên review/sửa hai test AI-generated là gate riêng, chưa được xác nhận bởi quyết định R-01/R-02 này.
