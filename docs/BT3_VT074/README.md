# BT3 / VT-074 — Trạng thái hoàn thiện

**Cập nhật:** 14/11/2026  
**Branch:** `feat/bt3-vt074-idempotent-run`  
**Commit đã kiểm chứng:** `1b81031b6742fc1670d37062903b477bbb7e13c0`  
**Trạng thái:** TECHNICAL VERIFICATION COMPLETED — PR/PDF PENDING

## 1. Tổng quan

Bài tập cá nhân 3 triển khai yêu cầu VT-074: một yêu cầu kết thúc lượt chơi được gửi lại nhiều lần không được tạo thêm dữ liệu hoặc giao dịch trùng (idempotency).

Phần implementation, automated testing, performance verification, Student Review và Reflection đã được cập nhật trên branch BT3.

GitHub Actions Linux tại commit `1b81031` đã **SUCCESS**.

[GitHub Actions — successful run](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43575655486)

Các công việc còn lại cho submission: tạo Pull Request vào `development` để nhóm review và hoàn thiện PDF.

## 2. Kết quả kỹ thuật

| Hạng mục | Kết quả |
| --- | --- |
| Specification | 5 AC, 3 NFR |
| Original/revised AI plan | Có evidence |
| AI plan review | R-01/R-02 MODIFY |
| AI-generated test review | TR-01/TR-02 MODIFY |
| Human test edits | HT-01/HT-02 PASS |
| Test-first RED → GREEN | PASS |
| Pairwise | 14/14 rows, 261 assertions PASS |
| Mutation testing | Original PASS → mutant FAIL → restored PASS |
| Flaky TIME/ORDER | 20 lượt mỗi loại PASS |
| Performance 40 tasks | 4/4 workloads đạt p95 ≤1.500 ms |
| Persistence regression | PASS |
| Manual E2E short-run | PASS |
| GitHub Actions Linux | SUCCESS |
| Line/branch coverage | NOT MEASURED |
| Student Review | ACCEPT |
| Reflection | Đã cập nhật |
| PR/PDF | Chưa hoàn tất |

C1 duplicate fast path và cache ownership đã được tích hợp vào production. Các benchmark và regression mới nhất đều có bằng chứng trong [PERSISTENCE_VERIFICATION.md](PERSISTENCE_VERIFICATION.md).

Các báo cáo performance FAIL cũ của Commit 5, Commit 6 và thử nghiệm P-01 là dữ liệu lịch sử, không phải kết quả cuối. Đề xuất P-01 đã bị từ chối vì không đạt tiêu chí cải thiện đặt trước.

Ba Perk baseline failures vẫn được ghi rõ (34/37 PASS). Không tuyên bố toàn bộ test của dự án đều PASS.

## 3. Persistence fix và Manual E2E

Lỗi `SAVE_FAILED` được ghi nhận trong lượt chơi Miya, seed `ALOALO1234`, Floor 5, 307 kills. Game Over xuất hiện nhưng History không có bản ghi mới.

Synthetic RED cho thấy một candidate JSON hợp lệ có thể vượt giới hạn 2 MiB. Bản sửa dùng lossless compact storage, bounded decoding và cải thiện thông báo Game Over/retry, không tăng giới hạn file hoặc xóa dữ liệu replay để giải quyết lỗi.

Sau khi sửa, sinh viên chơi thử:

- Hero: Miya
- Seed: `ALOALO1234`
- Floor: 2
- Kills: 39
- Game Over: `RUN SAVED`
- Expedition History: Có bản ghi khớp
- Restart: Bản ghi vẫn còn theo xác nhận của sinh viên

**Kết luận:** Manual E2E short-run PASS. Hai ảnh bằng chứng được chụp trước restart; không có ảnh sau restart. Human gameplay dài gần giới hạn 2 MiB chưa được chạy lại thủ công, nên vẫn ghi **NOT RUN**.

Bằng chứng: [MANUAL_E2E_VERIFICATION.md](MANUAL_E2E_VERIFICATION.md), [SAVE_FAILURE_FIX_REPORT.md](SAVE_FAILURE_FIX_REPORT.md), [EVIDENCE_INTEGRATION_REVIEW_20261114.md](EVIDENCE_INTEGRATION_REVIEW_20261114.md).

## 4. Source và CI

Các file triển khai chính:

- [GameManager.gd](../../Scene/GameManager.gd)
- [RunCompletionStore.gd](../../Scene/RunCompletionStore.gd)
- [BasePlayer.gd](../../Scene/Character/BasePlayer.gd)
- [Game Over menu](../../Menu/game%20over%20menu/game_over_menu.gd)

CI giữ các bài test sẵn có của nhóm và bổ sung VT-074 Smoke, Persistence Regression, byte-boundary và player-death checks.

Các kiểm thử mục tiêu đã PASS trên Windows local. GitHub Actions Linux đã SUCCESS ở commit `1b81031`. Heavy benchmark và mutation testing được chạy riêng, không phải các bước bắt buộc của CI mặc định.

## 5. Cách tái chạy

Từ thư mục gốc repository, sử dụng Godot 4.7.2 và Python 3:

```powershell
$Godot = 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
$Python = 'C:\Users\ADMIN\AppData\Local\Programs\Python\Python314\python.exe'

& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase target
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase all
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase groups
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase smoke

# Chạy benchmark riêng:
& $Python tests/vt074/run_persistence_review.py --godot $Godot --phase benchmark

& $Python tests/vt074/verify_persistence_performance.py --run docs/BT3_VT074/evidence/persistence_4a075bff8672_benchmark.json
& $Python tests/vt074/pairwise.py --check-only
```

Điều chỉnh đường dẫn Godot/Python theo môi trường của máy thực thi. Runner dùng thư mục dữ liệu riêng để tránh tác động tới personal save.

Thông số, raw output, exit codes và hướng dẫn chi tiết nằm trong [PERSISTENCE_VERIFICATION.md](PERSISTENCE_VERIFICATION.md).

## 6. Tài liệu bài tập

- [Specification](SPECIFICATION.md)
- [Original/revised AI plan](AI_IMPLEMENTATION_PLAN.md)
- [AI plan review](AI_PLAN_REVIEW.md)
- [Test strategy](TEST_STRATEGY.md)
- [Test cases](TEST_CASES.md)
- [Traceability](TRACEABILITY.md)
- [Coverage and risks](COVERAGE_AND_RISKS.md)
- [AI Usage Log và Student Review](AI_USAGE_LOG.md)
- [Human test edit review](HUMAN_TEST_EDIT_REVIEW.md)
- [Persistence verification](PERSISTENCE_VERIFICATION.md)
- [Save-failure fix report](SAVE_FAILURE_FIX_REPORT.md)
- [Manual E2E](MANUAL_E2E_VERIFICATION.md)
- [Reflection](REFLECTION.md)

Các báo cáo C1–C6, P-01, failed experiments và raw evidence được giữ nguyên làm bằng chứng lịch sử. Không dùng những trạng thái `PENDING` hoặc benchmark FAIL trong báo cáo cũ để thay cho kết quả hiện tại.

## 7. Kết luận

Bản triển khai VT-074 đã đáp ứng các yêu cầu kỹ thuật chính trong phạm vi kiểm chứng, bao gồm idempotency, test-first, mutation, pairwise, flaky checks, performance và persistence regression.

Những giới hạn còn lại được ghi rõ: line/branch coverage chưa đo, manual long-run gần 2 MiB chưa thử lại, pending completion chưa commit chỉ lưu RAM và ba Perk baseline failures vẫn tồn tại.

**Trạng thái nộp bài:** Cần tạo Pull Request để review và hoàn thiện PDF `BT3_23001833_VT-074.pdf`.
