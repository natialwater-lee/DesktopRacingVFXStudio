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

		var malformed_range_rule_schema := registry.schema()
		_rule_by_name(malformed_range_rule_schema, "PARTICLE_MOTION_RANGE_ORDER")["ranges"] = [{}]
		var malformed_range_rule := registry.load_data(malformed_range_rule_schema, "malformed_range_rule_schema.json")
		tests.expect_true(not malformed_range_rule.success, "malformed nested rule configuration is rejected")

		var unsupported_keyword_type_schema := registry.schema()
		unsupported_keyword_type_schema["properties"]["display_name"] = {"type": "not_a_supported_type"}
		var unsupported_keyword_type := registry.load_data(unsupported_keyword_type_schema, "unsupported_keyword_type_schema.json")
		tests.expect_true(not unsupported_keyword_type.success, "unsupported subset keyword type is rejected")

		var incomplete_emitter_mapping_schema := registry.schema()
		_rule_by_name(incomplete_emitter_mapping_schema, "PARTICLE_EMITTER_SHAPE")["geometry_by_shape"].erase("CIRCLE")
		var incomplete_emitter_mapping := registry.load_data(incomplete_emitter_mapping_schema, "incomplete_emitter_mapping_schema.json")
		tests.expect_true(not incomplete_emitter_mapping.success, "rule configuration must cover every declared emitter shape")

		var misspelled_anchor_field_schema := registry.schema()
		_rule_by_name(misspelled_anchor_field_schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")["anchors_field"] = "misspelled"
		var misspelled_anchor_field := registry.load_data(misspelled_anchor_field_schema, "misspelled_anchor_field_schema.json")
		tests.expect_true(not misspelled_anchor_field.success, "rule configuration must reference declared Layer fields")

		var wrong_anchor_field_type_schema := registry.schema()
		_rule_by_name(wrong_anchor_field_type_schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")["anchors_field"] = "id"
		var wrong_anchor_field_type := registry.load_data(wrong_anchor_field_type_schema, "wrong_anchor_field_type_schema.json")
		tests.expect_true(not wrong_anchor_field_type.success, "rule configuration must use an array Schema for anchors")

		var wrong_runtime_input_path_schema := registry.schema()
		_rule_by_name(wrong_runtime_input_path_schema, "RUNTIME_INPUT_NAMES")["runtime_inputs_path"] = "/display_name"
		var wrong_runtime_input_path := registry.load_data(wrong_runtime_input_path_schema, "wrong_runtime_input_path_schema.json")
		tests.expect_true(not wrong_runtime_input_path.success, "rule configuration must use an array Schema for runtime inputs")

		var wrong_layer_space_field_schema := registry.schema()
		_rule_by_name(wrong_layer_space_field_schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")["layer_space_field"] = "id"
		var wrong_layer_space_field := registry.load_data(wrong_layer_space_field_schema, "wrong_layer_space_field_schema.json")
		tests.expect_true(not wrong_layer_space_field.success, "rule configuration must use the declared Space Mode enum for Layer space")


static func _rule_by_name(schema: Dictionary, rule_name: String) -> Dictionary:
	for rule in schema["x_vfx_rules"]:
		if rule["name"] == rule_name:
			return rule
	return {}
