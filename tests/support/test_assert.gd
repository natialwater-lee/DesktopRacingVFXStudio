class_name TestAssert
extends RefCounted

var _failures: Array[String] = []


func expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func failure_count() -> int:
	return _failures.size()
