class_name VfxDiagnosticsPanel
extends PanelContainer

signal issue_activated(issue: VfxIssue)

var _issues: Array[VfxIssue] = []
var _rows: VBoxContainer


func set_issues(issues: Array[VfxIssue]) -> void:
	_issues = issues.duplicate()
	_rebuild_rows()


func issues() -> Array[VfxIssue]:
	return _issues.duplicate()


func activate_issue(index: int) -> void:
	if index >= 0 and index < _issues.size():
		issue_activated.emit(_issues[index])


func _ready() -> void:
	_rebuild_rows()


func _rebuild_rows() -> void:
	if _rows == null:
		_rows = VBoxContainer.new()
		_rows.name = "Rows"
		add_child(_rows)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for index in _issues.size():
		var issue := _issues[index]
		var button := Button.new()
		button.name = "Issue%d" % index
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _issue_text(issue)
		button.pressed.connect(activate_issue.bind(index))
		_rows.add_child(button)


func _issue_text(issue: VfxIssue) -> String:
	var location := issue.source_path
	if issue.line >= 0:
		location = "%s:%d:%d" % [location, issue.line, issue.column]
	return "%s | %s | %s | %s | %s | %s" % [issue.severity, issue.kind, issue.code, issue.message, issue.json_pointer, location]
