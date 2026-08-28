extends RefCounted

const VfxRuntimeInputsEditorModel := preload("res://src/editor/inspector/vfx_runtime_inputs_editor.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")


static func run(tests: TestAssert) -> void:
	var editor := VfxRuntimeInputsEditorModel.new()
	var host := Control.new()
	host.add_child(editor)
	var committed: Array = []
	editor.runtime_inputs_committed.connect(func(inputs: Array[String]) -> void: committed.append(inputs))
	editor.set_schema(_schema_fixture())
	tests.expect_true(editor.available_inputs() == ["intensity", "speed_normalized"], "Runtime Inputs preserve Schema declaration order")
	tests.expect_true(editor.available_inputs().has("intensity"), "Runtime Inputs come from Schema")
	editor.commit_selection(["speed_normalized", "unknown", "intensity"])
	tests.expect_true(editor.selected_inputs() == ["intensity", "speed_normalized"], "unknown Runtime Input names cannot be selected by UI")
	tests.expect_true(committed == [["intensity", "speed_normalized"]], "Runtime Input commits retain Schema declaration order")
	host.free()
	_test_runtime_input_commits_and_pipeline_diagnostics(tests)


static func _test_runtime_input_commits_and_pipeline_diagnostics(tests: TestAssert) -> void:
	var controller := VfxEditorControllerModel.new()
	var created := controller.create_new_preset("utility.inputs", "Inputs", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "controller creates a Preset for Runtime Input commits")
	if not created.success:
		return
	controller.commit_runtime_inputs(["speed_normalized", "intensity"])
	tests.expect_true(controller.working_preset().get("runtime_inputs") == ["intensity", "speed_normalized"], "Runtime Input controller commits keep Schema declaration order")
	controller.commit_preset_field("/runtime_inputs", ["not_defined"])
	tests.expect_true(_has_issue(controller.current_issues(), "unknown_runtime_input"), "manually injected unknown Runtime Input remains reported by Pipeline validation")


static func _schema_fixture() -> Dictionary:
	return {
		"x_vfx_runtime_inputs": {
			"intensity": {"type": "number"},
			"speed_normalized": {"type": "number"}
		}
	}


static func _has_issue(issues: Array[VfxIssue], code: String) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false
