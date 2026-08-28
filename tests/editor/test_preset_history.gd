extends RefCounted

const VfxPresetHistoryModel := preload("res://src/editor/session/vfx_preset_history.gd")


static func run(tests: TestAssert) -> void:
	var restored_state := {"value": {}}
	var history := VfxPresetHistoryModel.new()
	var before := {"layers": [{"id": "one", "nested": ["before"]}]}
	var after := {"layers": [{"id": "two", "nested": ["after"]}]}
	history.record_snapshot("rename", before, after, func(value: Dictionary): restored_state["value"] = value)
	after["layers"][0]["nested"][0] = "mutated after record"
	history.undo()
	tests.expect_true(restored_state["value"]["layers"][0]["id"] == "one", "undo restores independent before snapshot")
	restored_state["value"]["layers"][0]["nested"][0] = "mutated after undo"
	history.redo()
	tests.expect_true(restored_state["value"]["layers"][0]["id"] == "two", "redo restores independent after snapshot")
	tests.expect_true(restored_state["value"]["layers"][0]["nested"][0] == "after", "redo snapshot survives restored-data mutation")
	tests.expect_true(not history.can_redo(), "redo is exhausted after restoring after snapshot")
	tests.expect_true(history.can_undo(), "undo remains available after redo")
