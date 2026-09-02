extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxLayerFactoryModel := preload("res://src/editor/factories/vfx_layer_factory.gd")


static func run(tests: TestAssert) -> void:
	var registry := _loaded_registry()
	var skeleton_factory := VfxPresetSkeletonFactoryModel.new(registry)
	var layer_factory := VfxLayerFactoryModel.new(registry)
	var pipeline := VfxPresetPipelineModel.new()
	var skeleton := skeleton_factory.create("utility.flash", "Flash", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(skeleton.success, "Layer factory test creates Skeleton")
	if not skeleton.success:
		return
	var added := layer_factory.create("PARTICLE", "one_shot", skeleton.value)
	tests.expect_true(added.success, "Particle factory creates a Layer")
	if not added.success:
		return
	tests.expect_true(added.value["parameters"]["sprite_asset_ref"] == "fx.placeholder", "Particle factory owns explicit asset initial value")
	tests.expect_true(added.value["id"] == "one_shot.particle", "new Layer id derives from phase and Layer Type")
	tests.expect_true(added.value["render_plane"] == "WORLD", "render plane derives from effective world Space Mode")
	tests.expect_true(not added.value.has("space_mode"), "new Layer inherits Preset Space Mode")
	tests.expect_true(not added.value.has("anchors"), "world Space Mode Layer omits vehicle Anchors")
	tests.expect_true(added.value["enabled"] == true, "new Layer materializes Schema defaults")
	var with_particle: Dictionary = skeleton.value.duplicate(true)
	with_particle["phases"]["one_shot"]["layers"].append(added.value)
	tests.expect_true(pipeline.build_document_from_value(with_particle).success, "new Particle Layer completes a valid Preset")

	var duplicate := layer_factory.duplicate("one_shot", added.value, with_particle)
	tests.expect_true(duplicate.success, "Layer factory duplicates a Layer")
	if duplicate.success:
		tests.expect_true(duplicate.value["id"] == "one_shot.particle_2", "duplicate Layer id has deterministic global suffix")
		tests.expect_true(duplicate.value["parameters"] == added.value["parameters"], "duplicate retains type-specific fields")
		var with_duplicate: Dictionary = with_particle.duplicate(true)
		with_duplicate["phases"]["one_shot"]["layers"].append(duplicate.value)
		tests.expect_true(pipeline.build_document_from_value(with_duplicate).success, "duplicated Layer remains Contract-valid")

	var vehicle_skeleton := skeleton_factory.create("utility.vehicle_flash", "Vehicle Flash", "UTILITY", "ONE_SHOT", "VEHICLE_LOCAL")
	if vehicle_skeleton.success:
		var glow := layer_factory.create("GLOW", "one_shot", vehicle_skeleton.value)
		tests.expect_true(glow.success, "Glow factory creates a vehicle-local Layer")
		if glow.success:
			tests.expect_true(glow.value["anchors"] == ["CENTER"], "vehicle-local Layer uses Schema Anchor CENTER")
			tests.expect_true(glow.value["render_plane"] == "UNDER_VEHICLE", "vehicle render plane derives from Schema rule")
		var textured_sprite := layer_factory.create("TEXTURED_SPRITE", "one_shot", vehicle_skeleton.value)
		tests.expect_true(textured_sprite.success and textured_sprite.value["parameters"].get("texture_asset_ref") == "fx.placeholder" and textured_sprite.value["parameters"].get("opacity") == 1.0, "generic static texture Layer creation derives placeholder asset and default opacity without a type-specific editor branch")


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
