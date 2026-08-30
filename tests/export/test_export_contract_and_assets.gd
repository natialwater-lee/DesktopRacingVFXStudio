extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")


static func run(tests: TestAssert) -> void:
	_test_export_asset_policy_is_fail_closed(tests)
	_test_zero_zone_requirements_are_schema_derived(tests)
	_test_renderer_showcase_is_preset_blocked(tests)


static func _test_export_asset_policy_is_fail_closed(tests: TestAssert) -> void:
	var registry_script := load("res://src/export/vfx_export_asset_registry.gd") as Script
	tests.expect_true(registry_script != null and registry_script.can_instantiate(), "Export Asset Registry makes Production eligibility explicit instead of inheriting Preview assets")
	if registry_script == null or not registry_script.can_instantiate():
		return
	var registry: Variant = registry_script.new()
	var loaded: VfxResult = registry.load()
	tests.expect_true(loaded.success, "Export Asset Registry loads its own Production policy")
	if not loaded.success:
		return
	var shard: VfxResult = registry.resolve_exportable("fx.energy_shard")
	var spark: VfxResult = registry.resolve_exportable("fx.energy_spark")
	var flow: VfxResult = registry.resolve_exportable("fx.zero_zone_flow_streak")
	var fixture: VfxResult = registry.resolve_exportable("fx.preview_texture_fixture")
	var procedural: VfxResult = registry.resolve_exportable("fx.trail_streak")
	var unknown: VfxResult = registry.resolve_exportable("fx.not_registered")
	tests.expect_true(shard.success and spark.success and flow.success and flow.value.get("package_file_name") == "zero_zone_flow_streak.png", "explicit Production PNG assets resolve for Export with a stable flow-streak package filename")
	tests.expect_true(not fixture.success, "Preview-only fixture is blocked instead of exported")
	tests.expect_true(not procedural.success, "procedural Preview asset is blocked instead of exported")
	tests.expect_true(not unknown.success, "unregistered logical asset is blocked instead of falling back to Preview")


static func _test_zero_zone_requirements_are_schema_derived(tests: TestAssert) -> void:
	var deriver_script := load("res://src/export/vfx_export_requirement_deriver.gd") as Script
	tests.expect_true(deriver_script != null and deriver_script.can_instantiate(), "Export requirement deriver is available for valid Presets")
	if deriver_script == null or not deriver_script.can_instantiate():
		return
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	tests.expect_true(document_result.success, "Zero Zone source is contract-valid before requirement derivation")
	if not document_result.success:
		return
	var derived: VfxResult = deriver_script.new(_registry()).derive(document_result.value)
	tests.expect_true(derived.success, "Zero Zone requirements derive from the loaded Schema and normalized document")
	if not derived.success:
		return
	var requirements: Dictionary = derived.value
	tests.expect_true(requirements.get("required_vehicle_anchors") == ["CENTER"], "enabled vehicle Layers deduplicate CENTER in Schema Anchor order")
	tests.expect_true(requirements.get("runtime_input_names") == ["intensity"], "runtime input declaration order is preserved")
	var input_contracts: Array = requirements.get("runtime_inputs", [])
	tests.expect_true(input_contracts.size() == 1 and input_contracts[0] == {"name": "intensity", "value_type": "number", "default": 1.0, "minimum": 0.0, "maximum": 1.0}, "runtime input contract is derived from Schema defaults and range")
	tests.expect_true(requirements.get("asset_logical_ids") == ["fx.energy_shard", "fx.energy_spark", "fx.zero_zone_flow_streak"], "three logical Production assets are collected once in stable lexical order")
	tests.expect_true(requirements.get("importance_summary") == {"CORE": 4, "DETAIL": 5, "EXTRA": 3}, "Production Zero Zone keeps the fixed CORE DETAIL EXTRA importance summary")


static func _test_renderer_showcase_is_preset_blocked(tests: TestAssert) -> void:
	var policy_script := load("res://src/export/vfx_export_preset_policy.gd") as Script
	tests.expect_true(policy_script != null and policy_script.can_instantiate(), "Export Preset policy is available for Studio-only exceptions")
	if policy_script == null or not policy_script.can_instantiate():
		return
	var policy: Variant = policy_script.new()
	var loaded: VfxResult = policy.load()
	tests.expect_true(loaded.success, "Export Preset policy loads")
	if not loaded.success:
		return
	var showcase: VfxResult = policy.require_export_allowed("utility.renderer_showcase")
	var zero_zone: VfxResult = policy.require_export_allowed("talent.zero_zone")
	tests.expect_true(not showcase.success, "Renderer Showcase is blocked by Preset policy without banning UTILITY category")
	tests.expect_true(zero_zone.success, "Presets absent from Studio-only policy remain Export candidates")


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
