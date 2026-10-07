extends RefCounted

const VfxPreviewEquipmentCatalogModel := preload("res://src/preview/equipment/vfx_preview_equipment_catalog.gd")
const VfxPreviewVehicleArtHostModel := preload("res://src/preview/rendering/vfx_preview_vehicle_art_host.gd")
const GAME_ROOT := "res://../DesktopIdleRacing/"
const GAME_DEFS_PATH := GAME_ROOT + "data/special_equipment/special_equipment_defs.json"


static func run(tests: TestAssert) -> void:
	_test_rotor_lift_catalog_and_frames(tests)
	_test_rotor_lift_placement_matches_game_formula(tests)
	_test_phase_frame_resolution(tests)
	_test_vehicle_art_host_equipment(tests)
	_test_game_copy_parity(tests)


static func _test_rotor_lift_catalog_and_frames(tests: TestAssert) -> void:
	var catalog := VfxPreviewEquipmentCatalogModel.new()
	var deploy := catalog.frames("rotor_lift", "mk1", "deploy")
	var retract := catalog.frames("rotor_lift", "mk1", "retract")
	var all_marks_loaded := true
	for mark_id in catalog.marks("rotor_lift"):
		all_marks_loaded = all_marks_loaded and catalog.frames("rotor_lift", mark_id, "active").size() == 24 and catalog.frames("rotor_lift", mark_id, "deploy").size() == 12
	tests.expect_true(
		catalog.equipment_type_for_preset("equipment.rotor_lift.downwash") == "rotor_lift" \
		and catalog.equipment_type_for_preset("talent.solo_run.static_ribbon").is_empty() \
		and catalog.marks("rotor_lift") == ["mk1", "mk2", "mk3", "mk4"] and all_marks_loaded \
		and retract.size() == deploy.size() and retract[0] == deploy[deploy.size() - 1] and retract[retract.size() - 1] == deploy[0],
		"Rotor Lift preview catalog resolves the downwash preset, Mk.I-IV, 24 active and 12 deploy frames, and RETRACT as reversed deploy"
	)


static func _test_rotor_lift_placement_matches_game_formula(tests: TestAssert) -> void:
	var catalog := VfxPreviewEquipmentCatalogModel.new()
	var placement := catalog.placement("rotor_lift", Vector2(256, 512), Vector2(256, 256))
	tests.expect_true(
		placement.get("anchor_position") == Vector2.ZERO and is_equal_approx(float(placement.get("equipment_scale")), 2.5) and placement.get("visual_layer") == "underlay",
		"Rotor Lift placement mirrors Game: vehicle center, 1.25 x (512 reference / 256 texture) = 2.5, underlay"
	)


static func _test_phase_frame_resolution(tests: TestAssert) -> void:
	var catalog := VfxPreviewEquipmentCatalogModel.new()
	var active := catalog.frames("rotor_lift", "mk1", "active")
	var retract := catalog.frames("rotor_lift", "mk1", "retract")
	tests.expect_true(
		catalog.resolve_frame("rotor_lift", "mk1", "active", 0.0) == active[0] \
		and catalog.resolve_frame("rotor_lift", "mk1", "active", 1.5 / 24.0) == active[1] \
		and catalog.resolve_frame("rotor_lift", "mk1", "active", 1.0 + 0.5 / 24.0) == active[0] \
		and catalog.resolve_frame("rotor_lift", "mk1", "retract", 0.0) == retract[0] \
		and catalog.resolve_frame("rotor_lift", "mk1", "retract", 0.49) == retract[retract.size() - 1] \
		and catalog.resolve_frame("rotor_lift", "mk1", "retract", 0.5) == null \
		and catalog.resolve_frame("rotor_lift", "mk1", "", 0.0) == null,
		"Equipment frames follow Game timing: active loops at 24 fps, retract spans 0.5 s then hides"
	)


static func _test_vehicle_art_host_equipment(tests: TestAssert) -> void:
	var host := VfxPreviewVehicleArtHostModel.new()
	var texture := VfxPreviewEquipmentCatalogModel.new().frames("rotor_lift", "mk1", "active")[0]
	host.set_equipment(texture, Vector2.ZERO, 2.5, false)
	var stored := host.equipment_texture() == texture
	host.set_equipment(null, Vector2.ZERO, 1.0, false)
	tests.expect_true(stored and host.equipment_texture() == null, "Vehicle art host stores and clears the mounted equipment frame")
	host.free()


# Dev-time drift check against the Game copy source; skipped when the Game project is absent.
static func _test_game_copy_parity(tests: TestAssert) -> void:
	var game_defs_path := ProjectSettings.globalize_path(GAME_DEFS_PATH)
	if not FileAccess.file_exists(game_defs_path):
		tests.expect_true(true, "Game project absent; equipment copy parity skipped")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(game_defs_path))
	var catalog := VfxPreviewEquipmentCatalogModel.new()
	var entry := catalog.entry("rotor_lift")
	var matched := parsed is Dictionary
	var game_marks: Array[String] = []
	for definition in (parsed.get("definitions", []) if parsed is Dictionary else []):
		if not definition is Dictionary or definition.get("equipment_type_id") != "rotor_lift" or not bool(definition.get("enabled", true)):
			continue
		var mark_id := str(definition.get("mark_id"))
		game_marks.append(mark_id)
		matched = matched \
			and definition.get("visual_layer") == entry.get("visual_layer") \
			and definition.get("visual_anchor", {}).get("normalized_position") == entry.get("normalized_position") \
			and definition.get("runtime_visual") == entry.get("runtime_visual") \
			and float(definition.get("equipment_scale", 1.0)) == float(entry.get("equipment_scale")) \
			and float(definition.get("active_frame_rate")) == float(entry.get("active_frame_rate")) \
			and float(definition.get("retract_duration_seconds")) == float(entry.get("retract_duration_seconds")) \
			and definition.get("vehicle_visual_overrides", {}).is_empty()
		for phase_id in ["active", "deploy"]:
			var index := 0
			while true:
				var game_png := ProjectSettings.globalize_path("%sassets/special_equipment/rotor_lift/%s/%s/frame_%02d.png" % [GAME_ROOT, mark_id, phase_id, index])
				var studio_png := ProjectSettings.globalize_path("%s/%s/%s/frame_%02d.png" % [str(entry.get("asset_root")), mark_id, phase_id, index])
				if not FileAccess.file_exists(game_png):
					matched = matched and not FileAccess.file_exists(studio_png)
					break
				matched = matched and FileAccess.get_md5(game_png) == FileAccess.get_md5(studio_png)
				index += 1
	tests.expect_true(matched and game_marks == catalog.marks("rotor_lift"), "Studio Rotor Lift preview copy matches Game definitions and frame PNGs")
