extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewSharedStateModel := preload("res://src/preview/vfx_preview_shared_state.gd")


static func run(tests: TestAssert) -> void:
	_test_generic_showcase_contract_and_factory_dispatch(tests)
	_test_showcase_runtime_generates_all_five_layer_packets(tests)
	_test_existing_examples_keep_lifecycle_and_world_space(tests)
	_test_preview_scene_consumes_one_active_plan_without_reading_a_preset_path(tests)


static func _test_generic_showcase_contract_and_factory_dispatch(tests: TestAssert) -> void:
	var pipeline := VfxPresetPipelineModel.new()
	var document_result: VfxResult = pipeline.load_and_validate("res://presets/examples/utility.renderer_showcase.vfx.json")
	var builder_script := load("res://src/preview/rendering/vfx_preview_render_plan_builder.gd") as Script
	var factory_script := load("res://src/preview/rendering/vfx_preview_renderer_factory.gd") as Script
	tests.expect_true(document_result.success and builder_script != null and factory_script != null, "Renderer Showcase is a contract-valid generic Preset with the ordinary Plan and Factory services available")
	if not document_result.success or builder_script == null or factory_script == null:
		return
	var plan_result: VfxResult = builder_script.new(_registry()).build(document_result.value.normalized_data)
	var factory = factory_script.new()
	var dispatched_types: Dictionary = {}
	if plan_result.success:
		for phase_plan in plan_result.value.phase_plans():
			for layer_spec in phase_plan.layer_specs():
				dispatched_types[layer_spec.layer_type()] = factory.renderer_registration(layer_spec.layer_type()) is Script
	tests.expect_true(plan_result.success and dispatched_types.keys().size() == 5 and dispatched_types.values().all(func(dispatched: bool) -> bool: return dispatched), "Showcase dispatches PARTICLE, TRAIL, RING, GLOW, and SHIELD through the ordinary Layer-Type factory map")


static func _test_showcase_runtime_generates_all_five_layer_packets(tests: TestAssert) -> void:
	var pipeline := VfxPresetPipelineModel.new()
	var document_result: VfxResult = pipeline.load_and_validate("res://presets/examples/utility.renderer_showcase.vfx.json")
	var builder_script := load("res://src/preview/rendering/vfx_preview_render_plan_builder.gd") as Script
	var runtime_script := load("res://src/preview/rendering/vfx_preview_render_runtime.gd") as Script
	var factory_script := load("res://src/preview/rendering/vfx_preview_renderer_factory.gd") as Script
	var asset_registry_script := load("res://src/preview/rendering/vfx_preview_asset_registry.gd") as Script
	var asset_resolver_script := load("res://src/preview/rendering/vfx_preview_asset_resolver.gd") as Script
	if not document_result.success or builder_script == null or runtime_script == null or factory_script == null or asset_registry_script == null or asset_resolver_script == null:
		tests.expect_true(false, "Showcase runtime proof requires the ordinary Preview Plan, Runtime, Factory, and Asset services")
		return
	var registry := _registry()
	var plan_result: VfxResult = builder_script.new(registry).build(document_result.value.normalized_data)
	if not plan_result.success:
		tests.expect_true(false, "Showcase runtime proof requires a valid Render Plan")
		return
	var asset_resolver: Variant = asset_resolver_script.new(asset_registry_script.new())
	var runtime: Variant = runtime_script.new(plan_result.value, {"anchors": {"CENTER": [0, 0], "REAR_CENTER": [0, 160]}}, registry, factory_script.new(), asset_resolver)
	var frame := {"vehicle_translation_source": Vector2.ZERO, "vehicle_rotation_degrees": 0.0, "effective_game_scale": Vector2(0.095, 0.095), "playback_generation": 1}
	runtime.activate_phase("start", frame)
	runtime.activate_phase("loop", frame)
	runtime.advance(0.25, frame)
	var packet_types: Dictionary = {}
	for packet in runtime.draw_packets():
		packet_types[packet.get("type")] = true
	tests.expect_true(packet_types.keys().size() == 5 and packet_types.has("PARTICLE") and packet_types.has("TRAIL") and packet_types.has("RING") and packet_types.has("GLOW") and packet_types.has("SHIELD"), "Renderer Showcase START and LOOP create ordinary runtime draw packets for all five Schema Layer Types")


static func _test_existing_examples_keep_lifecycle_and_world_space(tests: TestAssert) -> void:
	var pipeline := VfxPresetPipelineModel.new()
	var builder_script := load("res://src/preview/rendering/vfx_preview_render_plan_builder.gd") as Script
	if builder_script == null:
		tests.expect_true(false, "Existing example regression requires the Render Plan Builder")
		return
	var builder = builder_script.new(_registry())
	var zero_document: VfxResult = pipeline.load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var finish_document: VfxResult = pipeline.load_and_validate("res://presets/examples/finish.confetti_world.vfx.json")
	var zero_plan: VfxResult = builder.build(zero_document.value.normalized_data) if zero_document.success else VfxResult.failure(zero_document.issues)
	var finish_plan: VfxResult = builder.build(finish_document.value.normalized_data) if finish_document.success else VfxResult.failure(finish_document.issues)
	var finish_spec: RefCounted = finish_plan.value.phase_named("one_shot").layer_specs()[0] if finish_plan.success else null
	tests.expect_true(zero_plan.success and zero_plan.value.lifecycle_mode() == "START_LOOP_END" and zero_plan.value.phase_plans().size() == 3, "Zero Zone retains its ordinary Start/Loop/End Render Plan lifecycle")
	tests.expect_true(finish_plan.success and finish_spec != null and finish_spec.effective_space() == "WORLD_AREA" and finish_spec.anchor_names().is_empty() and finish_spec.render_plane() == "WORLD", "Finish Confetti remains an anchorless WORLD_AREA Plan rather than a vehicle-space special case")


static func _test_preview_scene_consumes_one_active_plan_without_reading_a_preset_path(tests: TestAssert) -> void:
	var packed := load("res://src/preview/vfx_vehicle_preview.tscn") as PackedScene
	var builder_script := load("res://src/preview/rendering/vfx_preview_render_plan_builder.gd") as Script
	var pipeline := VfxPresetPipelineModel.new()
	var document_result: VfxResult = pipeline.load_and_validate("res://presets/examples/utility.renderer_showcase.vfx.json")
	var preview = packed.instantiate() if packed != null else null
	if preview == null or builder_script == null or not document_result.success:
		tests.expect_true(false, "Showcase Preview smoke requires a scene, valid document, and Render Plan Builder")
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(preview)
	var state := VfxPreviewSharedStateModel.new()
	state.set_game_scale_contract({"base_car_sprite_scale": [0.38, 0.38], "car_visual_scale": 0.25, "track_scales": [1.0]})
	state.set_profile_data({"reference_image": {"path": "res://assets/reference/vehicles/formula_reference.png", "expected_source_size_px": [256, 512]}, "anchors": {"CENTER": [0, 0], "REAR_CENTER": [0, 160]}})
	preview.set_shared_state(state)
	preview.set_schema_registry(_registry())
	var plan_result: VfxResult = builder_script.new(_registry()).build(document_result.value.normalized_data)
	if plan_result.success:
		preview.apply_render_plan(plan_result.value)
	var edit_render_host := preview.find_child("RenderHost_ADDITIVE", true, false)
	var game_render_host := preview.find_child("RenderHost_ALPHA", true, false)
	var active_plan: RefCounted = preview.active_render_plan()
	tests.expect_true(plan_result.success and active_plan != null and active_plan != plan_result.value and active_plan.preset_id() == plan_result.value.preset_id() and edit_render_host != null and game_render_host != null, "Edit and Game consume one immutable HIGH-derived valid Plan through per-canvas host projection, not a Preset path or a mutated source Plan")
	tree.root.remove_child(preview)
	preview.free()


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
