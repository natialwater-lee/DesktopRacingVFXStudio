extends RefCounted

const VfxIssueModel := preload("res://src/model/vfx_issue.gd")
const VfxDiagnosticsNavigatorModel := preload("res://src/editor/diagnostics/vfx_diagnostics_navigator.gd")
const VfxDiagnosticsPanelModel := preload("res://src/editor/diagnostics/vfx_diagnostics_panel.gd")


static func run(tests: TestAssert) -> void:
	var preset := {
		"phases": {
			"loop": {
				"layers": [
					{"id": "loop.glow_1"},
					{"id": "loop.glow_2"}
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

	var invalid_issue := VfxIssueModel.new("PRESET_VALIDATION", "required", "missing", "/phases/loop/layers/7/id")
	tests.expect_true(not navigator.navigate(invalid_issue, preset).get("handled", true), "out-of-range layer pointers remain visible and unhandled")
	var configuration_issue := VfxIssueModel.new("SCHEMA_CONFIGURATION", "unsupported", "unsupported", "/preset_id")
	tests.expect_true(not navigator.navigate(configuration_issue, preset).get("handled", true), "configuration issues are not routed to a guessed editor target")

	var panel := VfxDiagnosticsPanelModel.new()
	var activated := {"issue": null}
	panel.issue_activated.connect(func(issue: VfxIssue) -> void: activated["issue"] = issue)
	panel.set_issues([layer_issue])
	tests.expect_true(panel.issues().size() == 1, "diagnostics panel retains structured issues")
	panel.activate_issue(0)
	tests.expect_true(activated["issue"] == layer_issue, "diagnostics panel activation emits the original issue")
	panel.free()
