# Nội dung cần sinh viên review — không phải reflection đã phê duyệt

Ngày 14/11/2026. Giữ nguyên REFLECTION.md như nguồn lịch sử; không viết thay một bài ngôi thứ nhất mới.

- Phần provenance hiện ghi AI “chỉ lưu nguyên văn”. Cần sinh viên kiểm tra lại: AI đã hỗ trợ draft/reflection và gợi ý code HT-01/HT-02. Việc sinh viên gửi lại/sửa/lưu không chứng minh toàn bộ ý tưởng hoặc văn bản được viết độc lập.
- Câu heavy performance vẫn FAIL đã lỗi thời sau C1 được duyệt và áp dụng. Dùng báo cáo persistence mới cho số đo hiện tại; các kết quả FAIL cũ vẫn đúng cho source/thời điểm lịch sử.
- Manual gameplay đã có FAIL ngày 14/11: Miya, ALOALO1234, floor 5, kills 307, SAVE_FAILED, thiếu history. Manual sau fix vẫn PENDING cho tới khi sinh viên thực sự retest.
- Giải thích bài học từ synthetic RED: schema hợp lệ chưa đủ; tổng JSON có full recording và history vượt physical byte budget. Tách transaction SAVE_FAILED khỏi storage READY, và kiểm tra UI không che lỗi.
- Ghi rõ human decisions R-01/R-02, TR-01/TR-02 và HT-01/HT-02 theo evidence gốc. Assistant triển khai code/test mới trong phiên này; chưa có human review hoặc approval mới cho patch này.
- Line/branch coverage tiếp tục NOT MEASURED; assertion counts là behavioral evidence. Không gọi headless PASS là manual PASS hoặc local Windows PASS là GitHub Actions Linux PASS.

Đây là đề xuất nội dung, sinh viên cần tự xem xét, sửa reflection và hoàn thiện PDF riêng. Không có quyết định human mới được ghi nhận trong tài liệu này.
