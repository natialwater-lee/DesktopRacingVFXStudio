class_name VfxPresetHistory
extends RefCounted

var _undo_redo := UndoRedo.new()


func record_snapshot(label: String, before: Dictionary, after: Dictionary, restore: Callable) -> void:
	var before_snapshot := before.duplicate(true)
	var after_snapshot := after.duplicate(true)
	_undo_redo.create_action(label)
	_undo_redo.add_do_method(func() -> void: restore.call(after_snapshot.duplicate(true)))
	_undo_redo.add_undo_method(func() -> void: restore.call(before_snapshot.duplicate(true)))
	_undo_redo.commit_action()


func undo() -> void:
	_undo_redo.undo()


func redo() -> void:
	_undo_redo.redo()


func can_undo() -> bool:
	return _undo_redo.has_undo()


func can_redo() -> bool:
	return _undo_redo.has_redo()
