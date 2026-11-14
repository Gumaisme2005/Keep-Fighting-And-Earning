# Reflection – BT3 VT-074

Trong bài tập cá nhân 3, tôi thực hiện yêu cầu VT-074: gửi lại yêu cầu kết thúc lượt chơi nhưng không tạo lịch sử trùng. Tôi dùng Codex để phân tích mã Godot, lập kế hoạch, đề xuất test, sửa lỗi và hỗ trợ viết báo cáo. Tôi đối chiếu đề xuất với mã và test thực tế.

Khi review kế hoạch, tôi chỉnh R-01 để cô lập dữ liệu từng test và R-02 để bảo toàn run ID, ledger khi nạp lại save. Với test AI đề xuất, tôi bổ sung HT-01 để kiểm tra yêu cầu gốc không thay đổi sau retry và HT-02 để xác nhận replay tồn tại trước thao tác xóa. Nhờ vậy, test kiểm tra đúng hành vi.

Tôi đối chiếu bằng chứng RED → GREEN để xác nhận lỗi ghi trùng có trước khi sửa và được xử lý sau đó. Mutation tại ngưỡng retention bị test phát hiện; TIME và ORDER được chạy lặp lại để đánh giá tính ổn định. Benchmark 40 tác vụ cho p95 đạt ngưỡng trên cả bốn workload đã đo. Tuy nhiên, đây chỉ là mô hình trong một tiến trình, không tương đương 631 người dùng thực.

Trong lần chơi thử, tôi gặp SAVE_FAILED khiến một lượt chơi dài không xuất hiện trong History. AI giúp tạo fixture tái hiện trường hợp dữ liệu vượt 2 MiB và sửa bằng nén lossless. Tôi chấp nhận hướng này vì không cần xóa replay hay tăng giới hạn file. Sau đó tôi chơi lại lượt ngắn, thấy RUN SAVED, History có bản ghi đúng và vẫn còn sau khi khởi động lại. Dù vậy, tôi chưa chơi lại tình huống dài tương đương và chưa đo line/branch coverage.

Qua bài này, tôi hiểu rằng test tự động, CI và kiểm tra thủ công bổ sung cho nhau. AI giúp làm nhanh hơn, nhưng quyết định cuối cùng phải dựa trên bằng chứng và những giới hạn đã được ghi rõ.
