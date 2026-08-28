extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxLayerFactoryModel := preload("res://src/editor/factories/vfx_layer_factory.gd")
const VfxLayerStackModel := preload("res://src/editor/workspace/vfx_layer_stack.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")


static func run(tests: TestAssert) -> void:
	var registry := _loaded_registry()
	var skeleton_factory := VfxPresetSkeletonFactoryModel.new(registry)
	var layer_factory := VfxLayerFactoryModel.new(registry)
	var created := skeleton_factory.create("utility.channel", "Channel", "UTILITY", "START_LOOP_END", "WORLD_AREA")
	tests.expect_true(created.success, "layer stack fixture creates lifecycle Skeleton")
	if not created.success:
		return
	var first := layer_factory.create("GLOW", "loop", created.value)
	if not first.success:
		return
	var source: Dictionary = created.value.duplicate(true)
	source["phases"]["loop"]["layers"].append(first.value)
	var cross_phase_candidate: Dictionary = first.value.duplicate(true)
	cross_phase_candidate["id"] = "loop.glow_2"
	source["phases"]["start"]["layers"].append(cross_phase_candidate)
	var second := layer_factory.duplicate("loop", first.value, source)
	if not second.success:
		return
	source["phases"]["loop"]["layers"].append(second.value)
	var stack := VfxLayerStackModel.new(layer_factory)
	stack.set_available_layer_types(["GLOW"])
	stack.set_phase(source, "loop")
	stack.set_selected_layer_id(first.value["id"])
	var selected_row := stack.get_node_or_null("Rows/LayerRow0") as HBoxContainer
	tests.expect_true(selected_row != null, "Layer Stack creates one readable row per active-phase Layer")
	if selected_row != null:
		var select_layer := selected_row.get_node_or_null("SelectLayer") as Button
		var type_label := selected_row.get_node_or_null("Type") as Label
		var importance_label := selected_row.get_node_or_null("Importance") as Label
		var enabled := selected_row.get_node_or_null("Enabled") as CheckBox
		tests.expect_true(enabled != null and type_label != null and importance_label != null and select_layer != null, "Layer rows always show Enabled, Type, ID, and Importance")
		tests.expect_true(type_label.text == "GLOW" and importance_label.text == first.value["importance"], "Layer row summaries reflect Contract data")
		tests.expect_true(select_layer.button_pressed, "selected Layer uses the default pressed visual state")
		tests.expect_true(selected_row.get_node_or_null("Actions/Duplicate") is Button and selected_row.get_node_or_null("Actions/Delete") is Button, "only the selected Layer exposes row actions")
		tests.expect_true((selected_row.get_node("Actions/Duplicate") as Button).text == "Dup" and (selected_row.get_node("Actions/Delete") as Button).text == "Del", "selected row actions stay compact enough for the flexible Center pane")
	var unselected_row := stack.get_node_or_null("Rows/LayerRow1") as HBoxContainer
	tests.expect_true(unselected_row != null and unselected_row.get_node_or_null("Actions") == null, "unselected Layers keep their information area uncluttered")
	var long_id_source: Dictionary = source.duplicate(true)
	long_id_source["phases"]["loop"]["layers"][0]["id"] = "loop.extremely_long_layer_identifier_that_must_not_expand_the_center_pane"
	stack.set_phase(long_id_source, "loop")
	stack.set_selected_layer_id(long_id_source["phases"]["loop"]["layers"][0]["id"])
	tests.expect_true(stack.get_combined_minimum_size().x <= 320.0, "a selected long-id Layer row remains within the Center minimum width")

	var moved := stack.move_layer(source, "loop", 1, -1)
	tests.expect_true(moved["phases"]["loop"]["layers"][0]["id"] == second.value["id"], "move up changes active phase order")
	tests.expect_true(source["phases"]["loop"]["layers"][0]["id"] == first.value["id"], "move returns a deep-copied Preset")
	tests.expect_true(moved["phases"]["start"]["layers"][0]["id"] == cross_phase_candidate["id"] and moved["phases"]["end"]["layers"].is_empty(), "move leaves other phase arrays untouched")

	var toggled := stack.set_layer_enabled(source, "loop", first.value["id"], false)
	tests.expect_true(not toggled["phases"]["loop"]["layers"][0]["enabled"], "toggle changes only the requested Layer")
	tests.expect_true(source["phases"]["loop"]["layers"][0]["enabled"], "toggle does not alias source Layer")
	var deleted := stack.delete_layer(source, "loop", first.value["id"])
	tests.expect_true(deleted["phases"]["loop"]["layers"].size() == 1, "delete removes exactly one active-phase Layer")
	var duplicated := stack.duplicate_layer(source, "loop", first.value["id"])
	tests.expect_true(duplicated["phases"]["loop"]["layers"].size() == 3, "duplicate appends an active-phase Layer")
	tests.expect_true(duplicated["phases"]["loop"]["layers"][2]["id"] != cross_phase_candidate["id"], "duplicate avoids a candidate id already used in another phase")
	tests.expect_true(VfxPresetPipelineModel.new().build_document_from_value(duplicated).success, "Layer Stack duplicate remains Contract-valid")
	stack.set_phase(created.value, "start")
	var requested_layer_type := {"value": ""}
	stack.add_layer_requested.connect(func(layer_type: String) -> void: requested_layer_type["value"] = layer_type)
	var add_button := stack.get_node_or_null("Rows/AddControls/AddLayerButton") as Button
	var type_selector := stack.get_node_or_null("Rows/AddControls/LayerTypeSelector") as OptionButton
	tests.expect_true(add_button != null and not add_button.disabled, "Layer Stack exposes an enabled Add control for an empty active phase")
	tests.expect_true(type_selector != null and type_selector.selected == 0 and type_selector.get_item_text(type_selector.selected) == "GLOW", "Layer Stack Add selector retains its configured first Layer Type")
	if add_button != null:
		add_button.emit_signal("pressed")
	tests.expect_true(requested_layer_type["value"] == "GLOW", "Layer Stack Add control emits the selected Schema-provided Layer Type")
	stack.free()

	var controller := VfxEditorControllerModel.new()
	var controller_created := controller.create_new_preset("utility.controller", "Controller", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(controller_created.success, "controller creates a Preset for command history")
	if controller_created.success:
		controller.add_active_layer("GLOW")
		var selected_id: String = controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"]
		controller.select_layer(selected_id)
		controller.delete_active_layer(selected_id)
		tests.expect_true(controller.selected_layer_id().is_empty(), "deleting the selected Layer clears its stale selection")
		controller.undo()
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"] == selected_id, "undo restores the deleted Layer data")
		tests.expect_true(controller.selected_layer_id().is_empty(), "undo does not retain a stale deleted Layer id")
		controller.add_active_layer("GLOW")
		tests.expect_true(controller.can_undo(), "controller exposes history after a Preset A action")
		var replacement := controller.create_new_preset("utility.replacement", "Replacement", "UTILITY", "ONE_SHOT", "WORLD_AREA")
		tests.expect_true(replacement.success, "controller replaces Preset A with a new Preset B")
		tests.expect_true(not controller.can_undo(), "replacing the active Preset clears old history")
		controller.undo()
		tests.expect_true(controller.working_preset()["preset_id"] == "utility.replacement" and controller.working_preset()["phases"]["one_shot"]["layers"].is_empty(), "undo cannot restore Preset A into Preset B")


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
