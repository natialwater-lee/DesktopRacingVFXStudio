extends RefCounted

const VfxEditorMainModel := preload("res://src/editor/main/vfx_editor_main.gd")


static func run(tests: TestAssert) -> void:
	var packed := load("res://src/editor/main/vfx_editor_main.tscn") as PackedScene
	tests.expect_true(packed != null, "editor scene loads")
	if packed == null:
		return

	var editor := packed.instantiate() as VfxEditorMainModel
	tests.expect_true(editor != null, "editor scene instantiates its typed root")
	if editor == null:
		return
	tests.expect_true(editor.editor_controller != null, "editor assigns its typed controller")
	editor._ready()
	tests.expect_true(editor.get_node_or_null("Toolbar") != null, "toolbar exists")
	tests.expect_true(editor.get_node_or_null("LibraryPanel") != null, "library region exists")
	tests.expect_true(editor.get_node_or_null("PhaseTabs") != null, "phase tabs region exists")
	tests.expect_true(editor.get_node_or_null("LayerStack") != null, "layer stack region exists")
	tests.expect_true(editor.get_node_or_null("InspectorPanel") != null, "inspector region exists")
	tests.expect_true(editor.get_node_or_null("DiagnosticsPanel") != null, "diagnostics region exists")
	tests.expect_true(editor.get_node("Toolbar/NewButton").is_connected("pressed", Callable(editor.editor_controller, "_on_new_pressed")), "New button opens the schema-derived new dialog")
	tests.expect_true(editor.get_node("Toolbar/OpenButton").is_connected("pressed", Callable(editor.editor_controller, "_on_open_pressed")), "Open button starts the authoring-root file selection flow")
	tests.expect_true(editor.get_node("Toolbar/SaveButton").is_connected("pressed", Callable(editor.editor_controller, "_on_save_pressed")), "Save button uses the valid-only persistence flow")
	tests.expect_true(editor.get_node("Toolbar/SaveAsButton").is_connected("pressed", Callable(editor.editor_controller, "_on_save_as_pressed")), "Save As button starts the authoring-root destination flow")
	editor.queue_free()
