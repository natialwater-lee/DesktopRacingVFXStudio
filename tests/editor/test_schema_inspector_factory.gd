extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxLayerFactoryModel := preload("res://src/editor/factories/vfx_layer_factory.gd")
const VfxSchemaReaderModel := preload("res://src/editor/inspector/vfx_schema_reader.gd")
const VfxSchemaInspectorFactoryModel := preload("res://src/editor/inspector/vfx_schema_inspector_factory.gd")
const VfxPresetInspectorModel := preload("res://src/editor/inspector/vfx_preset_inspector.gd")
const VfxLayerInspectorModel := preload("res://src/editor/inspector/vfx_layer_inspector.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")


static func run(tests: TestAssert) -> void:
	var registry := _loaded_registry()
	var reader := VfxSchemaReaderModel.new(registry)
	var factory := VfxSchemaInspectorFactoryModel.new(reader)
	var expected_controls := {
		"PARTICLE": {"emission_mode": "OptionButton", "emitter": "VBoxContainer", "burst_count": "SpinBox", "sprite_asset_ref": "LineEdit", "acceleration": "HBoxContainer", "color_rgba": "HBoxContainer"},
		"TRAIL": {"texture_asset_ref": "LineEdit", "max_points": "SpinBox", "color_rgba": "HBoxContainer"},
		"RING": {"radius_start": "SpinBox", "duration_seconds": "SpinBox", "color_rgba": "HBoxContainer"},
		"GLOW": {"radius": "SpinBox", "opacity": "SpinBox", "color_rgba": "HBoxContainer"},
		"SHIELD": {"radius": "SpinBox", "arc_degrees": "SpinBox", "texture_asset_ref": "LineEdit", "color_rgba": "HBoxContainer"},
	}
	for layer_type in expected_controls:
		var parameter_schema: VfxResult = reader.layer_parameter_schema(layer_type)
		var fields: Array[Control] = factory.build_fields(parameter_schema.value, {})
		for field_name in expected_controls[layer_type]:
			var field := _find_field(fields, field_name)
			var input_name := "Fields" if field_name == "emitter" else "Input"
			var input := field.find_child(input_name, true, false) if field != null else null
			tests.expect_true(input != null and input.get_class() == expected_controls[layer_type][field_name], "%s.%s uses the expected current-Schema control" % [layer_type, field_name])
		_free_fields(fields)
	tests.expect_true(factory.control_kind_for({"type": "number", "minimum": 0.0, "maximum": 1.0}) == "SpinBox", "number range uses SpinBox")
	tests.expect_true(factory.control_kind_for({"type": "array", "minItems": 4, "maxItems": 4, "items": {"type": "number"}}) == "RGBA", "four-number vector uses RGBA row")
	tests.expect_true(factory.control_kind_for({"type": "array", "minItems": 2, "maxItems": 2, "items": {"type": "number"}}) == "Vector2", "two-number vector uses Vector2 row")
	var glow_schema: Dictionary = reader.layer_parameter_schema("GLOW").value
	var glow_fields: Array[Control] = factory.build_fields(glow_schema, {})
	var opacity_input := _find_field(glow_fields, "opacity").find_child("Input", true, false) as SpinBox
	tests.expect_true(opacity_input.min_value == 0.0 and opacity_input.max_value == 1.0 and opacity_input.tooltip_text.contains("Minimum") and opacity_input.tooltip_text.contains("Maximum"), "actual GLOW opacity control presents Schema bounds and tooltip")
	var color_row := _find_field(glow_fields, "color_rgba").find_child("Input", true, false) as HBoxContainer
	tests.expect_true((color_row.get_node("R") as SpinBox).value == 1.0 and (color_row.get_node("A") as SpinBox).value == 1.0, "local color_rgba ref displays its explicit Schema default")
	_free_fields(glow_fields)
	var diagnostic_fields: Array[Control] = factory.build_fields({"type": "object", "properties": {"curve": {"oneOf": []}}}, {})
	var diagnostic := _find_field(diagnostic_fields, "curve")
	tests.expect_true(diagnostic != null and diagnostic.find_child("ConfigurationDiagnostic", true, false) is Label, "unsupported Schema nodes show a configuration diagnostic")
	_free_fields(diagnostic_fields)

	var skeleton_factory := VfxPresetSkeletonFactoryModel.new(registry)
	var layer_factory := VfxLayerFactoryModel.new(registry)
	var pipeline := VfxPresetPipelineModel.new()
	var created_preset: VfxResult = skeleton_factory.create("utility.schema_inspector", "Schema Inspector", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created_preset.success, "type form test creates a Preset Skeleton")
	if not created_preset.success:
		return
	var preset: Dictionary = created_preset.value
	for layer_type in ["PARTICLE", "TRAIL", "RING", "GLOW", "SHIELD"]:
		var layer_result: VfxResult = layer_factory.create(layer_type, "one_shot", preset)
		tests.expect_true(layer_result.success, "%s form starts from type factory values" % layer_type)
		if layer_result.success:
			preset["phases"]["one_shot"]["layers"].append(layer_result.value)
			tests.expect_true(pipeline.build_document_from_value(preset).success, "%s type factory values remain Pipeline-valid" % layer_type)

	var particle: Dictionary = preset["phases"]["one_shot"]["layers"][0]
	var particle_schema: Dictionary = reader.layer_parameter_schema("PARTICLE").value
	var burst_fields: Array[Control] = factory.build_fields(particle_schema, particle["parameters"])
	tests.expect_true(_find_field(burst_fields, "burst_count") != null, "Particle BURST form exposes burst_count")
	tests.expect_true(_find_field(burst_fields, "emission_rate_per_second") == null and _find_field(burst_fields, "max_particles") == null, "Particle BURST form drops continuous-only controls")
	var commit_capture := {"suffix": "", "value": null}
	var emission_field := _find_field(burst_fields, "emission_mode")
	if emission_field != null:
		emission_field.field_committed.connect(func(suffix: String, value: Variant) -> void:
			commit_capture["suffix"] = suffix
			commit_capture["value"] = value
		)
		var emission_select := emission_field.find_child("Input", true, false) as OptionButton
		var continuous_index := _item_index(emission_select, "CONTINUOUS")
		emission_select.select(continuous_index)
		emission_select.emit_signal("item_selected", continuous_index)
	tests.expect_true(commit_capture == {"suffix": "/emission_mode", "value": "CONTINUOUS"}, "generated enum field emits its JSON Pointer suffix and value")
	_free_fields(burst_fields)

	var signal_fields: Array[Control] = factory.build_fields(particle_schema, particle["parameters"])
	var signal_capture := {"suffix": "", "value": null}
	var burst_count_field := _find_field(signal_fields, "burst_count")
	burst_count_field.field_committed.connect(func(suffix: String, value: Variant) -> void: signal_capture.assign({"suffix": suffix, "value": value}))
	var burst_count_input := burst_count_field.find_child("Input", true, false) as SpinBox
	burst_count_input.value = 7.0
	burst_count_input.get_line_edit().emit_signal("focus_exited")
	tests.expect_true(signal_capture == {"suffix": "/burst_count", "value": 7}, "actual Particle integer control emits an integer and JSON Pointer")
	signal_capture.assign({"suffix": "", "value": null})
	var acceleration_field := _find_field(signal_fields, "acceleration")
	acceleration_field.field_committed.connect(func(suffix: String, value: Variant) -> void: signal_capture.assign({"suffix": suffix, "value": value}))
	var acceleration_row := acceleration_field.find_child("Input", true, false) as HBoxContainer
	(acceleration_row.get_node("X") as SpinBox).value = 2.5
	(acceleration_row.get_node("X") as SpinBox).get_line_edit().emit_signal("focus_exited")
	tests.expect_true(signal_capture["suffix"] == "/acceleration" and signal_capture["value"] == [2.5, 0.0], "actual Particle Vector2 row emits its full array and JSON Pointer")
	signal_capture.assign({"suffix": "", "value": null})
	var emitter_signal_field := _find_field(signal_fields, "emitter")
	emitter_signal_field.field_committed.connect(func(suffix: String, value: Variant) -> void: signal_capture.assign({"suffix": suffix, "value": value}))
	var shape_select := emitter_signal_field.find_child("shape", true, false).find_child("Input", true, false) as OptionButton
	var circle_index := _item_index(shape_select, "CIRCLE")
	shape_select.select(circle_index)
	shape_select.emit_signal("item_selected", circle_index)
	tests.expect_true(signal_capture == {"suffix": "/emitter/shape", "value": "CIRCLE"}, "actual nested emitter enum propagates its full JSON Pointer")
	_free_fields(signal_fields)

	var glow_signal_fields: Array[Control] = factory.build_fields(glow_schema, {"radius": 1.0, "opacity": 0.5, "color_rgba": [1.0, 1.0, 1.0, 1.0]})
	var rgba_capture := {"suffix": "", "value": null}
	var rgba_field := _find_field(glow_signal_fields, "color_rgba")
	rgba_field.field_committed.connect(func(suffix: String, value: Variant) -> void: rgba_capture.assign({"suffix": suffix, "value": value}))
	var rgba_row := rgba_field.find_child("Input", true, false) as HBoxContainer
	(rgba_row.get_node("G") as SpinBox).value = 0.5
	(rgba_row.get_node("G") as SpinBox).get_line_edit().emit_signal("focus_exited")
	tests.expect_true(rgba_capture == {"suffix": "/color_rgba", "value": [1.0, 0.5, 1.0, 1.0]}, "actual GLOW RGBA row emits its full array and JSON Pointer")
	_free_fields(glow_signal_fields)

	var common_fields: Array[Control] = factory.build_fields(reader.layer_schema().value, {"enabled": true})
	var bool_capture := {"suffix": "", "value": null}
	var enabled_field := _find_field(common_fields, "enabled")
	enabled_field.field_committed.connect(func(suffix: String, value: Variant) -> void: bool_capture.assign({"suffix": suffix, "value": value}))
	var enabled_input := enabled_field.find_child("Input", true, false) as CheckBox
	enabled_input.button_pressed = false
	enabled_input.emit_signal("toggled", false)
	tests.expect_true(bool_capture == {"suffix": "/enabled", "value": false}, "actual Layer boolean control emits its value and JSON Pointer")
	_free_fields(common_fields)

	var continuous_parameters: Dictionary = particle["parameters"].duplicate(true)
	continuous_parameters["emission_mode"] = "CONTINUOUS"
	continuous_parameters.erase("burst_count")
	continuous_parameters["emission_rate_per_second"] = 10.0
	continuous_parameters["max_particles"] = 100
	var continuous_fields: Array[Control] = factory.build_fields(particle_schema, continuous_parameters)
	tests.expect_true(_find_field(continuous_fields, "burst_count") == null, "Particle CONTINUOUS form drops burst_count")
	tests.expect_true(_find_field(continuous_fields, "emission_rate_per_second") != null and _find_field(continuous_fields, "max_particles") != null, "Particle CONTINUOUS form exposes rate and capacity")
	_free_fields(continuous_fields)

	var missing_continuous: Dictionary = {"emission_mode": "CONTINUOUS", "emitter": {"shape": "POINT"}}
	var missing_continuous_fields: Array[Control] = factory.build_fields(particle_schema, missing_continuous)
	var missing_number_capture := {"count": 0}
	var missing_rate_field := _find_field(missing_continuous_fields, "emission_rate_per_second")
	missing_rate_field.field_committed.connect(func(_suffix: String, _value: Variant) -> void: missing_number_capture["count"] += 1)
	var missing_rate_input := missing_rate_field.find_child("Input", true, false) as SpinBox
	missing_rate_input.get_line_edit().emit_signal("focus_exited")
	tests.expect_true(missing_rate_input.get_line_edit().text.is_empty() and missing_number_capture["count"] == 0, "required missing number remains visibly unset and does not commit an invented minimum")
	_free_fields(missing_continuous_fields)

	var shield_schema: Dictionary = reader.layer_parameter_schema("SHIELD").value
	var shield_parameters: Dictionary = preset["phases"]["one_shot"]["layers"][4]["parameters"]
	var shield_fields: Array[Control] = factory.build_fields(shield_schema, shield_parameters)
	var string_capture := {"count": 0, "suffix": "", "value": null}
	var texture_field := _find_field(shield_fields, "texture_asset_ref")
	texture_field.field_committed.connect(func(suffix: String, value: Variant) -> void:
		string_capture["count"] += 1
		string_capture["suffix"] = suffix
		string_capture["value"] = value
	)
	var texture_input := texture_field.find_child("Input", true, false) as LineEdit
	texture_input.emit_signal("focus_exited")
	tests.expect_true(texture_input.text.is_empty() and string_capture["count"] == 0, "optional missing SHIELD texture remains unset on untouched focus exit")
	texture_input.text = "fx.shield"
	texture_input.emit_signal("focus_exited")
	tests.expect_true(string_capture == {"count": 1, "suffix": "/texture_asset_ref", "value": "fx.shield"}, "user-authored actual SHIELD string emits its JSON Pointer")
	_free_fields(shield_fields)

	var circle_parameters: Dictionary = particle["parameters"].duplicate(true)
	circle_parameters["emitter"] = {"shape": "CIRCLE", "radius": 2.0}
	var circle_fields: Array[Control] = factory.build_fields(particle_schema, circle_parameters)
	var emitter_field := _find_field(circle_fields, "emitter")
	tests.expect_true(emitter_field != null and emitter_field.find_child("radius", true, false) != null, "Particle CIRCLE form exposes configured radius geometry")
	tests.expect_true(emitter_field != null and emitter_field.find_child("size", true, false) == null and emitter_field.find_child("length", true, false) == null, "Particle emitter form drops geometry illegal for the selected shape")
	_free_fields(circle_fields)

	_test_controller_parameter_commits_and_type_request(tests)
	_test_particle_selector_rebuild_and_invalid_save(tests)
	_test_controller_preserves_absent_optional_parameter(tests)


static func _test_controller_parameter_commits_and_type_request(tests: TestAssert) -> void:
	var controller := VfxEditorControllerModel.new()
	var host := Control.new()
	var preset_inspector := VfxPresetInspectorModel.new()
	var layer_inspector := VfxLayerInspectorModel.new()
	host.add_child(preset_inspector)
	host.add_child(layer_inspector)
	controller.configure_inspectors(preset_inspector, layer_inspector)
	var created: VfxResult = controller.create_new_preset("utility.parameter_commit", "Parameter Commit", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success and controller.add_active_layer("GLOW"), "controller creates a Layer for parameter commits")
	if created.success:
		controller.select_layer("one_shot.glow")
		var radius_field := layer_inspector.find_child("radius", true, false)
		var radius_input := radius_field.find_child("Input", true, false) as SpinBox if radius_field != null else null
		if radius_input != null:
			radius_input.value = 12.0
			radius_input.get_line_edit().emit_signal("focus_exited")
		var glow: Dictionary = controller.working_preset()["phases"]["one_shot"]["layers"][0]
		tests.expect_true(glow["parameters"].get("radius") == 12.0, "generated parameter commit traverses Layer Inspector and controller snapshot")
		tests.expect_true(controller.current_issues().is_empty(), "valid parameter commit refreshes Pipeline diagnostics")

		var requested_type := {"value": ""}
		controller.layer_type_change_confirmation_requested.connect(func(target_type: String) -> void: requested_type["value"] = target_type)
		var type_select := layer_inspector.get_node_or_null("LayerType") as OptionButton
		var ring_index := _item_index(type_select, "RING")
		type_select.select(ring_index)
		type_select.emit_signal("item_selected", ring_index)
		tests.expect_true(requested_type["value"] == "RING" and controller.working_preset()["phases"]["one_shot"]["layers"][0]["type"] == "GLOW" and type_select.get_item_text(type_select.selected) == "GLOW", "Layer Type request restores the selector and asks for confirmation without replacing data")
		controller.undo()
		var after_request_undo: Dictionary = controller.working_preset()["phases"]["one_shot"]["layers"][0]
		tests.expect_true(after_request_undo["type"] == "GLOW" and after_request_undo["parameters"]["radius"] == 0.0, "unconfirmed Layer Type request creates no history action")
		controller.redo()
		controller.select_layer("one_shot.glow")
		controller.change_selected_layer_type("RING")
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["type"] == "RING", "confirmed Layer Type replacement commits one snapshot")
		controller.undo()
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["type"] == "GLOW", "confirmed Layer Type replacement is undoable")
	host.free()


static func _test_particle_selector_rebuild_and_invalid_save(tests: TestAssert) -> void:
	var controller := VfxEditorControllerModel.new()
	var host := Control.new()
	var preset_inspector := VfxPresetInspectorModel.new()
	var layer_inspector := VfxLayerInspectorModel.new()
	host.add_child(preset_inspector)
	host.add_child(layer_inspector)
	controller.configure_inspectors(preset_inspector, layer_inspector)
	var created: VfxResult = controller.create_new_preset("utility.particle_rebuild", "Particle Rebuild", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	if created.success and controller.add_active_layer("PARTICLE"):
		controller.select_layer("one_shot.particle")
		var emission_field := layer_inspector.find_child("emission_mode", true, false)
		var emission_select := emission_field.find_child("Input", true, false) as OptionButton if emission_field != null else null
		var continuous_index := _item_index(emission_select, "CONTINUOUS")
		emission_select.select(continuous_index)
		emission_select.emit_signal("item_selected", continuous_index)
		var parameters: Dictionary = controller.working_preset()["phases"]["one_shot"]["layers"][0]["parameters"]
		tests.expect_true(parameters["emission_mode"] == "CONTINUOUS" and not parameters.has("burst_count") and not controller.current_issues().is_empty(), "selector commit removes Schema-forbidden fields and retains missing-required diagnostics")
		tests.expect_true(layer_inspector.find_child("burst_count", true, false) == null and layer_inspector.find_child("emission_rate_per_second", true, false) != null, "emission selector commit rebuilds the configured Particle form")

		var emitter_field := layer_inspector.find_child("emitter", true, false)
		var shape_field := emitter_field.find_child("shape", true, false) if emitter_field != null else null
		var shape_select := shape_field.find_child("Input", true, false) as OptionButton if shape_field != null else null
		var circle_index := _item_index(shape_select, "CIRCLE")
		shape_select.select(circle_index)
		shape_select.emit_signal("item_selected", circle_index)
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["parameters"]["emitter"]["shape"] == "CIRCLE", "nested generated JSON Pointer commit reaches controller parameter data")
		var rebuilt_emitter := layer_inspector.find_child("emitter", true, false)
		tests.expect_true(rebuilt_emitter != null and rebuilt_emitter.find_child("radius", true, false) != null and rebuilt_emitter.find_child("size", true, false) == null, "emitter shape selector commit rebuilds only configured geometry fields")
		var radius_input := rebuilt_emitter.find_child("radius", true, false).find_child("Input", true, false) as SpinBox
		radius_input.value = 2.0
		radius_input.get_line_edit().emit_signal("focus_exited")
		var refreshed_emitter := layer_inspector.find_child("emitter", true, false)
		var refreshed_shape := refreshed_emitter.find_child("shape", true, false).find_child("Input", true, false) as OptionButton
		var box_index := _item_index(refreshed_shape, "BOX")
		refreshed_shape.select(box_index)
		refreshed_shape.emit_signal("item_selected", box_index)
		var box_emitter_data: Dictionary = controller.working_preset()["phases"]["one_shot"]["layers"][0]["parameters"]["emitter"]
		var box_emitter_fields := layer_inspector.find_child("emitter", true, false)
		tests.expect_true(not box_emitter_data.has("radius") and box_emitter_fields.find_child("size", true, false) != null and box_emitter_fields.find_child("radius", true, false) == null, "shape selector removes geometry forbidden by the configured Particle rule")

		var invalid_path := "res://presets/_phase1_task8_invalid.vfx.json"
		var save_result: VfxResult = controller.save_as(invalid_path, true)
		tests.expect_true(not save_result.success and not FileAccess.file_exists(invalid_path), "Task 5 valid-only save policy rejects a transient-invalid parameter edit")
	else:
		tests.expect_true(false, "controller creates a Particle Layer for selector rebuild tests")
	host.free()


static func _test_controller_preserves_absent_optional_parameter(tests: TestAssert) -> void:
	var controller := VfxEditorControllerModel.new()
	var host := Control.new()
	var preset_inspector := VfxPresetInspectorModel.new()
	var layer_inspector := VfxLayerInspectorModel.new()
	host.add_child(preset_inspector)
	host.add_child(layer_inspector)
	controller.configure_inspectors(preset_inspector, layer_inspector)
	var created: VfxResult = controller.create_new_preset("utility.absent_parameter", "Absent Parameter", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	if created.success and controller.add_active_layer("SHIELD"):
		controller.select_layer("one_shot.shield")
		var texture_field := layer_inspector.find_child("texture_asset_ref", true, false)
		var texture_input := texture_field.find_child("Input", true, false) as LineEdit if texture_field != null else null
		texture_input.emit_signal("focus_exited")
		var untouched_parameters: Dictionary = controller.working_preset()["phases"]["one_shot"]["layers"][0]["parameters"]
		tests.expect_true(not untouched_parameters.has("texture_asset_ref"), "untouched absent SHIELD texture stays absent through Inspector focus and refresh")
		texture_input.text = "fx.shield"
		texture_input.emit_signal("focus_exited")
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["parameters"].get("texture_asset_ref") == "fx.shield", "user-authored optional string propagates through controller JSON Pointer data")
	else:
		tests.expect_true(false, "controller creates SHIELD Layer for absent-parameter preservation")
	host.free()


static func _find_field(fields: Array[Control], field_name: String) -> Control:
	for field in fields:
		if field.name == field_name:
			return field
	return null


static func _item_index(select: OptionButton, item_text: String) -> int:
	if select == null:
		return -1
	for index in select.item_count:
		if select.get_item_text(index) == item_text:
			return index
	return -1


static func _free_fields(fields: Array[Control]) -> void:
	for field in fields:
		field.free()


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
