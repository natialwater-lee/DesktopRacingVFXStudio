extends RefCounted

const VfxRuntimeModulationProgramModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_program.gd")
const VfxPreviewRuntimeInputStateModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd")
const VfxPreviewRuntimeModulationEvaluatorModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd")


static func run(tests: TestAssert) -> void:
	var program := VfxRuntimeModulationProgramModel.new([], [], PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array(), [], PackedFloat64Array(), PackedByteArray(), {}, {})
	var state := VfxPreviewRuntimeInputStateModel.new(program)
	var evaluator := VfxPreviewRuntimeModulationEvaluatorModel.new(program, state)
	tests.expect_true(program.binding_count() == 0 and evaluator.sampled_source_count_last_tick() == 0, "zero-binding static program has no modulation samples")
