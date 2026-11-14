# BT3 VT-074 — Commit 4: Integration, Negative & Failure-Path Validation

Ngày 12/11/2026, Asia/Saigon. Vũ Xuân Bắc / 23001833, SE2026-T19, GAME-2D-02. **READY FOR COMMIT 4** theo các gate của prompt C4; chỉ có ba perk failures kế thừa đã chứng minh ở C3. **Không báo toàn bộ regression PASS.** Chưa stage/commit/push/PR; không làm Commit 5–6.

## A. Repository Audit

- Branch thực tế: `feat/bt3-vt074-idempotent-run`.
- HEAD bắt đầu và kết thúc: `2c7119510097c83cf5114d08fe3cd2daacb0fc06` — `fix(vt074): make run completion idempotent`. Commit 3 đã được commit, tồn tại trong lịch sử branch; xác minh bằng Git, không đoán SHA. Không fetch hoặc khẳng định trạng thái remote hiện thời.
- History tiếp theo: C2 `25026e34b0fc3514e2ae813f017774cf694e5375`, C1 `be8e39d3e5d8b3bdce9f815ab93966e3bcf51fde`, baseline `56e97e1b5c621774423b9e06aede4b8b6bcc0b08`.
- `git status --short` ban đầu không có output, working tree sạch; `git diff --check` exit 0. Không có unrelated user diff để ghi đè. Git dùng executable của GitHub Desktop `app-3.6.10` vì PATH không có Git. Không checkout/reset/merge/rebase/stage/commit/push.
- Đã đọc specification, revised plan P-06, plan/test human review, strategy/catalog, C2/C3 reports; đối chiếu GameManager, RunCompletionStore, CharacterSelect, GameOver, MainMenu history nodes, world/TileMap, existing tests và runners. Không có backend completion REST; SUT là autoload/local JSON thật.

Nguồn contract: [SPECIFICATION.md](SPECIFICATION.md), [revised plan](AI_IMPLEMENTATION_PLAN.md), [Human Plan Review](AI_PLAN_REVIEW.md), [Human Test Review](AI_TEST_REVIEW.md). Không thay đổi các tài liệu lịch sử này.

## B. Integration Tests

Files executable mới: [integration script](../../tests/test_vt074_integration.gd), [scene](../../tests/test_vt074_integration.tscn), [runner](../../tests/vt074/run_integration.py). Mỗi IT tạo fixture riêng, ID provider xác định theo IT/fixture/sequence, clock cố định `2026-11-12 14:00:00`, save directory `user://vt074_c4/IT-xx/...`. Teardown disconnect observer, xóa providers, free owner, reset PerkManager, clear counters và unpause. IT-08 dùng autoload thật, cuối luồng restore store/providers và load lại dữ liệu synthetic ban đầu của process.

| IT | AC / preconditions | Expected và actual cuối | Assertions / invocation |
| --- | --- | --- | --- |
| IT-01 | AC-04; fresh valid snapshot/OPEN run cho từng variant | 8 ID variants: empty, malformed, uppercase, leading space, int, null, dictionary → INVALID_REQUEST; valid unissued → UNKNOWN_RUN. 19 payload variants thiếu field/sai kiểu/ngoài bounds/NaN/Infinity → INVALID_REQUEST. Mọi variant giữ nguyên committed snapshot, disk, frames, writer/temp/replace counters và signals. PASS. | 81 |
| IT-02 | AC-02/04; P0 đã commit, mỗi field conflict có owner riêng | Đổi từng seed/hero/floor/kills/reason/session_mode/frames → CONFLICT, P0 và receipt/fingerprint giữ nguyên; P0 retry và JSON-equivalent input → DUPLICATE, zero side effects. PASS. | 56 |
| IT-03 | AC-02/05; sáu fixtures normal/replay deleted/history deleted/clear/history pruned/replay pruned | Fresh owner đọc file thật: metadata/history/last recording/ledger/receipt phục hồi; A/P0 → DUPLICATE, không resurrect hoặc save/signal. Seed save/remove không mất ledger; history15/replay10 và retained receipt sau prune được kiểm. PASS. | 117 |
| IT-04 | AC-05/NFR-03; synthetic legacy và bốn bad-file fixtures | Legacy giữ entries trùng seed/date độc lập, không ID backfill; sanitizer/clamps, history15/replay10/frame3600 còn nguyên; migration v2 đọc lại đúng. Missing ledger/unsupported schema/bad JSON/2MB+1 file → LOAD_ERROR, block start/write, không overwrite/bootstrap/signal. PASS với một diagnostic JSON dự kiến. | 32 |
| IT-05 | AC-03; hai run cùng seed và fixed date | Hai IDs/entries/receipts/signals độc lập; delete B không phá A/last recording A; start IDs mới giữ combat RNG cùng seed. PASS. | 11 |
| IT-06 | AC-02/05; bốn fault modes trên real writer | Actual open failure, actual replace failure, uncertainty đọc lại candidate hoặc old; không false commit/partial publish; pending ID/envelope/date giữ nguyên; recover/retry đúng một result/receipt/signal, tiếp theo DUPLICATE; fresh reload vẫn DUPLICATE. PASS. | 73 |
| IT-07 | AC-02/03/05; mỗi replay/history/clear operation có A/B riêng | Deletion đúng ID, bảo toàn A khi chỉ xóa B; clear-all đúng buffers; ledger giữ nguyên; retry không phục hồi data đã xóa. Legacy copy mơ hồ bị reject, exact object xóa đúng sibling. PASS. | 35 |
| IT-08 | AC-01/02/03/05; autoload + actual scenes | CharacterSelect button → world → completion adapter → GameOver nodes → MainMenu archive → disk load/recreated menu → explicit retry. Đúng một history row, đúng hero/seed/floor/kills/replay header; no duplicate. Actual Replay button và no-frame fallback mở world với IDs mới, modes đúng, cùng dungeon layout, không đổi source entry. PASS headless scene integration. | 40 |

Tổng **8 IT scenarios, 445 assertion executions trong một forward invocation**; gồm cả assertions setup/control. Không gọi đây là 445 independent test cases hoặc 445 catalog cases. Chạy thêm reverse và 8 invocations độc lập: cùng 445 assertions được thực thi thêm hai lần, **1.335 assertion executions / 10 integration invocations**. Không phải flaky benchmark 20 lần hoặc concurrency test. Không đổi status lịch sử 22 cases/pairwise rows thành PASS; covering-array rows chưa được chạy riêng trên engine.

Verifier so sánh **toàn bộ assertion labels, expected, actual và outcomes theo từng IT** giữa forward/reverse/independent, không chỉ matching counts. Cả tám IT có cùng kết quả/observations; snapshot/frame/disk hashes cũng khớp. Giá trị lớn được so sánh đầy đủ trong engine trước khi log digest/length để tránh dump hàng nghìn synthetic frames. Không làm yếu oracle.

## C. Negative Tests

IT-01 và IT-02 đều executable, chạy thật ba configurations. Negative requests luôn có status oracle và before/after observer: SHA-256 toàn committed `_snapshot`, disk file, recording/playback buffers; history/ledger/replay counts; writer/temp/replace/signal counts. Không dùng status hoặc “không crash” làm oracle duy nhất.

Ví dụ actual trong [integration.log](evidence/integration.log): ID variant0 trả INVALID_REQUEST, variant7 trả UNKNOWN_RUN; conflict từng canonical field trả CONFLICT; retry P0 sau conflict trả DUPLICATE với receipt cũ. Mọi expected/actual observer khớp before; writer/signal không tăng. Invalid payload được reject trước conflict lookup.

## D. Failure-Path

[integration_store.gd](../../tests/vt074/fixtures/integration_store.gd) kế thừa real RunCompletionStore; commit bình thường vẫn gọi production write/read/replace. Đây là adapter quan sát/fault hook, không fake idempotency hoặc always-success mock.

| Fault | Actual IO / expected status | Actual committed RAM/disk và recovery |
| --- | --- | --- |
| `open` | Gọi production `_write_temp` với parent không tồn tại; `FileAccess.open` thật thất bại, `get_open_error()!=OK`; SAVE_FAILED | RAM history0/ledger0/signals0, disk hash cũ nguyên; pending snapshot/envelope/ID/date giữ nguyên. Bỏ fault → COMMITTED một lần, tiếp theo DUPLICATE. |
| `replace` | Production `rename_absolute` thật đến path có parent không tồn tại; error!=OK; read-back chứng minh đích cũ; SAVE_FAILED | Old disk hash/RAM giữ nguyên; retry cùng pending request thành công đúng một entry/receipt/signal. |
| `uncertain_candidate` | Replace thật thành công, hook chặn destination read-back; STORAGE_UNCERTAIN | Disk đã chứa một result +receipt đúng ID nhưng committed RAM0/signals0. Start/blind retry bị chặn, unresolved reconcile vẫn uncertain và không writer mới. Phục hồi read → COMMITTED/publish một lần; subsequent retry DUPLICATE. |
| `uncertain_old` | Replace thật thất bại và destination read tạm bị chặn; STORAGE_UNCERTAIN | Old disk còn nguyên, RAM0/signals0; read phục hồi → reconcile SAVE_FAILED, sau đó retry pending COMMITTED một lần. |

Mọi mode cố ý đổi global kills/frames và clock sau failure; final result vẫn kills7/date gốc, không đọc lại để tạo payload/date khác. Sau recovery, RAM và JSON disk đều **1 result/1 receipt**, signal **1**; duplicate không tăng writer/signal hoặc đổi hash. Fresh owner load file và retry trả DUPLICATE. Tất cả assertions trên đều có expected/actual trong log.

Không khẳng định đã kiểm OS disk-full, partial write, power loss, process crash hoặc mọi filesystem. Uncertainty được tạo qua read-back fault hook có kiểm soát; actual open/replace failures là real IO. Không suy read-back thành fsync/durable atomicity.

## E. Save & Replay Compatibility

- IT-03 thực sự tạo owner mới và đọc persisted JSON, không copy biến RAM vào owner mới. Sáu scenarios bảo vệ receipt/fingerprint/date/mode và retention độc lập với history/replay. Với16 completions, A đã rời history15 nhưng retry vẫn DUPLICATE; với11 replays, A.frames vẫn rỗng sau reload/retry và cap10 giữ nguyên.
- Synthetic [legacy_save.json](../../tests/vt074/fixtures/legacy_save.json) được expand trong test để kiểm load cap15/10/3600, duplicate seed/date, note/seed/frame sanitizers, rồi save schema2 và fresh reload. Không sử dụng save cá nhân.
- IT-07 kiểm delete/clear giữ ledger và chống resurrection, legacy ambiguity và exact object. IT-05 fixed clock chứng minh khác ID dù cùng seed/date, không dùng system clock/sleep làm oracle.
- IT-08 actual action replay và no-frame fallback gọi SUT thật, vào `world.tscn`, so `TileMap.generated_rooms` với layout cùng seed ban đầu. Mỗi path cấp ID mới; action mode không đổi khi `is_replaying` chuyển false; fallback về live. Source history/replay còn nguyên.
- Biên retention128/129 vẫn có 40-assertion contract regression C3 chạy lại. Không thực hiện mutation `>`→`>=` hoặc benchmark Commit5.

## F. E2E Verification

**Đã chạy headless scene integration, không chỉ data model:** actual CharacterSelect scene/selection tween/launch Button, actual world và generator `TileMap`, GameOver `summary_label`/visibility/pause/return Button, MainMenu archive Button/modal/history row Label/Replay Button/header. UI row được đếm sau queue_free frame; menu được recreate sau disk load; explicit retry vẫn đúng một row.

Completion adapter và `GameOver.pause()` được gọi trực tiếp theo revised plan P-06 để tách death animation/timer khỏi identity oracle. Test chờ actual UI tween signal và hai layout frames của scene, không sleep theo system time. Gameplay processing của world được disable sau load để input/AI không đổi fixture stats/frames.

**NOT RUN/manual:** pixel rendering, bố cục/clipping, thao tác chuột/bàn phím vật lý, full combat death animation và timer2s → GameOver tự mở, cùng manual visual signoff. Không gọi headless hook-based flow là full manual gameplay E2E. Phần manual này được nêu đúng giới hạn cho phép của prompt C4, không tự nhận sinh viên đã kiểm tra.

## G. Regression và Evidence thực tế

Command đã chạy:

```powershell
py tests/vt074/run_integration.py --godot 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
py tests/vt074/verify_commit4.py
```

Lượt cuối bắt đầu **2026-11-12T14:13:34.711811+07:00**, Godot **4.7.2.stable.official.ed1daf0bf**, HEAD C3 ở §A. [Raw final JSON](evidence/integration_attempt_13b6de3063fb466ea4040781a779eaa3.json) giữ commands/stdout/stderr/exits/source hashes; [integration.log](evidence/integration.log) giữ integration output; [commit4_regression.log](evidence/commit4_regression.log) giữ regression riêng C4, không ghi đè C3 `regression.log`/`green.log`.

| Invocation/suite cuối | Actual result | Engine exit |
| --- | --- | --- |
| Integration forward / reverse | Mỗi lượt445 PASS,0 FAIL, đủ8 IT | Cả2:0 |
| IT-01…08 độc lập | 81/56/117/32/11/73/35/40 PASS,0 FAIL | Cả8:0 |
| VT74-02 unchanged | RAM/disk/signals1/1/1, GREEN marker | 0 |
| Contract C3 unchanged | 40 PASS,0 FAIL | 0 |
| Replay forward/reverse/shuffle seed23001833 | Mỗi lượt29 PASS,0 FAIL | Cả3:0 |
| Replay bounds/fifo/manual/clear/idle độc lập | 3/14/6/4/2 PASS,0 FAIL | Cả5:0 |
| Dungeon unit | 28 PASS,0 FAIL | 0 |
| Dungeon properties | 11/11 properties,100 original seeds +100 variants | 0 |
| Perk regression | **34/37 PASS,3 FAIL**, inherited format diagnostic | **1** |

Tổng **23 suite invocations:22 PASS +1 KNOWN BASELINE FAILURES**. C4 runner **exit0** vì mọi required test đạt và chỉ có exception đã chứng minh; field `entire_regression_suite_passed=false`. Không gọi toàn regression PASS. Những gameplay suites khác của full25-suite C3 không được giả ghi là đã chạy lại ở C4; production không thay đổi nên không chạy lại không cần thiết.

Ba perk names giữ nguyên:

1. `Player get_total_damage() increased by perk bonus`.
2. `Berserk Frenzy raw damage scales +15% per missing HP (Expected: %.2f, Got: %.2f)`.
3. `Completion callback invoked upon perk selection`.

C4 đối chiếu names, summary, engine1 và đúng diagnostic `ERROR: String formatting error: unsupported format character.` với raw A/B C3. Production và perk test byte/hash không đổi; A/B đã chứng minh expected/actual lần lượt2/3,2.90/4.35,true/false cùng root contexts (callback thực sự chạy). Không chạy instrumentation A/B lại hoặc nhận các numeric observations cũ là số đo mới C4. Xem [C3 report](COMMIT_3_REPORT.md), [A/B evidence](evidence/perk_ab.json). Không sửa Perk/balance để làm xanh; không có new regression quan sát được trong phạm vi đã chạy.

**Expected diagnostic có kiểm soát:** malformed JSON IT-04 cố ý làm loader phát đúng `ERROR: Parse JSON failed. Error at line 0: Expected key`. Runner chỉ chấp nhận đúng một dòng đó khi có marker và actual executable `LOAD_ERROR` assertion PASS; stderr/backtrace vẫn giữ nguyên. Mọi `SCRIPT ERROR`/diagnostic khác làm invocation FAIL; không lọc lỗi chung để giả xanh.

**Các attempts không thành công được giữ:**

- `integration_setup_attempt.{json,log}`: type-inference parser lỗi ở helper `ok := actual == expected`; không có behavioral assertions. Scope process cũ được xác định bằng command line/work path rồi dừng; runner termination exit1, các invocation timeout có engine exit=null, không gọi behavioral RED. Sửa bằng `ok: bool`, thêm entry guard thoát2 nếu child script không load được.
- `integration_attempt_ad1cd9596cb74da3b865105225a77752.json`: runner1; numeric scene/node fixture errors và malformed-JSON diagnostic chưa được phân loại. Forward/reverse có408 assertions chạy trước fixture exception; engine0 không được coi PASS vì stderr có errors. Sửa test truy cập `TileMap`, chờ scene layout và phân loại exact expected diagnostic; không sửa SUT.
- `integration_attempt_015e87a341594e19b6487e742d06f6bc.json`, `integration_scene_attempt.{json,log}`: fixture nhấn launch trong lúc selection tween còn disabled, explicit assertion FAIL và scene wait timeout (exit=null); runner1. Metadata `aborted=false` đúng thực tế: attempt đã kết thúc timeout trước khi yêu cầu dừng process đến nơi. Sửa fixture chờ actual `scroll_tween.finished`; thêm timeout fail-fast cho runner. Không xóa logs hoặc nhận rerun sau là thay thế kết quả lỗi trước.
- `13b6de...` là raw final successful C4 run. Các archive trước chứa source hashes của chính attempt đó; không gán hashes final cho các attempt lỗi.

**Save isolation:** mỗi attempt có một copied project dưới ignored `.godot/vt074_c4/<uuid>/`, reuse C2 `run`/capture/digest và C3 `PROBE`; không import live project, không tạo framework mới hoặc sửa project config. Mỗi invocation có child-only APPDATA/LOCALAPPDATA/TEMP/TMP riêng. Probe không autoload xác minh `OS.get_user_data_dir()` và sentinel round-trip trước khi chạy import/scene. Mỗi IT/fixture còn có save directory riêng trong user-data isolated. Chỉ seed fontdata để import, không reuse class/UID caches hoặc save.

Save cá nhân chỉ được đọc hash: SHA-256 trước/sau final run đều **`2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`**. Không backup/restore/xóa/ghi save cá nhân. Logs chỉ chứa fixture tổng hợp, seed/token/date xác định, metadata local và hashes; không dump nội dung save cá nhân. Credential scan trên evidence không phát hiện secret. Raw history/frames trong các attempts cũ đều synthetic fixtures có path/probe evidence, không phải personal data.

### AC mapping cuối

| AC | Test | Expected | Actual | Result / evidence |
| --- | --- | --- | --- | --- |
| AC-01 | IT-05/08, VT74-02, contract | First completion1 result/receipt/signal, đúng UI row | 1 result/receipt/signal; actual history1 row; RAM/disk/signals1/1/1 | PASS cho witnesses đã chạy; integration.log + commit4_regression.log |
| AC-02 | IT-02/03/06/07/08 | Duplicate không mutate/write/signal/resurrect | DUPLICATE receipt cũ, before/after hashes/counters khớp | PASS; 40 concurrent tasks NOT RUN (C5) |
| AC-03 | IT-05/08, replay/dungeon | Same seed/date khác IDs độc lập, replay/fallback identity mới, deterministic | 2 results/receipts; xóa B giữ A; actual replay/fallback IDs mới và layout bằng nhau | PASS cho scene/core witnesses |
| AC-04 | IT-01/02 | INVALID_REQUEST/UNKNOWN_RUN/CONFLICT,zero side effects | 27 invalid-ID/payload variants +7 conflict fields đúng status và observer | PASS; executable expected/actual trong log |
| AC-05 | IT-03/04/06/07, contract | Reload/legacy/failure/reconcile an toàn | Fresh file load đúng receipts, legacy caps/migration đúng, actual IO failures/recovery1 result, read-back old/candidate phân biệt | PASS cho các paths đã chạy; không suy full crash/disk-full matrix |

## H. File Changes & Review

**18 files mới,0 tracked modified. Production diff rỗng.** Tất cả regression assertions, C1–C3 docs/evidence, RED và GREEN giữ nguyên. Đã review test code/fixtures/runner và đọc từng new artifact; source SHA-256 khớp copied project final run. Git index vẫn rỗng.

| File | Lý do / review |
| --- | --- |
| `tests/test_vt074_integration.gd` | 8 IT; real SUT/status/full-state/disk/writer/signal oracles; setup controls, isolated directories, teardown, real scene nodes. Không fake completion hoặc nới assertions. |
| `tests/test_vt074_integration.tscn` | Entry root và child runner sống qua scene changes. |
| `tests/vt074/fixtures/integration_store.gd` | Counting real IO adapter; controlled actual open/replace faults và read-back uncertainty; empty synthetic snapshot helper. |
| `tests/vt074/fixtures/integration_entry.gd` | Narrow setup guard, tránh parser error bị treo mà không có assertions. |
| `tests/vt074/fixtures/legacy_save.json` | Small synthetic legacy template, duplicates/sanitizers; expand runtime để kiểm caps. |
| `tests/vt074/run_integration.py` | Reuse capture/probe; C3 commit gate; run10 integration +13 regression invocations; archive every completed attempt; exact expected diagnostic; inherited perk classification riêng. |
| `tests/vt074/verify_commit4.py` | Static evidence/source/scope/privacy/immutable checks và exact per-IT forward/reverse/independent comparison; không thay engine tests. |
| `docs/BT3_VT074/COMMIT_4_REPORT.md` | Report này, actual counts, AC mapping và giới hạn/human review chưa thực hiện. |
| `docs/BT3_VT074/evidence/integration.log` | Raw final integration commands/stdout/stderr/exits và isolation metadata. |
| `docs/BT3_VT074/evidence/commit4_regression.log` | Raw required regressions C4, giữ actual perk FAIL/exit1; không ghi đè C3 log. |
| `docs/BT3_VT074/evidence/integration_attempt_ad1cd9596cb74da3b865105225a77752.json` | Raw failed attempt, giữ fixture runtime errors. |
| `docs/BT3_VT074/evidence/integration_attempt_015e87a341594e19b6487e742d06f6bc.json` | Raw failed attempt, giữ disabled-button assertion và timeout. |
| `docs/BT3_VT074/evidence/integration_attempt_13b6de3063fb466ea4040781a779eaa3.json` | Raw final attempt với source hashes, per-suite results, exits và save hashes. |
| `docs/BT3_VT074/evidence/integration_setup_attempt.json` | Metadata parser attempt/process cancellation, không coi là behavioral test. |
| `docs/BT3_VT074/evidence/integration_setup_attempt.log` | Raw parser diagnostics của attempt bị dừng. |
| `docs/BT3_VT074/evidence/integration_scene_attempt.json` | Fixture tween failure metadata và thực tế không còn process để abort. |
| `docs/BT3_VT074/evidence/integration_scene_attempt.log` | Raw partial assertion output của fixture tween failure. |
| `docs/BT3_VT074/evidence/commit4_verification.json` | Commands/status/diffcheck/stat, readiness gates, file inventory/hashes và case comparison thực tế. Self-output hash là pre-write. |

Không commit `.godot/` disposable projects/caches, Python bytecode hoặc generated UID/import files. Không sửa GameManager/RunCompletionStore/CharacterSelect, gameplay, PerkManager, balance, UI hoặc tests C2/C3. Không có demonstrated VT-074 defect cần patch production; các lỗi tìm được trong lượt này thuộc test harness và đã sửa hẹp, logs giữ nguyên.

**AI Usage/human review:** AI viết và tự review C4 tests/runner/report. User đã chấp nhận TR-01/TR-02 design revisions trong lịch sử, nhưng điều đó **không chứng minh sinh viên trực tiếp sửa/xóa hai AI-generated automated tests**, cũng không phải phê duyệt C4 code. Yêu cầu evidence về thao tác sửa/xóa trực tiếp đó vẫn **OPEN**; không đánh dấu hoàn thành thay sinh viên. User sẽ review code/test bằng VS Code/GitHub Desktop. Không tạo reflection/README/PDF hoặc chuyển sang C6 để lấp mục này.

## I. Commit Readiness

**READY FOR COMMIT 4**: có executable negative cases IT-01/02 với zero-side-effect evidence, actual IO failure paths và retry/reconcile IT-06, fresh-owner reload/legacy/cap/deletion evidence, headless actual scene/UI integration IT-08, required VT-074 GREEN/contract/replay/dungeon regressions đạt. Không có new regression quan sát được; ba perk failures vẫn KNOWN BASELINE FAILURES và giữ actual FAIL/exit1.

Final verification: `git status --short`, `git diff --check`, `git diff --stat` và inventory untracked; verifier exit0 khi toàn checks đạt, tracked diff/index rỗng, original raw RED pins và C1–C3 artifacts nguyên, save hash không đổi. Xem [commit4_verification.json](evidence/commit4_verification.json). `git diff --stat` rỗng vì mọi C4 file là untracked, không có nghĩa không có changes; đủ18 files ở §H đã đọc trực tiếp.

Manual visual/gameplay E2E chưa chạy như §F; không có mutation, p95/40-task performance harness, flaky repeated benchmark hoặc coverage percentage. Các giới hạn này được báo đúng và không nhận PASS cho test chỉ được thiết kế. Commit message đề xuất: `test(vt074): cover persistence failure and replay integration`.

**Dừng sau C4 để user review. Không stage/commit/push/reset/merge/rebase; không triển khai Commit 5–6.**
