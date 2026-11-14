# VT-074 — xác minh gameplay thủ công

Ngày lập: 14/11/2026, Asia/Saigon. Nhật ký phân biệt quan sát do sinh viên cung cấp và automated evidence; không suy ra approval của sinh viên đối với patch/reflection.

**MANUAL E2E — FAIL (November 14, 2026).** Người dùng báo: Miya, seed `ALOALO1234`, floor 5, 307 kills. Game Over hiện bình thường nhưng Expedition History không có lượt chơi. Remote Inspector: `last_completion_result.status = SAVE_FAILED`, `storage_state = READY`, ledger rỗng. Kích thước save được người dùng báo khoảng 1.891 KiB. Agent không mở save/backup để kiểm tra; nguyên nhân chính xác của file riêng tư chưa được xác nhận. Người kiểm thử: người dùng báo trong yêu cầu; không có tên tester hoặc ảnh được cung cấp. Screenshot references: **chưa cung cấp**.

## Short-run sau fix — PASS, ảnh và xác nhận của sinh viên

Ngày 14/11/2026, sinh viên thực hiện short-run manual E2E: **Miya**, seed **`ALOALO1234`**, **Floor 2**, **39 kills**. Game Over hiển thị **`RUN SAVED`**; Expedition History hiển thị entry khớp. Sinh viên xác nhận entry vẫn còn sau khi khởi động lại game. Agent đã đọc [human observation](MANUAL_E2E_OBSERVATION_20261114.md) và xem hai ảnh thật bên dưới: kết quả hiển thị khớp báo cáo. Đây là gameplay do sinh viên thực hiện, không phải graphical test do AI chạy hoặc kết luận suy ra từ headless tests; không suy ra student approval đối với patch hoặc reflection.

| Nội dung sau fix | Actual được sinh viên báo | Giới hạn bằng chứng |
| --- | --- | --- |
| Hero / seed / kết quả | Miya / ALOALO1234 / Floor 2 / 39 kills | Agent đã đối chiếu nội dung hai ảnh thật |
| Game Over | RUN SAVED | [Ảnh Game Over trước restart](evidence/manual_e2e_20261114_gameover_run_saved.png) |
| Expedition History | Có entry mới trên cùng khớp | [Ảnh History trước restart](evidence/manual_e2e_20261114_history_miya_floor2.png) |
| Restart game | Entry persisted, sinh viên xác nhận | **Không có ảnh sau restart được cung cấp**; không tạo hoặc giả định có ảnh này |
| Duplicate-history sau restart | Sinh viên không báo có duplicate mới | PASS theo xác nhận sinh viên trong observation; không có independent full-list audit |
| Inspector status / Watch Replay / Retry Current Seed | Chưa có quan sát riêng được cung cấp | Không tự đánh dấu PASS các bước này; human replay playback NOT RUN |
| Human gameplay gần giới hạn 2 MiB sau fix | **NOT RUN** | Short-run không thay thế scenario dài hoặc phép đo responsiveness |

Ba file human evidence đã đọc/xem và đưa vào manifest kèm SHA-256/bytes:

- `docs/BT3_VT074/MANUAL_E2E_OBSERVATION_20261114.md`
- `docs/BT3_VT074/evidence/manual_e2e_20261114_gameover_run_saved.png`
- `docs/BT3_VT074/evidence/manual_e2e_20261114_history_miya_floor2.png`

Hai ảnh ghi nhận quan sát **trước restart**. Không có ảnh sau restart; kết quả restart dựa trên xác nhận trực tiếp của sinh viên trong observation. Case **Floor 5 / 307 kills ở trên vẫn là FAIL trước fix**, không bị thay thế bởi short-run PASS. Short-run không chứng minh human near-2-MiB, 18.000-frame gameplay hoặc long-run responsiveness.

Nếu SAVE_FAILED: Game Over phải hiện `PROGRESS NOT SAVED`, giữ pending và khóa navigation tạo/chuyển run; Retry Saving dùng ID/envelope ban đầu. Nếu STORAGE_UNCERTAIN: hiện `SAVE NOT CONFIRMED`, retry chỉ reconcile trước. Khi đã xác định file cũ còn nguyên, có thể nhấn retry tiếp để commit. Giữ game đang mở; pending chưa commit chỉ ở RAM, thoát/crash sẽ mất pending. Không dùng save thật để cố tình gây lỗi IO; các failure paths đã có fixtures synthetic.

Tester sau fix: **sinh viên cung cấp observation và ảnh**, chưa có tên riêng/giờ chạy. Ngày báo cáo: **14/11/2026**. Kết luận short-run: **PASS (human gameplay; screenshots + restart confirmation)**. Human near-2-MiB: **NOT RUN**. [Review tích hợp hiện tại](EVIDENCE_INTEGRATION_REVIEW_20261114.md) ghi inventory và giới hạn, không phải human approval.
