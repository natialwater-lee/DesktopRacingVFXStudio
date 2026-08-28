extends RefCounted

const VfxIssueModel := preload("res://src/model/vfx_issue.gd")
const VfxDiagnosticsNavigatorModel := preload("res://src/editor/diagnostics/vfx_diagnostics_navigator.gd")
const VfxDiagnosticsPanelModel := preload("res://src/editor/diagnostics/vfx_diagnostics_panel.gd")


static func run(tests: TestAssert) -> void:
	var preset := {
		"lifecycle": {"mode": "ONE_SHOT"},
		"runtime_inputs": ["intensity"],
		"phases": {
			"loop": {
				"layers": [
					{"id": "loop.glow_1"},
					{
						"id": "loop.glow_2",
						"type": "GLOW",
						"anchors": ["CENTER"],
						"transform": {"offset": [0.0, 0.0], "rotation_degrees": 0.0, "scale": [1.0, 1.0]},
						"parameters": {"radius": 4.0, "color_rgba": [1.0, 1.0, 1.0, 1.0]}
					}
				]
			}
		}
	}
	var navigator := VfxDiagnosticsNavigatorModel.new()
	var layer_issue := VfxIssueModel.new("PRESET_VALIDATION", "required", "missing", "/phases/loop/layers/1/parameters/radius")
	var layer_route: Dictionary = navigator.navigate(layer_issue, preset)
	tests.expect_true(layer_route.get("handled", false), "Layer parameter pointer is navigable")
	tests.expect_true(layer_route.get("phase_name", "") == "loop", "navigator selects phase")
	tests.expect_true(layer_route.get("layer_id", "") == "loop.glow_2", "navigator resolves Layer id from array index")

	var escaped_phase := {"phases": {"loop/a": {"layers": [{"id": "escaped.layer"}]}}}
	var escaped_issue := VfxIssueModel.new("PRESET_VALIDATION", "required", "missing", "/phases/loop~1a/layers/0/id")
	var escaped_route: Dictionary = navigator.navigate(escaped_issue, escaped_phase)
	tests.expect_true(escaped_route.get("handled", false) and escaped_route.get("phase_name", "") == "loop/a", "navigator unescapes JSON Pointer phase segments")

	var root_issue := VfxIssueModel.new("PRESET_VALIDATION", "required", "missing", "/display_name")
	var root_route: Dictionary = navigator.navigate(root_issue, preset)
	tests.expect_true(root_route.get("handled", false) and root_route.get("layer_id", "") == "", "root Preset pointers route without guessing a Layer")
	var lifecycle_mode_issue := VfxIssueModel.new("PRESET_VALIDATION", "invalid_enum", "invalid", "/lifecycle/mode")
	tests.expect_true(navigator.navigate(lifecycle_mode_issue, preset).get("handled", false), "validator lifecycle mode descendants route to the Preset Inspector")
	var runtime_input_issue := VfxIssueModel.new("PRESET_VALIDATION", "runtime_input_not_declared", "unknown", "/runtime_inputs/0")
	tests.expect_true(navigator.navigate(runtime_input_issue, preset).get("handled", false), "validator runtime input indexes route to the Preset Inspector")
	var runtime_input_out_of_range := VfxIssueModel.new("PRESET_VALIDATION", "runtime_input_not_declared", "unknown", "/runtime_inputs/1")
	tests.expect_true(not navigator.navigate(runtime_input_out_of_range, preset).get("handled", true), "runtime input indexes are bounded by the current Preset")

	var invalid_issue := VfxIssueModel.new("PRESET_VALIDATION", "required", "missing", "/phases/loop/layers/7/id")
	tests.expect_true(not navigator.navigate(invalid_issue, preset).get("handled", true), "out-of-range layer pointers remain visible and unhandled")
	var configuration_issue := VfxIssueModel.new("SCHEMA_CONFIGURATION", "unsupported", "unsupported", "/preset_id")
	tests.expect_true(not navigator.navigate(configuration_issue, preset).get("handled", true), "configuration issues are not routed to a guessed editor target")
	for unsupported_pointer in [
		"/preset_id/unknown",
		"/phases/loop/unknown",
		"/phases/loop/layers/1/unknown",
		"/phases/loop/layers/1/parameters/not_declared",
		"/phases//layers/1/id",
		"/phases/loop/layers/1/~2bad"
	]:
		var unsupported_issue := VfxIssueModel.new("PRESET_VALIDATION", "unknown", "unknown", unsupported_pointer)
		tests.expect_true(not navigator.navigate(unsupported_issue, preset).get("handled", true), "navigator rejects unsupported JSON Pointer grammar: %s" % unsupported_pointer)
	var common_layer_issue := VfxIssueModel.new("PRESET_VALIDATION", "required", "missing", "/phases/loop/layers/1/transform/offset/0")
	tests.expect_true(navigator.navigate(common_layer_issue, preset).get("handled", false), "navigator accepts documented common Layer transform pointers")
	var anchor_index_issue := VfxIssueModel.new("PRESET_VALIDATION", "invalid_enum", "invalid", "/phases/loop/layers/1/anchors/0")
	tests.expect_true(navigator.navigate(anchor_index_issue, preset).get("handled", false), "anchor indexes within the current Layer are navigable")
	var anchor_out_of_range := VfxIssueModel.new("PRESET_VALIDATION", "invalid_enum", "invalid", "/phases/loop/layers/1/anchors/999")
	tests.expect_true(not navigator.navigate(anchor_out_of_range, preset).get("handled", true), "anchor indexes outside the current Layer are rejected")
	var offset_out_of_range := VfxIssueModel.new("PRESET_VALIDATION", "type", "invalid", "/phases/loop/layers/1/transform/offset/999")
	tests.expect_true(not navigator.navigate(offset_out_of_range, preset).get("handled", true), "transform value indexes outside the current Layer are rejected")

	var missing_radius_preset: Dictionary = preset.duplicate(true)
	missing_radius_preset["phases"]["loop"]["layers"][1]["parameters"].erase("radius")
	var missing_radius_issue := VfxIssueModel.new("PRESET_VALIDATION", "required", "missing", "/phases/loop/layers/1/parameters/radius")
	tests.expect_true(navigator.navigate(missing_radius_issue, missing_radius_preset).get("handled", false), "Schema-declared missing-required parameter paths remain navigable")
	var color_index_issue := VfxIssueModel.new("PRESET_VALIDATION", "maximum", "invalid", "/phases/loop/layers/1/parameters/color_rgba/3")
	tests.expect_true(navigator.navigate(color_index_issue, preset).get("handled", false), "Schema-declared parameter array indexes within current data are navigable")
	var color_index_out_of_range := VfxIssueModel.new("PRESET_VALIDATION", "maximum", "invalid", "/phases/loop/layers/1/parameters/color_rgba/9")
	tests.expect_true(not navigator.navigate(color_index_out_of_range, preset).get("handled", true), "parameter array indexes outside current data are rejected")

	var panel := VfxDiagnosticsPanelModel.new()
	var activated := {"issue": null}
	panel.issue_activated.connect(func(issue: VfxIssue) -> void: activated["issue"] = issue)
	panel.set_issues([layer_issue])
	tests.expect_true(panel.issues().size() == 1, "diagnostics panel retains structured issues")
	panel.activate_issue(0)
	tests.expect_true(activated["issue"] == layer_issue, "diagnostics panel activation emits the original issue")
	panel.free()
