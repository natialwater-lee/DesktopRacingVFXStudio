extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxParticleDirectionModel := preload("res://src/preview/rendering/vfx_particle_direction.gd")

const PRESET_PATH := "res://presets/examples/driving.rain_tire_spray.vfx.json"
const ASSET_ID := "fx.weather_rain_droplet"
# Shared rear-wheel contact (source px) used by the Game tire marks and weather wake strips.
const REAR_CONTACT_X := 84.0
const PARTICLE_Y := 172.0


static func run(tests: TestAssert) -> void:
	_test_droplet_asset_is_registered(tests)
	_test_rain_preset_uses_bilateral_wheel_droplets(tests)
	_test_droplets_kick_back_and_slightly_outward(tests)


static func _test_droplet_asset_is_registered(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var result: VfxResult = resolver.resolve(ASSET_ID)
	var image: Image = result.value.get("texture").get_image() if result.success and result.value.get("texture") is Texture2D else null
	tests.expect_true(
		result.success and result.value.get("source") == "TEXTURE" and not result.value.get("is_fallback", true) \
		and image != null and image.get_size() == Vector2i(24, 48),
		"Rain Tire Spray resolves the non-fallback 24x48 droplet texture"
	)


static func _test_rain_preset_uses_bilateral_wheel_droplets(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate(PRESET_PATH)
	var data: Dictionary = document_result.value.normalized_data if document_result.success else {}
	var phases: Dictionary = data.get("phases", {})
	var loop := _layers_by_id(phases.get("loop", {}).get("layers", []))
	var left: Dictionary = loop.get("loop.left_droplets", {})
	var right: Dictionary = loop.get("loop.right_droplets", {})
	tests.expect_true(
		document_result.success \
		and data.get("preset_id") == "driving.rain_tire_spray" \
		and data.get("category") == "WEATHER" \
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" \
		and data.get("runtime_inputs", []).is_empty() \
		and phases.get("start", {}).get("layers", []).is_empty() and is_equal_approx(float(phases.get("start", {}).get("duration_seconds", 0.0)), 0.05) \
		and phases.get("end", {}).get("layers", []).is_empty() and is_equal_approx(float(phases.get("end", {}).get("duration_seconds", 0.0)), 0.3) \
		and phases.get("loop", {}).get("layers", []).size() == 2 \
		and _wheel_layer_matches(left, -REAR_CONTACT_X) and _wheel_layer_matches(right, REAR_CONTACT_X),
		"Rain Tire Spray keeps only two CORE wheel droplet layers at the shared rear contact, with empty START/END phases"
	)


static func _test_droplets_kick_back_and_slightly_outward(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate(PRESET_PATH)
	var loop := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", [])) if document_result.success else {}
	var left_degrees := float(loop.get("loop.left_droplets", {}).get("parameters", {}).get("direction_degrees", 0.0))
	var right_degrees := float(loop.get("loop.right_droplets", {}).get("parameters", {}).get("direction_degrees", 0.0))
	var left_direction := VfxParticleDirectionModel.from_degrees(left_degrees)
	var right_direction := VfxParticleDirectionModel.from_degrees(right_degrees)
	tests.expect_true(
		document_result.success \
		and is_equal_approx(left_degrees + right_degrees, 360.0) \
		and left_direction.y > 0.9 and right_direction.y > 0.9 \
		and left_direction.x < 0.0 and right_direction.x > 0.0,
		"Rain Tire Spray droplets fly rearward with a small mirrored outward bias"
	)


static func _wheel_layer_matches(layer: Dictionary, contact_x: float) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var offset: Array = layer.get("transform", {}).get("offset", []) if layer.get("transform", {}).get("offset", []) is Array else []
	return layer.get("type") == "PARTICLE" \
		and layer.get("importance") == "CORE" \
		and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL" \
		and layer.get("blend_mode") == "ALPHA" \
		and layer.get("render_plane") == "UNDER_VEHICLE" \
		and parameters.get("emission_mode") == "CONTINUOUS" \
		and parameters.get("sprite_asset_ref") == ASSET_ID \
		and int(parameters.get("max_particles", 0)) == 2 \
		and offset.size() == 2 and is_equal_approx(float(offset[0]), contact_x) and is_equal_approx(float(offset[1]), PARTICLE_Y)


static func _layers_by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
