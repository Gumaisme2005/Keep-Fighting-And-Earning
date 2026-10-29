# VT-075 - Risk-based test strategy

Risk trong tam: **race condition khi hai yeu cau dong thoi cung thay doi mot tai nguyen** (check-then-act:
nhieu reviewer cung approve; approve chay cung luc nguoi choi sua; nhieu nguoi choi cung sua/them).
Risk phu: reviewer vuot quyen sua du lieu goc (AC2), input doc hai (NFR4), luu that bai giua chung.

## 1. Phan bo muc test

| Muc | Pham vi | Co lam? | Ly do |
|---|---|---|---|
| Unit (service, mot luong) | RBAC, validation, approve/stale/revoke, snapshot, sanitization, cap | **Co** (TC-01..11, 19, 20) | Chi phi thap, bat loi hop dong; la nen cho mutation testing |
| Integration | `ReviewService` + `GameManager.sanitize_seed/sanitize_note` + cau truc `run_history` that; guard khong cham `saved_seeds/run_history` | **Co** (TC-12 + GUARD) | Dam bao slice gan voi repo that thay vi mock |
| Concurrency (muc service, nhieu Thread that) | check-then-act, lost update, failure-path trong tranh chap | **Co** (TC-13, 13b, 14, 15, 16b, 17, 18) | Day la risk chinh; bat buoc theo bien the |
| Failure-path | luu that bai -> khong luu nua chung, khong deadlock | **Co** (TC-16a/b) | Risk rieng: giu khoa/trang thai nua chung khi loi |
| Performance/load | 120 tac vu dong thoi, p95 <= 3.5 s | **Co** (TC-15 + `tests/vt075/load_p95.tscn`) | NFR1 |
| API/HTTP test | - | **Khong can** | Game offline mot nguoi choi; `grep` khong thay HTTPRequest/ENet/WebSocket (xem `evidence/00_plan_review_checks.log`). "API" o day la API cong khai cua service, da duoc test o muc unit/integration |
| E2E qua giao dien | - | **Khong can cho lat cat nay** | Chua co UI reviewer; rui ro nam o tang logic/dong thoi. Regression UI da co `UT-09` trong `tests/test_dungeon_generator_unit.gd`, van duoc chay trong CI |
| Property-based them | - | Khong can | Space trang thai nho; da co concurrency oracle (dem chinh xac) + 20 mutants |

## 2. Test cases (>= 10; hien co 20 test, 23 assertion)

Ghi chu: tat ca nam trong `tests/test_reviewer_concurrency.gd`. Priority: P0 = chan release, P1 = quan trong, P2 = bo sung.

| ID | Risk / Requirement | Muc | Precondition / Input | Expected | Pri |
|---|---|---|---|---|---|
| TC-01 | AC1 reviewer doc | Unit | 2 record; role=reviewer goi `list_records`, `get_record` | ok, 2 record sap theo id, `revision=1`, chua co approval | P0 |
| TC-02 | AC1/INV-2 snapshot | Unit | lay snapshot, sua `note/revision`, xoa mang list | Hash record goc khong doi; list van 2->1 phan tu | P0 |
| TC-03 | AC2 **negative** | Unit | reviewer `update_note` | `FORBIDDEN`; hash + revision goc bat bien | P0 |
| TC-04 | AC2 **negative** | Unit | reviewer `add_record`, `remove_record`, `import_run_history` | ca ba `FORBIDDEN`; khong thay doi | P0 |
| TC-05 | Deny-by-default **negative** | Unit | role `""`, `admin`, `REVIEWER`, `Player`, `"reviewer "`, `root` x 7 API | tat ca `FORBIDDEN` | P0 |
| TC-06 | AC3 approve | Unit | reviewer approve dung revision 1 | `OK`; approval luu rieng `{reviewer, revision}`; record khong doi; audit 1 su kien | P0 |
| TC-07 | AC3 **negative** | Unit | role=player goi `approve` | `FORBIDDEN`; khong co approval | P0 |
| TC-08 | AC3/NFR4 **negative** | Unit | `expected_revision` 0/-3; reviewer_id `bad id<script>`/rong; record_id `../etc/passwd`/33 ky tu; id la; seed `!!!` | `INVALID_INPUT` / `NOT_FOUND`; khong doi trang thai (10 kiem tra) | P1 |
| TC-09 | AC3/INV-1 stale | Unit | reviewer doc rev1; player sua -> rev2; reviewer approve(rev1) | `STALE_REVISION` (rev=2), khong co approval; approve(rev2) -> `OK` | P0 |
| TC-10 | INV-1 thu hoi | Unit | approve rev1; player sua | approval bi thu hoi; duyet lai rev2 `OK`; audit `[1,2]` | P0 |
| TC-11 | AC4 tuan tu | Unit | approve hai lan | lan 2 `ALREADY_APPROVED`; nguoi dau tien khong bi ghi de | P1 |
| TC-12 | INV-2 integration | Integration | `run_history` dang that: entry hop le, seed `<b>x</b>seed`, phan tu `42`, seed rong | import 2; seed = `GameManager.sanitize_seed(...)`; mang goc hash khong doi | P1 |
| TC-13 | AC4 **concurrency** | Concurrency | 120 reviewer cung approve 1 record, cung `expected_revision=1` | dung 1 `OK`, 119 `ALREADY_APPROVED`; 1 approval; nguoi thang khop audit | P0 |
| TC-13b | AC4 cap race toi thieu | Concurrency | 100 vong x 2 luong, record moi moi vong | moi vong dung 1 `OK` | P0 |
| TC-14 | AC5/INV-1 **concurrency** | Concurrency | 80 tac vu "doc roi approve" + 40 player sua tren 1 record | final_rev = 1+40; approval (neu co) khop revision; khong duyet 2 lan cung revision | P0 |
| TC-15 | NFR1 + INV (tai) | Concurrency/Perf | 120 tac vu tron tren 12 record (7 approve, 2 sua, 1 reviewer sua trai phep moi record) | reviewer sua -> `FORBIDDEN`; moi record rev=3; INV-1; **p95 <= 3.5 s** | P1 |
| TC-16a | **Failure-path** | Unit/Failure | hook luu tra `false` o lan dau, roi `true` | `PERSIST_FAILED`, khong approval, revision doi; thu lai `OK` trong thoi han (khong deadlock) | P0 |
| TC-16b | **Failure-path** + concurrency | Concurrency | 120 reviewer, 5 lan luu dau that bai | dung 5 `PERSIST_FAILED`, 1 `OK`, 114 `ALREADY_APPROVED`; 1 approval | P0 |
| TC-17 | Race them trung | Concurrency | 120 `add_record` cung id | dung 1 `OK`, 119 `DUPLICATE` | P1 |
| TC-18 | Lost update | Concurrency | 120 `update_note` dong thoi | final_rev = 121; 120 revision tra ve khac nhau | P0 |
| TC-19 | NFR4 **negative** | Unit | note co `<script>`, `\n`, `\t`, 200 ky tu | khong con `<`, `>`, ky tu dieu khien; <= 80 ky tu; bang `GameManager.sanitize_note` (add + update) | P1 |
| TC-20 | NFR4 **negative** | Unit | them 500 record roi them thu 501 | `INVALID_INPUT`; dem = 500 | P2 |

Negative tests: TC-03, 04, 05, 07, 08, 19, 20 (>= 2). Failure-path rieng cho risk: TC-16a/16b.

## 3. Ky thuat concurrency testing va cach chon test data

1. **Cong xuat phat (gate)**: moi tac vu chay tren `Thread` rieng va cho tren mot `Semaphore`; main tha dong thoi
   (`tests/vt075/concurrency_harness.gd`). Khong dung `sleep` de "hy vong" tranh chap -> giam flaky.
2. **Mo rong cua so race co chu dich**: service goi `persist_hook` (mo phong ghi dia) giua buoc kiem tra va commit;
   test dat do tre 300 us. Day la ky thuat "widening the race window": loi check-then-act bi lo ra ngay ca khi lich luong thuan loi,
   thay vi phu thuoc may rui. Han che: do tre nay la mo phong, khong chung minh khong co race trong cua so nho hon.
3. **Chon N**: N=2 (cap toi thieu, TC-13b lap 100 vong) bat race hep; N=120 (dung muc tai bien the, TC-13/14/17/18) bat race rong va
   do p95; hai muc N khac nhau tranh chi test mot kich thuoc.
4. **Oracle dem chinh xac, khong dung "khong crash"**: dung 1 OK / N-1 ALREADY_APPROVED; revision cuoi = 1 + so lan sua thanh cong;
   120 revision tra ve khac nhau; INV-1 kiem o trang thai cuoi; khong duyet hai lan cung mot revision (audit log).
5. **Trong so ket hop**: TC-14/15 tron approve + update + hanh vi trai phep de co tranh chap giua nhieu loai thao tac tren cung tai nguyen.
6. **Du lieu co dinh, khong ngau nhien**: id `run-N`, `rev-N`, seed co dinh; khong dung RNG trong test (loai bo flaky do du lieu ngau nhien).
7. **Watchdog deadlock**: moi lan chay co timeout 20 s; qua han -> danh dau HUNG, in ket qua va `OS.kill` (neu khong tien trinh se treo vinh vien).

