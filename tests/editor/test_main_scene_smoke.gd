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
	tests.expect_true(editor.get_node_or_null("Toolbar") != null, "toolbar exists")
	tests.expect_true(editor.get_node_or_null("LibraryPanel") != null, "library region exists")
	tests.expect_true(editor.get_node_or_null("PhaseTabs") != null, "phase tabs region exists")
	tests.expect_true(editor.get_node_or_null("LayerStack") != null, "layer stack region exists")
	tests.expect_true(editor.get_node_or_null("InspectorPanel") != null, "inspector region exists")
	tests.expect_true(editor.get_node_or_null("DiagnosticsPanel") != null, "diagnostics region exists")
	editor.queue_free()
