# Thiết Kế Sương Mù Chiến Tranh, Bẫy Kim Cọc & Cân Bằng Hầm Ngục Moria

Tài liệu này ghi nhận chi tiết kiến trúc kỹ thuật của hệ thống bản đồ ngục tối u ám, sương mù chiến tranh lấy cảm hứng từ Đế Chế, cơ chế bẫy chông vật lý và hệ thống tăng độ khó leo thang theo tầng trong **Keep Fighting And Earning**.

---

## 1. Sương Mù Chiến Tranh & Bản Đồ Nhỏ — Minimap Fog of War

### 1.1. Nguyên lý che phủ sương mù
* **Màn đêm toàn cảnh**: Khi bước vào một tầng ngục mới, bản đồ nhỏ chỉ hiển thị duy nhất gian phòng xuất phát của người chơi. Toàn bộ các gian phòng còn lại đều chìm hoàn toàn trong bóng tối sương mù, người chơi không thể nhìn thấy vị trí, số lượng hay cấu trúc của các phòng phía trước.
* **Mở đường theo bước chân**: Khi nhân vật tiến vào một gian phòng mới, hệ thống tự động ghi nhận trạng thái khám phá và gian phòng đó lập tức hiện diện trên bản đồ nhỏ với màu sắc đặc trưng:
  * Xanh lá cây: Gian phòng xuất phát
  * Xanh dương: Gian phòng chiến đấu đã dọn sạch quái vật
  * Cam rực: Gian phòng chiến đấu đang đóng sập cửa đá
  * Vàng ánh kim: Gian phòng kho báu
  * Đỏ thẫm: Gian phòng thủ lĩnh Boss
* **Hành lang dò đường**: Đường nối giữa hai phòng chỉ hiển thị hoàn chỉnh khi cả hai phòng đã được khai phá. Nếu chỉ mới khám phá một phòng, bản đồ chỉ vẽ một nhánh đường ngắn mờ nhạt chỉ hướng vào màn đêm sâu thẳm, tái hiện đúng cảm giác thăm dò lãnh thổ trong các trò chơi chiến thuật cổ điển.

---

## 2. Bầu Không Khí U Tối & Đèn Lồng Linh Hồn — Atmosphere & Lighting

* **Độ tối ngục sâu**: Ánh sáng môi trường toàn cục được điều chỉnh về mức sâu thẳm `Color 0.06, 0.06, 0.10`, khiến toàn bộ không gian ngoài tầm mắt nhân vật chìm trong màn đêm trung cổ dày đặc.
* **Đèn lồng dẫn đường**: Nhân vật mang theo ngọn đèn linh hồn ấm áp với bán kính soi rọi đủ để quan sát và giao tranh cận chiến trong phạm vi an toàn, trong khi các khúc quanh hành lang và gian phòng lân cận vẫn hoàn toàn bị che khuất.
* **Đuốc tường bừng lửa**: Toàn bộ đuốc sắt gắn trên tường tại các phòng chưa khám phá đều ở trạng thái tắt lịm trong bóng đêm. Chỉ khi người chơi vượt qua ngưỡng cửa bước vào phòng, các ngọn đuốc trên trụ đá mới bừng lửa và tỏa ánh sáng lung linh khắp gian phòng.

---

## 3. Cơ Chế Bẫy Kim Cọc Vật Lý — Spike Trap

Bẫy chông sàn đá được nâng cấp toàn diện về mặt vật lý và tương tác chiến thuật:
* **Miễn nhiễm sát thương cho quái vật**: Vòng quét sát thương khi cọc nhô lên chỉ áp dụng cho người chơi. Quái vật và kẻ địch di chuyển qua bẫy hoàn toàn không bị tổn hại sinh lực.
* **Rào cản vật lý ngăn đường**: Bẫy tích hợp một thực thể vật lý chặn đường. Khi cọc gai đâm trồi lên, khối vật cản được kích hoạt khiến cả người chơi lẫn quái vật không thể đi xuyên qua, biến bẫy thành một bức tường chông ngăn cách chiến thuật. Khi cọc gai thụt xuống nền đá, lối đi được mở lại bình thường.
* **Thời gian duy trì kéo dài**: Thời gian cọc nhô lên và giữ nguyên vị trí được nâng từ 1.0 giây lên **2.8 giây**, mang lại sức ép sinh tồn lớn hơn khi người chơi phải lựa chọn thời điểm vượt qua.

---

## 4. Hệ Thống Tăng Độ Khó Leo Thang Theo Tầng — Dungeon Depth Scaling

### 4.1. Bảng chỉ số quái vật cơ bản — Tầng 1
* **Moria Orc**: Máu 4 • Sát thương 2 • Tốc độ 75.0
* **Armored Uruk-hai**: Máu 5 • Giáp 6 • Sát thương cơ bản 2 • Cuồng nộ 4
* **Barrow-wight Skeleton**: Máu 3 • Sát thương 1 • Tốc độ 110.0
* **Minas Morgul Bone Archer**: Máu 5 • Sát thương 2 • Tốc độ 70.0 • Hồi chiêu bắn tên 1.6 giây
* **Angmar Blood Bat**: Máu 5 • Sát thương 2 • Tốc độ 85.0 • Hồi chiêu cắn 1.4 giây

### 4.2. Chỉ số Thủ Lĩnh — Bosses
* **Tử Linh Pháp Sư Dol Guldur**: Máu 45 • Sát thương cận chiến 2 • Độc tố bóng đêm 3 • Tốc độ 55.0 • Hồi chiêu 1.3 giây
* **Thủ Lĩnh Kỵ Binh Warg**: Máu 50 • Sát thương 3 • Tốc độ 75.0

### 4.3. Quy luật tăng tiến theo tầng sâu
* **Mật độ quái vật mỗi phòng**: Tăng từ mức cơ bản 3 đến 7 quái ở Tầng 1, lên đến tối đa 8 đến 14 quái ở các tầng sâu tiếp theo theo công thức tính toán lũy tiến.
* **Cường hóa thực thể từ Tầng 2 trở đi**:
  * Quái vật thường nhận thêm 2 điểm Máu cho mỗi tầng vượt qua, và tăng thêm sát thương từ Tầng 3.
  * Thủ lĩnh Boss nhận thêm 20 điểm Máu và 1 điểm Sát thương cho mỗi tầng sâu tiếp theo.

---

## 5. Hướng Dẫn Vận Hành Qua Docker — Dockerization Guide

Dự án cung cấp bộ công cụ Docker hóa hoàn chỉnh gồm `Dockerfile`, `docker-compose.yml` và cấu hình máy chủ Nginx với đầy đủ tiêu chuẩn WebAssembly:

### 5.1. Chơi game trực tiếp trên trình duyệt qua Docker
Chạy lệnh sau tại thư mục dự án để khởi chạy máy chủ Web Nginx trên cổng 8080:
```bash
docker compose up game --build
```
Mở trình duyệt và truy cập: `http://localhost:8080`

### 5.2. Chạy bộ kiểm thử tự động Headless qua Docker
Chạy lệnh sau để thực thi toàn bộ 19 Unit Tests và 500 phép kiểm chứng thuộc tính trong môi trường Linux Container:
```bash
docker compose run --rm test
```
