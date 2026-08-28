extends RefCounted

const VfxPreviewGameScaleModel := preload("res://src/preview/vfx_preview_game_scale.gd")
const VfxPreviewSharedStateModel := preload("res://src/preview/vfx_preview_shared_state.gd")
const VfxPreviewTransformResolverModel := preload("res://src/preview/vfx_preview_transform_resolver.gd")
const VfxVehiclePreviewModel := preload("res://src/preview/vfx_vehicle_preview.gd")
const VfxVehiclePreviewCanvasModel := preload("res://src/preview/vfx_vehicle_preview_canvas.gd")


static func run(tests: TestAssert) -> void:
	var contract := {
		"version": 1,
		"base_car_sprite_scale": [0.38, 0.38],
		"car_visual_scale": 0.25,
		"track_scales": [1.0, 0.95, 0.9, 0.85]
	}
	var resolved := VfxPreviewGameScaleModel.effective_scale(contract, 1.0)
	if not resolved.success:
		tests.expect_true(false, "Preview foundation requires the Phase 2 game scale contract")
		return
	var game_size := VfxPreviewTransformResolverModel.reference_draw_size(Vector2i(256, 512), resolved.value, 1.0)
	var edit_200 := VfxPreviewTransformResolverModel.reference_draw_size(Vector2i(256, 512), resolved.value, 2.0)
	var edit_400 := VfxPreviewTransformResolverModel.reference_draw_size(Vector2i(256, 512), resolved.value, 4.0)
	tests.expect_true(_same_vector(game_size, Vector2(24.32, 48.64)), "Game Canvas keeps the native 256 by 512 image at exact 100 percent game scale")
	tests.expect_true(_same_vector(edit_200, game_size * 2.0) and _same_vector(edit_400, game_size * 4.0), "Edit Canvas zoom is relative to Game View rather than source image scale")

	var source_point := Vector2(10, -20)
	var projected := VfxPreviewTransformResolverModel.project_source_local(source_point, Vector2(100, 120), Vector2(0, 0), 0.0, resolved.value, 2.0)
	var round_trip := VfxPreviewTransformResolverModel.inverse_project_source_local(projected, Vector2(100, 120), Vector2(0, 0), 0.0, resolved.value, 2.0)
	tests.expect_true(_same_vector(round_trip, source_point), "source-local projection round-trips without inheriting Control layout scale")

	var packed := load("res://src/preview/vfx_vehicle_preview.tscn") as PackedScene
	tests.expect_true(packed != null, "dual vehicle Preview scene loads")
	if packed == null:
		return
	var preview := packed.instantiate() as VfxVehiclePreviewModel
	tests.expect_true(preview != null, "dual vehicle Preview scene instantiates its typed root")
	if preview == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(preview)
	var state := VfxPreviewSharedStateModel.new()
	state.set_game_scale_contract(contract)
	state.set_track_scale(1.0)
	state.set_profile_data({
		"reference_image": {"path": "res://assets/reference/vehicles/formula_reference.png", "expected_source_size_px": [256, 512]},
		"anchors": {"CENTER": [0, 0]}
	})
	preview.set_shared_state(state)
	tests.expect_true(preview.get_future_vfx_host("EDIT") != null and preview.get_future_vfx_host("GAME") != null, "Edit and Game Canvas each own a separate FutureVfxHost")
	var game_canvas := preview.get_node_or_null("PreviewSurface/GameSizeInset/GameInsetContents/GameCanvas") as VfxVehiclePreviewCanvasModel
	tests.expect_true(game_canvas != null and not game_canvas.is_interactive() and is_equal_approx(game_canvas.view_zoom(), 1.0), "Game Canvas is a 100 percent display-only readability view")
	tree.root.remove_child(preview)
	preview.free()


static func _same_vector(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
