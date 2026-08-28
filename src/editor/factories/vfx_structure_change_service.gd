class_name VfxStructureChangeService
extends RefCounted

var _skeleton_factory
var _layer_factory


func _init(skeleton_factory: Variant, layer_factory: Variant) -> void:
	_skeleton_factory = skeleton_factory
	_layer_factory = layer_factory


func replace_lifecycle(preset: Dictionary, lifecycle_mode: String) -> VfxResult:
	var phases: VfxResult = _skeleton_factory.create_phase_stack(lifecycle_mode)
	if not phases.success:
		return phases
	var replaced: Dictionary = preset.duplicate(true)
	if not replaced.get("lifecycle") is Dictionary:
		return _failure("lifecycle_unavailable", "Preset has no mutable lifecycle object.")
	replaced["lifecycle"]["mode"] = lifecycle_mode
	replaced["phases"] = phases.value
	return VfxResult.ok(replaced)


func replace_layer_type(preset: Dictionary, phase_name: String, layer_index: int, layer_type: String) -> VfxResult:
	if not preset.get("phases") is Dictionary or not preset["phases"].has(phase_name):
		return _failure("unknown_phase", "Layer phase is not present in the Preset.")
	var layers: Variant = preset["phases"][phase_name].get("layers", null)
	if not layers is Array or layer_index < 0 or layer_index >= layers.size():
		return _failure("unknown_layer", "Layer index is not present in the phase.")
	if not layers[layer_index] is Dictionary:
		return _failure("layer_unavailable", "Layer value must be an object.")
	var created: VfxResult = _layer_factory.create(layer_type, phase_name, preset)
	if not created.success:
		return created
	var replaced: Dictionary = preset.duplicate(true)
	var target: Dictionary = replaced["phases"][phase_name]["layers"][layer_index]
	target["type"] = created.value["type"]
	target["parameters"] = created.value["parameters"]
	return VfxResult.ok(replaced)


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("FACTORY", code, message)])
