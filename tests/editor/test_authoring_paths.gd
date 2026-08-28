extends RefCounted

const VfxAuthoringPathsModel := preload("res://src/editor/application/vfx_authoring_paths.gd")


static func run(tests: TestAssert) -> void:
	var paths := VfxAuthoringPathsModel.new()
	tests.expect_true(paths.preset_root() == "res://presets/", "authoring root has one default")
	tests.expect_true(paths.contains_preset_path("res://presets/examples/talent.zero_zone.vfx.json"), "nested Preset is inside root")
	tests.expect_true(not paths.contains_preset_path("res://schemas/vfx_schema_v1.json"), "Schema is not an authoring Preset")
	tests.expect_true(paths.default_save_path("boost.flame") == "res://presets/boost.flame.vfx.json", "default save path is root-contained")
	tests.expect_true(paths.contains_preset_path("res:\\\\presets\\\\examples\\\\talent.zero_zone.vfx.json"), "backslash resource paths normalize inside root")
	tests.expect_true(not paths.contains_preset_path("res://presets-copy/boost.flame.vfx.json"), "root prefix without separator is outside root")
