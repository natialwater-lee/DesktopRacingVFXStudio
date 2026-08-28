class_name VfxResult
extends RefCounted

var success: bool
var value: Variant
var issues: Array[VfxIssue]


func _init(value_value: Variant = null, issue_values: Array[VfxIssue] = []) -> void:
	value = value_value
	issues = issue_values.duplicate()
	success = not issues.any(func(issue: VfxIssue) -> bool: return issue.severity == "ERROR")


static func ok(value_value: Variant) -> VfxResult:
	return VfxResult.new(value_value)


static func with_issues(value_value: Variant, issue_values: Array[VfxIssue]) -> VfxResult:
	return VfxResult.new(value_value, issue_values)


static func failure(issue_values: Array[VfxIssue]) -> VfxResult:
	return VfxResult.new(null, issue_values)
