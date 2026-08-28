extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")


static func run(tests: TestAssert) -> void:
	var codec := VfxPresetCodecModel.new()
	var schema_result := codec.decode_file("res://schemas/vfx_schema_v1.json")
	tests.expect_true(schema_result.success, "Schema file is JSON")
	if schema_result.success:
		tests.expect_true(schema_result.value is Dictionary, "Schema root is an object")
		tests.expect_true((schema_result.value as Dictionary).has("x_vfx_rules"), "Schema declares VFX rules")

	var catalog := VfxRuleCatalogModel.new()
	tests.expect_true(catalog.supports("LIFECYCLE_PHASE_STRUCTURE"), "catalog recognizes lifecycle rule")
	var unknown_issues := catalog.validate_configuration({"name": "UNKNOWN_RULE"}, "/x_vfx_rules/0")
	tests.expect_true(not unknown_issues.is_empty(), "catalog rejects unknown rule")
	tests.expect_true(unknown_issues[0].kind == "SCHEMA_CONFIGURATION", "unknown rule is a schema error")
