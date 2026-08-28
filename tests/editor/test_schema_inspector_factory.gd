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
	for layer_type in ["PARTICLE", "TRAIL", "RING", "GLOW", "SHIELD"]:
		var parameter_schema: VfxResult = reader.layer_parameter_schema(layer_type)
		var fields: Array[Control] = factory.build_fields(parameter_schema.value, {})
		tests.expect_true(not fields.is_empty(), "%s has Schema-generated fields" % layer_type)
		_free_fields(fields)
	tests.expect_true(factory.control_kind_for({"type": "number", "minimum": 0.0, "maximum": 1.0}) == "SpinBox", "number range uses SpinBox")
	tests.expect_true(factory.control_kind_for({"type": "array", "minItems": 4, "maxItems": 4, "items": {"type": "number"}}) == "RGBA", "four-number vector uses RGBA row")
	tests.expect_true(factory.control_kind_for({"type": "array", "minItems": 2, "maxItems": 2, "items": {"type": "number"}}) == "Vector2", "two-number vector uses Vector2 row")
	tests.expect_true(factory.control_kind_for({"type": "boolean"}) == "CheckBox" and factory.control_kind_for({"type": "string"}) == "LineEdit", "v1 scalar controls map bool and string deliberately")
	var ranged_fields: Array[Control] = factory.build_fields({"type": "object", "properties": {"opacity": {"type": "number", "minimum": 0.0, "maximum": 1.0}}}, {"opacity": 0.5})
	var ranged_input := _find_field(ranged_fields, "opacity").find_child("Input", true, false) as SpinBox
	tests.expect_true(ranged_input.tooltip_text.contains("Minimum") and ranged_input.tooltip_text.contains("Maximum"), "numeric field tooltip presents its Schema range")
	_free_fields(ranged_fields)
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

	var continuous_parameters: Dictionary = particle["parameters"].duplicate(true)
	continuous_parameters["emission_mode"] = "CONTINUOUS"
	continuous_parameters.erase("burst_count")
	continuous_parameters["emission_rate_per_second"] = 10.0
	continuous_parameters["max_particles"] = 100
	var continuous_fields: Array[Control] = factory.build_fields(particle_schema, continuous_parameters)
	tests.expect_true(_find_field(continuous_fields, "burst_count") == null, "Particle CONTINUOUS form drops burst_count")
	tests.expect_true(_find_field(continuous_fields, "emission_rate_per_second") != null and _find_field(continuous_fields, "max_particles") != null, "Particle CONTINUOUS form exposes rate and capacity")
	_free_fields(continuous_fields)

	var circle_parameters: Dictionary = particle["parameters"].duplicate(true)
	circle_parameters["emitter"] = {"shape": "CIRCLE", "radius": 2.0}
	var circle_fields: Array[Control] = factory.build_fields(particle_schema, circle_parameters)
	var emitter_field := _find_field(circle_fields, "emitter")
	tests.expect_true(emitter_field != null and emitter_field.find_child("radius", true, false) != null, "Particle CIRCLE form exposes configured radius geometry")
	tests.expect_true(emitter_field != null and emitter_field.find_child("size", true, false) == null and emitter_field.find_child("length", true, false) == null, "Particle emitter form drops geometry illegal for the selected shape")
	_free_fields(circle_fields)

	_test_controller_parameter_commits_and_type_request(tests)
	_test_particle_selector_rebuild_and_invalid_save(tests)


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
		tests.expect_true(requested_type["value"] == "RING" and controller.working_preset()["phases"]["one_shot"]["layers"][0]["type"] == "GLOW", "Layer Type request asks for confirmation without replacing data")
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
