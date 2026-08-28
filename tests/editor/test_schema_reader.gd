extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxSchemaReaderModel := preload("res://src/editor/inspector/vfx_schema_reader.gd")


static func run(tests: TestAssert) -> void:
	var registry := _loaded_registry()
	var reader := VfxSchemaReaderModel.new(registry)
	var root_schema := registry.schema()
	var category_schema := reader.property_schema(root_schema, "category")
	tests.expect_true(category_schema.success, "root property schemas resolve through the Schema reader")
	if category_schema.success:
		var category_values := reader.enum_values(category_schema.value)
		tests.expect_true(category_values.has("UTILITY"), "category options come from Schema")
	var particle_schema := reader.layer_parameter_schema("PARTICLE")
	tests.expect_true(particle_schema.success, "type parameters resolve through x_vfx_layer_types")
	var unsupported := reader.resolve({"$ref": "https://example.invalid/schema.json"})
	tests.expect_true(not unsupported.success, "Schema reader rejects non-local references")


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
