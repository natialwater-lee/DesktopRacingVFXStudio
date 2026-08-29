class_name VfxStressMeasurementEnvironment
extends RefCounted

const VfxStressEnvironmentBackendModel := preload("res://src/performance/vfx_stress_environment_backend.gd")

var _backend: RefCounted
var _before_run: Dictionary = {}
var _after_uncap_request: Dictionary = {}
var _after_restore: Dictionary = {}
var _uncap_requested := false
var _uncap_verification := "NOT_REQUESTED"
var _restore_verified: Variant = null
var _warnings: Array[String] = []
var _context: Dictionary = {}


func _init(backend: RefCounted = null) -> void:
	_backend = backend if backend != null else VfxStressEnvironmentBackendModel.new()


func begin(request_temporary_uncap: bool) -> Dictionary:
	_before_run = _read_state()
	_after_restore = {}
	_uncap_requested = request_temporary_uncap
	_uncap_verification = "NOT_REQUESTED"
	_restore_verified = null
	_warnings.clear()
	if not _uncap_requested:
		_after_uncap_request = _read_state()
	elif not _supports_uncap():
		_after_uncap_request = _read_state()
		_uncap_verification = "UNSUPPORTED"
		_warnings.append("Temporary Uncap is unsupported because the VSync API cannot be controlled or read in this environment.")
	else:
		_backend.write_vsync(_backend.vsync_disabled_mode(), int(_before_run.get("window_id", 0)))
		_backend.write_max_fps(0)
		_after_uncap_request = _read_state()
		_uncap_verification = "CONFIRMED" if _is_uncap_confirmed(_after_uncap_request) else "PARTIAL"
		if _uncap_verification == "PARTIAL":
			_warnings.append("Temporary Uncap read-back did not confirm both VSync disabled and Engine.max_fps = 0.")
	_rebuild_context()
	return _context.duplicate(true)


func restore() -> Dictionary:
	if _before_run.is_empty():
		_after_restore = _read_state()
		_rebuild_context()
		return _context.duplicate(true)
	if _uncap_requested and _supports_uncap():
		var original_vsync: Variant = _before_run.get("vsync_mode")
		if original_vsync != null:
			_backend.write_vsync(int(original_vsync), int(_before_run.get("window_id", 0)))
		_backend.write_max_fps(int(_before_run.get("engine_max_fps", 0)))
	_after_restore = _read_state()
	_restore_verified = _states_match(_before_run, _after_restore)
	if not _restore_verified:
		_warnings.append("Environment restore read-back differs from the state captured before the Studio Stress run.")
	_rebuild_context()
	return _context.duplicate(true)


func context() -> Dictionary:
	return _context.duplicate(true)


func add_warning(message: String) -> void:
	if not message.is_empty():
		_warnings.append(message)
		_rebuild_context()


func _supports_uncap() -> bool:
	return _backend != null and _backend.supports_uncap()


func _read_state() -> Dictionary:
	var engine_max_fps: Variant = _backend.read_max_fps() if _backend != null else null
	if not _supports_uncap():
		return {"window_id": null, "vsync_mode": null, "engine_max_fps": engine_max_fps}
	var window_id: Variant = _backend.main_window_id()
	return {"window_id": window_id, "vsync_mode": _backend.read_vsync(int(window_id)), "engine_max_fps": engine_max_fps}


func _is_uncap_confirmed(state: Dictionary) -> bool:
	return state.get("vsync_mode") == _backend.vsync_disabled_mode() and state.get("engine_max_fps") == 0


func _states_match(expected: Dictionary, actual: Dictionary) -> bool:
	return expected.get("window_id") == actual.get("window_id") and expected.get("vsync_mode") == actual.get("vsync_mode") and expected.get("engine_max_fps") == actual.get("engine_max_fps")


func _rebuild_context() -> void:
	var active_state: Dictionary = _after_uncap_request if not _after_uncap_request.is_empty() else _before_run
	var cap_status_known: bool = active_state.get("vsync_mode") != null and active_state.get("engine_max_fps") != null
	var cap_limited: bool = cap_status_known and (active_state.get("vsync_mode") != _backend.vsync_disabled_mode() or int(active_state.get("engine_max_fps", 0)) > 0)
	var external_cap_possible: bool = _uncap_verification == "CONFIRMED"
	_context = {
		"before_run": _before_run.duplicate(true),
		"uncap_requested": _uncap_requested,
		"after_uncap_request": _after_uncap_request.duplicate(true),
		"after_restore": _after_restore.duplicate(true),
		"uncap_verification": _uncap_verification,
		"restore_verified": _restore_verified,
		"warnings": _warnings.duplicate(),
		"external_cap_possible": external_cap_possible,
		"actual_headroom_unknown": cap_limited or external_cap_possible or not cap_status_known,
		"vsync_mode": active_state.get("vsync_mode"),
		"engine_max_fps": active_state.get("engine_max_fps"),
		"cap_limited": cap_limited,
		"temporary_uncap_requested": _uncap_requested,
		"temporary_uncap_applied": _uncap_verification == "CONFIRMED"
	}
