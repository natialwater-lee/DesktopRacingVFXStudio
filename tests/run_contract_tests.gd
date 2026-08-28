extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")


func _init() -> void:
	var tests := TestAssertHelper.new()
	tests.expect_true(true, "test runner executes assertions")
	quit(1 if tests.failure_count() > 0 else 0)
