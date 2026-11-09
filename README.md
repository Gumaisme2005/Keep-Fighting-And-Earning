# Keep Fighting And Earning — QA Test Suite

> **Nhánh `qa/test-suite` là nhánh dành riêng cho QA/Tester.**
> Nhánh này **không chứa mã nguồn game** và **không dùng để merge vào `main` hoặc `development`**.
> Mọi pull request từ nhánh này vào các nhánh trên cần bị từ chối.

Nhánh lưu toàn bộ tài liệu kiểm thử của dự án **Keep Fighting And Earning** (game roguelite Godot 2D): bộ test case, bằng chứng lỗi (video/ảnh), bản xuất lỗi từ Jira và nhật ký kiểm thử.

Để test game, hãy clone `main` hoặc `development` vào một thư mục riêng, chạy bằng Godot, rồi ghi kết quả vào các file trong nhánh này.

---

## 1. Cấu trúc thư mục

```
Test/
├── TestCase.xlsx      # Bộ test case chính (3 sheet: Tổng quan, Test Case, Điểm cần xác minh)
├── TestCase.csv       # Bản CSV của sheet "Test Case"
├── CHANGELOG.md       # Nhật ký kiểm thử theo ngày (QA, bug, tiến độ)
├── linkJira           # Đường dẫn tới Jira board của dự án (project SPK)
├── JiraLogBug/        # Bản xuất từng bug từ Jira (SPK-1.doc, SPK-2.doc, ...)
└── Evidence/          # Video/ảnh minh chứng cho từng bug
```

## 2. Bộ test case

### 2.1 Các cột

| Cột | Ý nghĩa |
|---|---|
| `ID` | Mã test case, dạng `TC-<MODULE>-<SỐ>` (ví dụ `TC-PY-01`) |
| `Module` / `Chức năng` | Phân hệ và chức năng được kiểm thử |
| `Tiêu đề test case` | Mô tả ngắn mục tiêu kiểm thử |
| `Điều kiện tiên quyết` | Trạng thái cần có trước khi test |
| `Các bước thực hiện` | Các bước đánh số theo thứ tự |
| `Dữ liệu test` | Nhân vật, seed hoặc dữ liệu đầu vào |
| `Kết quả mong đợi` | Hành vi đúng theo thiết kế |
| `Loại` | `Chức năng`, `Biên`, `Tiêu cực`, `Giao diện` |
| `Ưu tiên` | `Cao`, `Trung bình`, `Thấp` |
| `Kết quả thực tế`, `Trạng thái`, `Người test`, `Ngày test` | Điền sau khi chạy |
| `Ghi chú` | Điểm cần lưu ý, thường là chỗ mã nguồn lệch với tài liệu |

### 2.2 Trạng thái

| Giá trị | Ý nghĩa |
|---|---|
| `Chưa chạy` | Chưa thực hiện |
| `Đạt` | Kết quả thực tế khớp kết quả mong đợi |
| `Không đạt` | Có lỗi, cần tạo bug trên Jira và ghi mã bug vào `Ghi chú` |

### 2.3 Phân hệ (22 module, nhân vật gốc và hệ thống cơ bản)

| Mã | Module | Số TC | | Mã | Module | Số TC |
|---|---|---|---|---|---|---|
| MN | Menu chính | 4 | | HP | Máu / Giáp / Bất tử | 13 |
| CS | Chọn nhân vật | 7 | | IT | Vật phẩm | 11 |
| PA | Pause Menu | 8 | | IV | Túi đồ & trang bị | 12 |
| GO | Game Over | 5 | | CH | Rương & nhặt đồ | 8 |
| MV | Di chuyển & điều khiển | 7 | | PR | Đạn & bom | 4 |
| UI | HUD & Hotbar | 7 | | EN | Quái thường | 12 |
| PY | Pyrois | 10 | | BS | Boss | 12 |
| OL | Olaf | 6 | | MP | Sinh hầm ngục | 11 |
| MI | Miya | 10 | | RM | Phòng & khóa cửa | 7 |
| CL | Charlotte | 8 | | PT | Cổng & qua màn | 8 |
| SP | Bẫy gai | 7 | | SY | Hệ thống & môi trường | 6 |

Tổng cộng: **182 test case** trong `TestCase.xlsx`. Loại test: chức năng, biên, tiêu cực và giao diện.

## 3. Tiến độ kiểm thử

Số liệu trong file `TestCase.xlsx` tại thời điểm cập nhật gần nhất (27/10/2026):

| Trạng thái | Số lượng |
|---|---|
| Đạt | 51 |
| Không đạt | 2 (`TC-PY-01`, `TC-EN-01`) |
| Chưa chạy | 129 |

> **Lưu ý:** phần lớn test case của bộ nhân vật gốc và hệ thống cơ bản **đã được chạy**, nhưng cột `Trạng thái` **chưa được cập nhật tương ứng**. Các test case đã ghi bug nhưng vẫn hiện `Chưa chạy` gồm `TC-BS-07`, `TC-MI-02`, `TC-SP-02`, `TC-SY-03`. Số liệu ở bảng trên sẽ được đồng bộ lại.

**Lưu ý đồng bộ:** `TestCase.csv` hiện có 183 dòng, nhiều hơn `TestCase.xlsx` 1 dòng (`TC-GO-05`, trạng thái `Chưa chạy`). Khi cập nhật, cần giữ hai file khớp nhau.

## 4. Danh sách bug đã ghi nhận

Quản lý trên Jira (project **SPK**, xem đường dẫn trong `Test/linkJira`). Bản xuất từng bug nằm ở `Test/JiraLogBug/`, bằng chứng nằm ở `Test/Evidence/`.

| Mã bug | Tiêu đề | Mức ưu tiên | Test case liên quan |
|---|---|---|---|
| SPK-1 | [ORC] Cannot attack Player when Player is below Orc within 35px | — | `TC-EN-01` |
| SPK-2 | [HUD] Hotbar is clipped after changing window size | — | `TC-SY-03` |
| SPK-3 | [Gameplay] Pyrois character stats in-game do not match README documentation | Medium | `TC-PY-01` |
| SPK-4 | [Gameplay] Orc Rider boss stops chasing and attacking when Miya stands in a specific corner, allowing a risk-free kill | High | `TC-BS-07`, `TC-BS-08`, `TC-BS-09` |
| SPK-5 | [Miya] Arrow animation spawns from the character's feet instead of from the bow | Low | `TC-MI-02`, `TC-MI-01` |
| SPK-7 | [Doraemon] Basic attack (left mouse button) passes through wooden crates | Medium | Chưa có test case riêng (phát hiện khi test thăm dò) |
| SPK-8 | [Spike Trap] Player standing at the edge of the spike row takes no damage when spikes are active | Low | `TC-SP-02`, `TC-SP-01` |

Trạng thái tất cả bug theo `CHANGELOG.md` gần nhất: **To Do**. Mục `—` là chưa ghi mức ưu tiên trong nhật ký.

Ghi chú: trong nhật ký ngày 01/11/2026 còn một điểm cần xác nhận (mũi tên của Miya gây 1 sát thương lên boss trong khi dự kiến là 2), chưa tách thành bug riêng.

## 5. Quy trình làm việc

1. **Chuẩn bị:** clone `main` hoặc `development`, mở trong Godot và chạy game (F5).
2. **Chạy test case:** thực hiện đúng các bước trong `Các bước thực hiện`, so với `Kết quả mong đợi`.
3. **Ghi kết quả:** điền `Kết quả thực tế`, `Trạng thái`, `Người test`, `Ngày test` trong `TestCase.xlsx` (và đồng bộ sang `TestCase.csv`).
4. **Khi `Không đạt`:**
   - Quay video hoặc chụp ảnh, lưu vào `Test/Evidence/` với tên trùng tiêu đề bug.
   - Tạo bug trên Jira (project SPK), xuất bản `.doc` vào `Test/JiraLogBug/`.
   - Ghi mã bug và mã test case liên quan vào `Ghi chú`.
5. **Nhật ký:** thêm mục vào `Test/CHANGELOG.md` theo ngày, gồm `QA`, `Bug` và `Progress`.
6. **Retest:** khi nhóm dev báo đã sửa, chạy lại test case liên quan và cập nhật trạng thái.

## 6. Đang bổ sung (sẽ cập nhật)

Bộ test case hiện bao phủ chủ yếu **4 nhân vật nguyên bản** (Pyrois, Olaf, Miya, Charlotte). Các phần dưới đây đang được viết thêm:

- [ ] Test case cho **perk**
- [ ] Test case cho **trang bị mới**
- [ ] Test case cho **boss mới**
- [ ] Test case cho **nhân vật mới** (Yugi, Doraemon, Hoshimi Miyabi, Lương Thơ)
- [ ] Cập nhật lại cột `Trạng thái` cho các test case đã chạy
- [ ] Đồng bộ `TestCase.csv` và `TestCase.xlsx`

*(Chi tiết từng hạng mục sẽ được bổ sung khi test case hoàn tất.)*

## 7. Quy ước nhánh

- Nhánh này chỉ chứa thư mục `Test/`. Không thêm mã nguồn game hoặc asset vào đây.
- Không merge vào `main` hay `development`.
- Nên bật **branch protection** cho `main` và `development` (yêu cầu pull request và duyệt) để tránh vô tình merge nhánh này.
