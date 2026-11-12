# BT3 VT-074 — Constrained pairwise design và verification

Ngày 12/11/2026. Thiết kế từ SPEC §4–6, revised plan P-04. Dữ liệu tại [pairwise_cases.csv](../../tests/vt074/pairwise_cases.csv). Các rows đều `PLANNED AFTER PATCH`; verifier PASS chỉ là kiểm chứng covering array, không phải GameManager đã đạt contract.

## Factors, levels và fixture semantics

| Factor | Levels | Định nghĩa vận hành |
| --- | --- | --- |
| identity | active_new / retained / invalid / unknown_unissued / unknown_expired | New là active OPEN do start cấp. Retained là ID ledger còn receipt. Invalid dùng chuỗi `not-a-run-id`. Unissued đúng cú pháp 32 hex nhưng chưa được cấp. Expired là oldest ID đã bị prune đúng tại completion thành công thứ 129. |
| payload | same / different | So với reference payload P0 của fixture; same=P0, different=P1 chỉ đổi kills 7→8. Cả hai đều hợp lệ schema. Đối với retained, reference là payload đã commit; các IDs fixture fill khác có payload cố định riêng và đều do lifecycle cấp. |
| storage | in_memory / after_reload | Fixture synthetic tạo xong trong owner hiện tại / snapshot hợp lệ được load vào owner mới. “Fresh” được đổi thành in_memory vì fresh không đồng nghĩa ledger rỗng. New sau reload phải start mới, không resume active cũ. |
| ledger | below / at_128 / overflow_129 | Trước request quan sát: fixture có 16 /128 /129 successful completions lịch sử; ledger hiện tại là 16/128/128. Overflow đã prune đúng oldest. Chỉ count thành công, không dùng clock/TTL. |

Điều chỉnh identity tách unknown thành unissued/expired để kiểm admission và retention rõ ràng. Payload relation vẫn có nghĩa ở invalid/unknown/new: P0/P1 là dữ liệu hợp lệ so với reference fixture, không nói rằng request sai ID có một completion gốc. Vì vậy invalid+different không bị loại một cách tùy ý. Malformed payload là directed VT74-16, không trộn vào pairwise này.

Retained target luôn còn ledger (ở overflow chọn receipt thứ 2 hoặc mới hơn); unknown_expired target là receipt thứ nhất; new start sau fill/reload; unknown_unissued không trùng bất cứ ID đã được cấp. ID provider xác định và duy nhất, không suy ID từ seed/date. Fixture có thể đã prune history15/replay10; receipt là oracle, không cần history của target còn tồn tại.

## Constraints và expected statuses

Chỉ constraint loại full rows trong mô hình này: `identity == unknown_expired` yêu cầu `ledger == overflow_129`. Below/at_128 không có eviction trong fixture quy định. Do đó 8/60 full combinations không khả thi; 52 full combinations còn lại đều có setup hợp lệ, kể cả new sau reload vì start mới được thực hiện sau load.

Hai cặp không khả thi:

| Cặp bị loại | Lý do |
| --- | --- |
| unknown_expired × below | 16 completion thành công chưa làm oldest hết retention. |
| unknown_expired × at_128 | Đúng 128 chưa được prune; oldest vẫn phải nhận diện. |

Unknown do clear ledger thủ công/save corruption không thuộc fixture này; v2 lỗi phải fail closed, không biến thành unknown_expired. Không tuyên bố bao phủ toàn bộ state machine chỉ bằng bốn factors.

Oracle: active_new → COMMITTED (storage success), retained+same → DUPLICATE, retained+different → CONFLICT, invalid → INVALID_REQUEST, cả unknown → UNKNOWN_RUN. Các row retry/reject phải không đổi committed RAM/disk/frames/ledger/FIFO/save/signal; new phải có đúng 1 result/receipt/save/signal, enforce caps và ledger đúng. Các counters loại setup/fill/reload/delete ra khỏi phép đo. Writer success cố định ở đây; lỗi writer chỉ exercise nhánh write trong directed cases.

## Generation và verification thực tế

[pairwise.py](../../tests/vt074/pairwise.py) chỉ dùng Python stdlib. Enumerate toàn Cartesian có constraint; deterministic greedy chọn row phủ nhiều cặp chưa phủ nhất, tie-break theo Cartesian order; loại row dư theo thứ tự ngược. Không có randomness/seed và không tuyên bố tối ưu số rows. Generate ghi CSV; verify mặc định đọc CSV hiện hữu, không tái sinh hay tự sửa CSV. Verifier enumerate lại tập full combinations để tính feasible pairs, so sánh toàn bộ pairs của array, kiểm levels/constraints/duplicate row IDs/rows/oracle/mapping/status.

```powershell
py tests/vt074/pairwise.py --generate
py tests/vt074/pairwise.py
```

Kết quả chạy thực tế: **14 array rows, 49/49 feasible pairs covered**, 0 missing pairs, 0 validation errors; 51 theoretical pairs, 2 excluded; 60 full combinations, 52 feasible. Evidence JSON có toàn bộ factors/constraints và pairs bị loại: [pairwise_verification.json](evidence/pairwise_verification.json). Command stdout/exit code được lưu trong [verification.log](evidence/verification.log). Đây là coverage strength 2, không phải 52/52 full combinations và không phải kết quả chạy 14 rows trên Godot.

CSV có `expected_status`, `test_cases` và `execution_status` cho từng PW-01…PW-14. Ví dụ PW-03 retained/same/reload/overflow map 02+07+10; PW-07 retained/different/memory/below map 04; PW-09/10 map expired oracle 10; PW-12 map retained-at128 oracle 02+09. Verifier kiểm reference tồn tại trong đúng 22 case IDs của catalog và expected mapping theo từng row; JSON liệt kê IDs được map và directed IDs ngoài matrix. Mapping là các template/scenario áp dụng, không yêu cầu mỗi sub-assertion của mọi case được gắn chạy ở mọi row. 03/11 đã cập nhật human-approved v1; chúng là directed scenarios, không làm thay đổi factors/constraints hoặc CSV. Tất cả 14 rows vẫn PLANNED AFTER PATCH, kể cả khi reference 01/02 có baseline subset đã chạy.

## Directed coverage bổ sung bắt buộc

- VT74-08/19/22: definite save failure, uncertain/reconcile, UTF-8 cap 2MB; không thay storage success bằng lỗi ở duplicate vì duplicate không được gọi writer.
- VT74-03/12: frozen envelope và toàn bộ retry side effects (TR-01 v1); Expedition History E2E. Hai hành vi này không suy ra từ pairwise factors.
- VT74-09/10: 127→128→129, oldest không active và rời history15; kiểm FIFO/receipt riêng. Rows at128/overflow không tự chứng minh transition này.
- VT74-04/05/15/16/18: conflict từng field, invalid ID/type/schema, never-issued, canonical equivalence.
- VT74-06/13/17/20/21: cùng seed/date, delete/caps rồi retry, legacy/corrupt loader, replay/session mode.
- VT74-11/14: độc lập/đảo thứ tự và queue witness 40 pending; array tĩnh không chứng minh concurrency hoặc hết flaky.

Không triển khai generation ID, canonical hash, writer hoặc ledger vào test để giả lập SUT. Expected status trong CSV là specification, chỉ executable sau patch tương lai. Behavioral RED hiện tại là VT74-02 existing adapter, tách biệt với covering array.
