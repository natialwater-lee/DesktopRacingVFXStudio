extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxSchemaSubsetValidatorModel := preload("res://src/model/vfx_schema_subset_validator.gd")


static func run(tests: TestAssert) -> void:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	var loaded := registry.load("res://schemas/vfx_schema_v1.json")
	if not loaded.success:
		tests.expect_true(false, "subset validator requires a valid Schema registry")
		return

	var validator := VfxSchemaSubsetValidatorModel.new(registry)
	var strict_schema := {
		"type": "object",
		"required": ["known"],
		"additionalProperties": false,
		"properties": {
			"known": {
				"type": "array",
				"minItems": 2,
				"items": {"type": "number", "minimum": 0.0}
			}
		}
	}
	var issues := validator.validate({"known": [1.0], "unknown": true}, strict_schema)
	tests.expect_true(issues.any(func(issue: VfxIssue) -> bool: return issue.code == "min_items"), "minimum array size is validated")
	tests.expect_true(issues.any(func(issue: VfxIssue) -> bool: return issue.code == "additional_property"), "unknown property is rejected")

	var item_issues := validator.validate({"known": [1.0, -1.0]}, strict_schema)
	tests.expect_true(item_issues.any(func(issue: VfxIssue) -> bool: return issue.code == "minimum"), "items are validated")

	var integer_enum_schema := {"type": "integer", "enum": [1.0]}
	var integer_enum_issues := validator.validate(1, integer_enum_schema)
	tests.expect_true(not integer_enum_issues.any(func(issue: VfxIssue) -> bool: return issue.code == "invalid_enum"), "whole numeric enum matches integer input")
