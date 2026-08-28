extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxDirtyTrackerModel := preload("res://src/editor/session/vfx_dirty_tracker.gd")
const VfxPresetEditSessionModel := preload("res://src/editor/session/vfx_preset_edit_session.gd")


static func run(tests: TestAssert) -> void:
	var session := VfxPresetEditSessionModel.new(VfxDirtyTrackerModel.new(VfxPresetCodecModel.new()))
	var source := {
		"preset_id": "test.one",
		"phases": {"one_shot": {"layers": []}}
	}
	session.begin_new(source)
	source["phases"]["one_shot"]["layers"].append({"id": "outside"})
	tests.expect_true(session.working_copy()["phases"]["one_shot"]["layers"].is_empty(), "new session owns nested source data")
	tests.expect_true(session.is_dirty(), "new unsaved session is dirty")

	var pipeline := VfxPresetPipelineModel.new()
	var opened := pipeline.load_and_validate("res://tests/fixtures/valid/zero_zone.vfx.json")
	tests.expect_true(opened.success, "valid document opens for edit-session baseline test")
	if not opened.success:
		return

	session.open_document(opened.value)
	tests.expect_true(not session.is_dirty(), "opened normalized document starts clean")
	var changed := session.working_copy()
	changed["display_name"] = "Changed Name"
	session.replace_working_data(changed)
	tests.expect_true(session.is_dirty(), "working mutation is dirty against normalized baseline")

	var saved_document: VfxPresetDocument = opened.value
	saved_document.normalized_data["display_name"] = "Changed Name"
	session.mark_saved(saved_document)
	tests.expect_true(not session.is_dirty(), "matching saved normalized baseline is clean")
	saved_document.normalized_data["display_name"] = "Outside Mutation"
	tests.expect_true(not session.is_dirty(), "saved document mutation does not alias session baseline")
