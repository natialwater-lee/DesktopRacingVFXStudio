class_name TestAssert
extends RefCounted

var _failures: Array[String] = []
var _assertion_count := 0


func expect_true(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func failure_count() -> int:
	return _failures.size()


func assertion_count() -> int:
	return _assertion_count
