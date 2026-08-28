extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const AuthoringPathsTests := preload("res://tests/editor/test_authoring_paths.gd")
const MainSceneSmokeTests := preload("res://tests/editor/test_main_scene_smoke.gd")


func _init() -> void:
	var tests := TestAssertHelper.new()
	AuthoringPathsTests.run(tests)
	MainSceneSmokeTests.run(tests)
	print("EDITOR_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)
