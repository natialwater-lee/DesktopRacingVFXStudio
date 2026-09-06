extends RefCounted

const VfxRuntimeModulationProgramModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_program.gd")
const VfxPreviewRuntimeInputStateModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd")
const VfxPreviewRuntimeModulationEvaluatorModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd")
const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	var program := VfxRuntimeModulationProgramModel.new([], [], PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), [], PackedFloat64Array(), PackedByteArray(), {}, {})
	var state := VfxPreviewRuntimeInputStateModel.new(program)
	var evaluator := VfxPreviewRuntimeModulationEvaluatorModel.new(program, state)
	tests.expect_true(program.binding_count() == 0 and evaluator.sampled_source_count_last_tick() == 0, "zero-binding static program has no modulation samples")
	_test_linear_phase_fixed_program_tick_path(tests)


static func _test_linear_phase_fixed_program_tick_path(tests: TestAssert) -> void:
	var fixture: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.linear_phase_rotation_fixture.vfx.json")
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(fixture.value.normalized_data) if fixture.success else VfxResult.failure(fixture.issues)
	if not plan_result.success:
		tests.expect_true(false, "LINEAR_PHASE fixed-cost tick assertion requires the validated two-source fixture")
		return
	var program: RefCounted = plan_result.value.runtime_modulation_program()
	var source_zero: RefCounted = program.source_at(0)
	var source_one: RefCounted = program.source_at(1)
	var evaluator := VfxPreviewRuntimeModulationEvaluatorModel.new(program, VfxPreviewRuntimeInputStateModel.new(program))
	var states: Array = []
	for layer_spec in plan_result.value.phase_named("one_shot").layer_specs():
		states.append(evaluator.create_effective_state(layer_spec))
	var stable: bool = program.source_count() == 2 and program.binding_count() == 4 and source_zero != null and source_one != null
	for tick in 100:
		evaluator.refresh(float(tick) * 0.01, states)
		stable = stable and evaluator.sampled_source_count_last_tick() == 2 and is_same(program.source_at(0), source_zero) and is_same(program.source_at(1), source_one)
	tests.expect_true(stable, "two LINEAR_PHASE sources and four bindings keep one compiled program and immutable source identities across 100 steady-state ticks")


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
