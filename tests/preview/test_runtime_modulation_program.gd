extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewCoordinateResolverModel := preload("res://src/preview/rendering/vfx_preview_coordinate_resolver.gd")
const VfxPreviewRenderRuntimeModel := preload("res://src/preview/rendering/vfx_preview_render_runtime.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxPreviewLodFilterModel := preload("res://src/performance/vfx_preview_lod_filter.gd")
const VfxPerformancePolicyModel := preload("res://src/performance/vfx_performance_policy.gd")
const VfxPreviewRuntimeInputStateModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd")
const VfxPreviewRuntimeModulationEvaluatorModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd")


static func run(tests: TestAssert) -> void:
	var fixture := VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.runtime_modulation_fixture.vfx.json")
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(fixture.value.normalized_data) if fixture.success else VfxResult.failure(fixture.issues)
	tests.expect_true(plan_result.success, "Runtime Modulation fixture compiles into a Preview Render Plan")
	if not plan_result.success:
		return
	var program = plan_result.value.runtime_modulation_program()
	tests.expect_true(program != null and program.binding_count() == 14, "turn-rate rotation binding joins twelve CORE parity bindings plus one EXTRA binding")
	if program == null:
		return
	tests.expect_true(program.runtime_input_slot("speed_normalized") >= 0, "used speed input has a stable slot")
	tests.expect_true(program.runtime_input_slot("longitudinal_load") >= 0, "used signed load input has a stable slot")
	tests.expect_true(program.runtime_input_slot("turn_rate_normalized") >= 0, "used signed turn-rate input has a stable slot")
	tests.expect_true(program.runtime_input_slot("surface_type") == -1, "unused nonnumeric input has no slot")
	tests.expect_true(program.bindings_for_layer("one.shot.left.core").size() == 7, "turn-rate rotation binding remains Layer-local to the left CORE sprite")
	tests.expect_true(program.bindings_for_layer("one.shot.right.core").size() == 6, "right CORE parity bindings remain Layer-local")
	tests.expect_true(program.bindings_for_layer("one.shot.lod.extra").size() == 1, "EXTRA binding remains Layer-local")
	tests.expect_true(program.clamps_for_layer("one.shot.left.core").size() == 1, "clamp belongs to its Layer target, not a binding")
	_test_evaluator(tests, plan_result.value, program)
	_test_pivot_compensation(tests)
	_test_textured_sprite_runtime_consumer(tests, plan_result.value)
	_test_lod_reachability(tests, plan_result.value)
	_test_visual_bend_evaluator_and_straight_preview_fallback(tests)


static func _test_evaluator(tests: TestAssert, plan: RefCounted, program: RefCounted) -> void:
	var input_state := VfxPreviewRuntimeInputStateModel.new(program)
	input_state.set_named_value(program, "speed_normalized", 1.0)
	input_state.set_named_value(program, "longitudinal_load", 0.0)
	var evaluator := VfxPreviewRuntimeModulationEvaluatorModel.new(program, input_state)
	var phase: RefCounted = plan.phase_named("one_shot")
	var left_state = evaluator.create_effective_state(phase.layer_specs()[0])
	var right_state = evaluator.create_effective_state(phase.layer_specs()[1])
	evaluator.refresh(0.5, [left_state, right_state])
	tests.expect_true(is_equal_approx(left_state.effective_scale().y, 1.7), "multiply bindings compose in authored order and clamp once after composition")
	tests.expect_true(is_equal_approx(left_state.effective_offset().x, -54.0), "offset binding adds to authored base")
	tests.expect_true(is_equal_approx(left_state.effective_rotation_degrees(), 355.4), "shared oscillator rotation maps deterministically")
	tests.expect_true(is_equal_approx(left_state.visual_opacity_multiplier(), 1.05), "legal opacity multiplier above one remains available to the final alpha seam")
	tests.expect_true(right_state.effective_scale() == left_state.effective_scale() and evaluator.sampled_source_count_last_tick() == 1, "two consumers share one sampled oscillator")
	input_state.set_named_value(program, "turn_rate_normalized", -1.0)
	evaluator.refresh(0.5, [left_state])
	tests.expect_true(is_equal_approx(left_state.effective_rotation_degrees(), 343.4), "turn-rate -1 maps through generic LINEAR_RANGE into rotation ADD")
	input_state.set_named_value(program, "turn_rate_normalized", 0.0)
	evaluator.refresh(0.5, [left_state])
	tests.expect_true(is_equal_approx(left_state.effective_rotation_degrees(), 355.4), "turn-rate zero keeps the authored plus oscillator rotation unchanged")
	input_state.set_named_value(program, "turn_rate_normalized", 1.0)
	evaluator.refresh(0.5, [left_state])
	tests.expect_true(is_equal_approx(left_state.effective_rotation_degrees(), 367.4), "turn-rate +1 maps through generic LINEAR_RANGE into rotation ADD")
	evaluator.refresh(0.5, [left_state, right_state])
	tests.expect_true(is_equal_approx(left_state.effective_scale().y, 1.7) and is_equal_approx(left_state.effective_rotation_degrees(), 367.4), "refreshing the same time is deterministic without advancing playback")


static func _test_pivot_compensation(tests: TestAssert) -> void:
	var base_origin := Vector2(-55.638927, -317.925671)
	var base_scale := Vector2(1.55, 1.60)
	var pivot := Vector2(-0.5, 89.0)
	var root := VfxPreviewCoordinateResolverModel.attachment_root(base_origin, base_scale, 355.0, pivot)
	var compensated := VfxPreviewCoordinateResolverModel.compensated_source_origin(base_origin, base_scale, 355.0, pivot, Vector2(1.55, 1.76), 355.4, Vector2.ZERO)
	var effective_root := VfxPreviewCoordinateResolverModel.attachment_root(compensated, Vector2(1.55, 1.76), 355.4, pivot)
	tests.expect_true(root.distance_to(Vector2(-44.0, -176.0)) <= 0.2 and effective_root.distance_to(root) <= 0.001, "generic pivot compensation preserves the attached local point")


static func _test_textured_sprite_runtime_consumer(tests: TestAssert, plan: RefCounted) -> void:
	var runtime := VfxPreviewRenderRuntimeModel.new(plan, {"anchors": {"CENTER": [0.0, 0.0]}}, _registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	var input_state := VfxPreviewRuntimeInputStateModel.new(plan.runtime_modulation_program())
	input_state.set_named_value(plan.runtime_modulation_program(), "speed_normalized", 1.0)
	runtime.set_runtime_input_state(input_state)
	runtime.activate_phase("one_shot", {"preview_time": 0.0})
	runtime.advance(0.5, {"preview_time": 0.5})
	var left_packet: Dictionary = {}
	for packet in runtime.draw_packets():
		if packet.get("layer_id") == "one.shot.left.core":
			left_packet = packet
	tests.expect_true(runtime.has_modulation_evaluator() and runtime.active_runtime_modulation_binding_count() == 14 and runtime.modulation_sample_count_last_tick() == 1, "all fourteen renderer-backed TEXTURED_SPRITE bindings create one shared evaluator")
	tests.expect_true(is_equal_approx(float(left_packet.get("alpha", 0.0)), 0.84), "TEXTURED_SPRITE applies the legal opacity multiplier at its final alpha seam")


static func _test_lod_reachability(tests: TestAssert, plan: RefCounted) -> void:
	var policy_result: VfxResult = VfxPerformancePolicyModel.new().load(_registry())
	var low_result: VfxResult = VfxPreviewLodFilterModel.new().filter(plan, "LOW", policy_result.value) if policy_result.success else VfxResult.failure(policy_result.issues)
	tests.expect_true(low_result.success and low_result.value.runtime_modulation_program().binding_count() == 13, "LOW LOD removes the EXTRA binding before runtime evaluator construction")


static func _test_visual_bend_evaluator_and_straight_preview_fallback(tests: TestAssert) -> void:
	var fixture := VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.visual_bend_fixture.vfx.json")
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(fixture.value.normalized_data) if fixture.success else VfxResult.failure(fixture.issues)
	tests.expect_true(plan_result.success, "Visual Bend fixture validates, saves/loads through the normal Pipeline, and builds a generic Preview modulation program")
	if not plan_result.success:
		return
	var plan: RefCounted = plan_result.value
	var program: RefCounted = plan.runtime_modulation_program()
	var bend_slot := _target_slot(program, "VISUAL_BEND_OFFSET_X")
	tests.expect_true(program != null and bend_slot >= 0 and program.runtime_input_slot("turn_rate_normalized") >= 0, "Visual Bend uses the existing generic turn-rate input and a Schema-derived modulation target slot")
	if program == null or bend_slot < 0:
		return
	var input_state := VfxPreviewRuntimeInputStateModel.new(program)
	var evaluator := VfxPreviewRuntimeModulationEvaluatorModel.new(program, input_state)
	var phase: RefCounted = plan.phase_named("one_shot")
	var state: RefCounted = evaluator.create_effective_state(phase.layer_specs()[0])
	var values_by_turn: Dictionary = {}
	for turn_value in [-1.0, 0.0, 1.0]:
		input_state.set_named_value(program, "turn_rate_normalized", turn_value)
		evaluator.refresh(0.0, [state])
		values_by_turn[turn_value] = state.effective_value(bend_slot)
	tests.expect_true(is_equal_approx(float(values_by_turn[-1.0]), -18.0) and is_equal_approx(float(values_by_turn[0.0]), 0.0) and is_equal_approx(float(values_by_turn[1.0]), 18.0), "generic LINEAR_RANGE evaluates VISUAL_BEND_OFFSET_X and applies its configured target clamp exactly once")

	var runtime := VfxPreviewRenderRuntimeModel.new(plan, {"anchors": {"CENTER": [0.0, 0.0]}}, _registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	runtime.set_runtime_input_state(input_state)
	input_state.set_named_value(program, "turn_rate_normalized", -1.0)
	runtime.activate_phase("one_shot", {"preview_time": 0.0})
	runtime.advance(0.0, {"preview_time": 0.0})
	var negative_packet := _packet_for_layer(runtime.draw_packets(), "one_shot.visual_bend_fixture")
	input_state.set_named_value(program, "turn_rate_normalized", 1.0)
	runtime.refresh_modulation({"preview_time": 0.0})
	var positive_packet := _packet_for_layer(runtime.draw_packets(), "one_shot.visual_bend_fixture")
	tests.expect_true(
		negative_packet.get("position") == positive_packet.get("position") and negative_packet.get("geometry_scale") == positive_packet.get("geometry_scale") and negative_packet.get("geometry_rotation_degrees") == positive_packet.get("geometry_rotation_degrees"),
		"Preview keeps Visual Bend metadata and its numeric target on the existing straight TEXTURED_SPRITE packet path without renderer or packet-order changes"
	)


static func _target_slot(program: RefCounted, target_name: String) -> int:
	if program == null:
		return -1
	for slot in program.target_count():
		if program.target_name(slot) == target_name:
			return slot
	return -1


static func _packet_for_layer(packets: Array, layer_id: String) -> Dictionary:
	for packet in packets:
		if packet is Dictionary and packet.get("layer_id") == layer_id:
			return packet
	return {}


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
