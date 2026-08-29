class_name VfxStressEnvironmentBackend
extends RefCounted


func supports_uncap() -> bool:
	return DisplayServer.get_name() != "headless"


func main_window_id() -> int:
	return DisplayServer.MAIN_WINDOW_ID


func vsync_disabled_mode() -> int:
	return DisplayServer.VSYNC_DISABLED


func read_vsync(window_id: int) -> Variant:
	return DisplayServer.window_get_vsync_mode(window_id)


func write_vsync(vsync_mode: int, window_id: int) -> void:
	DisplayServer.window_set_vsync_mode(vsync_mode, window_id)


func read_max_fps() -> int:
	return Engine.max_fps


func write_max_fps(max_fps: int) -> void:
	Engine.max_fps = max_fps
