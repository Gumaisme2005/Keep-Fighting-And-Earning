# VT-074 — điều tra và sửa completion SAVE_FAILED

Ngày 14/11/2026, Asia/Saigon. Branch `feat/bt3-vt074-idempotent-run`, HEAD `476ff8efaec5e0c09b078e86468057d40dc7013e` cộng working diff chưa commit. Không fetch hoặc xác nhận lại remote HEAD. Không stage/commit/push/PR/PDF.

## Kết luận và mức chắc chắn

Đã tái hiện một lỗi production: candidate hợp lệ nhưng JSON chứa full `last_recorded_run` cộng history vượt 2 MiB, nên writer trả SAVE_FAILED **trước temporary-file creation**, không publish history/receipt/signal. `READY` chỉ mô tả storage có thể thử ghi, không xác nhận transaction thành công. Pending envelope/snapshot vẫn ở RAM, chặn run mới; gọi lại cùng reason dùng nguyên ID/payload/date.

Human manual failure là quan sát riêng: Miya / ALOALO1234 / floor 5 / kills 307 / SAVE_FAILED / thiếu history ngày 14/11/2026. Agent **không mở, parse, copy, hash hoặc upload save/backup riêng tư**, nên không tuyên bố đã chứng minh exact syscall/stage của lượt người dùng. Kích thước save cũ khoảng 1.891 KiB không tự chứng minh candidate vượt cap. Synthetic reproduction chứng minh cơ chế cụ thể tương thích với triệu chứng, còn post-fix gameplay phải retest theo [checklist](MANUAL_E2E_VERIFICATION.md).

## Behavioral RED trước production patch

[Raw RED](evidence/persistence_54b931c50351_red.json): Godot `4.7.2.stable.official.ed1daf0bf`, engine exit **1**, runner exit **0** vì oracle mong behavioral RED. 10 assertions PASS, 1 assertion FAIL: `long completion commits`, expected COMMITTED, actual SAVE_FAILED. Không có parser/runtime error. Production GameManager SHA-256 `097cfb2cfb99135759a18bd0a4f0bee6b2b1201d8eb1b8bc406934583198e2a7`; writer SHA và command/environment nằm trong JSON.

- Save synthetic cũ: **1.936.384 encoded bytes**, ba history entries, mỗi entry 2.800 frames. Legal JSON whitespace đưa file tới gần cap; không dùng dữ liệu riêng tư.
- Candidate: **5.116.489 UTF-8 bytes**, `_valid_v2_snapshot = true`, full 18.000-frame recording; history mới giữ 3.600 frames theo policy cũ.
- Cả lần có cấu hình fault `open` và lần retry khi đã bỏ fault đều SAVE_FAILED. `temp_attempts=0`, `replace_attempts=0`: fault IO chưa được chạm; thất bại nằm đúng ở `RunCompletionStore.commit()` size guard.
- Previous-file hash/history/ledger/signal giữ nguyên; frozen envelope không đổi dù globals và recording thay đổi. `storage_state=READY`, nhưng `can_start_new_run=false` vì completion PENDING.
- Default path được đo qua `ProjectSettings.globalize_path(SAVE_FILE_PATH)` và khớp child Godot app_userdata đã probe/sentinel trước autoload. Cấu hình project không có custom user directory.

Attempt `persistence_9267747c8374_red.json` là lỗi Windows certificate sandbox; `persistence_0d3b5e74b5dd_red.json` là lỗi type inference trong harness, **không phải behavioral RED**. Attempt verbose `persistence_9a72db772462_red.json` giữ local/ignored; raw RED compact ở trên giữ cùng behavioral failure. Không sửa/xóa các failed experiments.

## Lựa chọn sửa và tính tương thích

Không thể chỉ rút gọn whitespace vì candidate đã dùng JSON compact; bỏ full recording, xóa replay cũ hoặc bớt ledger sẽ vi phạm contract. Tăng cap cũng bị cấm. Vì vậy writer giữ JSON cũ cho snapshot vừa cap; khi vượt cap, tạo bản sao, encode bốn replay doubles `dx/dy/ax/ay` thành 16 hex characters biểu diễn đủ tám bytes, rồi **lossless Zstandard + base64 JSON envelope**. Logical snapshot vẫn là schema v2, fingerprints vẫn tính toàn bộ canonical frames trước encoding. Không migrate file khi load; representation chỉ thay sau một transaction thành công.

Reader mới nhận legacy JSON, JSON v2 và compact envelope `zstd-frame64-json-v1`; kiểm encoding, bounded logical size, SHA-256, finite double bytes và schema trước publish. Outer `schema_version=3` khiến older v2 binaries fail closed thay vì coi wrapper là legacy rỗng; test chạy reader thật từ `8db06a5` xác nhận không overwrite file. Giới hạn file thực vẫn **2.097.152 bytes**; decompression có giới hạn riêng **33.554.432 bytes**. Incompressible hoặc quá giới hạn vẫn SAVE_FAILED, giữ dữ liệu cũ và pending; không hứa mọi recording đều lưu được. SHA là kiểm tra integrity, không phải chữ ký chống sửa save.

Probe bổ sung dùng 18.000 frames với hướng/aim/keys/slot/result/pg biến đổi, không chỉ hai frame lặp. [Supplemental RED](evidence/persistence_659092fe835d_codec_probe.json) có hai full-snapshot failures. Loader cũ chỉ chấp nhận `result is int`, trong khi JSON đọc số nguyên thành float, nên result khác 0 bị mất; sửa sanitizer nhận whole finite numeric values. [Field-level RED](evidence/persistence_5290ad85dab8_codec.json) còn phát hiện `/run_history/0/frames/388/dy` đổi từ `-0.000700383188032016` thành `-0.00070038318803201`. [Full-precision JSON trial](evidence/persistence_5187c946fc71_codec.json) vẫn không bit-exact, nên bị loại. Frame-double encoding được chọn sau các phép thử này, không giảm assertions để làm test xanh. Compact round-trip cuối phải giữ **mọi canonical replay value bằng nhau chính xác**, cùng full-snapshot hash và receipt/fingerprint. Legacy JSON đã làm tròn từ trước không thể phục hồi các bit đã mất; ordinary JSON tiếp tục dùng representation cũ để không đổi baseline workload.

`RunCompletionStore` tách codec khỏi `_commit_bytes()`, giữ previous-read → same-directory temp-write → byte read-back → replace → destination reconcile. Cleanup chạy cả partial-write, temp-readback failure và khi reconciliation xác định old/candidate; unresolved uncertainty giữ temporary witness tới khi giải quyết. Read-back/flush không chứng minh power-loss durability.

`GameManager` decode representation trước validation/migration và cung cấp `retry_pending_completion()`. Retry dùng `_envelope` cùng `current_run_id`; uncertain retry reconcile trước. Không thay admission, canonicalization, fingerprints, FIFO 128, history 15, replay 10, recording caps, C1 cache/ownership hoặc atomic publication.

[Follow-up RED](evidence/persistence_1d8ce204784e_codec.json) phát hiện compact file có thể nhỏ lại sau sanitization/history cleanup rồi bị ordinary save đổi về decimal JSON. Writer/loader nay nhớ compact representation cho cả subsequent small saves; không downgrade replay đã encode exact. Test kiểm storage marker và replay values qua save/reload tiếp theo. Đây là policy của storage representation, không thay envelope/receipt hoặc tạo migration file khi load.

`BasePlayer.take_damage()` truyền kết quả completion qua timer sang Game Over. UI hiển thị RUN SAVED cho COMMITTED/DUPLICATE; SAVE_FAILED là PROGRESS NOT SAVED; uncertainty/unexpected status không tuyên bố saved. Nút Retry Saving giữ game hiện tại và request gốc; navigation tạo/chuyển run bị khóa khi save chưa xác nhận. Thoát game vẫn có thể mất pending trong RAM; UI nêu rõ giới hạn này. Không có journal khôi phục pending sau restart.

## Kiểm chứng

Kết quả cuối, exit codes, all-suite matrix, performance và source manifest được tổng hợp trong [verification hiện tại](PERSISTENCE_VERIFICATION.md). Target GREEN ban đầu đạt long-session 28/28, byte/codec 51/51, actual death/UI retry 16/16; bản verbose giữ local/ignored, index attempts ghi SHA/outcome. `persistence_b1d3de0954dd_target.json` giữ một failed test experiment: oracle so sánh Dictionary int với JSON float không phù hợp; sửa oracle so với cùng baseline JSON-reader representation, thêm kiểm UTF-8 text nguyên vẹn, không thay physical byte-boundary expectations. Parser failure sau đó và harness encoding failure được ghi riêng là SETUP/RUNNER ERROR, không phải behavioral RED. Không sửa evidence lịch sử để xóa failure.

Line/branch coverage NOT MEASURED. Không có instrumentation đáng tin cậy được cấu hình trong repository; không cài dependency mới hoặc suy coverage từ số assertions. Human post-fix E2E và GitHub Actions cho working diff này chưa chạy. Không đổi ba Perk baseline failures thành PASS.
