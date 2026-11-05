# QA thủ công

Trạng thái hiện tại, phân biệt lỗi lịch sử/rủi ro/chưa kiểm thử và tiêu chí đóng
việc ở [Project status](../PROJECT_STATUS.md), [backlog](../DEVELOPMENT_BACKLOG.md)
và [test plan MA-01…MA-07](TEST_PLAN.md). CSV cũ có 183 testcase, tất cả ghi Chưa
chạy; không dùng log tự động để tích PASS vào dữ liệu này. Lượt QA mới cần ghi
đúng branch/SHA và roster; giữ file lịch sử nguyên vẹn.

- `test_cases.csv` và `test_cases.xlsx`: giữ nguyên dữ liệu testcase do nhóm cung cấp.
- `CHANGELOG.md`: lịch sử QA và các lỗi ghi nhận tháng 10/2026, không phải kết quả
  kiểm thử lại của bản tái cấu trúc.
- `jira_url.txt`: liên kết board Jira có sẵn; cần quyền của nhóm để truy cập.

Mã kiểm thử tự động đặt tại [`tests/`](../../tests/); báo cáo và công cụ benchmark
đặt tại [`benchmarks/`](../../benchmarks/). Hai nhóm này khác chức năng nên không
gộp tài liệu QA vào mã test. `.gdignore` ở `docs/` ngăn import CSV QA thành bản dịch.
