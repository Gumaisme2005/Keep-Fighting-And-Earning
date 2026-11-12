# Reflection — Vũ Xuân Bắc, 23001833

Nguồn: sinh viên gửi trực tiếp trong phiên Commit 6 sau khi xác nhận đã sửa hai test trong VS Code. AI chỉ lưu nguyên văn phần dưới và kiểm tra số từ/tính nhất quán; không nhận đây là bài do AI tự viết thay sinh viên. Tiêu đề và ghi chú nguồn không tính vào số từ thân bài.

## Nội dung sinh viên cung cấp

Trong bài tập cá nhân 3, tôi sử dụng AI để phân tích yêu cầu VT-074, lập kế hoạch, thiết kế test cases và xây dựng runner kiểm thử tính năng chống ghi trùng lịch sử lượt chơi. AI giúp giảm thời gian chuẩn bị fixture và evidence, nhưng tôi không coi kết quả AI tạo ra là bằng chứng đúng nếu chưa đối chiếu source code và chạy test thực tế.

Tôi xem xét R-01 về test phụ thuộc trạng thái chung và R-02 về khôi phục run ID, ledger sau khi tải save. Với TR-01 và TR-02, tôi nhận thấy việc chỉ đếm bản ghi hoặc lặp lại cùng thứ tự kiểm thử chưa đủ mạnh. Tôi đã áp dụng HT-01 để kiểm tra trực tiếp frozen envelope sau các lần retry và HT-02 để xác nhận fixture có replay trước thao tác xóa. Các thay đổi này bổ sung điều kiện kiểm tra mà vẫn giữ assertions gốc.

Bằng chứng RED cho thấy cùng yêu cầu hoàn tất lượt chơi tạo hai bản ghi thay vì một. Sau khi sửa, tình huống đó chuyển sang GREEN, giúp tôi tin tưởng hơn vì test bắt đúng lỗi và xác nhận hành vi mới. Mutation đổi > thành >= tại ngưỡng retention cũng bị test biên phát hiện; khôi phục code khiến test PASS trở lại. Kiểm tra TIME và ORDER qua 20 lượt hỗ trợ đánh giá tính ổn định, nhưng không bảo đảm hệ thống hoàn toàn hết flaky.

Benchmark 40 tác vụ cho thấy workload 2 frames đạt mục tiêu p95, còn 3.600 frames vẫn FAIL. Đề xuất P-01 bị loại sau thử nghiệm vì cải thiện chưa đủ thuyết phục. Manual visual E2E và line/branch coverage cũng chưa được xác minh đầy đủ.

Test tiếp theo tôi ưu tiên là kiểm tra trực tiếp luồng chọn nhân vật, kết thúc lượt chơi, mở lịch sử, khởi động lại game và retry. Điều này giúp kiểm chứng trải nghiệm người chơi mà test headless chưa chứng minh hoàn toàn.
