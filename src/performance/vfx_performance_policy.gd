class_name VfxPerformancePolicy
extends RefCounted

const DEFAULT_POLICY_PATH := "res://config/vfx_performance_policy_v1.json"

var _policy_path: String
var _data: Dictionary = {}


func _init(policy_path: String = DEFAULT_POLICY_PATH) -> void:
	_policy_path = policy_path


func load(schema_registry: RefCounted) -> VfxResult:
	var file := FileAccess.open(_policy_path, FileAccess.READ)
	if file == null:
		return _failure("performance_policy_open", "Performance Policy could not be opened.")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _failure("performance_policy_parse", "Performance Policy must decode to an object.")
	var issues := _validate(parsed, schema_registry)
	if not issues.is_empty():
		return VfxResult.failure(issues)
	_data = parsed.duplicate(true)
	return VfxResult.ok(self)


func policy_version() -> int:
	return int(_data.get("policy_version", 0))


func calibration_state() -> String:
	return str(_data.get("calibration_state", ""))


func scope_name() -> String:
	return str(_data.get("scope", ""))


func lod_importances(lod_level: String) -> Array[String]:
	var values: Variant = _data.get("lod_levels", {}).get(lod_level, [])
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(str(value))
	return result


func threshold_limits(severity: String) -> Dictionary:
	var values: Variant = _data.get("thresholds", {}).get(severity, {})
	return values.duplicate(true) if values is Dictionary else {}


func scenario_definition(scenario_id: String) -> Dictionary:
	var value: Variant = _data.get("scenarios", {}).get(scenario_id, {})
	return value.duplicate(true) if value is Dictionary else {}


func timing_seconds() -> Dictionary:
	var value: Variant = _data.get("timing_seconds", {})
	return value.duplicate(true) if value is Dictionary else {}


func _validate(data: Dictionary, schema_registry: RefCounted) -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	if data.get("policy_version") != 1:
		issues.append(_issue("performance_policy_version", "Performance Policy version must be 1.", "/policy_version"))
	if data.get("calibration_state") != "UNCALIBRATED":
		issues.append(_issue("performance_policy_calibration", "Phase 4 Policy calibration_state must be UNCALIBRATED.", "/calibration_state"))
	if data.get("scope") != "VEHICLE_STRESS":
		issues.append(_issue("performance_policy_scope", "Phase 4 Policy scope must be VEHICLE_STRESS.", "/scope"))
	var allowed_importances := _schema_importances(schema_registry)
	var lod_levels: Variant = data.get("lod_levels")
	if not lod_levels is Dictionary:
		issues.append(_issue("performance_policy_lod", "Performance Policy requires a lod_levels object.", "/lod_levels"))
	else:
		for lod_level in ["HIGH", "MEDIUM", "LOW"]:
			var values: Variant = lod_levels.get(lod_level)
			if not values is Array or values.is_empty():
				issues.append(_issue("performance_policy_lod", "Performance Policy %s requires an Importance list." % lod_level, "/lod_levels/%s" % lod_level))
				continue
			for importance in values:
				if not allowed_importances.has(str(importance)):
					issues.append(_issue("performance_policy_importance", "Performance Policy Importance %s is absent from Schema v1." % str(importance), "/lod_levels/%s" % lod_level))
	var thresholds: Variant = data.get("thresholds")
	for severity in ["SAFE", "CAUTION"]:
		var limits: Variant = thresholds.get(severity) if thresholds is Dictionary else null
		if not limits is Dictionary:
			issues.append(_issue("performance_policy_threshold", "Performance Policy requires %s threshold limits." % severity, "/thresholds/%s" % severity))
			continue
		for metric in _threshold_metric_names():
			if not limits.get(metric) is int and not limits.get(metric) is float:
				issues.append(_issue("performance_policy_threshold", "Performance Policy threshold %s/%s must be numeric." % [severity, metric], "/thresholds/%s/%s" % [severity, metric]))
	var safe: Dictionary = thresholds.get("SAFE", {}) if thresholds is Dictionary else {}
	var caution: Dictionary = thresholds.get("CAUTION", {}) if thresholds is Dictionary else {}
	for metric in _threshold_metric_names():
		if safe.get(metric) is float or safe.get(metric) is int:
			if caution.get(metric) is float or caution.get(metric) is int:
				if float(caution.get(metric)) < float(safe.get(metric)):
					issues.append(_issue("performance_policy_threshold_order", "CAUTION must not be lower than SAFE for %s." % metric, "/thresholds/%s" % metric))
	return issues


func _schema_importances(schema_registry: RefCounted) -> Array[String]:
	var schema: Dictionary = schema_registry.schema() if schema_registry != null else {}
	var values: Variant = schema.get("$defs", {}).get("importance", {}).get("enum", [])
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(str(value))
	return result


func _threshold_metric_names() -> Array[String]:
	return ["expanded_runtime_instances", "particle_workload_envelope", "trail_point_capacity", "transparent_renderer_instances"]


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([_issue(code, message)])


func _issue(code: String, message: String, pointer: String = "") -> VfxIssue:
	return VfxIssue.new("PERFORMANCE_CONFIGURATION", code, message, pointer)
