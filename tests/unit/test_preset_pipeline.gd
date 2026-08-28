extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")


static func run(tests: TestAssert) -> void:
	var pipeline := VfxPresetPipelineModel.new()
	var zero_zone := pipeline.load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	tests.expect_true(zero_zone.success, "Zero Zone completes load-normalize-validate")
	tests.expect_true(zero_zone.value is VfxPresetDocument, "pipeline returns a document")
	if zero_zone.success:
		tests.expect_true(not zero_zone.value.raw_data["phases"]["loop"]["layers"][0].has("sort_order"), "pipeline preserves raw source data")
		tests.expect_true(zero_zone.value.normalized_data["phases"]["loop"]["layers"][0]["sort_order"] == 0, "pipeline exposes normalized defaults")

	var confetti := pipeline.load_and_validate("res://presets/examples/finish.confetti_world.vfx.json")
	tests.expect_true(confetti.success, "Finish Confetti World completes load-normalize-validate")

	var loaded := pipeline.load_and_validate("res://tests/fixtures/valid/zero_zone.vfx.json")
	tests.expect_true(loaded.success, "valid Zero Zone fixture loads")
	if loaded.success:
		var first := pipeline.serialize_document(loaded.value)
		var codec := VfxPresetCodecModel.new()
		var decoded := codec.decode_text(first.value, "round_trip.vfx.json")
		var second := codec.encode(decoded.value)
		tests.expect_true(first.success, "pipeline serializes a valid normalized document")
		tests.expect_true(decoded.success, "serialized document decodes")
		tests.expect_true(second.success, "decoded document serializes")
		if first.success and decoded.success and second.success:
			tests.expect_true(first.value == second.value, "normalized serialization is deterministic")
		loaded.value.normalized_data["category"] = "INVALID_CATEGORY"
		var rejected_serialization := pipeline.serialize_document(loaded.value)
		tests.expect_true(not rejected_serialization.success, "pipeline revalidates a changed document before serialization")
		tests.expect_true(_has_code(rejected_serialization, "invalid_enum"), "revalidation reports the changed document issue")

	var invalid_cases := {
		"invalid_schema_version.vfx.json": "invalid_enum",
		"unknown_property.vfx.json": "additional_property",
		"missing_required.vfx.json": "required",
		"duplicate_layer_id.vfx.json": "duplicate_layer_id",
		"invalid_start_loop_end.vfx.json": "lifecycle_phase_structure",
		"invalid_one_shot.vfx.json": "lifecycle_phase_structure",
		"vehicle_without_anchor.vfx.json": "vehicle_anchor_required",
		"world_with_anchor.vfx.json": "anchor_not_allowed",
		"invalid_render_plane.vfx.json": "render_plane_for_space",
		"invalid_continuous_particle.vfx.json": "continuous_emission_fields",
		"invalid_emitter_shape.vfx.json": "emitter_shape_geometry",
		"unknown_runtime_input.vfx.json": "unknown_runtime_input",
		"invalid_asset_reference.vfx.json": "pattern"
	}
	for fixture_name in invalid_cases:
		var invalid_result := pipeline.load_and_validate("res://tests/fixtures/invalid/%s" % fixture_name)
		tests.expect_true(not invalid_result.success, "%s is rejected" % fixture_name)
		tests.expect_true(_has_code(invalid_result, invalid_cases[fixture_name]), "%s returns its focused issue code" % fixture_name)


static func _has_code(result: VfxResult, expected_code: String) -> bool:
	return result.issues.any(func(issue: VfxIssue) -> bool: return issue.code == expected_code)
