| Mutant | Loai | Mo ta | Ket qua | Test phat hien |
|---|---|---|---|---|
| M1 | validation | update_note: bo kiem tra role (reviewer sua duoc du lieu goc) | KILLED | TC-03, TC-05, TC-15 |
| M2 | validation | approve: bo kiem tra revision (STALE_REVISION) | KILLED | TC-09, TC-14, TC-15 |
| M3 | validation | approve: bo kiem tra ALREADY_APPROVED | KILLED | TC-11, TC-13, TC-13b, TC-14, TC-16b |
| M4 | validation | get_record: bo deny-by-default cho role la | KILLED | TC-05 |
| M5 | validation | approve: bo validate reviewer_id | KILLED | TC-08 |
| M6 | validation | approve: bo kiem tra expected_revision >= 1 | KILLED | TC-08 |
| M7 | invariant | update_note: khong thu hoi approval khi sua | KILLED | TC-10, TC-14, TC-15 |
| M8 | concurrency | approve: bo Mutex quanh chuoi check-then-act | KILLED | TC-13, TC-13b, TC-14, TC-15, TC-16b |
| M9 | validation | update_note: bo sanitize_note (ghi chu khong duoc lam sach) | SURVIVED | - |
| M10 | validation | add_record: bo gioi han MAX_RECORDS | SURVIVED | - |
| M11 | validation | _valid_id luon tra true (bo validate id) | KILLED | TC-08 |
| M12 | isolation | get_record: tra tham chieu noi bo thay vi ban sao | KILLED | TC-02 |
| M13 | validation | add_record: bo kiem tra DUPLICATE | KILLED | TC-17 |
| M14 | validation | approve: bo kiem tra role reviewer (player duyet duoc) | KILLED | TC-05, TC-07 |
| M15 | failure-path | approve: bo qua ket qua luu that bai | KILLED | TC-16a, TC-16b |
| M16 | validation | add_record: bo kiem tra seed rong sau khi lam sach | KILLED | TC-08, TC-12 |
| M17 | validation | remove_record: bo kiem tra role (reviewer xoa duoc) | KILLED | TC-04, TC-05 |
| M18 | validation | add_record: bo kiem tra role (reviewer them duoc) | KILLED | TC-04, TC-05 |

Mutation score: 16/18 (89%)
