class_name VfxPerformanceStressPreview
extends VBoxContainer

const VfxPerformanceStressStageModel := preload("res://src/preview/performance/vfx_performance_stress_stage.gd")
const VfxRuntimeMetricAccumulatorModel := preload("res://src/performance/vfx_runtime_metric_accumulator.gd")
const VfxPerformanceSnapshotModel := preload("res://src/performance/vfx_performance_snapshot.gd")
const VfxStressMeasurementEnvironmentModel := preload("res://src/performance/vfx_stress_measurement_environment.gd")

signal studio_stress_completed(snapshot: RefCounted)

var _registry: RefCounted
var _factory: RefCounted
var _asset_resolver: RefCounted
var _stage: Control
var _input: Dictionary = {}
var _timing_seconds := {"baseline_warmup": 1.0, "baseline_measurement": 3.0, "vfx_warmup": 1.0, "vfx_measurement": 3.0}
var _state := "IDLE"
var _state_history: Array[String] = []
var _phase_elapsed := 0.0
var _baseline_accumulator := VfxRuntimeMetricAccumulatorModel.new()
var _vfx_accumulator := VfxRuntimeMetricAccumulatorModel.new()
var _latest_stage_facts: Dictionary = {}
var _latest_snapshot: RefCounted
var _measurement_environment := VfxStressMeasurementEnvironmentModel.new()


func _init(registry: RefCounted, factory: RefCounted, asset_resolver: RefCounted) -> void:
	_registry = registry
	_factory = factory
	_asset_resolver = asset_resolver


func _ready() -> void:
	_ensure_stage()


func _exit_tree() -> void:
	_measurement_environment.restore()


func _process(delta: float) -> void:
	advance_stress(delta)


func set_timing_seconds(timing_seconds: Dictionary) -> void:
	for key in _timing_seconds:
		if timing_seconds.get(key) is int or timing_seconds.get(key) is float:
			_timing_seconds[key] = maxf(float(timing_seconds.get(key)), 0.0)


func set_measurement_environment(environment: RefCounted) -> void:
	if environment != null:
		_measurement_environment = environment


func measurement_environment_context() -> Dictionary:
	return _measurement_environment.context()


func configure_stress_input(input: Dictionary) -> VfxResult:
	if not input.get("scenario") is RefCounted or not input.get("slot_plans") is Array or not input.get("profile_data") is Dictionary or not input.get("game_scale_contract") is Dictionary:
		return VfxResult.failure([VfxIssue.new("PERFORMANCE_CONFIGURATION", "stress_input", "Studio Stress requires scenario, slot plans, profile data, and game-scale contract.")])
	_input = input.duplicate(true)
	return VfxResult.ok(self)


func run_studio_stress(request_temporary_uncap: bool) -> VfxResult:
	_measurement_environment.restore()
	if _input.is_empty():
		_set_state("ERROR")
		return VfxResult.failure([VfxIssue.new("PERFORMANCE_CONFIGURATION", "stress_unconfigured", "Studio Stress input has not been configured.")])
	_ensure_stage()
	_state_history.clear()
	_set_state("PREPARE")
	var prepared: VfxResult = _stage.prepare(_input["scenario"], _input["slot_plans"], _input["profile_data"], _input["game_scale_contract"], float(_input.get("track_scale", 1.0)))
	if not prepared.success:
		_measurement_environment.restore()
		_set_state("ERROR")
		return prepared
	_stage.set_vfx_enabled(false)
	_baseline_accumulator = VfxRuntimeMetricAccumulatorModel.new()
	_vfx_accumulator = VfxRuntimeMetricAccumulatorModel.new()
	_latest_snapshot = null
	_latest_stage_facts = {}
	_measurement_environment.begin(request_temporary_uncap)
	_set_state("BASELINE_WARMUP")
	_phase_elapsed = 0.0
	return VfxResult.with_issues(self, prepared.issues)


func cancel_studio_stress() -> void:
	if _stage != null:
		_stage.set_vfx_enabled(false)
	_measurement_environment.restore()
	_set_state("CANCELLED")
	_phase_elapsed = 0.0


func abort_studio_stress(message: String) -> void:
	if _stage != null:
		_stage.set_vfx_enabled(false)
	_measurement_environment.add_warning("Studio Stress measurement error: %s" % message)
	_measurement_environment.restore()
	_set_state("ERROR")
	_phase_elapsed = 0.0


func advance_stress(delta_seconds: float) -> void:
	if not _state in ["BASELINE_WARMUP", "BASELINE_MEASURE", "VFX_WARMUP", "VFX_MEASURE"] or _stage == null:
		return
	_latest_stage_facts = _stage.advance(delta_seconds)
	if _state == "BASELINE_MEASURE":
		_baseline_accumulator.sample(delta_seconds, _latest_stage_facts)
	elif _state == "VFX_MEASURE":
		_vfx_accumulator.sample(delta_seconds, _latest_stage_facts)
	_phase_elapsed += maxf(delta_seconds, 0.0)
	if _phase_elapsed + 0.000001 >= _duration_for_state():
		_transition_to_next_state()


func state_name() -> String:
	return _state


func state_history() -> Array[String]:
	return _state_history.duplicate()


func latest_stage_facts() -> Dictionary:
	return _latest_stage_facts.duplicate(true)


func latest_snapshot() -> RefCounted:
	return _latest_snapshot


func stage_vehicle_node_ids() -> Array:
	return _stage.vehicle_node_ids() if _stage != null else []


func _ensure_stage() -> void:
	if _stage != null:
		return
	_stage = VfxPerformanceStressStageModel.new(_registry, _factory, _asset_resolver)
	_stage.name = "StudioPreviewStressStage"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_stage)


func _duration_for_state() -> float:
	match _state:
		"BASELINE_WARMUP":
			return float(_timing_seconds["baseline_warmup"])
		"BASELINE_MEASURE":
			return float(_timing_seconds["baseline_measurement"])
		"VFX_WARMUP":
			return float(_timing_seconds["vfx_warmup"])
		"VFX_MEASURE":
			return float(_timing_seconds["vfx_measurement"])
	return 0.0


func _transition_to_next_state() -> void:
	_phase_elapsed = 0.0
	match _state:
		"BASELINE_WARMUP":
			_set_state("BASELINE_MEASURE")
			_baseline_accumulator.begin_measurement()
		"BASELINE_MEASURE":
			_set_state("VFX_WARMUP")
			_stage.set_vfx_enabled(true)
		"VFX_WARMUP":
			_set_state("VFX_MEASURE")
			_vfx_accumulator.begin_measurement()
		"VFX_MEASURE":
			_complete()


func _complete() -> void:
	_set_state("COMPLETE")
	var metadata := {
		"calibration_state": "UNCALIBRATED",
		"scope": _input["scenario"].scope_name(),
		"workload_type": _input["scenario"].workload_type(),
		"synchronization": "SYNCHRONIZED",
		"scenario_id": _input["scenario"].scenario_id()
	}
	var environment_context := _measurement_environment.restore()
	_latest_snapshot = VfxPerformanceSnapshotModel.new(_baseline_accumulator.finish(), _vfx_accumulator.finish(), metadata, environment_context)
	studio_stress_completed.emit(_latest_snapshot)


func _set_state(next_state: String) -> void:
	_state = next_state
	_state_history.append(next_state)
