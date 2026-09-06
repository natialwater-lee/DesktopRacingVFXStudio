class_name VfxPreviewRuntimeModulationEvaluator
extends RefCounted

const VfxPreviewEffectiveLayerStateModel := preload("res://src/preview/runtime_modulation/vfx_preview_effective_layer_state.gd")
const VfxRuntimeModulationBindingSpecModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_binding_spec.gd")
const VfxRuntimeModulationSourceSpecModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_source_spec.gd")

var _program: RefCounted
var _input_state: RefCounted
var _source_values: PackedFloat64Array = PackedFloat64Array()
var _sampled_source_count_last_tick := 0


func _init(program: RefCounted, input_state: RefCounted) -> void:
	_program = program
	_input_state = input_state
	if _program != null:
		_source_values.resize(_program.source_count())


func create_effective_state(layer_spec: RefCounted) -> RefCounted:
	return VfxPreviewEffectiveLayerStateModel.new(_program, layer_spec)


func advance(instance_elapsed_seconds: float, active_states: Array) -> void:
	refresh(instance_elapsed_seconds, active_states)


func refresh(instance_elapsed_seconds: float, active_states: Array) -> void:
	_sample_sources(instance_elapsed_seconds)
	for state_value in active_states:
		if state_value is RefCounted:
			_compose_state(state_value)


func sampled_source_count_last_tick() -> int:
	return _sampled_source_count_last_tick


func _sample_sources(instance_elapsed_seconds: float) -> void:
	_sampled_source_count_last_tick = 0
	if _program == null:
		return
	for slot in _program.source_count():
		var source: RefCounted = _program.source_at(slot)
		match source.source_kind():
			VfxRuntimeModulationSourceSpecModel.SOURCE_OSCILLATOR_SINE:
				_source_values[slot] = sin(TAU * source.frequency_hz() * instance_elapsed_seconds + source.phase_radians())
			VfxRuntimeModulationSourceSpecModel.SOURCE_LINEAR_PHASE:
				_source_values[slot] = fposmod(instance_elapsed_seconds * source.frequency_hz(), 1.0)
		_sampled_source_count_last_tick += 1


func _compose_state(state: RefCounted) -> void:
	state.reset_from(_layer_spec_for_state(state))
	for binding in state.bindings():
		var sampled_input: float = _input_state.value_at(binding.source_slot()) if binding.source_kind() == VfxRuntimeModulationBindingSpecModel.SOURCE_RUNTIME_INPUT else _source_values[binding.source_slot()]
		var ratio: float = (sampled_input - binding.input_min()) / (binding.input_max() - binding.input_min())
		var contribution: float = lerpf(binding.output_min(), binding.output_max(), ratio)
		var current: float = state.effective_value(binding.target_slot())
		state.set_effective_value(binding.target_slot(), current + contribution if binding.operation_slot() == 0 else current * contribution)
	for clamp in state.clamps():
		var value: float = state.effective_value(clamp.target_slot())
		if clamp.has_minimum():
			value = maxf(value, clamp.minimum_effective())
		if clamp.has_maximum():
			value = minf(value, clamp.maximum_effective())
		state.set_effective_value(clamp.target_slot(), value)
	for target_slot in _program.target_count():
		if _program.target_has_minimum(target_slot):
			state.set_effective_value(target_slot, maxf(state.effective_value(target_slot), _program.target_minimum(target_slot)))


func _layer_spec_for_state(state: RefCounted) -> RefCounted:
	return state.layer_spec()
