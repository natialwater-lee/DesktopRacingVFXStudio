extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const VehicleProfileTests := preload("res://tests/preview/test_vehicle_profiles.gd")
const PreviewGameScaleTests := preload("res://tests/preview/test_preview_game_scale.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests := TestAssertHelper.new()
	VehicleProfileTests.run(tests)
	PreviewGameScaleTests.run(tests)
	print("PREVIEW_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)
