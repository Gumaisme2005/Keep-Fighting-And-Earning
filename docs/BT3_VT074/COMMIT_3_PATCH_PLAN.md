# Commit 3 — AI patch proposal trước implementation

Ngày 12/11/2026 (Asia/Saigon); branch `feat/bt3-vt074-idempotent-run`, HEAD/start `25026e34b0fc3514e2ae813f017774cf694e5375`; working tree sạch. Prompt user nguyên văn: [commit3_prompt.txt](evidence/commit3_prompt.txt). Đây là phương án AI, chưa phải xác nhận sinh viên review code.

Phạm vi dự kiến trước khi sửa:

- `Scene/GameManager.gd`: AC-01/02 lifecycle OPEN/PENDING/CLOSED, token 128-bit không dựa clock/seed, frozen adapter envelope; AC-04 boundary validate/canonical hash/receipt; AC-05 ledger FIFO 128 và v2/legacy loader; AC-03 identity-safe deletion/replay. Mọi writer dùng snapshot candidate chung, publish sau commit xác minh.
- `Scene/RunCompletionStore.gd` mới: helper local JSON nhỏ, temp cùng thư mục, byte cap/write/flush/read-back/replace, tách SAVE_FAILED với STORAGE_UNCERTAIN và reconcile; không hứa power-loss durability hoặc multi-writer safety.
- `Scene/UI/character_select.gd`: guard hẹp trước đổi hero/start/chuyển scene nếu PENDING/storage blocked. Baseline dòng 417–423 hiện chuyển scene dù start chưa thể báo lỗi. Replay callers trong GameManager cũng cần guard trước đổi hero/scene. Không đổi UI layout hoặc flow.
- `tests/test_replay_security.gd`: start trước stats/frames, các groups tự tạo fixture riêng, giữ mọi assert cũ. Thêm lựa chọn chạy group/order để kiểm R-01 mà không sửa gameplay.
- Test contract/scene mới chỉ kiểm branch cốt lõi của patch và loader/writer/start guard; không triển khai toàn bộ catalog/integration/fault matrix Commit 4 hoặc benchmark/mutation Commit 5.
- GREEN runner mới: tái sử dụng child APPDATA + probe/sentinel của C2, copied project, oracle engine exit 0 + assertions. Không dùng RED runner exit code, không sửa script VT74-02, RED log/JSON, Original AI Plan hoặc các docs kết quả lịch sử C2.
- Docs/evidence C3: production diff, command/stdout/stderr/exits, actual regression counts, AC mapping và AI review/residual risks. Không stage/commit/push/PR.

Luồng dự kiến: validate → ledger lookup → active admission → freeze payload/date → deep-copy candidate result+receipt → writer xác minh snapshot → publish RAM/close active → signal một lần. Reject/duplicate không gọi writer. Deterministic failure giữ pending envelope; uncertain chặn writes/start đến reconcile. Loader validate toàn snapshot trước publish, v2 lỗi không bootstrap ghi đè; legacy không suy/backfill ID.

Điểm cần tự review trong quá trình patch: reentrant signal có thể gọi start/retry khi chưa close; delete candidate không được mutate live frames trước commit; loader JSON numeric types không được làm mất fingerprint; rename failure không được tự suy đích còn bản cũ. Source baseline: finish 219–245, save/load 356–434, delete 258–291, start/replay 152–171/333–354, regression FIFO 43–52/manual69–79/clear81–86.

Tài liệu API tham khảo: [DirAccess.rename](https://docs.godotengine.org/en/stable/classes/class_diraccess.html#class-diraccess-method-rename), [FileAccess.flush](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-flush). Behavior overwrite/read-back trên binary Windows local phải có test thực trước kết luận; docs không thay runtime evidence.

Scope clarification sau khi chạy regression (không viết lại proposal ban đầu): `test_perk_system.gd` không parse vì fixture gọi `PerkManager.new()` trên autoload instance (baseline dòng 114/140/158/187). Suite này cần để bảo vệ reseed/reset perk khi GameManager start. Chỉ preload script PerkManager rõ ràng và đổi bốn constructor fixture sang script.new(); giữ nguyên mọi assertions và production PerkManager. Các lỗi/type-inference thực tế giữ trong archive GREEN attempt. Không sửa balance/Equipment/perk logic để test xanh.
