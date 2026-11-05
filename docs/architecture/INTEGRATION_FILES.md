# Danh sách file tích hợp

Ngày 2026-11-05; branch `chore/project-structure-v2`; base `777d9d9fbcfffe61ea421071d3d891a3dd7bd788`.

Thêm **115**, sửa tại chỗ **7**, di chuyển **330**, xóa thuần túy **0**, giữ nguyên vị trí/nội dung **615**.

File di chuyển có thể đồng thời đổi tham chiếu. Không có file đích ban đầu bị mất. SHA-256 và quyết định từng file ở [manifest](integration_manifest.json); kết quả ở [báo cáo tích hợp](INTEGRATION_REPORT.md).

## Thêm

- `.dockerignore`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `CONTRIBUTING.md`
- `benchmarks/advanced/results/.gdignore`
- `benchmarks/advanced/results/seed_replay_2026-11-05T15-04-54_11684.csv`
- `benchmarks/advanced/results/seed_replay_2026-11-05T15-16-30_18068.csv`
- `benchmarks/advanced/results/seed_replay_2026-11-05T18-07-09_22084.csv`
- `benchmarks/advanced/results/seed_replay_2026-11-05T18-13-07_12112.csv`
- `benchmarks/benchmark_dungeon_generator.gd`
- `benchmarks/benchmark_dungeon_generator.gd.uid`
- `benchmarks/benchmark_dungeon_generator.tscn`
- `benchmarks/reports/.gdignore`
- `benchmarks/results/.gdignore`
- `benchmarks/results/basic_2026-11-05T18-14-20_204.csv`
- `docs/.gdignore`
- `docs/DEVELOPMENT_BACKLOG.md`
- `docs/DEVELOPMENT_ROADMAP.md`
- `docs/FEATURE_CHECKLIST.md`
- `docs/PROJECT_STATUS.md`
- `docs/README.md`
- `docs/architecture/DOCUMENTATION_AUDIT.md`
- `docs/architecture/FILES_CHANGED.md`
- `docs/architecture/INTEGRATION_FILES.md`
- `docs/architecture/INTEGRATION_REPORT.md`
- `docs/architecture/MASTER_AUDIT.md`
- `docs/architecture/PROJECT_STRUCTURE.md`
- `docs/architecture/RESTRUCTURE_REPORT.md`
- `docs/architecture/evidence/content_changes.diff`
- `docs/architecture/evidence/documentation_image_check.json`
- `docs/architecture/evidence/documentation_inventory_after.json`
- `docs/architecture/evidence/documentation_inventory_before.json`
- `docs/architecture/evidence/environment.json`
- `docs/architecture/evidence/inventory_after.txt`
- `docs/architecture/evidence/inventory_before.txt`
- `docs/architecture/evidence/master_audit.json`
- `docs/architecture/evidence/master_audit/documentation.json`
- `docs/architecture/evidence/master_audit/resources.json`
- `docs/architecture/evidence/preservation_check.json`
- `docs/architecture/evidence/progress_review_2026-11-05.json`
- `docs/architecture/evidence/resource_smoke.gd.txt`
- `docs/architecture/evidence/static_check.json`
- `docs/architecture/integration_manifest.json`
- `docs/architecture/integration_tests.json`
- `docs/architecture/refactor_manifest.json`
- `docs/qa/CHANGELOG.md`
- `docs/qa/README.md`
- `docs/qa/TEST_PLAN.md`
- `docs/qa/jira_url.txt`
- `docs/qa/test_cases.csv`
- `docs/qa/test_cases.xlsx`
- `run_tests.bat`
- `scripts/review/review_service.gd`
- `scripts/review/review_service.gd.uid`
- `tests/README.md`
- `tests/mock_player.gd`
- `tests/mock_player.gd.uid`
- `tests/test_doraemon.gd`
- `tests/test_doraemon.gd.uid`
- `tests/test_doraemon.tscn`
- `tests/test_dungeon_generator_unit.gd`
- `tests/test_dungeon_generator_unit.gd.uid`
- `tests/test_dungeon_generator_unit.tscn`
- `tests/test_dungeon_properties.gd`
- `tests/test_dungeon_properties.gd.uid`
- `tests/test_dungeon_properties.tscn`
- `tests/test_moba_hud_and_inventory.gd`
- `tests/test_moba_hud_and_inventory.gd.uid`
- `tests/test_moba_hud_and_inventory.tscn`
- `tests/test_new_mechanics.tscn`
- `tests/test_new_mechanics_node.gd`
- `tests/test_new_mechanics_node.gd.uid`
- `tests/test_orc_battle.gd`
- `tests/test_orc_battle.gd.uid`
- `tests/test_orc_battle.tscn`
- `tests/test_replay_security.gd`
- `tests/test_replay_security.gd.uid`
- `tests/test_replay_security.tscn`
- `tests/test_resource_loading.gd`
- `tests/test_resource_loading.gd.uid`
- `tests/test_reviewer_concurrency.gd`
- `tests/test_reviewer_concurrency.gd.uid`
- `tests/test_reviewer_concurrency.tscn`
- `tests/test_skeleton_king.gd`
- `tests/test_skeleton_king.gd.uid`
- `tests/test_skeleton_king.tscn`
- `tests/test_visual_backdrop.tscn`
- `tests/test_visual_backdrop_node.gd`
- `tests/test_visual_backdrop_node.gd.uid`
- `tests/test_werewolf.gd`
- `tests/test_werewolf.gd.uid`
- `tests/test_werewolf.tscn`
- `tests/test_yugi.gd`
- `tests/test_yugi.gd.uid`
- `tests/test_yugi.tscn`
- `tests/vt075/concurrency_harness.gd`
- `tests/vt075/concurrency_harness.gd.uid`
- `tests/vt075/cov_probe.gd`
- `tests/vt075/cov_probe.gd.uid`
- `tests/vt075/load_p95.gd`
- `tests/vt075/load_p95.gd.uid`
- `tests/vt075/load_p95.tscn`
- `tests/vt075/tools/coverage.py`
- `tests/vt075/tools/flaky_runs.py`
- `tests/vt075/tools/generate_report_pdf.py`
- `tests/vt075/tools/mutation_run.py`
- `tests/vt075/tools/plan_review_checks.ps1`
- `tests/vt075/tools/run_suite.ps1`
- `tests/vt075/tools/thread_probe.gd`
- `tests/vt075/tools/thread_probe.gd.uid`
- `tools/.gdignore`
- `tools/README.md`
- `tools/check_documentation.py`
- `tools/check_project_structure.py`
- `tools/godot_helpers.ps1`
- `tools/run_tests.ps1`

## Sửa tại chỗ

- `.agent/workflows/balance-unit.md`
- `.github/workflows/ci.yml`
- `.gitignore`
- `CHANGELOG.md`
- `README.md`
- `project.godot`
- `run_game.bat`

## Di chuyển

| Trước | Sau | Nội dung |
| --- | --- | --- |
| `benchmark/CHANGELOG.md` | `benchmarks/CHANGELOG.md` | giữ byte |
| `benchmark/README.md` | `benchmarks/README.md` | đổi tham chiếu/nội dung |
| `benchmark/advanced/analyze_stress.py` | `benchmarks/advanced/analyze_stress.py` | đổi tham chiếu/nội dung |
| `benchmark/advanced/gan_diem_do_tuong.py` | `benchmarks/advanced/gan_diem_do_tuong.py` | đổi tham chiếu/nội dung |
| `benchmark/advanced/kiem_tra_cau_truc_tilemap.gd` | `benchmarks/advanced/kiem_tra_cau_truc_tilemap.gd` | đổi tham chiếu/nội dung |
| `benchmark/advanced/kiem_tra_cau_truc_tilemap.gd.uid` | `benchmarks/advanced/kiem_tra_cau_truc_tilemap.gd.uid` | giữ byte |
| `benchmark/advanced/kiem_tra_seed_doc_lap.gd` | `benchmarks/advanced/kiem_tra_seed_doc_lap.gd` | đổi tham chiếu/nội dung |
| `benchmark/advanced/kiem_tra_seed_doc_lap.gd.uid` | `benchmarks/advanced/kiem_tra_seed_doc_lap.gd.uid` | giữ byte |
| `benchmark/advanced/phan_tich_giai_doan.py` | `benchmarks/advanced/phan_tich_giai_doan.py` | giữ byte |
| `benchmark/advanced/profile_giai_doan.gd` | `benchmarks/advanced/profile_giai_doan.gd` | đổi tham chiếu/nội dung |
| `benchmark/advanced/profile_giai_doan.gd.uid` | `benchmarks/advanced/profile_giai_doan.gd.uid` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.boss.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.boss.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.csv` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.csv` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.csv.import` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.csv.import` | đổi tham chiếu/nội dung |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.decor.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.decor.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.edge.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.edge.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.floor.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.floor.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.graph.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.graph.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.layer.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.layer.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.layout.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.layout.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.overlap.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.overlap.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.passed.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.passed.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.pillars.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.pillars.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.prepare.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.prepare.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.reproducible.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.reproducible.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.room.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.room.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.seed.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.seed.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.start.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.start.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.total.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.total.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.trap.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.trap.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.traps.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.traps.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.treasure.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.treasure.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.trial.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.trial.translation` | giữ byte |
| `benchmark/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.walls.translation` | `benchmarks/advanced/results/du_lieu_chua_day_du/profile_truoc_toi_uu_KHONG_DAY_DU.walls.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.collision.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.collision.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.csv` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.csv` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.csv.import` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.csv.import` | đổi tham chiếu/nội dung |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.edge.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.edge.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.floor.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.floor.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.graph.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.graph.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.hard.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.hard.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.layer.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.layer.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.overlap.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.overlap.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.physics.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.physics.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.room.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.room.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.seed.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.seed.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.trap.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.trap.translation` | giữ byte |
| `benchmark/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.trial.translation` | `benchmarks/advanced/results/kiem_tra_tilemap_2026-10-26T12-34-10.trial.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.boss.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.boss.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.csv` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.csv` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.csv.import` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.csv.import` | đổi tham chiếu/nội dung |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.decor.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.decor.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.edge.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.edge.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.floor.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.floor.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.graph.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.graph.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.layer.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.layer.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.layout.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.layout.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.overlap.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.overlap.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.passed.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.passed.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.pillars.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.pillars.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.prepare.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.prepare.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.reproducible.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.reproducible.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.room.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.room.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.seed.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.seed.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.start.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.start.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.total.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.total.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.trap.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.trap.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.traps.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.traps.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.treasure.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.treasure.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.trial.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.trial.translation` | giữ byte |
| `benchmark/advanced/results/profile_giai_doan_2026-10-27T20-35-22.walls.translation` | `benchmarks/advanced/results/profile_giai_doan_2026-10-27T20-35-22.walls.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.csv` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.csv` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.csv.import` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.csv.import` | đổi tham chiếu/nội dung |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.full.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.full.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.generator.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.generator.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.geometry.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.geometry.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.godot.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.godot.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.layer.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.layer.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.room.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.room.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.rooms.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.rooms.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.run.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.run.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.seed.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.seed.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.tilemap.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.tilemap.translation` | giữ byte |
| `benchmark/advanced/results/seed_replay_2026-10-27T20-28-57_20040.trial.translation` | `benchmarks/advanced/results/seed_replay_2026-10-27T20-28-57_20040.trial.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.boss.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.boss.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.csv` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.csv` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.csv.import` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.csv.import` | đổi tham chiếu/nội dung |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.decor.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.decor.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.edge.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.edge.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.floor.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.floor.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.graph.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.graph.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.layer.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.layer.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.layout.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.layout.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.overlap.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.overlap.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.passed.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.passed.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.pillars.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.pillars.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.prepare.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.prepare.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.reproducible.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.reproducible.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.room.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.room.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.seed.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.seed.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.start.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.start.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.total.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.total.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.trap.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.trap.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.traps.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.traps.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.treasure.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.treasure.translation` | giữ byte |
| `benchmark/advanced/results/stress_2026-10-25T20-23-39.trial.translation` | `benchmarks/advanced/results/stress_2026-10-25T20-23-39.trial.translation` | giữ byte |
| `benchmark/advanced/so_sanh_seed_doc_lap.py` | `benchmarks/advanced/so_sanh_seed_doc_lap.py` | đổi tham chiếu/nội dung |
| `benchmark/advanced/stress_benchmark.gd` | `benchmarks/advanced/stress_benchmark.gd` | đổi tham chiếu/nội dung |
| `benchmark/advanced/stress_benchmark.gd.uid` | `benchmarks/advanced/stress_benchmark.gd.uid` | giữ byte |
| `benchmark/benchmark.tscn` | `benchmarks/benchmark.tscn` | đổi tham chiếu/nội dung |
| `benchmark/dungeon_benchmark.gd` | `benchmarks/dungeon_benchmark.gd` | đổi tham chiếu/nội dung |
| `benchmark/dungeon_benchmark.gd.uid` | `benchmarks/dungeon_benchmark.gd.uid` | giữ byte |
| `benchmark/reports/BAO_CAO_TONG_KET_2026-10-27.md` | `benchmarks/reports/BAO_CAO_TONG_KET_2026-10-27.md` | đổi tham chiếu/nội dung |
| `docs/BENCHMARK_REPORT.md` | `benchmarks/reports/GENERATOR_PERFORMANCE_REPORT.md` | đổi tham chiếu/nội dung |
| `benchmark/reports/TONG_HOP_KET_QUA.cham.translation` | `benchmarks/reports/TONG_HOP_KET_QUA.cham.translation` | giữ byte |
| `benchmark/reports/TONG_HOP_KET_QUA.csv` | `benchmarks/reports/TONG_HOP_KET_QUA.csv` | giữ byte |
| `benchmark/reports/TONG_HOP_KET_QUA.csv.import` | `benchmarks/reports/TONG_HOP_KET_QUA.csv.import` | đổi tham chiếu/nội dung |
| `benchmark/reports/TONG_HOP_KET_QUA.ghi.translation` | `benchmarks/reports/TONG_HOP_KET_QUA.ghi.translation` | giữ byte |
| `benchmark/reports/TONG_HOP_KET_QUA.nhanh.translation` | `benchmarks/reports/TONG_HOP_KET_QUA.nhanh.translation` | giữ byte |
| `benchmark/reports/TONG_HOP_KET_QUA.p95.translation` | `benchmarks/reports/TONG_HOP_KET_QUA.p95.translation` | giữ byte |
| `benchmark/reports/TONG_HOP_KET_QUA.so.translation` | `benchmarks/reports/TONG_HOP_KET_QUA.so.translation` | giữ byte |
| `benchmark/reports/TONG_HOP_KET_QUA.trung.translation` | `benchmarks/reports/TONG_HOP_KET_QUA.trung.translation` | giữ byte |
| `benchmark/benchmark_report.txt` | `benchmarks/reports/benchmark_report.txt` | giữ byte |
| `benchmark/reports/images/01_benchmark_theo_so_phong.png` | `benchmarks/reports/images/01_benchmark_theo_so_phong.png` | giữ byte |
| `benchmark/reports/images/01_benchmark_theo_so_phong.png.import` | `benchmarks/reports/images/01_benchmark_theo_so_phong.png.import` | đổi tham chiếu/nội dung |
| `benchmark/reports/images/02_stress_1000_seed.png` | `benchmarks/reports/images/02_stress_1000_seed.png` | giữ byte |
| `benchmark/reports/images/02_stress_1000_seed.png.import` | `benchmarks/reports/images/02_stress_1000_seed.png.import` | đổi tham chiếu/nội dung |
| `benchmark/reports/images/03_truoc_sau_toi_uu.png` | `benchmarks/reports/images/03_truoc_sau_toi_uu.png` | giữ byte |
| `benchmark/reports/images/03_truoc_sau_toi_uu.png.import` | `benchmarks/reports/images/03_truoc_sau_toi_uu.png.import` | đổi tham chiếu/nội dung |
| `benchmark/results/benchmark_2026-10-25T18-01-50.boss.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.boss.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.csv` | `benchmarks/results/benchmark_2026-10-25T18-01-50.csv` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.csv.import` | `benchmarks/results/benchmark_2026-10-25T18-01-50.csv.import` | đổi tham chiếu/nội dung |
| `benchmark/results/benchmark_2026-10-25T18-01-50.decor.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.decor.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.edge.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.edge.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.graph.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.graph.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.layout.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.layout.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.passed.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.passed.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.pillars.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.pillars.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.prepare.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.prepare.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.reproducible.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.reproducible.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.room.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.room.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.seed.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.seed.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.total.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.total.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.trap.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.trap.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.traps.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.traps.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.treasure.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.treasure.translation` | giữ byte |
| `benchmark/results/benchmark_2026-10-25T18-01-50.trial.translation` | `benchmarks/results/benchmark_2026-10-25T18-01-50.trial.translation` | giữ byte |
| `benchmark/benchmark_log.txt` | `benchmarks/results/benchmark_log.txt` | giữ byte |
| `benchmark/results.csv` | `benchmarks/results/results.csv` | giữ byte |
| `benchmark/results.csv.import` | `benchmarks/results/results.csv.import` | đổi tham chiếu/nội dung |
| `benchmark/results.generation.translation` | `benchmarks/results/results.generation.translation` | giữ byte |
| `benchmark/results.layout.translation` | `benchmarks/results/results.layout.translation` | giữ byte |
| `benchmark/results.room.translation` | `benchmarks/results/results.room.translation` | giữ byte |
| `benchmark/results.seed.translation` | `benchmarks/results/results.seed.translation` | giữ byte |
| `benchmark/results.valid.translation` | `benchmarks/results/results.valid.translation` | giữ byte |
| `benchmark/scalability/analyze_benchmark.py` | `benchmarks/scalability/analyze_benchmark.py` | giữ byte |
| `benchmark/scalability/dungeon_benchmark.gd` | `benchmarks/scalability/dungeon_benchmark.gd` | đổi tham chiếu/nội dung |
| `benchmark/scalability/dungeon_benchmark.gd.uid` | `benchmarks/scalability/dungeon_benchmark.gd.uid` | giữ byte |
| `docs/SECURITY.md` | `docs/architecture/SECURITY.md` | giữ byte |
| `docs/BALANCE_WORKFLOW.md` | `docs/gameplay/BALANCE_WORKFLOW.md` | đổi tham chiếu/nội dung |
| `docs/DUNGEON_FOG_AND_BALANCE.md` | `docs/gameplay/DUNGEON_FOG_AND_BALANCE.md` | đổi tham chiếu/nội dung |
| `docs/GAME_DESIGN_DOCUMENT.md` | `docs/gameplay/GAME_DESIGN_DOCUMENT.md` | đổi tham chiếu/nội dung |
| `docs/SEED_BUG_ISSUES.md` | `docs/qa/SEED_BUG_ISSUES.md` | đổi tham chiếu/nội dung |
| `Scene/Character/Player 4_Charlotte/player_4.gd` | `scenes/characters/charlotte/player.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Player 4_Charlotte/player_4.gd.uid` | `scenes/characters/charlotte/player.gd.uid` | giữ byte |
| `Scene/Character/Player 4_Charlotte/player_4.tscn` | `scenes/characters/charlotte/player.tscn` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/DoraemonSprites.gd` | `scenes/characters/doraemon/DoraemonSprites.gd` | giữ byte |
| `Scene/Character/Doraemon/DoraemonSprites.gd.uid` | `scenes/characters/doraemon/DoraemonSprites.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/air_cannon_shot.gd` | `scenes/characters/doraemon/air_cannon_shot.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/air_cannon_shot.gd.uid` | `scenes/characters/doraemon/air_cannon_shot.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/door_ghost.gd` | `scenes/characters/doraemon/door_ghost.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/door_ghost.gd.uid` | `scenes/characters/doraemon/door_ghost.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/dora_fx.gd` | `scenes/characters/doraemon/dora_fx.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/dora_fx.gd.uid` | `scenes/characters/doraemon/dora_fx.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/dora_hud.gd` | `scenes/characters/doraemon/dora_hud.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/dora_hud.gd.uid` | `scenes/characters/doraemon/dora_hud.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/dora_projectile.gd` | `scenes/characters/doraemon/dora_projectile.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/dora_projectile.gd.uid` | `scenes/characters/doraemon/dora_projectile.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/dora_stun.gd` | `scenes/characters/doraemon/dora_stun.gd` | giữ byte |
| `Scene/Character/Doraemon/dora_stun.gd.uid` | `scenes/characters/doraemon/dora_stun.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/dora_util.gd` | `scenes/characters/doraemon/dora_util.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/dora_util.gd.uid` | `scenes/characters/doraemon/dora_util.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/dora_walker.gd` | `scenes/characters/doraemon/dora_walker.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/dora_walker.gd.uid` | `scenes/characters/doraemon/dora_walker.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/doraemon.gd` | `scenes/characters/doraemon/doraemon.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/doraemon.gd.uid` | `scenes/characters/doraemon/doraemon.gd.uid` | giữ byte |
| `Scene/Character/Doraemon/doraemon.tscn` | `scenes/characters/doraemon/doraemon.tscn` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/trex_summon.gd` | `scenes/characters/doraemon/trex_summon.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Doraemon/trex_summon.gd.uid` | `scenes/characters/doraemon/trex_summon.gd.uid` | giữ byte |
| `Scene/Character/InventoryManager.gd` | `scenes/characters/inventory_manager.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/InventoryManager.gd.uid` | `scenes/characters/inventory_manager.gd.uid` | giữ byte |
| `Scene/Character/Player 3_Miya/player_3.gd` | `scenes/characters/miya/player.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Player 3_Miya/player_3.gd.uid` | `scenes/characters/miya/player.gd.uid` | giữ byte |
| `Scene/Character/Player 3_Miya/player_3.tscn` | `scenes/characters/miya/player.tscn` | đổi tham chiếu/nội dung |
| `Scene/Character/Player 2_Olaf/player_2.gd` | `scenes/characters/olaf/player.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Player 2_Olaf/player_2.gd.uid` | `scenes/characters/olaf/player.gd.uid` | giữ byte |
| `Scene/Character/Player 2_Olaf/player_2.tscn` | `scenes/characters/olaf/player.tscn` | đổi tham chiếu/nội dung |
| `Scene/Character/Player 1_Pyrois/player.gd` | `scenes/characters/pyrois/player.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Player 1_Pyrois/player.gd.uid` | `scenes/characters/pyrois/player.gd.uid` | giữ byte |
| `Scene/Character/Player 1_Pyrois/player.tscn` | `scenes/characters/pyrois/player.tscn` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/README.md` | `scenes/characters/yugi/README.md` | giữ byte |
| `Scene/Character/Yugi/YugiSprites.gd` | `scenes/characters/yugi/YugiSprites.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/YugiSprites.gd.uid` | `scenes/characters/yugi/YugiSprites.gd.uid` | giữ byte |
| `Scene/Character/Yugi/energy_ball.gd` | `scenes/characters/yugi/energy_ball.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/energy_ball.gd.uid` | `scenes/characters/yugi/energy_ball.gd.uid` | giữ byte |
| `Scene/Character/Yugi/explosion_flash.gd` | `scenes/characters/yugi/explosion_flash.gd` | giữ byte |
| `Scene/Character/Yugi/explosion_flash.gd.uid` | `scenes/characters/yugi/explosion_flash.gd.uid` | giữ byte |
| `Scene/Character/Yugi/fire_beam.gd` | `scenes/characters/yugi/fire_beam.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/fire_beam.gd.uid` | `scenes/characters/yugi/fire_beam.gd.uid` | giữ byte |
| `Scene/Character/Yugi/key_green.gdshader` | `scenes/characters/yugi/key_green.gdshader` | giữ byte |
| `Scene/Character/Yugi/key_green.gdshader.uid` | `scenes/characters/yugi/key_green.gdshader.uid` | giữ byte |
| `Scene/Character/Yugi/lightning_hit.gd` | `scenes/characters/yugi/lightning_hit.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/lightning_hit.gd.uid` | `scenes/characters/yugi/lightning_hit.gd.uid` | giữ byte |
| `Scene/Character/Yugi/room_blast.gd` | `scenes/characters/yugi/room_blast.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/room_blast.gd.uid` | `scenes/characters/yugi/room_blast.gd.uid` | giữ byte |
| `Scene/Character/Yugi/room_fire.gd` | `scenes/characters/yugi/room_fire.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/room_fire.gd.uid` | `scenes/characters/yugi/room_fire.gd.uid` | giữ byte |
| `Scene/Character/Yugi/room_laser.gd` | `scenes/characters/yugi/room_laser.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/room_laser.gd.uid` | `scenes/characters/yugi/room_laser.gd.uid` | giữ byte |
| `Scene/Character/Yugi/room_lightning.gd` | `scenes/characters/yugi/room_lightning.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/room_lightning.gd.uid` | `scenes/characters/yugi/room_lightning.gd.uid` | giữ byte |
| `Scene/Character/Yugi/room_pull.gd` | `scenes/characters/yugi/room_pull.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/room_pull.gd.uid` | `scenes/characters/yugi/room_pull.gd.uid` | giữ byte |
| `Scene/Character/Yugi/summon.gd` | `scenes/characters/yugi/summon.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/summon.gd.uid` | `scenes/characters/yugi/summon.gd.uid` | giữ byte |
| `Scene/Character/Yugi/target_ring.gd` | `scenes/characters/yugi/target_ring.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/target_ring.gd.uid` | `scenes/characters/yugi/target_ring.gd.uid` | giữ byte |
| `Scene/Character/Yugi/yugi.gd` | `scenes/characters/yugi/yugi.gd` | đổi tham chiếu/nội dung |
| `Scene/Character/Yugi/yugi.gd.uid` | `scenes/characters/yugi/yugi.gd.uid` | giữ byte |
| `Scene/Character/Yugi/yugi.tscn` | `scenes/characters/yugi/yugi.tscn` | đổi tham chiếu/nội dung |
| `Scene/Map/dungeon_atmosphere.gd` | `scenes/dungeon/dungeon_atmosphere.gd` | đổi tham chiếu/nội dung |
| `Scene/Map/dungeon_atmosphere.gd.uid` | `scenes/dungeon/dungeon_atmosphere.gd.uid` | giữ byte |
| `Scene/Map/dungeon_generator.gd` | `scenes/dungeon/dungeon_generator.gd` | đổi tham chiếu/nội dung |
| `Scene/Map/dungeon_generator.gd.uid` | `scenes/dungeon/dungeon_generator.gd.uid` | giữ byte |
| `Scene/Map/portal.gd` | `scenes/dungeon/portal.gd` | giữ byte |
| `Scene/Map/portal.gd.uid` | `scenes/dungeon/portal.gd.uid` | giữ byte |
| `Scene/Map/portal.tscn` | `scenes/dungeon/portal.tscn` | đổi tham chiếu/nội dung |
| `Scene/Map/room_manager.gd` | `scenes/dungeon/room_manager.gd` | giữ byte |
| `Scene/Map/room_manager.gd.uid` | `scenes/dungeon/room_manager.gd.uid` | giữ byte |
| `Scene/Map/RoomManager.tscn` | `scenes/dungeon/room_manager.tscn` | đổi tham chiếu/nội dung |
| `Scene/Map/spike_trap.gd` | `scenes/dungeon/spike_trap.gd` | giữ byte |
| `Scene/Map/spike_trap.gd.uid` | `scenes/dungeon/spike_trap.gd.uid` | giữ byte |
| `Scene/Map/SpikeTrap.tscn` | `scenes/dungeon/spike_trap.tscn` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Armored_orc/armored_orc.gd` | `scenes/enemies/armored_orc/armored_orc.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Armored_orc/armored_orc.gd.uid` | `scenes/enemies/armored_orc/armored_orc.gd.uid` | giữ byte |
| `Scene/Enemies/Armored_orc/armored_orc.tscn` | `scenes/enemies/armored_orc/armored_orc.tscn` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Boss/Necromancer/necromancer.gd` | `scenes/enemies/bosses/necromancer/necromancer.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Boss/Necromancer/necromancer.gd.uid` | `scenes/enemies/bosses/necromancer/necromancer.gd.uid` | giữ byte |
| `Scene/Enemies/Boss/Necromancer/necromancer.tscn` | `scenes/enemies/bosses/necromancer/necromancer.tscn` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Boss/Orc Rider/orc_rider.gd` | `scenes/enemies/bosses/orc_rider/orc_rider.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Boss/Orc Rider/orc_rider.gd.uid` | `scenes/enemies/bosses/orc_rider/orc_rider.gd.uid` | giữ byte |
| `Scene/Enemies/Boss/Orc Rider/orc_rider.tscn` | `scenes/enemies/bosses/orc_rider/orc_rider.tscn` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Boss/Skeleton King/skeleton_king.gd` | `scenes/enemies/bosses/skeleton_king/skeleton_king.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Boss/Skeleton King/skeleton_king.gd.uid` | `scenes/enemies/bosses/skeleton_king/skeleton_king.gd.uid` | giữ byte |
| `Scene/Enemies/Boss/Skeleton King/skeleton_king_crystal.gd` | `scenes/enemies/bosses/skeleton_king/skeleton_king_crystal.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Boss/Skeleton King/skeleton_king_crystal.gd.uid` | `scenes/enemies/bosses/skeleton_king/skeleton_king_crystal.gd.uid` | giữ byte |
| `Scene/Enemies/Boss/Skeleton King/skeleton_king_laser.gd` | `scenes/enemies/bosses/skeleton_king/skeleton_king_laser.gd` | giữ byte |
| `Scene/Enemies/Boss/Skeleton King/skeleton_king_laser.gd.uid` | `scenes/enemies/bosses/skeleton_king/skeleton_king_laser.gd.uid` | giữ byte |
| `Scene/Enemies/Orc/orc.gd` | `scenes/enemies/orc/orc.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Orc/orc.gd.uid` | `scenes/enemies/orc/orc.gd.uid` | giữ byte |
| `Scene/Enemies/Orc/orc.tscn` | `scenes/enemies/orc/orc.tscn` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Skeleton/skeleton.gd` | `scenes/enemies/skeleton/skeleton.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Skeleton/skeleton.gd.uid` | `scenes/enemies/skeleton/skeleton.gd.uid` | giữ byte |
| `Scene/Enemies/Skeleton/skeleton.tscn` | `scenes/enemies/skeleton/skeleton.tscn` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Skeleton Archer/skeleton_archer.gd` | `scenes/enemies/skeleton_archer/skeleton_archer.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Skeleton Archer/skeleton_archer.gd.uid` | `scenes/enemies/skeleton_archer/skeleton_archer.gd.uid` | giữ byte |
| `Scene/Enemies/Skeleton Archer/skeleton_archer.tscn` | `scenes/enemies/skeleton_archer/skeleton_archer.tscn` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Vampire/vampire.gd` | `scenes/enemies/vampire/vampire.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Vampire/vampire.gd.uid` | `scenes/enemies/vampire/vampire.gd.uid` | giữ byte |
| `Scene/Enemies/Vampire/vampire.tscn` | `scenes/enemies/vampire/vampire.tscn` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Werewolf/werewolf.gd` | `scenes/enemies/werewolf/werewolf.gd` | đổi tham chiếu/nội dung |
| `Scene/Enemies/Werewolf/werewolf.gd.uid` | `scenes/enemies/werewolf/werewolf.gd.uid` | giữ byte |
| `Scene/Enemies/Werewolf/werewolf.tscn` | `scenes/enemies/werewolf/werewolf.tscn` | đổi tham chiếu/nội dung |
| `Scene/Items/big_health_potion.tres` | `scenes/items/big_health_potion.tres` | đổi tham chiếu/nội dung |
| `Scene/Items/Chest/chest.gd` | `scenes/items/chest/chest.gd` | giữ byte |
| `Scene/Items/Chest/chest.gd.uid` | `scenes/items/chest/chest.gd.uid` | giữ byte |
| `Scene/Items/Chest/chest.tscn` | `scenes/items/chest/chest.tscn` | đổi tham chiếu/nội dung |
| `Scene/Items/health_potion.tres` | `scenes/items/health_potion.tres` | đổi tham chiếu/nội dung |
| `Scene/Items/iron_armor.tres` | `scenes/items/iron_armor.tres` | đổi tham chiếu/nội dung |
| `Scene/Items/iron_helmet.tres` | `scenes/items/iron_helmet.tres` | đổi tham chiếu/nội dung |
| `Scene/Items/iron_sword.tres` | `scenes/items/iron_sword.tres` | đổi tham chiếu/nội dung |
| `Scene/Items/ItemData.gd` | `scenes/items/item_data.gd` | giữ byte |
| `Scene/Items/ItemData.gd.uid` | `scenes/items/item_data.gd.uid` | giữ byte |
| `Scene/Items/mystic_armor.tres` | `scenes/items/mystic_armor.tres` | đổi tham chiếu/nội dung |
| `Scene/Items/mystic_sword.tres` | `scenes/items/mystic_sword.tres` | đổi tham chiếu/nội dung |
| `Scene/Items/WorldItem/WorldItem.gd` | `scenes/items/world_item/world_item.gd` | giữ byte |
| `Scene/Items/WorldItem/WorldItem.gd.uid` | `scenes/items/world_item/world_item.gd.uid` | giữ byte |
| `Scene/Items/WorldItem/WorldItem.tscn` | `scenes/items/world_item/world_item.tscn` | đổi tham chiếu/nội dung |
| `world.tscn` | `scenes/main/world.tscn` | đổi tham chiếu/nội dung |
| `Menu/game over menu/game_over_menu.gd` | `scenes/menus/game_over_menu/game_over_menu.gd` | đổi tham chiếu/nội dung |
| `Menu/game over menu/game_over_menu.gd.uid` | `scenes/menus/game_over_menu/game_over_menu.gd.uid` | giữ byte |
| `Menu/game over menu/game_over_menu.tscn` | `scenes/menus/game_over_menu/game_over_menu.tscn` | đổi tham chiếu/nội dung |
| `Menu/main menu/main_menu.gd` | `scenes/menus/main_menu/main_menu.gd` | đổi tham chiếu/nội dung |
| `Menu/main menu/main_menu.gd.uid` | `scenes/menus/main_menu/main_menu.gd.uid` | giữ byte |
| `Menu/main menu/main_menu.tscn` | `scenes/menus/main_menu/main_menu.tscn` | đổi tham chiếu/nội dung |
| `Menu/pause menu/pause_menu.gd` | `scenes/menus/pause_menu/pause_menu.gd` | đổi tham chiếu/nội dung |
| `Menu/pause menu/pause_menu.gd.uid` | `scenes/menus/pause_menu/pause_menu.gd.uid` | giữ byte |
| `Menu/pause menu/pause_menu.tscn` | `scenes/menus/pause_menu/pause_menu.tscn` | đổi tham chiếu/nội dung |
| `Scene/Projectiles/arrow.gd` | `scenes/projectiles/arrow.gd` | giữ byte |
| `Scene/Projectiles/arrow.gd.uid` | `scenes/projectiles/arrow.gd.uid` | giữ byte |
| `Scene/Projectiles/arrow.tscn` | `scenes/projectiles/arrow.tscn` | đổi tham chiếu/nội dung |
| `Scene/Projectiles/bomb.gd` | `scenes/projectiles/bomb.gd` | giữ byte |
| `Scene/Projectiles/bomb.gd.uid` | `scenes/projectiles/bomb.gd.uid` | giữ byte |
| `Scene/Projectiles/bomb.tscn` | `scenes/projectiles/bomb.tscn` | đổi tham chiếu/nội dung |
| `Scene/Projectiles/enemy_arrow.gd` | `scenes/projectiles/enemy_arrow.gd` | giữ byte |
| `Scene/Projectiles/enemy_arrow.gd.uid` | `scenes/projectiles/enemy_arrow.gd.uid` | giữ byte |
| `Scene/Projectiles/enemy_arrow.tscn` | `scenes/projectiles/enemy_arrow.tscn` | đổi tham chiếu/nội dung |
| `Scene/Projectiles/magic_spell.gd` | `scenes/projectiles/magic_spell.gd` | giữ byte |
| `Scene/Projectiles/magic_spell.gd.uid` | `scenes/projectiles/magic_spell.gd.uid` | giữ byte |
| `Scene/Projectiles/magic_spell.tscn` | `scenes/projectiles/magic_spell.tscn` | đổi tham chiếu/nội dung |
| `Scene/Projectiles/poison_explosion.gd` | `scenes/projectiles/poison_explosion.gd` | giữ byte |
| `Scene/Projectiles/poison_explosion.gd.uid` | `scenes/projectiles/poison_explosion.gd.uid` | giữ byte |
| `Scene/Projectiles/poison_explosion.tscn` | `scenes/projectiles/poison_explosion.tscn` | đổi tham chiếu/nội dung |
| `Scene/UI/character_select.gd` | `scenes/ui/character_select.gd` | đổi tham chiếu/nội dung |
| `Scene/UI/character_select.gd.uid` | `scenes/ui/character_select.gd.uid` | giữ byte |
| `Scene/UI/CharacterSelect.tscn` | `scenes/ui/character_select.tscn` | đổi tham chiếu/nội dung |
| `Scene/UI/GameUI.gd` | `scenes/ui/game_ui.gd` | đổi tham chiếu/nội dung |
| `Scene/UI/GameUI.gd.uid` | `scenes/ui/game_ui.gd.uid` | giữ byte |
| `Scene/UI/GameUI.tscn` | `scenes/ui/game_ui.tscn` | đổi tham chiếu/nội dung |
| `Scene/UI/InventorySlot.gd` | `scenes/ui/inventory_slot.gd` | giữ byte |
| `Scene/UI/InventorySlot.gd.uid` | `scenes/ui/inventory_slot.gd.uid` | giữ byte |
| `Scene/UI/InventorySlot.tscn` | `scenes/ui/inventory_slot.tscn` | đổi tham chiếu/nội dung |
| `Scene/UI/UITheme.gd` | `scenes/ui/ui_theme.gd` | giữ byte |
| `Scene/UI/UITheme.gd.uid` | `scenes/ui/ui_theme.gd.uid` | giữ byte |
| `Scene/AudioManager.gd` | `scripts/core/audio_manager.gd` | giữ byte |
| `Scene/AudioManager.gd.uid` | `scripts/core/audio_manager.gd.uid` | giữ byte |
| `Scene/BalanceConfig.gd` | `scripts/core/balance_config.gd` | giữ byte |
| `Scene/BalanceConfig.gd.uid` | `scripts/core/balance_config.gd.uid` | giữ byte |
| `Scene/GameManager.gd` | `scripts/core/game_manager.gd` | đổi tham chiếu/nội dung |
| `Scene/GameManager.gd.uid` | `scripts/core/game_manager.gd.uid` | giữ byte |

## Xóa

Không xóa thuần túy file nào của repository. Những old path không còn là các file đã di chuyển trong bảng trên.

## Không nhập từ nguồn

- `.git`, `.godot`, cache, log, file tạm và output instrument/mutant.
- Bộ Docker đang chờ quyết định: `Dockerfile`, `docker-compose.yml`, `nginx.conf`.
