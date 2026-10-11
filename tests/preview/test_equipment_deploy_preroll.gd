extends RefCounted

# Game order: DEPLOYING plays deploy frames for 0.5 s, then ACTIVE starts the VFX.
# The Vehicle Preview reproduces it by holding the VFX during a deploy pre-roll.

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewEquipmentCatalogModel := preload("res://src/preview/equipment/vfx_preview_equipment_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")


static func run(tests: TestAssert) -> void:
	_test_downforce_wing_preroll(tests)
	_test_super_booster_has_no_preroll(tests)


static func _test_downforce_wing_preroll(tests: TestAssert) -> void:
	var preview := _make_preview("res://presets/examples/equipment.downforce_wing.wind_streak.vfx.json", "gt")
	if preview == null:
		tests.expect_true(false, "Deploy pre-roll test requires the Preview scene, GT profile and Downforce Wing preset")
		return
	var catalog := VfxPreviewEquipmentCatalogModel.new()
	var deploy := catalog.frames("downforce_wing", "mk1", "deploy")
	var active := catalog.frames("downforce_wing", "mk1", "active")
	var playback: RefCounted = preview.get("_playback")
	preview.call("_process", 0.0)
	tests.expect_true(float(preview.get("_equipment_deploy_elapsed")) == 0.0 and _equipment_texture(preview) == deploy[0] and playback.simulation_time() == 0.0, "Equipment preset run begins with deploy frame 0 and the VFX held at time zero")
	preview.call("_process", 0.25)
	tests.expect_true(_equipment_texture(preview) == deploy[6] and playback.simulation_time() == 0.0, "Deploy frames advance over 0.5 s while the VFX stays held")
	var generation: int = playback.generation()
	playback.pause()
	preview.call("_process", 0.5)
	tests.expect_true(_equipment_texture(preview) == deploy[6] and float(preview.get("_equipment_deploy_elapsed")) == 0.25, "Pausing freezes the deploy pre-roll")
	playback.play()
	preview.call("_process", 0.3)
	tests.expect_true(float(preview.get("_equipment_deploy_elapsed")) < 0.0 and playback.generation() == generation + 1 and playback.simulation_time() == 0.0, "VFX START restarts exactly when deploy ends (equipment ACTIVE)")
	preview.call("_process", 0.1)
	tests.expect_true(playback.simulation_time() > 0.0 and _equipment_texture(preview) == active[2], "After deploy the VFX runs and the equipment loops its active frames")
	preview.call("_process", 0.1)
	tests.expect_true(float(preview.get("_equipment_deploy_elapsed")) < 0.0, "The pre-roll runs once per playback run")
	_free_preview(preview)


static func _test_super_booster_has_no_preroll(tests: TestAssert) -> void:
	var preview := _make_preview("res://presets/examples/equipment.super_booster.vfx.json", "hyper")
	if preview == null:
		tests.expect_true(false, "Super Booster pre-roll test requires the Preview scene, Hyper profile and preset")
		return
	var playback: RefCounted = preview.get("_playback")
	preview.call("_process", 0.1)
	tests.expect_true(float(preview.get("_equipment_deploy_elapsed")) < 0.0 and playback.simulation_time() > 0.0, "Super Booster starts its VFX with DEPLOYING, so it has no pre-roll")
	_free_preview(preview)


static func _make_preview(preset_path: String, profile_id: String) -> Node:
	var packed := load("res://src/preview/vfx_vehicle_preview.tscn") as PackedScene
	var loaded: VfxResult = VfxPresetPipelineModel.new().load_and_validate(preset_path)
	var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://profiles/vehicles/%s.vehicle_profile.json" % profile_id))
	if packed == null or not loaded.success or not profile is Dictionary:
		return null
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	var plan: VfxResult = VfxPreviewRenderPlanBuilderModel.new(registry).build(loaded.value.normalized_data)
	if not plan.success:
		return null
	var preview := packed.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)
	preview.set_process(false)
	preview.set_schema_registry(registry)
	preview.set_profile_data(profile)
	preview.apply_render_plan(plan.value)
	return preview


static func _equipment_texture(preview: Node) -> Texture2D:
	var canvas: Control = preview.call("_game_canvas")
	var hosts: Dictionary = canvas.get("_plane_hosts") if canvas != null else {}
	var vehicle_art: Node = hosts.get("vehicle_art")
	return vehicle_art.equipment_texture() if vehicle_art != null else null


static func _free_preview(preview: Node) -> void:
	preview.get_parent().remove_child(preview)
	preview.free()
