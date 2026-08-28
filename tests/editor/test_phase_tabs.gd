extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxPhaseTabsModel := preload("res://src/editor/workspace/vfx_phase_tabs.gd")


static func run(tests: TestAssert) -> void:
	var factory := VfxPresetSkeletonFactoryModel.new(_loaded_registry())
	var one_shot := factory.create("utility.flash", "Flash", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	var start_loop_end := factory.create("utility.channel", "Channel", "UTILITY", "START_LOOP_END", "WORLD_AREA")
	tests.expect_true(one_shot.success and start_loop_end.success, "phase tabs fixtures are valid Skeletons")
	if not one_shot.success or not start_loop_end.success:
		return

	var tabs := VfxPhaseTabsModel.new()
	tabs.set_duration_schemas({
		"one_shot": {"minimum": 0.001},
		"start": {"minimum": 0.001},
		"end": {"minimum": 0.001}
	})
	tabs.set_preset(one_shot.value)
	tests.expect_true(tabs.visible_phase_names() == ["one_shot"], "one-shot exposes its actual configured phase")
	tests.expect_true(tabs.selected_phase_name() == "one_shot", "first available phase is selected")
	tests.expect_true(tabs.phase_has_duration("one_shot"), "one-shot renders a duration control")

	tabs.set_preset(start_loop_end.value)
	tests.expect_true(tabs.visible_phase_names() == ["start", "loop", "end"], "start-loop-end exposes its configured phases")
	tests.expect_true(tabs.phase_has_duration("start") and tabs.phase_has_duration("end"), "timed boundary phases render duration controls")
	tests.expect_true(not tabs.phase_has_duration("loop"), "loop has no duration control")
	tabs.set_preset({"phases": {"unexpected": {"duration_seconds": 2.0, "layers": []}}})
	tests.expect_true(not tabs.phase_has_duration("unexpected"), "an unexpected phase never exposes a duration control")
	tabs.set_preset(start_loop_end.value)
	tabs.select_phase("end")
	tabs.select_phase("missing")
	tests.expect_true(tabs.selected_phase_name() == "end", "selecting an absent phase leaves the selected phase unchanged")
	tabs.free()


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
