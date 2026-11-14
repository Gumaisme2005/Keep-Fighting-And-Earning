extends Node

const IMPORTER_PATH := "res://Scene/Balance/BulkBalanceImporter.gd"
const BalanceConfig = preload("res://Scene/BalanceConfig.gd")

var passed_count: int = 0
var failed_count: int = 0


func _ready() -> void:
    print("")
    print("============================================================")
    print("[VT-076] BULK BALANCE IMPORT - TEST FIRST")
    print("============================================================")

    var importer_script = load(IMPORTER_PATH)

    _assert_true(
        importer_script != null,
        "VT076-T01: BulkBalanceImporter implementation exists"
    )

    if importer_script == null:
        _finish()
        return

    var importer = importer_script.new()

    _assert_true(
        str(importer.get_state()) == "IDLE",
        "VT076-T02: Initial importer state is IDLE"
    )

    var old_miya_hp: int = int(BalanceConfig.get_hero_stats("miya").get("hp", 0))
    var old_orc_hp: int = int(BalanceConfig.get_enemy_stats("orc").get("hp", 0))

    var batch: Array = [
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

    var result: Dictionary = importer.import_batch(batch)

    _assert_true(
        int(result.get("accepted_count", -1)) == 2,
        "VT076-T03: Two valid records are accepted"
    )

    _assert_true(
        int(result.get("rejected_count", -1)) == 1,
        "VT076-T04: Invalid record is rejected independently"
    )

    _assert_true(
        int(BalanceConfig.get_hero_stats("miya").get("hp", -1)) == old_miya_hp + 1,
        "VT076-T05: Valid record before invalid record is preserved"
    )

    _assert_true(
        int(BalanceConfig.get_enemy_stats("orc").get("hp", -1)) == old_orc_hp + 1,
        "VT076-T06: Valid record after invalid record is still applied"
    )

    _assert_true(
        str(importer.get_state()) == "COMPLETED_WITH_ERRORS",
        "VT076-T07: Mixed batch ends in COMPLETED_WITH_ERRORS"
    )

    var transitions: Array = result.get("transitions", [])
    _assert_true(
        transitions.has("PARTIAL_FAILURE"),
        "VT076-T08: State-transition path records PARTIAL_FAILURE"
    )

    # Restore shared/static balance state so this test does not contaminate
    # later regression suites.
    BalanceConfig.set_unit_stat("hero", "miya", "hp", old_miya_hp)
    BalanceConfig.set_unit_stat("enemy", "orc", "hp", old_orc_hp)

    _assert_true(
        int(BalanceConfig.get_hero_stats("miya").get("hp", -1)) == old_miya_hp
        and int(BalanceConfig.get_enemy_stats("orc").get("hp", -1)) == old_orc_hp,
        "VT076-T09: Test cleanup restores shared BalanceConfig state"
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
    print("[SUMMARY] VT-076: %d PASSED | %d FAILED" % [passed_count, failed_count])
    print("============================================================")

    if failed_count > 0:
        get_tree().quit(1)
    else:
        get_tree().quit(0)
