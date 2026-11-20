# VT-075 - Specification, AI-assisted Plan va Review

Sinh vien: Bui Quang Chien - 23001837 | Nhom: SE2026-T19 | De tai: GAME-2D-02
Baseline commit: `232f261c88ec7748f73d5ba6c912a91c517f1ce5` (HEAD cua `development` luc tao nhanh)
Nhanh lam bai: `feat/vt-075-reviewer-concurrency`

## 1. Problem statement

Du lieu luu run (`GameManager.run_history`, `GameManager.saved_seeds`) la bang chung de tai lap
va cham mot run theo seed. Hien chi co mot vai tro duy nhat (nguoi choi) duoc ghi du lieu
(`save_seed_entry`, `remove_saved_seed`, `finish_run`); khong co cach de nguoi thu hai kiem tra
va xac nhan mot run ma khong co quyen sua no. Can them vai tro **reviewer**: doc ban ghi,
phe duyet (approve) dung mot lan cho dung phien ban (revision) da doc, va **khong the sua/xoa
du lieu goc**. Khi nhieu yeu cau dong thoi tac dong len cung mot ban ghi (nhieu reviewer cung
approve, hoac approve cung luc nguoi choi sua), ket qua phai nhat quan.

## 2. Acceptance criteria (kiem thu duoc)

| ID | Tieu chi | Cach kiem tra |
|---|---|---|
| AC1 | Reviewer doc duoc `list_records`/`get_record`; ket qua la snapshot (deep copy), sua snapshot khong lam doi du lieu goc | assert noi dung + sha256 truoc/sau |
| AC2 | Reviewer goi `add_record`/`update_note`/`remove_record` -> `FORBIDDEN`; hash noi dung va revision cua ban ghi goc khong doi | negative test |
| AC3 | `approve` chi thanh cong khi role=reviewer, id ton tai, `expected_revision` == revision hien tai; approval luu tach rieng, khong sua record. Player/role la -> `FORBIDDEN`; id la -> `NOT_FOUND`; input sai -> `INVALID_INPUT`; revision cu -> `STALE_REVISION` | unit + negative |
| AC4 | 120 reviewer cung approve mot record -> dung 1 `OK`, 119 `ALREADY_APPROVED`, so approval = 1 | concurrency test |
| AC5 | approve chay dong thoi voi nguoi choi sua -> trang thai cuoi nhat quan: neu co approval thi `approval.revision == record.revision`; revision tang dung bang so lan sua thanh cong (khong lost update) | concurrency test |

## 3. Non-functional constraints

- NFR1 (hieu nang): 120 tac vu dong thoi, p95 do tu luc tac vu bat dau den luc co ket qua <= 3.5 s.
- NFR2 (tinh lap lai): test khong dua vao may rui lich luong; chay lap 30 lan cho cung ket qua.
- NFR3 (tuong thich): chi dung API co o Godot 4.3 (CI ghim `GODOT_VERSION: "4.3"` trong `.github/workflows/ci.yml`), may local la 4.7.2.
- NFR4 (bao mat): moi chuoi dau vao di qua `GameManager.sanitize_seed/sanitize_note` (da co san, gioi han do dai); role mac dinh bi tu choi (deny-by-default).

## 4. Invariant / contract quan trong nhat

**INV-1: approval gan voi dung revision cua record.** Voi moi record: co toi da 1 approval, va
neu approval ton tai thi `approval.revision == record.revision`.
Mot invariant phu lien quan: **INV-2: moi thao tac cua reviewer khong lam doi record goc**
(noi dung va revision). INV-1 la invariant bi race condition de pha vo nhat nen duoc chon la chinh.

## 5. AI-assisted plan

### 5.1 Prompt gui coding agent (Antigravity, Claude Sonnet 5.5)
> "Doc repo Godot nay. Change request: them vai tro reviewer co quyen doc va phe duyet nhung khong
> duoc sua du lieu goc. Risk: race condition khi 2 yeu cau dong thoi doi cung mot tai nguyen.
> Hay de xuat 2 phuong an thiet ke, lap implementation plan (file se doi, assumptions, test), chua viet code."

### 5.2 Hai phuong an do AI de xuat
- **Phuong an A**: them `current_role` vao `GameManager` autoload va chen kiem tra role vao
  `save_seed_entry`, `remove_saved_seed`, `finish_run`; luu approval trong `run_history`.
- **Phuong an B**: tao module doc lap `Scene/Review/review_service.gd` (RefCounted) giu kho ban ghi + approvals
  rieng, tu bao ve bang `Mutex`; `GameManager` khong bi sua; nap du lieu tu `run_history` qua ham import.

### 5.3 Ban nhap plan cua AI (truoc khi doi chieu repo)
Assumptions cua AI (A1-A6) va file du dinh sua:

| # | Assumption | File du dinh |
|---|---|---|
| A1 | Repo co lop API/mang nen can API test | `tests/api_*.gd` |
| A2 | Dung GUT/gdUnit4 de viet test va do coverage | `addons/` |
| A3 | Phuong an A tot hon vi it file hon | `Scene/GameManager.gd` |
| A4 | `Thread`/`Mutex` chay duoc trong `--headless` | - |
| A5 | Godot co co do coverage dong lenh | CI |
| A6 | Co `gh` CLI de tao PR | - |

### 5.4 Review plan bang repository that
Ket qua kiem chung nam trong `docs/vt075/evidence/00_plan_review_checks.log` (lenh + output).

| # | Ket luan | Evidence |
|---|---|---|
| A1 | **Bac bo** | `Select-String` tren `Scene/`, `Menu/` voi `HTTPRequest|HTTPClient|ENet|WebSocket|MultiplayerAPI` -> 0 ket qua. Game offline mot nguoi choi; thay bang integration test muc service + `GameManager` that |
| A2 | **Bac bo** | khong co thu muc `addons/`; test hien tai la script tu viet (`_assert_true`) chay bang `godot --headless <scene>` (`tests/test_dungeon_generator_unit.gd`). Theo convention hien co |
| A3 | **Bac bo (loai phuong an A)** | `GameManager.gd`: `save_seed_entry`/`remove_saved_seed`/`finish_run` deu `emit` signal (L195, L219, L228) va ghi file co dinh `SAVE_FILE_PATH` (L7, L261). Test 120 luong tren do se ghi de save file that cua nguoi dung va goi signal tu thread phu (khong an toan trong Godot). Khong co `Mutex` nao trong `Scene/` |
| A4 | Xac nhan (co sua) | chay thu 120 `Thread` + `Semaphore` trong `--headless` (xem evidence). Phai dung cong xuat phat (Semaphore) de cac luong thuc su tranh nhau |
| A5 | **Bac bo** | `godot --help` khong co co coverage (chi co `--profiling`). Thay bang do coverage bang instrument ma nguon (`tests/vt075/tools/coverage.py`) va noi ro gioi han |
| A6 | Bac bo | `Get-Command gh` rong -> khong tao PR tu CLI; nop link branch |

Cac diem phai sua them trong plan: (1) CI dang ghim Godot 4.3 trong khi may local la 4.7.2 -> chi dung API da co o 4.3 (NFR3);
(2) plan ban dau chua tinh den failure-path (luu that bai giua chung) -> them `PERSIST_FAILED` + test khong deadlock.

### 5.5 Phuong an duoc chon: B (Phuong an A bi loai)
Ly do chon B dua tren evidence A3: GameManager khong co co che khoa, mutator phat signal va ghi file co dinh;
module doc lap cho phep test 120 luong tren du lieu trong bo nho, khong dong vao save file that va khong doi hanh vi hien co.
Danh doi: phai co ham import tu `run_history` de khong tach roi khoi repo, va chua noi UI (xem pham vi ben duoi).

### 5.6 File thuc te se thay doi (sau review)
- Moi: `Scene/Review/review_service.gd`, `tests/test_reviewer_concurrency.gd(.tscn)`, `tests/vt075/*`, `docs/vt075/*`
- Sua: `.github/workflows/ci.yml` (them buoc chay test), `README.md` (huong dan chay test), `run_tests.bat`
- **Khong sua**: `Scene/GameManager.gd`

### 5.7 Pham vi vertical slice
Service (RBAC + approve + revision + mutex) + import tu `run_history` + test. **Khong** lam UI reviewer: E2E qua giao dien
khong can thiet cho lat cat nay (rui ro nam o tang service); UT-09 hien co van la lop bao ve hoi quy cho cac scene UI.

