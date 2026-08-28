extends RefCounted

const VfxPreviewGameScaleModel := preload("res://src/preview/vfx_preview_game_scale.gd")


static func run(tests: TestAssert) -> void:
	var contract := {
		"version": 1,
		"base_car_sprite_scale": [0.38, 0.38],
		"car_visual_scale": 0.25,
		"track_scales": [1.0, 0.95, 0.9, 0.85]
	}
	var expected_scales := {
		1.0: Vector2(0.095, 0.095),
		0.95: Vector2(0.09025, 0.09025),
		0.9: Vector2(0.0855, 0.0855),
		0.85: Vector2(0.08075, 0.08075)
	}
	for track_scale in expected_scales:
		var resolved := VfxPreviewGameScaleModel.effective_scale(contract, track_scale)
		tests.expect_true(resolved.success and _same_vector(resolved.value, expected_scales[track_scale]), "track scale %.2f derives the supplied Sprite2D scale" % track_scale)

	var unsupported := VfxPreviewGameScaleModel.effective_scale(contract, 0.8)
	tests.expect_true(not unsupported.success, "Preview rejects a Track Scale outside its compact reference contract")


static func _same_vector(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
