extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const ExportCompilerAndWriterTests := preload("res://tests/export/test_export_compiler_and_writer.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests := TestAssertHelper.new()
	ExportCompilerAndWriterTests.run_writer_contract(tests)
	print("EXPORT_WRITER_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)
