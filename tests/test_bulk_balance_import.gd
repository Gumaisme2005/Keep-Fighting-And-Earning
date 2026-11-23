extends Node

const IMPORTER_PATH := "res://Scene/Balance/BulkBalanceImporter.gd"
const BalanceConfig = preload("res://Scene/BalanceConfig.gd")

var passed_count: int = 0
var failed_count: int = 0


func _ready() -> void:
    print("")
    print("============================================================")
    print("[VT-076] BULK BALANCE IMPORT - RISK-BASED TEST SUITE")
    print("============================================================")

    var importer_script: Script = load(IMPORTER_PATH) as Script

    _assert_true(
        importer_script != null,
        "VT076-T01: BulkBalanceImporter implementation exists"
    )

    if importer_script == null:
        _finish()
        return

    var old_miya_hp: int = int(
        BalanceConfig.get_hero_stats("miya").get("hp", 0)
    )
    var old_orc_hp: int = int(
        BalanceConfig.get_enemy_stats("orc").get("hp", 0)
    )

    # ---------------------------------------------------------
    # T02 - Initial state
    # ---------------------------------------------------------
    var importer: Variant = importer_script.new()

    _assert_true(
        str(importer.get_state()) == "IDLE",
        "VT076-T02: Initial importer state is IDLE"
    )

    # ---------------------------------------------------------
    # T03-T07 - Mixed batch / partial success / state transition
    # ---------------------------------------------------------
    var mixed_batch: Array = [
        {
            "category": "hero",
            "unit_id": "miya",
            "stats": {"hp": old_miya_hp + 1}
        },
        {
            "category": "enemy",
            "unit_id": "does_not_exist",
            "stats": {"hp": 999}
        },
        {
            "category": "enemy",
            "unit_id": "orc",
            "stats": {"hp": old_orc_hp + 1}
        }
    ]

    var mixed_result: Dictionary = importer.import_batch(mixed_batch)

    _assert_true(
        int(mixed_result.get("accepted_count", -1)) == 2
        and int(mixed_result.get("rejected_count", -1)) == 1,
        "VT076-T03: Mixed batch accepts 2 valid records and rejects 1 invalid record"
    )

    _assert_true(
        int(BalanceConfig.get_hero_stats("miya").get("hp", -1))
        == old_miya_hp + 1,
        "VT076-T04: Valid record before invalid record is preserved"
    )

    _assert_true(
        int(BalanceConfig.get_enemy_stats("orc").get("hp", -1))
        == old_orc_hp + 1,
        "VT076-T05: Valid record after invalid record is still applied"
    )

    _assert_true(
        str(importer.get_state()) == "COMPLETED_WITH_ERRORS",
        "VT076-T06: Mixed batch ends in COMPLETED_WITH_ERRORS"
    )

    var expected_mixed_transitions: Array = [
        "IDLE",
        "VALIDATING",
        "APPLYING",
        "VALIDATING",
        "PARTIAL_FAILURE",
        "VALIDATING",
        "APPLYING",
        "COMPLETED_WITH_ERRORS"
    ]

    _assert_true(
        mixed_result.get("transitions", []) == expected_mixed_transitions,
        "VT076-T07: Mixed batch follows exact partial-failure state transitions"
    )

    # Restore after mixed-batch mutation.
    BalanceConfig.set_unit_stat("hero", "miya", "hp", old_miya_hp)
    BalanceConfig.set_unit_stat("enemy", "orc", "hp", old_orc_hp)

    # ---------------------------------------------------------
    # T08-T09 - All-valid success path
    # ---------------------------------------------------------
    importer = importer_script.new()

    var valid_batch: Array = [
        {
            "category": "hero",
            "unit_id": "miya",
            "stats": {"hp": old_miya_hp + 2}
        },
        {
            "category": "enemy",
            "unit_id": "orc",
            "stats": {"hp": old_orc_hp + 2}
        }
    ]

    var valid_result: Dictionary = importer.import_batch(valid_batch)

    _assert_true(
        int(valid_result.get("accepted_count", -1)) == 2
        and int(valid_result.get("rejected_count", -1)) == 0
        and str(importer.get_state()) == "COMPLETED",
        "VT076-T08: All-valid batch completes successfully with no rejection"
    )

    var expected_success_transitions: Array = [
        "IDLE",
        "VALIDATING",
        "APPLYING",
        "VALIDATING",
        "APPLYING",
        "COMPLETED"
    ]

    _assert_true(
        valid_result.get("transitions", []) == expected_success_transitions,
        "VT076-T09: All-valid batch follows exact success state transitions"
    )

    BalanceConfig.set_unit_stat("hero", "miya", "hp", old_miya_hp)
    BalanceConfig.set_unit_stat("enemy", "orc", "hp", old_orc_hp)

    # ---------------------------------------------------------
    # T10 - Negative HP
    # ---------------------------------------------------------
    importer = importer_script.new()

    var negative_hp_result: Dictionary = importer.import_batch([
        {
            "category": "enemy",
            "unit_id": "orc",
            "stats": {"hp": 0}
        }
    ])

    _assert_true(
        int(negative_hp_result.get("accepted_count", -1)) == 0
        and int(negative_hp_result.get("rejected_count", -1)) == 1
        and int(BalanceConfig.get_enemy_stats("orc").get("hp", -1))
        == old_orc_hp,
        "VT076-T10: Invalid HP is rejected without changing existing balance"
    )

    # ---------------------------------------------------------
    # T11 - Unsupported category
    # ---------------------------------------------------------
    importer = importer_script.new()

    var bad_category_result: Dictionary = importer.import_batch([
        {
            "category": "npc",
            "unit_id": "orc",
            "stats": {"hp": 99}
        }
    ])

    _assert_true(
        int(bad_category_result.get("rejected_count", -1)) == 1,
        "VT076-T11: Unsupported category is rejected"
    )

    # ---------------------------------------------------------
    # T12 - Empty stats
    # ---------------------------------------------------------
    importer = importer_script.new()

    var empty_stats_result: Dictionary = importer.import_batch([
        {
            "category": "enemy",
            "unit_id": "orc",
            "stats": {}
        }
    ])

    _assert_true(
        int(empty_stats_result.get("rejected_count", -1)) == 1,
        "VT076-T12: Empty stats dictionary is rejected"
    )

    # ---------------------------------------------------------
    # T13 - Non-Dictionary record
    # ---------------------------------------------------------
    importer = importer_script.new()

    var malformed_result: Dictionary = importer.import_batch([
        "not-a-dictionary"
    ])

    _assert_true(
        int(malformed_result.get("rejected_count", -1)) == 1
        and str(importer.get_state()) == "COMPLETED_WITH_ERRORS",
        "VT076-T13: Non-Dictionary record follows failure path safely"
    )

    # ---------------------------------------------------------
    # T14 - Unknown unit
    # ---------------------------------------------------------
    importer = importer_script.new()

    var unknown_unit_result: Dictionary = importer.import_batch([
        {
            "category": "hero",
            "unit_id": "missing_hero",
            "stats": {"hp": 10}
        }
    ])

    _assert_true(
        int(unknown_unit_result.get("rejected_count", -1)) == 1,
        "VT076-T14: Unknown unit_id is rejected"
    )

    # ---------------------------------------------------------
    # T15 - Multiple bad records must not block a valid record
    # ---------------------------------------------------------
    importer = importer_script.new()

    var multi_failure_result: Dictionary = importer.import_batch([
        {
            "category": "enemy",
            "unit_id": "orc",
            "stats": {"hp": -5}
        },
        {
            "category": "enemy",
            "unit_id": "orc",
            "stats": {"hp": old_orc_hp + 3}
        },
        {
            "category": "invalid_category",
            "unit_id": "orc",
            "stats": {"hp": 100}
        }
    ])

    _assert_true(
        int(multi_failure_result.get("accepted_count", -1)) == 1
        and int(multi_failure_result.get("rejected_count", -1)) == 2
        and int(BalanceConfig.get_enemy_stats("orc").get("hp", -1))
        == old_orc_hp + 3,
        "VT076-T15: Multiple faulty records do not discard the valid record between them"
    )

    BalanceConfig.set_unit_stat("enemy", "orc", "hp", old_orc_hp)

    # ---------------------------------------------------------
    # T16 - Empty batch edge case
    # ---------------------------------------------------------
    importer = importer_script.new()

    var empty_batch_result: Dictionary = importer.import_batch([])

    _assert_true(
        int(empty_batch_result.get("accepted_count", -1)) == 0
        and int(empty_batch_result.get("rejected_count", -1)) == 0
        and str(importer.get_state()) == "COMPLETED"
        and empty_batch_result.get("transitions", [])
        == ["IDLE", "COMPLETED"],
        "VT076-T16: Empty batch completes safely with zero processed records"
    )

    # ---------------------------------------------------------
    # T17 - Shared-state cleanup
    # ---------------------------------------------------------
    BalanceConfig.set_unit_stat("hero", "miya", "hp", old_miya_hp)
    BalanceConfig.set_unit_stat("enemy", "orc", "hp", old_orc_hp)

    _assert_true(
        int(BalanceConfig.get_hero_stats("miya").get("hp", -1))
        == old_miya_hp
        and int(BalanceConfig.get_enemy_stats("orc").get("hp", -1))
        == old_orc_hp,
        "VT076-T17: Test suite restores shared BalanceConfig state"
    )

    _finish()


func _assert_true(condition: bool, test_name: String) -> void:
    if condition:
        passed_count += 1
        print("  [PASS] " + test_name)
    else:
        failed_count += 1
        print("  [FAIL] " + test_name)


func _finish() -> void:
    print("------------------------------------------------------------")
    print(
        "[SUMMARY] VT-076: %d PASSED | %d FAILED"
        % [passed_count, failed_count]
    )
    print("============================================================")

    if failed_count > 0:
        get_tree().quit(1)
    else:
        get_tree().quit(0)