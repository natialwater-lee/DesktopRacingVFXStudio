extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const AuthoringPathsTests := preload("res://tests/editor/test_authoring_paths.gd")
const MainSceneSmokeTests := preload("res://tests/editor/test_main_scene_smoke.gd")
const EditSessionTests := preload("res://tests/editor/test_edit_session.gd")
const PresetHistoryTests := preload("res://tests/editor/test_preset_history.gd")
const PresetSkeletonFactoryTests := preload("res://tests/editor/test_preset_skeleton_factory.gd")
const LayerFactoryTests := preload("res://tests/editor/test_layer_factory.gd")
const StructureChangeServiceTests := preload("res://tests/editor/test_structure_change_service.gd")
const PresetLibraryTests := preload("res://tests/editor/test_preset_library.gd")
const EditorSaveServiceTests := preload("res://tests/editor/test_editor_save_service.gd")


func _init() -> void:
	var tests := TestAssertHelper.new()
	AuthoringPathsTests.run(tests)
	MainSceneSmokeTests.run(tests)
	EditSessionTests.run(tests)
	PresetHistoryTests.run(tests)
	PresetSkeletonFactoryTests.run(tests)
	LayerFactoryTests.run(tests)
	StructureChangeServiceTests.run(tests)
	PresetLibraryTests.run(tests)
	EditorSaveServiceTests.run(tests)
	print("EDITOR_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)
