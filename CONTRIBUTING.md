# Đóng góp cho Keep Fighting And Earning

Đọc [README](README.md), [cấu trúc dự án](docs/architecture/PROJECT_STRUCTURE.md)
và [quy trình cân bằng](docs/gameplay/BALANCE_WORKFLOW.md) trước khi sửa gameplay.

## Branch và Pull Request

- Kiểm tra `git status --short --branch`, remote và commit hiện tại. Bản ZIP không
  có lịch sử Git; đối chiếu thay đổi với một clone của repository trước khi tạo PR.
- Fetch rồi so sánh với nhánh đích đã thống nhất trong nhóm; không mặc định branch
  đang mở hoặc `main` là phiên bản mới nhất. Không ghi đè thay đổi chưa commit.
- Làm trên `feature/<muc-tieu>`, `fix/<loi>`, `chore/<cong-viec>` hoặc `qa/<pham-vi>`;
  không sửa trực tiếp `main`. Giữ PR theo một mục tiêu có thể review.
- Tiêu đề commit/PR mô tả kết quả, ví dụ `chore: organize Godot scenes and QA evidence`.
- Ghi rõ vấn đề, hành vi sau thay đổi, đường dẫn bị ảnh hưởng, lệnh test đã chạy,
  phiên bản Godot và giới hạn kiểm chứng. Dùng [mẫu PR](.github/PULL_REQUEST_TEMPLATE.md).
- Thay đổi phiên bản engine, CI/CD lớn hoặc branch protection cần đề xuất riêng
  để nhóm thống nhất. Không coi benchmark từ commit khác là bằng chứng của PR hiện tại.

## Quy ước mã nguồn và tài nguyên

- Thư mục và tệp mới dùng `snake_case`; tên class/node giữ `PascalCase` theo chức năng.
- Scene và script gắn liền đặt cạnh nhau trong `scenes/<feature>/`. Script dùng chung
  không thuộc scene đặt trong `scripts/`. Không chia thêm tầng nếu chưa có nhu cầu.
- `Assets/` giữ tên gói tài nguyên hiện có. Không đổi tên hàng loạt ảnh/font/audio
  trong PR gameplay. Tài nguyên mới nên có tên rõ nghĩa, tránh khoảng trắng.
- Khi chuyển tệp, dùng FileSystem dock của Godot khi có thể. Di chuyển `.gd.uid`
  cùng script, giữ UID trong `.tscn`, `.tres`, `.import`, và kiểm tra toàn bộ đường
  dẫn `res://`, `extends`, `preload`, autoload và cấu hình main scene.
- Commit source assets và các sidecar UID/import cần thiết; không commit `.godot/`,
  `build/`, file bí mật export hoặc bản sao coverage/mutation sinh tự động.
- Giữ nguyên node path, signal và tên lớp khi chỉ sắp xếp tệp. Không trộn đổi thuật
  toán RNG, cân bằng hoặc quy mô benchmark vào PR tái cấu trúc.

## Kiểm tra trước khi gửi PR

Chạy `python tools/check_project_structure.py`, import với Godot đúng phiên bản,
chạy `run_tests.bat` trên Windows và chơi thử luồng menu → chọn nhân vật → dungeon.
Xem [README](README.md) để đặt `GODOT_BIN` hoặc chạy lệnh Godot trực tiếp trên Linux/macOS.
Kiểm tra phân biệt hoa/thường vì CI chạy Linux.

Khi sửa tài liệu hoặc hình ảnh, đọc [mục lục và quy ước docs](docs/README.md), rồi
chạy `python tools/check_documentation.py`. Giữ ảnh/CSV và báo cáo cũ; chỉ di chuyển
khi cần, cập nhật mọi đường dẫn ảnh liên quan và không ghi đè số liệu lịch sử.

Kết quả mới lưu trong thư mục kết quả tương ứng của `benchmarks/`, kèm seed, engine,
commit, máy đo và phạm vi đo. Không sửa CSV lịch sử để khớp kết quả mong đợi. Các
thư mục kết quả/tài liệu có `.gdignore` để Godot không import CSV thành bản dịch.
Không đặt script hay scene cần chạy bên trong các thư mục được bỏ qua này.

## Cập nhật tiến độ cùng Pull Request

Đọc [Project status](docs/PROJECT_STATUS.md) để chọn đúng baseline/SHA. Khi sửa
feature, cập nhật hàng Fxx trong [checklist](docs/FEATURE_CHECKLIST.md); khi xử lý
lỗi/việc, cập nhật PB-xx và link issue/PR thật trong [backlog](docs/DEVELOPMENT_BACKLOG.md).
Nếu thay scope/phụ thuộc/gate release, cập nhật [roadmap](docs/DEVELOPMENT_ROADMAP.md)
và Project status. PR chỉ sửa docs không cần chạy lại toàn bộ Godot khi runtime
không đổi, nhưng phải kiểm tra liên kết và nêu rõ test cũ được dùng lại.

Ghi ngày/commit/engine/platform, test ID/lệnh, kết quả và log/artifact; phân biệt
PASS/FAIL/NOT TESTED/SKIPPED. Chỉ đóng việc khi đạt tiêu chí trên bản đích; ghi
branch thực sự merged vào. Giữ nguyên log/CSV và trạng thái testcase cũ, lưu lượt
mới riêng. Quy trình và mẫu bằng chứng ở Project status; không yêu cầu phân công
thành viên trong tài liệu.
