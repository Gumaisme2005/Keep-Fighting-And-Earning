class_name BulkBalanceImporter
extends RefCounted

const BalanceConfig = preload("res://Scene/BalanceConfig.gd")

const VALID_CATEGORIES: Array[String] = ["hero", "enemy", "boss"]

var _state: String = "IDLE"
var _transitions: Array[String] = ["IDLE"]


func get_state() -> String:
    return _state


func import_batch(records: Array) -> Dictionary:
    _state = "IDLE"
    _transitions = ["IDLE"]

    var accepted_count: int = 0
    var rejected_count: int = 0
    var rejected_records: Array = []

    for index in range(records.size()):
        _transition("VALIDATING")

        var validation: Dictionary = _validate_record(records[index])

        # Business rule for VT-076:
        # Only a valid record may be applied. An invalid record is rejected
        # independently and must not stop other valid records in the batch.
        if bool(validation.get("valid", false)):
            _transition("APPLYING")

            if _apply_record(records[index]):
                accepted_count += 1
            else:
                rejected_count += 1
                _transition("PARTIAL_FAILURE")
                rejected_records.append({
                    "index": index,
                    "errors": ["BalanceConfig rejected the update"]
                })
        else:
            rejected_count += 1
            _transition("PARTIAL_FAILURE")
            rejected_records.append({
                "index": index,
                "errors": validation.get("errors", [])
            })

    if rejected_count > 0:
        _transition("COMPLETED_WITH_ERRORS")
    else:
        _transition("COMPLETED")

    return {
        "accepted_count": accepted_count,
        "rejected_count": rejected_count,
        "rejected_records": rejected_records,
        "transitions": _transitions.duplicate()
    }


func _validate_record(record: Variant) -> Dictionary:
    var errors: Array[String] = []

    if not (record is Dictionary):
        return {
            "valid": false,
            "errors": ["Record must be a Dictionary"]
        }

    var category: String = str(record.get("category", "")).strip_edges().to_lower()
    var unit_id: String = str(record.get("unit_id", "")).strip_edges().to_lower()
    var stats_value: Variant = record.get("stats", null)

    if category not in VALID_CATEGORIES:
        errors.append("Unsupported category")

    if unit_id.is_empty():
        errors.append("unit_id is required")
    elif category in VALID_CATEGORIES and not _unit_exists(category, unit_id):
        errors.append("Unknown unit_id")

    if not (stats_value is Dictionary):
        errors.append("stats must be a Dictionary")
    else:
        var stats: Dictionary = stats_value

        if stats.is_empty():
            errors.append("stats must not be empty")
        else:
            _validate_stat_values(stats, errors)

    return {
        "valid": errors.is_empty(),
        "errors": errors
    }


func _validate_stat_values(stats: Dictionary, errors: Array[String]) -> void:
    if stats.has("hp"):
        if not _is_number(stats["hp"]) or float(stats["hp"]) <= 0.0:
            errors.append("hp must be greater than 0")

    for key in ["armor", "damage", "speed"]:
        if stats.has(key):
            if not _is_number(stats[key]) or float(stats[key]) < 0.0:
                errors.append("%s must be non-negative" % key)

    if stats.has("drop_chance"):
        if (
            not _is_number(stats["drop_chance"])
            or float(stats["drop_chance"]) < 0.0
            or float(stats["drop_chance"]) > 1.0
        ):
            errors.append("drop_chance must be between 0 and 1")


func _unit_exists(category: String, unit_id: String) -> bool:
    match category:
        "hero":
            return BalanceConfig.HERO_STATS.has(unit_id)
        "enemy":
            return BalanceConfig.ENEMY_STATS.has(unit_id)
        "boss":
            return BalanceConfig.BOSS_STATS.has(unit_id)
        _:
            return false


func _apply_record(record: Dictionary) -> bool:
    var category: String = str(record.get("category", "")).strip_edges().to_lower()
    var unit_id: String = str(record.get("unit_id", "")).strip_edges().to_lower()
    var stats: Dictionary = record.get("stats", {})

    for stat_key in stats.keys():
        if not BalanceConfig.set_unit_stat(
            category,
            unit_id,
            str(stat_key),
            stats[stat_key]
        ):
            return false

    return true


func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _transition(next_state: String) -> void:
    _state = next_state
    _transitions.append(next_state)
