extends RefCounted

const VfxIssueModel := preload("res://src/model/vfx_issue.gd")
const VfxResultModel := preload("res://src/model/vfx_result.gd")
const VfxPresetDocumentModel := preload("res://src/model/vfx_preset_document.gd")


static func run(tests: TestAssert) -> void:
	var issue := VfxIssueModel.new(
		"JSON_PARSE",
		"invalid_json",
		"bad JSON",
		"",
		"preset.vfx.json",
		3,
		-1
	)
	var failed_result := VfxResultModel.failure([issue])
	tests.expect_true(not failed_result.success, "ERROR issue makes result unsuccessful")
	tests.expect_true(failed_result.issues[0].column == -1, "unknown JSON column stays -1")

	var warning := VfxIssueModel.new("PRESET_VALIDATION", "note", "warning", "", "", -1, -1, "WARNING")
	var warning_result := VfxResultModel.with_issues({"ok": true}, [warning])
	tests.expect_true(warning_result.success, "WARNING issue does not make result unsuccessful")

	var raw := {"layers": []}
	var normalized := {"layers": [{"id": "loop.core"}]}
	var document := VfxPresetDocumentModel.new("preset.vfx.json", raw, normalized)
	raw["layers"].append({"id": "mutated_raw"})
	normalized["layers"].append({"id": "mutated_normalized"})
	tests.expect_true(document.raw_data["layers"].is_empty(), "document keeps independent raw data")
	tests.expect_true(document.normalized_data["layers"].size() == 1, "document keeps independent normalized data")
