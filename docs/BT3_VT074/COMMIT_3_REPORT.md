# BT3 VT-074 — Commit 3: Idempotent Run Completion (GREEN)

Ngày 12/11/2026 (Asia/Saigon); Vũ Xuân Bắc /23001833, SE2026-T19, GAME-2D-02. Chỉ Commit 3, chưa stage/commit/push/PR.

**FINAL TRIAGE: READY FOR COMMIT 3**, theo điều kiện user cho phép ba perk failures đã chứng minh kế thừa. **Toàn regression KHÔNG PASS:** 24/25 suite invocations PASS; perk 34/37, 3 FAIL, engine/full runner exit 1. Chi tiết A/B ở §E; danh sách đủ 24 file và review ở §G. Audit cuối không sửa production, gameplay hoặc regression assertions.

## A. Repository Audit

Branch `feat/bt3-vt074-idempotent-run`, HEAD/start `25026e34b0fc3514e2ae813f017774cf694e5375` (Commit 2); working tree sạch trước thay đổi. Không checkout/reset/merge/rebase/force push. Git dùng binary của GitHub Desktop vì không có trong PATH. Commit 1 `be8e39d3e5d8b3bdce9f815ab93966e3bcf51fde` đã nằm trong history.

Đã đối chiếu SPEC, revised plan, plan/test human review, strategy/catalog, C2 report/RED; kiểm source/callers bằng search. Caller gameplay finish duy nhất là `BasePlayer.take_damage()`; không đổi caller này. Start caller CharacterSelect và replay helpers cần guard trước chuyển scene. Common save trước patch là JSON local, không REST API.

Prompt user giữ nguyên tại [commit3_prompt.txt](evidence/commit3_prompt.txt). [AI patch proposal](COMMIT_3_PATCH_PLAN.md) ghi trước implementation và giữ proposal ban đầu; scope clarification fixture perk được append sau khi phát hiện regression.

## B. Implementation Summary và source evidence

Production thay đổi đúng ba file:

- [GameManager.gd](../../Scene/GameManager.gd): start cấp 128-bit token bằng Crypto, kiểm trùng active/ledger; OPEN/PENDING/CLOSED và session_mode chốt tại start. `register_level_advance` không đổi token. Adapter `finish_run(reason)` giữ API gọi cũ và frozen envelope/date; explicit `complete_run_request` validate/canonicalize → ledger trước active lookup → conflict/admission → candidate → writer → publish/close → một signal. Dictionary receipt trả deep-copy. Root stats/frame globals thay đổi không thay retry snapshot.
- [RunCompletionStore.gd](../../Scene/RunCompletionStore.gd): helper một writer local. Candidate UTF-8 <=2MB, temp cùng thư mục, kiểm store/flush/error và read-back, rename destination và đối chiếu bytes với candidate/previous. Đích candidate → COMMITTED; đích old → SAVE_FAILED; không xác định → STORAGE_UNCERTAIN, chặn writer đến reconcile. Không truncate destination để bắt đầu save. File temp có thể còn sau write failure; không tự xóa/restore save thật.
- [character_select.gd](../../Scene/UI/character_select.gd): chỉ preflight và kiểm start thành công trước đổi hero/chuyển world; không sửa layout/UI. Hai replay helpers cũng preflight trước set hero/scene. Source baseline không kiểm kết quả start (417–423 và GameManager333–354), nên guard cần để pending không bị mất.

Persistence v2 giữ schema + FIFO ledger tối đa128 + ID/metadata history/last recorded trong cùng snapshot. Load validate trước publish, restore rõ whitelist; không resume active run. Legacy không ID vẫn sanitize/cap như cũ, không gộp/backfill seed/date. V2 lỗi fail closed, `_ready` không bootstrap ghi đè. Mọi seed/delete/clear save dùng writer chung, giữ ledger; candidate deep-copy tránh sửa frames đã publish trước khi disk xác nhận. Entry có ID xóa bằng ID, legacy object/unique full match, không date-only.

Caps giữ history15/replay10/frame18000/disk3600; chỉ prune receipt khi `size > 128`. Không mutation, không benchmark40 tasks, không sửa Enemy AI/Dungeon/Equipment/Balance/PerkManager production hoặc project/CI.

## C. Acceptance Criteria và giới hạn verification

| AC | Implementation | Test witness C3 | Trạng thái |
| --- | --- | --- | --- |
| AC-01 | Start ID entropy độc lập seed/time; một candidate result+receipt; publish sau xác minh | VT74-02 first-completion control; CG-01…03, CG-37 | PASS core witnesses; không suy full AC từ parser/no crash. |
| AC-02 | Frozen adapter, canonical digest/receipt, duplicate không writer/signal/caps/deletion resurrection | VT74-02 unchanged; CG-04…08, CG-17, CG-37/38 | PASS core; 40 overlapping tasks và mọi deletion/retry permutation vẫn NOT RUN (C4–5). |
| AC-03 | ID riêng cùng S/T, identity-safe delete, session mode bất biến; seed RNG cũ giữ nguyên | CG-18…20, CG-39; replay/hero/seed regressions | PASS core; successful world-scene replay/fallback E2E NOT RUN (C4). |
| AC-04 | Strict ID/schema, canonical same/conflict, unknown admission, mode fixed at start | CG-07…12, CG-15, CG-40 | PASS core; full malformed-ID/schema combinatorial matrix chưa chạy. |
| AC-05 | Common v2 writer/loader, legacy, receipt retention, pending/reconcile | CG-13…17, CG-21…36 | PASS core; full open/disk-full/partial-write/crash/corrupt-file matrix thuộc C4, không báo PASS. |

Contract đã triển khai không đồng nghĩa mọi test case trong catalog C2 đã tự động hóa. Không đổi các docs/evidence lịch sử C2 để tự gắn nhãn PASS; C3 chỉ bổ sung witnesses cần cho patch. Queue40/p95/mutation/flaky20 lượt/E2E và coverage instrumentation chưa thực hiện, không có % coverage hoặc benchmark/CI PASS.

## D. GREEN Verification

Command đã chạy:

```powershell
py tests/vt074/run_green.py --godot 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
```

Godot `4.7.2.stable.official.ed1daf0bf`; lượt cuối bắt đầu `2026-11-12T11:53:45.274770+07:00`, SHA `25026e34b0fc3514e2ae813f017774cf694e5375` với working diff. Test được chạy trong copied project `.godot/vt074_green/94472f1d456c40179d949e1c0e3c1c91/project`; mỗi invocation có child APPDATA riêng và probe/sentinel không autoload trước khi khởi động GameManager. Full engine command của từng suite, stdout/stderr/exits và source SHA-256 ở [final raw run](evidence/green_attempt_94472f1d456c40179d949e1c0e3c1c91.json).

VT74-02 dùng script/scene C2 giữ nguyên byte-for-byte:

| Oracle | Expected | Actual cuối |
| --- | --- | --- |
| RAM history entries | 1 | 1 |
| Disk history entries | 1 | 1 |
| Completion signals | 1 | 1 |
| Godot test exit code | 0 | 0 |

First completion vẫn đúng seed/hero/floor/kills/reason/frames. [green.log](evidence/green.log) chứa marker PASS và raw output; RED C2 vẫn Expected1/Actual2, exit1, không bị sửa. **VT74-02 GREEN**, nhưng **full runner exit=1** do perk regression dưới đây; không nhầm hai exit codes hoặc gọi toàn suite GREEN.

## E. Regression

Lượt cuối chạy **25 suite invocations: 24 PASS, 1 FAIL**. Contract mới có **40 assertions PASS /0 FAIL**, không phải 40 concurrent tasks hoặc 40 catalog cases. Catalog C2 có22 cases; đây chỉ là core witnesses/partial cases được chạy ở C3, các phần chưa chạy giữ rõ ở §C. Replay forward/reverse/shuffle cùng group-specific invocations bảo vệ fixture independence với seed23001833. Counts của các order là lặp lại assertions, không coi là unique tests.

| Suite/invocations | Actual assertions / summary | Exit / result |
| --- | --- | --- |
| VT74-02 | RAM/disk/signals 1/1/1 | 0 PASS |
| Contract patch | 40 passed, 0 failed | 0 PASS |
| Replay forward /reverse /shuffle | Mỗi lượt 29 passed, 0 failed | Cả3 exit0 PASS |
| Replay từng group bounds/fifo/manual/clear/idle | 3/14/6/4/2 passed, mỗi group0 failed | Cả5 exit0 PASS |
| Dungeon unit | 28 passed, 0 failed | 0 PASS |
| Dungeon properties | 11/11 properties, original100 seeds +100 variant cases | 0 PASS |
| Perk system | **34/37 passed, 3 failed**; có runtime string-format ERROR | **1 FAIL** |
| Orc battle | Harness kết thúc thành công; không xuất aggregate count | 0 PASS |
| Doraemon | 49 passed, 0 failed | 0 PASS |
| Yugi | `YUGI TESTS PASSED`; không xuất aggregate count | 0 PASS |
| Miyabi /Luong Tho | 18/15 passed, mỗi suite0 failed | Cả2 exit0 PASS |
| MOBA HUD/inventory | 159 passed, 0 failed | 0 PASS |
| Archer combat/lifecycle | 12 passed, 0 failed | 0 PASS |
| Tactical navigation /BaseEnemy | Mỗi suite49 passed, 0 failed, 0 runtime errors | Cả2 exit0 PASS |
| Projectile obstacles | Report failures0, không xuất aggregate pass count | 0 PASS |
| Skeleton King /Werewolf | 22/50 passed, mỗi suite0 failed | Cả2 exit0 PASS |

[regression.log](evidence/regression.log) và final raw JSON giữ toàn bộ stdout/stderr/exits; không chỉ lấy summary. Source hashes trong JSON khớp files bàn giao (final verifier kiểm). Lượt core đầu có parser error fixture contract; lượt full trung gian có parser perk và Doraemon timeout120s. Không tính chúng là PASS hoặc xóa failure evidence. Doraemon timeout được nâng riêng lên300s để đủ chuỗi physics frames, không đổi asserts/FPS; lượt cuối49/49 thực sự đạt. Ba attempt JSON được giữ.

### E.1. Đối chứng A/B cuối — không suy từ matching counts

Command thực: `py tests/vt074/audit_commit3.py --godot 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'`. [Runner](../../tests/vt074/audit_commit3.py), [raw JSON](evidence/perk_ab.json), [raw stdout/stderr/commands/exits](evidence/perk_ab.log). Audit runner **exit 0** nghĩa xác lập được baseline exception; hai behavioral engine invocations vẫn **exit 1**.

A được giải nén bằng `git archive 25026e34b0fc3514e2ae813f017774cf694e5375`, không checkout/reset. B copy working tree. Cả hai dùng chính binary `4.7.2.stable.official.ed1daf0bf`, config/autoload giống nhau, fresh child APPDATA/LOCALAPPDATA/TEMP/TMP từng phase, probe không autoload kiểm path và sentinel trước chạy scene. Chỉ seed imported resource bytes, không reuse global-class/UID caches hoặc save. Hash `project.godot`, PerkManager, PerkDatabase, BasePlayer, BalanceConfig và PerkSelectionModal giống hệt A/B. Initial observed state giống nhau: seed `ALOALO1234`, hero 2, floor 1, kills 0, perks 0, combat RNG seed 1554938935. Đây là fixture tổng hợp, không đọc payload save cá nhân.

| Phase | A: Commit 2 | B: working tree | Phân loại |
| --- | --- | --- | --- |
| Pristine scene, chưa thay fixture/observation | Parser failure; 0 assertions. Engine exit 0 do `--quit-after 60` buộc đóng scene không chạy được `_ready`; **không phải PASS** | 34/37 PASS, đúng 3 FAIL, engine exit 1 | A có constructor/type-inference setup failure; không dùng làm behavioral RED |
| A* / B, cùng fixture constructor và observation | 34/37 PASS, 3 FAIL, engine exit 1 | 34/37 PASS, 3 FAIL, engine exit 1 | Behavioral comparison hợp lệ; không parser/setup failure |
| CLI `--script --check-only` diagnostic | Exit 1: thiếu autoload context và type inference | Exit 1: thiếu autoload context | Lỗi cách gọi CLI, tách khỏi kết quả scene; giữ raw, không tính là gameplay regression |

**A* không được gọi là unmodified test fixture.** Production A vẫn nguyên C2; A* chỉ thêm preload script và thay bốn constructors đúng như B, sau đó cả hai nhận cùng instrumentation. Mọi predicate/message `_assert_test` gốc giữ nguyên. Instrumentation chỉ print expected/actual/context và dùng một mutable bool box phụ để quan sát callback đi vào; không thay outer bool hoặc assertion gốc. Pristine A trước thay fixture đã được chạy và hash lưu lại. A GameManager SHA-256 `6f0a8ae1abd40841dc293f251bb6f13f72815de54980a661245b12429d9ddada`; B `ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe`, khớp source full GREEN run. Hash các input và instrumented fixture nằm trong JSON.

| Exact failing assertion name (A* và B giống hệt) | Expected, cả A*/B | Actual, cả A*/B | Source/context chứng minh |
| --- | --- | --- | --- |
| `Player get_total_damage() increased by perk bonus` | 2 (`base_before=1` + 1) | 3 | Sau add perk: player base=2, perk bonus=1. PerkManager `_apply_perk_to_player` cộng base; BasePlayer `get_raw_damage` cộng bonus lần nữa. Các source này không đổi giữa A/B. |
| `Berserk Frenzy raw damage scales +15% per missing HP (Expected: %.2f, Got: %.2f)` | 2.90 | 4.35 | Missing HP=3, player base=2, perk bonus=1, weapon damage=0. Oracle dùng `2 * 1.45`; production dùng `(2+1+0) * 1.45`. Không sửa balance/oracle. |
| `Completion callback invoked upon perk selection` | true | false | Instrumented callback box=true cả A*/B: callback thực sự được gọi. Local bool capture không cập nhật outer bool mà assertion đang đọc. Không kết luận UI bỏ callback. |

Berserk label trên là template **nguyên văn thực tế** vì `15%` không escape khiến string-format lỗi trước khi thay `%.2f`. Cả A*/B có đúng cùng diagnostic `ERROR: String formatting error: unsupported format character.`; numbers lấy trực tiếp từ observation JSON, không tự suy từ label lỗi. Đây là inherited test-format diagnostic, tách khỏi ba behavioral assertion failures.

So sánh kiểm **tên, expected/actual, context, initial state/RNG, errors và exits**, không chỉ 34/37. Không có failing name mới trên B; đúng ba tên cũng xuất hiện trong full 25-suite run B không instrumentation. Tất cả 24 suite invocations khác exit 0. **Ba assertions: KNOWN BASELINE FAILURES; không thêm regression quan sát được trong phạm vi đã chạy.** Không sửa PerkManager, damage, Berserk, UI callback hoặc balance để làm suite xanh.

[perk_baseline.json](evidence/perk_baseline.json) và [runner cũ](../../tests/vt074/run_perk_baseline.py) giữ làm lịch sử: đã dùng fixture normalization, và key `same_three_failures_reproduced` của runner cũ chỉ kiểm count/summary, chưa đủ chứng minh cùng root cause. Kết luận hiện tại dựa trên A/B mới ở trên, không dựa key đó. Theo yêu cầu FINAL TRIAGE mới của user, exception đã được chứng minh này không chặn readiness C3; raw suite result vẫn FAIL.

### E.2. Giải thích toàn bộ thay đổi `test_perk_system.gd`

- Thêm đúng một constant preload `PerkManagerScript` trỏ script production hiện có. `PerkManager` là autoload instance, không phải constructor class.
- Thay đúng bốn `PerkManager.new()` thành `PerkManagerScript.new()` trong `test_deterministic_perk_rolling`, `test_unique_perk_filtering`, `test_apply_perk_to_mock_player`, `test_perk_manager_query_helpers`. Mỗi test vẫn tạo manager riêng và giữ setup/reset cũ.
- Không thay predicates, expected values, messages, tolerance, thứ tự test, global PerkManager cho combat hoặc callback. Verifier kiểm mọi 38 assertion call sites gốc còn nguyên; suite thực thi 37 assertions trong fixture này (call site cho nhánh duplicate ID không đi qua).
- Đây là fixture-only fix cần thiết để chạy inherited regression. Pristine A runtime parse errors chứng minh lý do; exact normalized-text comparison chặn mọi sửa khác. Không có unrelated user diff phải bỏ. Giữ fix tối thiểu này; observation chỉ nằm trong disposable copies, không chép vào test bàn giao.

## F. AI-Assisted Patch Review

AI tạo proposal và patch; AI tự review source/diff và chạy tools. Sinh viên **chưa xác nhận review code Commit 3**; R-01/R-02/TR-01/TR-02 là quyết định lịch sử cho plan/tests, không phải phê duyệt production patch này. [Production diff](evidence/production.patch) được xuất trực tiếp từ Git, gồm helper mới bằng no-index diff; không sửa Original AI Plan.

Các điểm thật đã phát hiện/làm rõ và sửa:

1. **Publish trước signal và reentrancy:** draft clear-all gọi writer/emit rồi mới clear playback/current frames. Observer có thể thấy nửa state hoặc start mới rồi bị clear frames sau callback. Đã đưa clear_frames vào nhánh publish trước signal và giữ flag qua reconcile; completion cũng CLOSED trước emit. CG-37/38 kiểm synchronous retry và state quan sát tại signal. Đây là finding tự review tĩnh đã sửa, không nhận là bug từng được tái hiện trên game thật. Draft trước sửa còn trong copied project của attempt `89994ee5535c4c678be125a520a3358d` (ignored cache); patch cuối ở production diff.
2. **JSON numeric types:** loader không được tái tính digest từ history/frame đã prune hoặc mất integer frame fields như result sau JSON parse. Canonical tuple có field order/number types rõ; loader giữ fingerprint riêng và normalize receipt summary về schema canonical. CG-15 kiểm explicit retry với payload qua JSON round-trip. Không gọi loader whitelist cũ là tự động giữ field mới.
3. **Test fixture lỗi, không tính là RED:** draft test contract dùng `:= gm._snapshot()` qua Node không đủ type, gây parser error/timeout. Đã khai báo Dictionary tường minh; CharacterSelect fixture dùng scene thật với required child nodes. Suite perk còn gọi autoload instance.new; sửa thành script preload/new, giữ mọi assertions. Không chỉnh production perk/balance. Các failures giữ trong attempt JSON, không xóa để làm đẹp kết quả.
4. **Lifecycle admission:** boundary không được chấp nhận payload mode trái mode đã chốt ở start; CG-40 kiểm reject trước khi freeze. RNG provider trong contract tests xác định; production ID generator vẫn dùng Crypto, không tiêu thụ combat RNG (CG-39).

Các quyết định cần sinh viên review khi xem diff: giữ bool/Dictionary return cho adapter tương thích các caller đang bỏ qua return; chính sách fail-closed khi load/replace uncertain; phạm vi guard CharacterSelect; fixture perk migration. Đây là danh sách cần review, không phải gate mới tự đặt để ngừng công việc.

Residual risks: single owner/process, không writer ngoài process; token/digest collision ngoài retained set là rủi ro còn lại. PENDING chỉ ở RAM, không resume gameplay sau crash; không hứa fsync/power-loss atomic durability hoặc Node/thread safety. Windows rename/read-back được kiểm theo lượt local thực; không suy từ đó rằng Linux CI hoặc crash matrix đã đạt. Các custom fault hooks chứng minh status/publish policy; không thay cho test disk-full/permission/power loss thật.

**Final diff audit theo yêu cầu mới:** đã đọc toàn bộ ba production files, tracked diff, fixtures/contract/runners và artifacts trong danh sách §G. Không tìm thấy demonstrated VT-074 defect hoặc assertion bị làm yếu cần sửa thêm. Audit này không sửa production hoặc test runtime sources, nên hashes vẫn khớp full run; không tạo lại log GREEN giả từ kết quả cũ.

| Điểm review | Kết luận và evidence |
| --- | --- |
| Kích thước GameManager patch | Khoảng 321 dòng net tăng; phạm vi là lifecycle, boundary, common transaction writer/loader và identity deletion, không refactor gameplay. Đổi mọi save path sang candidate là cần để seed/delete không ghi snapshot thiếu ledger hoặc mutate RAM trước disk. |
| State có trùng lặp không | History15/replay10 và ledger128 có retention khác nhau; cần riêng để retry sau delete/prune. Envelope giữ payload đầu; pending snapshot giữ transaction chưa publish; store giữ old/candidate bytes để phân giải replace; uncertain flags giữ thao tác publish. Không thêm registry thứ hai hoặc seed/time identity. |
| ID transitions/admission | Chỉ start cấp token; floor giữ token; PENDING chặn start/edit/load; receipt lookup trước active; CLOSED không quay lại nhánh new. Generator độc lập combat RNG; CG-01/02/18/20/21–23/35/36/39/40 và source callers. |
| Frozen retry/conflict | Canonical field/frame order cố định; normalize JSON numbers; lần retry adapter dùng envelope cũ. Receipt deep-copy; duplicate/conflict không writer/caps/signal. CG-04–08/12/15/17/37. |
| Save failure/partial publish | Deep candidate trước temp; validate/byte cap; đóng file trước rename; đọc lại đích để phân biệt candidate/old/uncertain. Publish/close/clear flags trước signal; failed/uncertain không publish result hoặc signal. CG-24–30/37/38. Không suy syscall success là durability. |
| Reload/other save paths | V2 validate trước publish, restore ledger/ID/date/reason/mode; corrupted v2 không bootstrap overwrite. Common `_snapshot` luôn mang ledger; delete/clear/seed dùng cùng writer. Legacy không backfill/dedup. CG-13–17/21–23/31–34 và các replay groups. |
| Replay/deletion | ID matching cho new; legacy đúng object/unique full copy, ambiguous reject. Cùng seed/date không xóa nhầm last recorded. Start guards trước hero/scene; action/seed replay cấp token mới qua start, RNG reseed cũ không đổi. Core mode/RNG/guard và 8 replay invocations PASS; successful world scene replay/fallback E2E vẫn NOT RUN, không triển khai C4. |
| FileAccess/DirAccess | `_write_temp` kiểm bool `store_buffer`, flush/get_error và read-back; `rename_absolute` dùng globalized absolute paths; mọi handles đóng trước replace. Local Windows normal replace và injected failures đã chạy; không giả định rename luôn overwrite/atomic trên mọi filesystem. |
| Test integrity | Toàn bộ assertion calls regression cũ giữ nguyên. Mọi fixture-only diff đã giải thích; contract40 không phải40 concurrent tasks. Runners dùng copied projects, bounded timeouts, marker + exit/error checks; raw earlier parser/timeout attempts giữ nguyên. |

Không có finding mở được chứng minh trong phạm vi C3. Các giới hạn §C và residual risks vẫn công khai, không gắn PASS cho test chỉ được thiết kế. Human review bằng GitHub Desktop còn do user thực hiện; audit không ghi nhận thay họ.

## G. File Changes và Final Verification

Files tracked modified: `Scene/GameManager.gd`, `Scene/UI/character_select.gd`, `tests/test_replay_security.gd`, `tests/test_perk_system.gd` (fixture constructor only). Audit nhận 21 changed files, thêm đúng `audit_commit3.py`, `perk_ab.json`, `perk_ab.log` để đối chứng; cuối cùng **24 files =4 modified +20 new**. Không đưa project/cache/sprite/import/bytecode tạm vào commit.

Danh sách cuối đầy đủ để user review, chưa stage:

```text
M  Scene/GameManager.gd
M  Scene/UI/character_select.gd
M  tests/test_perk_system.gd
M  tests/test_replay_security.gd
N  Scene/RunCompletionStore.gd
N  docs/BT3_VT074/COMMIT_3_PATCH_PLAN.md
N  docs/BT3_VT074/COMMIT_3_REPORT.md
N  docs/BT3_VT074/evidence/commit3_prompt.txt
N  docs/BT3_VT074/evidence/commit3_verification.json
N  docs/BT3_VT074/evidence/green.log
N  docs/BT3_VT074/evidence/green_attempt_2866fbd345ef424487da4732ada9fca3.json
N  docs/BT3_VT074/evidence/green_attempt_89994ee5535c4c678be125a520a3358d.json
N  docs/BT3_VT074/evidence/green_attempt_94472f1d456c40179d949e1c0e3c1c91.json
N  docs/BT3_VT074/evidence/perk_ab.json
N  docs/BT3_VT074/evidence/perk_ab.log
N  docs/BT3_VT074/evidence/perk_baseline.json
N  docs/BT3_VT074/evidence/production.patch
N  docs/BT3_VT074/evidence/regression.log
N  tests/test_run_completion_contract.gd
N  tests/test_run_completion_contract.tscn
N  tests/vt074/audit_commit3.py
N  tests/vt074/run_green.py
N  tests/vt074/run_perk_baseline.py
N  tests/vt074/verify_green.py
```

Review disposition cho mọi file ở trên:

| Files | Review / lý do giữ |
| --- | --- |
| Ba production files | AC-01…05; chi tiết §B/F; không sửa thêm trong final audit. |
| Hai regression fixtures | Từng diff ở §E.2 và replay setup/groups: start trước frames, fixture riêng, forward/reverse/seeded shuffle; giữ nguyên original assertions. |
| `test_run_completion_contract.gd` + `.tscn` | 40 core assertions đã chạy; deterministic providers/isolated store/fault seams; scene chỉ gắn script. Không sửa trong audit. |
| `run_green.py` | Fresh copy/probe/environment từng suite; giữ engine exit/errors; 300s chỉ Doraemon, không đổi FPS/oracle. Runtime sources khớp raw full run. |
| `run_perk_baseline.py` | Historical count-only diagnostic; không dùng làm bằng chứng root cause hoặc readiness. Giữ để tái lập evidence cũ. |
| `audit_commit3.py` | Mới: pristine scene + constructor-normalized A*/B; exact fail names/values/context/errors/exits, source hashes/save guards; không sửa live sources. |
| `verify_green.py` | Bỏ count-only readiness inference; đòi exact A/B và duy nhất perk là failed suite. Phân biệt readiness policy mới với actual full-suite FAIL; kiểm scope, immutable artifacts, hashes, whitespace, links, privacy. |
| `COMMIT_3_PATCH_PLAN.md` | Proposal ban đầu + scope clarification giữ nguyên; không viết lại lịch sử. |
| `COMMIT_3_REPORT.md` | Report này: thay kết luận NOT READY cũ theo yêu cầu triage mới sau evidence A/B, giữ mọi actual counts/limits. |
| `commit3_prompt.txt` | Prompt C3 nguyên văn, không sửa. |
| `green_attempt_89994ee5535c4c678be125a520a3358d.json` | Raw core attempt có contract parser failure; giữ làm lịch sử, không tính PASS. |
| `green_attempt_2866fbd345ef424487da4732ada9fca3.json` | Raw full attempt có perk parser failure/Doraemon timeout; giữ, không tính PASS. |
| `green_attempt_94472f1d456c40179d949e1c0e3c1c91.json` | Raw final 25-suite run, 24/25; source hashes hiện tại khớp. |
| `green.log` | Unchanged VT74-02 actual engine0/oracles1; không thay RED. |
| `regression.log` | Giữ original raw final run; append final A/B triage có actual values/exits, không đổi full runner1 thành0. |
| `perk_baseline.json` | Historical constructor-normalized baseline result; original count-only key không được nâng thành root-cause proof. |
| `perk_ab.json` + `.log` | Mới, raw commands/stdout/stderr/exits/pristine và observed pair; synthetic state/numbers, không personal save payload. |
| `production.patch` | Trực tiếp tracked production diff + no-index helper, regeneration không sửa production. |
| `commit3_verification.json` | Actual status/check/source/assertion/immutable/privacy/readiness checks và raw regression classification riêng; tự-hash là pre-write, ghi rõ trong JSON. |

Lệnh cuối: `py tests/vt074/verify_green.py`; script xuất production diff thật (gồm helper no-index), `git status --short --untracked-files=all`, `git diff --check`, index/stat/branch/head, đọc trực tiếp untracked, so Git blobs C2 theo text attributes, pin raw SHA-256 RED trước commit, kiểm original regression assertions còn nguyên và source fingerprints khớp run đã chạy. Python-written logs trên Windows có CRLF trong working file, còn Git lưu LF; raw khác blob không đồng nghĩa bị sửa. [commit3_verification.json](evidence/commit3_verification.json) giữ cả hai phép so sánh và danh sách đủ24 file. **Verifier exit0 là readiness/artifact checks theo exception user vừa cho phép, không phải full regression PASS.** Field `regression_result.entire_suite_passed=false`, full runner exit1 và failing names/values được giữ riêng. Không dùng matching counts để bỏ qua perk.

Save cá nhân trước/sau cả full run và baseline control đều có SHA-256 `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`, không thay đổi; chỉ đọc hash, không dump payload vào evidence. RED C2/Original Plan/test VT74-02 byte-identical. Git index không đổi, không stage/commit/push/PR. Không sửa docs kết quả lịch sử C2 để giả PASS. Không triển khai C4–6.

## H. Commit Readiness

**READY FOR COMMIT 3** theo điều kiện FINAL REGRESSION TRIAGE mới của user: VT74-02 GREEN,40 contract assertions PASS, replay forward/reverse/shuffle29 mỗi lượt và năm groups độc lập đều PASS; cả24 suite invocations ngoài perk exit0; ba perk assertions được đối chứng tên/expected/actual/context/RNG/errors/exits và phân loại **KNOWN BASELINE FAILURES**. Không có thêm failure quan sát được hoặc demonstrated VT-074 defect còn mở; toàn bộ24 changed files đã audit. Giữ actual full run **24 PASS/1 FAIL, exit1**, perk **34/37 PASS,3FAIL**, inherited formatting ERROR; không báo toàn regression suite PASS.

Readiness này là bàn giao để user kiểm tra GitHub Desktop, không phải giả nhận human code approval hoặc các C4/C5 tests chưa chạy. Không sửa production trong audit cuối, RED/Original AI Plan giữ nguyên; index rỗng. Dừng tại C3, không stage/commit/push/reset/merge/rebase hoặc làm C4–6.

Commit message dự kiến: `fix(vt074): make run completion idempotent`.
