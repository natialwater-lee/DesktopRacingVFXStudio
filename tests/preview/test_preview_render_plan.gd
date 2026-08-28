extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")


static func run(tests: TestAssert) -> void:
	_test_plan_is_independent_snapshot(tests)
	_test_asset_catalog_and_missing_fallback(tests)
	_test_vehicle_multi_anchor_expands_in_declared_order(tests)
	_test_factory_configuration_coverage(tests)
	_test_canvas_exposes_ordered_plane_hosts(tests)


static func _test_plan_is_independent_snapshot(tests: TestAssert) -> void:
	var builder_script := load("res://src/preview/rendering/vfx_preview_render_plan_builder.gd") as Script
	var pipeline := VfxPresetPipelineModel.new()
	var document_result: VfxResult = pipeline.load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	tests.expect_true(builder_script != null and document_result.success, "Render Plan test requires a builder and a valid Zero Zone document")
	if builder_script == null or not document_result.success:
		return
	var builder = builder_script.new(_registry())
	var plan_result: VfxResult = builder.build(document_result.value.normalized_data)
	tests.expect_true(plan_result.success, "Render Plan builder accepts a contract-valid normalized Preset")
	if not plan_result.success:
		return
	var plan = plan_result.value
	var start_phase = plan.phase_named("start")
	var glow_spec = start_phase.layer_specs()[0] if start_phase != null and not start_phase.layer_specs().is_empty() else null
	var before_radius: float = float(glow_spec.parameters().get("radius", -1.0)) if glow_spec != null else -1.0
	document_result.value.normalized_data["phases"]["start"]["layers"][0]["parameters"]["radius"] = 999.0
	var after_radius: float = float(glow_spec.parameters().get("radius", -1.0)) if glow_spec != null else -1.0
	tests.expect_true(before_radius != 999.0 and after_radius == before_radius, "Render Plan deep-copies type-specific parameters so later working edits cannot mutate the active valid Plan")


static func _test_asset_catalog_and_missing_fallback(tests: TestAssert) -> void:
	var registry_script := load("res://src/preview/rendering/vfx_preview_asset_registry.gd") as Script
	var resolver_script := load("res://src/preview/rendering/vfx_preview_asset_resolver.gd") as Script
	tests.expect_true(registry_script != null and resolver_script != null, "Preview Asset Registry and Resolver scripts are available")
	if registry_script == null or resolver_script == null:
		return
	var registry = registry_script.new()
	var resolver = resolver_script.new(registry)
	var known: VfxResult = resolver.resolve("fx.energy_shard")
	var missing: VfxResult = resolver.resolve("fx.not_in_catalog")
	var all_known := true
	for logical_id in ["fx.energy_shard", "fx.confetti_square", "fx.trail_streak", "fx.placeholder"]:
		var resolved: VfxResult = resolver.resolve(logical_id)
		all_known = all_known and resolved.success and resolved.value.get("is_fallback", true) == false and resolved.value.get("texture") is Texture2D
	tests.expect_true(known.success and all_known, "Preview Asset Registry resolves all four catalog logical ids with generated Preview textures and no Preset-specific branches")
	tests.expect_true(missing.success and missing.value.get("is_fallback", false) and missing.issues.size() == 1 and missing.issues[0].code == "preview_asset_missing", "unknown Preview logical assets use an explicit warning and magenta fallback without invalidating the Preset")


static func _test_vehicle_multi_anchor_expands_in_declared_order(tests: TestAssert) -> void:
	var builder_script := load("res://src/preview/rendering/vfx_preview_render_plan_builder.gd") as Script
	var resolver_script := load("res://src/preview/rendering/vfx_preview_instance_resolver.gd") as Script
	var pipeline := VfxPresetPipelineModel.new()
	var document_result: VfxResult = pipeline.load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if builder_script == null or resolver_script == null or not document_result.success:
		tests.expect_true(false, "Multi-anchor expansion requires the Plan Builder, Instance Resolver, and a valid document")
		return
	var normalized: Dictionary = document_result.value.normalized_data.duplicate(true)
	normalized["phases"]["start"]["layers"][0]["anchors"] = ["TIRE_FL", "TIRE_FR", "TIRE_RL", "TIRE_RR"]
	var plan_result: VfxResult = builder_script.new(_registry()).build(normalized)
	var instances_result: VfxResult = resolver_script.new(_registry()).resolve(plan_result.value, {"anchors": {"TIRE_FL": [-10, -10], "TIRE_FR": [10, -10], "TIRE_RL": [-10, 10], "TIRE_RR": [10, 10]}}) if plan_result.success else VfxResult.failure(plan_result.issues)
	var names: Array[String] = []
	if instances_result.success:
		for instance in instances_result.value:
			if instance.layer_spec().layer_id() == "start.inner_flash":
				names.append(instance.anchor_name())
	tests.expect_true(instances_result.success and names == ["TIRE_FL", "TIRE_FR", "TIRE_RL", "TIRE_RR"], "Vehicle-space Multi Anchor Layers expand into one renderer instance per declared Anchor in stable source order")


static func _test_factory_configuration_coverage(tests: TestAssert) -> void:
	var factory_script := load("res://src/preview/rendering/vfx_preview_renderer_factory.gd") as Script
	tests.expect_true(factory_script != null, "Preview Renderer Factory script is available")
	if factory_script == null:
		return
	var factory = factory_script.new({})
	var configuration: VfxResult = factory.validate_configuration(_registry())
	tests.expect_true(not configuration.success and not configuration.issues.is_empty(), "Renderer factory reports a configuration error when Schema Layer Types have no implementation registration")


static func _test_canvas_exposes_ordered_plane_hosts(tests: TestAssert) -> void:
	var packed := load("res://src/preview/vfx_vehicle_preview.tscn") as PackedScene
	var preview := packed.instantiate() if packed != null else null
	if preview == null:
		tests.expect_true(false, "Plane host test requires the reusable Vehicle Preview scene")
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(preview)
	var canvas: Node = preview.get_node_or_null("PreviewSurface/EditScroll/EditCanvas")
	var root: Node = canvas.get_node_or_null("StageWorldRoot") if canvas != null else null
	var vehicle_root: Node = root.get_node_or_null("FutureVfxHost") if root != null else null
	var has_hosts := root != null \
		and root.get_node_or_null("WorldPlaneHost") != null \
		and root.get_node_or_null("UnderFollowWorldHost") != null \
		and vehicle_root != null \
		and vehicle_root.get_node_or_null("UnderVehicleLocalHost") != null \
		and vehicle_root.get_node_or_null("VehicleArtHost") != null \
		and vehicle_root.get_node_or_null("OverVehicleLocalHost") != null \
		and root.get_node_or_null("OverFollowWorldHost") != null
	tests.expect_true(has_hosts, "Edit Canvas owns concrete WORLD, Under, Vehicle, and Over plane hosts instead of an empty FutureVfxHost")
	tree.root.remove_child(preview)
	preview.free()


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
