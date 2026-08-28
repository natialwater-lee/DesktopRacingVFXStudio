extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")


static func run(tests: TestAssert) -> void:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	var loaded := registry.load("res://schemas/vfx_schema_v1.json")
	tests.expect_true(loaded.success, "approved Schema loads as configuration")

	var local_ref := registry.resolve_local_ref("#/$defs/layer")
	tests.expect_true(local_ref.success, "local ref resolves")

	var external_ref := registry.resolve_local_ref("https://example.com/schema.json")
	tests.expect_true(not external_ref.success, "external ref is rejected")
	tests.expect_true(external_ref.issues[0].kind == "SCHEMA_CONFIGURATION", "external ref is schema error")

	if loaded.success:
		var missing_ref_schema := registry.schema()
		missing_ref_schema["properties"]["preset_id"] = {"$ref": "#/$defs/missing"}
		var missing_ref := registry.load_data(missing_ref_schema, "missing_ref_schema.json")
		tests.expect_true(not missing_ref.success, "missing local ref is rejected")
		tests.expect_true(missing_ref.issues[0].kind == "SCHEMA_CONFIGURATION", "missing ref is schema error")

		var cyclic_schema := registry.schema()
		cyclic_schema["$defs"]["cycle_a"] = {"$ref": "#/$defs/cycle_b"}
		cyclic_schema["$defs"]["cycle_b"] = {"$ref": "#/$defs/cycle_a"}
		var cyclic := registry.load_data(cyclic_schema, "cyclic_schema.json")
		tests.expect_true(not cyclic.success, "cyclic local refs are rejected")
		tests.expect_true(cyclic.issues.any(func(issue: VfxIssue) -> bool: return issue.code == "ref_cycle"), "cyclic ref reports ref_cycle")

		var unknown_rule_schema := registry.schema()
		unknown_rule_schema["x_vfx_rules"].append({"name": "UNKNOWN_RULE"})
		var unknown_rule := registry.load_data(unknown_rule_schema, "unknown_rule_schema.json")
		tests.expect_true(not unknown_rule.success, "unknown x_vfx_rule is rejected")

		var invalid_default_schema := registry.schema()
		invalid_default_schema["$defs"]["layer"]["properties"]["enabled"]["default"] = "yes"
		var invalid_default := registry.load_data(invalid_default_schema, "invalid_default_schema.json")
		tests.expect_true(not invalid_default.success, "default incompatible with subschema is rejected")
