extends RefCounted

const VfxPreviewRenderPlanModel := preload("res://src/preview/rendering/vfx_preview_render_plan.gd")


static func run(tests: TestAssert) -> void:
	var packed := load("res://src/preview/vfx_vehicle_preview.tscn") as PackedScene
	var preview = packed.instantiate() if packed != null else null
	tests.expect_true(preview != null and preview.has_method("apply_render_plan") and preview.has_method("set_preview_validation_state"), "Vehicle Preview exposes explicit valid-Plan and validation-state boundaries")
	if preview == null or not preview.has_method("apply_render_plan") or not preview.has_method("set_preview_validation_state"):
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(preview)
	var plan := VfxPreviewRenderPlanModel.new("utility.last_valid", "ONE_SHOT", [], 7)
	preview.apply_render_plan(plan)
	preview.set_preview_validation_state([VfxIssue.new("PRESET_VALIDATION", "invalid_radius", "radius is invalid")])
	tests.expect_true(preview.active_render_plan().revision() == 7 and preview.preview_status_text() == "PREVIEW STALE — VALIDATION ERROR", "Validation error keeps the active valid Render Plan while exposing stale Preview status")
	tree.root.remove_child(preview)
	preview.free()
