class_name VfxBudgetThresholdEvaluator
extends RefCounted


func evaluate(projection: RefCounted, policy: RefCounted) -> VfxBudgetThresholdEvaluation:
	var safe: Dictionary = policy.threshold_limits("SAFE") if policy != null else {}
	var caution: Dictionary = policy.threshold_limits("CAUTION") if policy != null else {}
	var reasons: Array[String] = []
	var severity := "SAFE"
	for metric in _metric_values(projection):
		var value: int = _metric_values(projection)[metric]
		var safe_limit: int = int(safe.get(metric, -1))
		var caution_limit: int = int(caution.get(metric, -1))
		if caution_limit < 0 or value > caution_limit:
			severity = "HEAVY"
			reasons.append("%s=%d exceeds CAUTION limit %d" % [metric, value, caution_limit])
		elif value > safe_limit and severity != "HEAVY":
			severity = "CAUTION"
			reasons.append("%s=%d exceeds SAFE limit %d" % [metric, value, safe_limit])
	return VfxBudgetThresholdEvaluation.new(severity, policy.calibration_state() if policy != null else "", reasons)


func _metric_values(projection: RefCounted) -> Dictionary:
	return {
		"expanded_runtime_instances": projection.expanded_instance_count(),
		"particle_workload_envelope": projection.particle_workload_envelope(),
		"trail_point_capacity": projection.trail_max_point_capacity(),
		"transparent_renderer_instances": projection.transparent_renderer_instance_count()
	}


class VfxBudgetThresholdEvaluation extends RefCounted:
	var _severity: String
	var _calibration_state: String
	var _reasons: Array[String]

	func _init(severity: String, calibration_state: String, reasons: Array[String]) -> void:
		_severity = severity
		_calibration_state = calibration_state
		_reasons = reasons.duplicate()

	func severity() -> String:
		return _severity

	func calibration_state() -> String:
		return _calibration_state

	func reasons() -> Array[String]:
		return _reasons.duplicate()
