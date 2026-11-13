# VT-074 — Final performance trade-off review

Ngày 14/11/2026, Asia/Saigon. Branch `feat/bt3-vt074-idempotent-run`, HEAD `8db06a56720d7f2bbe359c908eb55950b8d208c8`. Tiếp tục project đã import của trial `1a3b68d5d730`; không dựng lại thí nghiệm cũ. Review mới `144f3df0463e`. **Giữ nguyên bytes của toàn bộ 48 file local có từ đầu review**, gồm pairwise/CI và evidence lịch sử. Production chưa thay đổi; không stage/commit/push/merge/tạo PR.

## 1. Nguyên nhân đo được, và điều chưa thể quy kết

Candidate cũ thêm một deep copy đầy đủ trong `_remember_validated_payload()`, sau khi payload canonical mới đã được cấp phát và `_envelope` đã có bản sao riêng. Nó còn khóa Dictionary của từng frame, Array frames và Dictionary payload thành read-only. Đây là phần code bổ sung thực sự trên đường first-COMMITTED.

[Scoped profile](evidence/heavy_tradeoff_144f3df0463e_profile.json) xen kẽ ba scripts thật theo thứ tự xuôi/ngược giữa các iteration, trên cùng real store: 2/3.600 frames, 5 warm-up +30 measured first commits/variant/frames, tổng 210 commits. Đây là phép chẩn đoán một first commit, **không thay thế acceptance workload 40 submissions**. [Raw spans](evidence/heavy_tradeoff_144f3df0463e_scopes_attempt1.json) và [instrumentation patch](evidence/heavy_tradeoff_144f3df0463e_instrumentation_attempt1.patch) giữ toàn bộ chi tiết.

| Scope, 3.600 frames, mean ms | Gốc | Cache cũ C0 | Cache nhận ownership C1 |
| --- | ---: | ---: | ---: |
| Cache construction inclusive | 0 | 8,269 | 0,476 |
| Deep copy thêm cho cache | 0 | 7,767 | 0 |
| Nhận Dictionary canonical | 0 | 0 | 0,003 |
| Khóa các container read-only | 0 | 0,482 | 0,464 |
| Instrumented first-COMMITTED service | 294,567 | 300,501 | 292,337 |

Cache construction bao gồm copy/adopt và read-only; **không cộng lại các inclusive scopes lồng nhau**. Self-time của mọi spans cộng đúng root request. Thao tác khóa không chạy một recursive sanitizer mới: canonical payload có schema scalar và frames chứa scalar; vòng lặp khóa mọi Dictionary frame cùng hai container ngoài. Unknown nested metadata đã được canonicalization gốc loại bỏ.

**Cả ba variants đều có đúng 4 canonicalization calls, 1 fingerprint call và 1 store transaction/first commit.** Canonicalization lặp do snapshot validation là hành vi gốc, không phải phần mới của candidate. Không thêm validation hoặc hash nào trong cache construction. Profile giữ cả CPU-side scopes và elapsed filesystem/store scopes; đây không phải hardware CPU counters hay physical disk latency.

**Không thể quy chính xác toàn bộ mức tăng lịch sử 345,155 →455,496 ms cho deep copy.** Lần cũ không có spans cho cache/OS scheduling/CPU frequency tại thời điểm đó. Scope mới đo copy khoảng 7,77 ms và khóa khoảng 0,48 ms; chúng không chứng minh cache gây cả 110,34 ms tăng lịch sử. Workstation drift/background load/filesystem timing là giả thuyết cho phần còn lại, chưa có bằng chứng để gán tỷ lệ cụ thể. Lượt matched mới tái hiện C0 tăng mean chỉ 10,461 ms so với gốc, thay vì 110,34 ms. Không sửa hoặc thay provenance của số cũ.

## 2. Đúng một cải tiến tối thiểu

Delta C0 →C1 chỉ là:

```diff
-	_duplicate_payload = payload.duplicate(true)
+	_duplicate_payload = payload
```

`payload` ở đây là **kết quả canonical cục bộ mới được tạo bên trong `complete_run_request()`**, không phải `raw_payload` của caller. Canonicalization tạo Dictionary/Array/frame Dictionary mới, sau đó cache khóa toàn bộ container. Không có shared mutable cache data. `_envelope` đã được deep-copy trước đó và vẫn giữ ownership riêng; entry/last-recorded/summary vẫn dùng các copies gốc.

Không tái sử dụng/khóa trực tiếp `_envelope`: lifecycle gốc còn gọi `_envelope.clear()` khi start run mới. Nhận canonical cục bộ tránh thay đổi lifecycle đó. Không bỏ validation, canonicalization, conflict detection, fingerprint, persistence, receipt copying hoặc cache-reset guards. Không thử thêm một phương án optimization khác.

[Ownership suite](../../tests/vt074/test_heavy_tradeoff_ownership.gd) kiểm cả 2 và 3.600 frames: caller vẫn mutable và không đổi; mọi frame/cache container read-only; cache không alias caller, envelope, history, last recording; exported snapshot vẫn mutable và detached; nested invalid/conflict đúng; receipt/fingerprint không đổi; start run mới giải phóng cache và receipt cũ vẫn duplicate. **56 assertions PASS.**

Exact production proposal: [full original →C1 patch](evidence/heavy_tradeoff_144f3df0463e_candidate.patch). [C0 →C1 ownership-only patch](evidence/heavy_tradeoff_144f3df0463e_ownership.patch) có đúng một dòng thay đổi. `git apply --check` đã PASS đối với bản sao project gốc; không apply vào checkout production.

| Source | SHA-256 |
| --- | --- |
| Production gốc | `ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe` |
| C0 | `85f0aa28dca74f73c3c7f60cd023c83adbcce24754e1399d76d89343b93968de` |
| C1 đề nghị giữ | `097cfb2cfb99135759a18bd0a4f0bee6b2b1201d8eb1b8bc406934583198e2a7` |

[Source artifact](evidence/heavy_tradeoff_144f3df0463e_sources.json) giữ bytes UTF-8/line endings chính xác của cả ba scripts. Các scripts candidate chỉ chạy trong project cô lập.

## 3. So sánh cuối, không instrumentation

Thứ tự đối xứng: **ORIGINAL_A →COPY_A →OWNED_A →OWNED_B →COPY_B →ORIGINAL_B**. Dùng lại project/harness đã import; mỗi invocation có child save directory và isolation probe riêng. Cùng Godot `4.7.2.stable.official.ed1daf0bf`, cùng binary hash, cùng source harness/store/fixture. Không chạy profiling/regression đồng thời với benchmark.

Giữ nguyên **40 overlapping submissions**, **5 warm-up +30 measured batches mỗi workload/lượt**, 2 và 3.600 frames. Primary có 1 COMMITTED +39 DUPLICATE; secondary có 20 DUPLICATE +10 CONFLICT +10 INVALID_REQUEST trên owner đã precommit. Không giảm workload hoặc bỏ validation để đạt target. Secondary setup commit nằm ngoài timer như harness gốc; first-COMMITTED statistics dưới đây lấy từ timed primary first requests.

Sáu datasets có **840 batches, 28.800 measured +4.800 warm-up records**. Mỗi variant/workload có 2.400 measured requests; nearest-rank p95 index 2279. Kiểm riêng từng run 1.200/index 1139 và từng batch 40/index 37. Latency là submit →finish, **bao gồm queue/barrier wait**. Không gộp workloads/frames với nhau.

| Workload | Frames | Gốc p95 ms | C0 p95 ms | C1 p95 ms | C1 max end-to-end ms | C1 batches >1500 ms /60 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Primary | 2 | 12,909 | 4,060 | 4,058 | 4,332 | 0 |
| Secondary | 2 | 2,535 | 1,156 | 1,170 | 1,339 | 0 |
| Primary | 3600 | 2974,893 | 420,644 | 404,493 | 443,485 | 0 |
| Secondary | 3600 | 2159,997 | 794,423 | 788,134 | 865,261 | 0 |

**C1 PASS cả bốn workloads và mọi measured batch.** Gốc heavy FAIL 60/60 batches/family. C1 heavy p95 giảm **86,40% primary, 63,51% secondary** so với baseline cùng phiên. So với C0 cùng phiên, C1 primary heavy giảm 16,151 ms, secondary heavy giảm 6,289 ms. Secondary/2 tăng nhẹ 0,014 ms so với C0; không che hoặc làm tròn thành không đổi.

[Benchmark report](evidence/heavy_tradeoff_144f3df0463e_benchmark.json) lưu commands, version, source hashes, stdout/stderr và exits. [Portable verification](evidence/heavy_tradeoff_144f3df0463e_verification.json) tính lại mọi CSV/barrier/status/queue/service/p95 và giải nén **840 persisted snapshots**. 140 batch IDs tương ứng **byte-identical trên cả sáu lượt**. Không dùng profile spans để kết luận acceptance p95.

## 4. First-COMMITTED: mean, p95 và maximum tuyệt đối

Đơn vị ms, **60 measured first commits/variant/frames**; không bỏ outlier. Maximum là giá trị quan sát trong trial, không phải hard bound cho mọi máy/lần chạy.

| Frames | Variant | Mean service | p95 service | Max service | p95 submit→finish | Max submit→finish |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 2 | Gốc | 6,495 | 10,072 | 15,291 | 10,224 | 15,539 |
| 2 | C0 | 3,375 | 3,570 | 4,016 | 3,717 | 4,163 |
| 2 | C1 | 3,325 | 3,646 | 3,727 | 3,795 | 3,871 |
| 3600 | Gốc | 294,714 | 306,747 | 477,640 | 307,119 | 477,866 |
| 3600 | C0 | 305,175 | 332,796 | 372,551 | 333,001 | 372,728 |
| 3600 | C1 | 293,512 | 314,384 | 330,327 | 314,642 | 330,491 |

C0 →C1 heavy first mean giảm **11,663 ms (3,82%)**, p95 giảm **18,412 ms (5,53%)**, max giảm **42,224 ms**. Scoped profile trực tiếp xác định copy bị loại khoảng 7,77 ms; không quy toàn bộ chênh lệch uninstrumented cho copy vì còn run variation.

**Trade-off còn lại so với production gốc:** C1 mean giảm 1,202 ms (0,41%), nhưng p95 service tăng **7,637 ms (2,49%)**. Max service giảm 147,313 ms; max first request gồm queue wait là **330,491 ms**. First/2 p95 C1 cũng tăng 0,076 ms so với C0, vẫn thấp hơn gốc. Đây là các thay đổi quan sát được; không có confidence interval đủ để tuyên bố mọi chênh lệch nhỏ là do code hoặc đều chỉ là noise.

Secondary heavy fallback CONFLICT service mean/p95 gốc **71,381/75,934 ms**, C1 **72,316/77,210 ms**. Invalid service p95 gốc/C1 **0,011/0,012 ms**. Secondary/2 conflict p95 **0,082 →0,096 ms**. Các nhánh này vẫn chạy validation/hash gốc; raw evidence giữ toàn bộ per-status statistics, không tuyên tất cả đường đi đều nhanh hơn.

## 5. Correctness và regression

[Validation](evidence/heavy_tradeoff_144f3df0463e_validate.json): completion differential **26 scenarios /1.051 assertions PASS**, canonical/alias **94 cases /284 assertions PASS**, ownership **56 assertions PASS**. Tổng 1.391 assertions của ba suites mới chạy, 0 FAIL. Duplicate, conflict, invalid payload, nested/caller/receipt mutations, reload kể cả 3.600 frames, frozen envelope, save-open/replace failures, uncertain reconciliation, writer busy/reentrant callbacks, legacy migration và retention 127/128/129 đều giữ contract gốc.

[Regression](evidence/heavy_tradeoff_144f3df0463e_regression.json): **34 oracle invocations PASS**, runner exit 0:

- All VT-074: 31 invocations, gồm contract 41, integration forward/reverse 445 mỗi lượt và 8 cases độc lập, replay/order/group comparisons, boundary 27, TIME 20 iterations/340 assertions.
- Pairwise: **14/14 cases, 261 assertions PASS**, real GameManager/real writer, CSV không đổi.
- Mutation: 27 PASS →19 PASS/8 FAIL →27 PASS; mutant engine exit 1 được phát hiện đúng, restored hash đúng.
- Perk chạy lại 34/37, đúng ba **KNOWN BASELINE FAILURES**; không công bố whole-project regression PASS.

Không có correctness regression mới trong phạm vi kiểm chứng. Performance còn các tail/fallback khác biệt nhỏ được công khai ở mục 4. Pairwise/CI local files và mọi bước CI cũ không bị sửa trong review này; không thêm profiling/heavy/mutation vào CI mặc định. Smoke Windows từ review trước vẫn có provenance riêng; Linux/Actions cho patch chưa được chạy trong lượt này.

## 6. Những file trong 48 file cũ cần giữ

[Inventory đủ 48 paths và SHA-256](evidence/heavy_tradeoff_144f3df0463e_existing48_inventory.json) chia **35 file đề nghị giữ**, **13 file lịch sử audit không bắt buộc để tính lại kết quả mới**. Đây là phân loại để review commit, không phải đã xóa file, và 35 không được tuyên là tập dependency toán học nhỏ nhất của verifier.

| Nhóm từ 48 file hiện có | Số file | Vai trò |
| --- | ---: | --- |
| 6 code/test files, workflow, README, báo cáo trước | 9 | Rerun helpers, behavioral tests, CI và review context |
| `evidence/.gitignore` | 1 | Giữ snapshot ZIP có thể commit được |
| Prefix `heavy_1a3b68d5d730_` | 22 | Raw ABBA trước, patch, correctness/regression và summary |
| `vt074_final_942e400cf5a4_all.json`, `vt074_final_9f75c585fc5c_smoke.json` | 2 | Regression/smoke checkout gốc mới nhất |
| `vt074_resume_final_checks.json` | 1 | Integrity và inventory trước review này |
| 13 attempt/log/check files cũ còn lại | 13 | Provenance lịch sử; không cần để tính lại benchmark mới |

Trong 22 heavy files, input raw cho verifier cũ là **12 CSV/batch files +4 snapshot ZIPs +compare JSON +benchmark JSON =18 files**; patch/validate/regression/verification giữ review và audit. Code verifier cũ còn đọc source/test hashes của trạng thái đã ghi; khi production thay đổi sau này cần dùng đúng source đó. Verifier mới đọc ba source bytes từ artifact nên không phụ thuộc production đang được đề nghị sửa.

Các files thuộc nhóm 13 audit-only là: bốn `heavy_4992759f992a_*`; `heavy_ddd21c5696b8_compare.json`; bốn pairwise attempts `25f705a64d37`, `43b00db1e9d0`, `d76dba213bfa`, `e8bf00df8fd7`; all `315966019bc5`; smoke `0084cf203d62`; `vt074_final_pairwise.log`; `vt074_final_checks.json`. **Giữ nguyên cả 48 file để người dùng tự review; chưa xóa hoặc stage file nào.**

Evidence mới cần đi cùng review này gồm runner/profile/ownership tests, candidate/ownership/instrumentation patches, source artifact, scoped raw/summary, validation/regression JSON, sáu bộ CSV/batches/snapshot ZIPs, benchmark/verification, inventory và final checks. Cache/project copies dưới `.godot/` không phải file commit.

## 7. Tái kiểm và integrity

Tiếp tục phases trên project đã import:

```powershell
$Tradeoff = '.godot/vt074_heavy/1a3b68d5d730/tradeoff_144f3df0463e'
py tests/vt074/run_heavy_tradeoff.py --phase profile --godot $Godot
# Lệnh profile mới tạo review ID khác; dùng work path được in ra cho các phase sau.
py tests/vt074/run_heavy_tradeoff.py --phase validate --work $Tradeoff --godot $Godot
py tests/vt074/run_heavy_tradeoff.py --phase benchmark --work $Tradeoff --godot $Godot
py tests/vt074/run_heavy_tradeoff.py --phase regression --work $Tradeoff --godot $Godot
```

Đây là continuation runner, yêu cầu imported parent project và integrity manifest có sẵn; không phải yêu cầu chạy lại các phases vừa hoàn tất. Giữ source giữa các phase. Mỗi phase chỉ ghi evidence mới và restore original manager/store bytes trong `finally`. Không gọi entrypoints lịch sử có thể viết lại logs cũ. Benchmark raw filenames là write-once; dùng review ID mới khi muốn đo lại.

**Tính lại evidence mới không cần project/save tạm hoặc production gốc:**

```powershell
py tests/vt074/run_heavy_tradeoff.py --phase verify --run docs/BT3_VT074/evidence/heavy_tradeoff_144f3df0463e_benchmark.json
```

Verifier kiểm variant source SHA/one-line transform, giải nén ZIP an toàn vào temporary child dưới `.godot/`, kiểm lại mọi record và bytes snapshot rồi dọn đúng temporary child. Mặc định không ghi evidence; `--output <new.json>` từ chối ghi đè. Windows sandbox của môi trường này chặn certificate store/temp access, nên các lượt thực tế chạy qua approval ngoài sandbox, vẫn giữ child-only save và probe.

[Final checks](evidence/heavy_tradeoff_144f3df0463e_final_checks.json) xác nhận 48 file cũ và tất cả source/evidence có trước review không đổi, branch/HEAD/index không đổi, production và personal save không đổi, harness/store nguyên bản, whitespace và patch applicability PASS. Profile/benchmark/regression đều có probe và hashes riêng. Memory bytes/peak RAM chưa đo; chỉ xác nhận loại một allocation/copy theo code và timing, vẫn giữ một bounded cache payload.

## 8. Recommendation và acceptance policy

**KEEP CANDIDATE — giữ C1, bản đã được kiểm chứng bỏ một deep copy.** Không còn một cải tiến nhỏ chưa kiểm chứng cần thực hiện trong phạm vi review này.

Lý do: giữ correctness/receipt/fingerprint/persisted snapshot; đủ workload gốc; mọi measured batch và cả bốn workload đều đạt p95 ≤1.500 ms; heavy p95 giảm 86,40%/63,51%; chi phí cache copy được đo và loại an toàn. First-COMMITTED mean/max tốt hơn gốc trong phiên matched này, first service p95 còn tăng 7,637 ms lên 314,384 ms, max first end-to-end quan sát 330,491 ms. Các số đó là trade-off được đề nghị duyệt, không bị che bằng pooled workload p95.

**Không âm thầm đổi acceptance policy:** correctness và NFR workload gates đều PASS; gate hiểu theo nghĩa “không có bất kỳ tail/service regression nào” chưa PASS vì first p95 và một số fallback statistics vẫn tăng nhẹ. KEEP là đề nghị người dùng chấp thuận rõ trade-off quan sát được này, không phải tự coi zero-regression gate đã đạt hoặc tự nới target. Nếu người dùng giữ gate zero-regression tuyệt đối, cần từ chối/tiếp tục công việc bằng một chỉ dẫn mới.

**Chờ người dùng duyệt C1 và trade-off trước khi áp dụng production.** Production chưa sửa; không stage/commit/push/merge/PR. Dừng sau review này.
