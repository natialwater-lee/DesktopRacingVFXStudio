extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxExportFileBackendModel := preload("res://src/export/vfx_export_file_backend.gd")


class StagingFailureBackend:
	extends RefCounted

	var final_path := ""
	var sentinel := "keep-existing-package"
	var removed_paths: Array[String] = []

	func _init(final_path_value: String) -> void:
		final_path = final_path_value

	func directory_exists(path: String) -> bool:
		return path == final_path

	func make_directory(path: String) -> int:
		return ERR_CANT_CREATE if path.contains("/.staging/") else OK

	func file_exists(_path: String) -> bool:
		return false

	func write_text(_path: String, _text: String) -> int:
		return ERR_CANT_CREATE

	func copy_file(_source_path: String, _target_path: String) -> int:
		return ERR_CANT_CREATE

	func rename_path(_source_path: String, _target_path: String) -> int:
		return ERR_CANT_CREATE

	func remove_tree(path: String) -> int:
		removed_paths.append(path)
		return OK


static func run(tests: TestAssert) -> void:
	run_compile_only(tests)
	_test_atomic_writer_preserves_final_package_on_staging_failure(tests)
	_test_atomic_writer_writes_and_replaces_real_package(tests)


static func run_compile_only(tests: TestAssert) -> void:
	_test_compiler_preserves_raw_source_and_compiles_runtime(tests)
	_test_compiler_is_deterministic_and_deduplicates_assets(tests)


static func _test_compiler_preserves_raw_source_and_compiles_runtime(tests: TestAssert) -> void:
	var compiler: Variant = _compiler(tests)
	if compiler == null:
		return
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var plan_result: VfxResult = compiler.compile(document_result.value) if document_result.success else VfxResult.failure(document_result.issues)
	tests.expect_true(plan_result.success, "Export compiler accepts a saved contract-valid Preset document")
	if not plan_result.success:
		return
	var plan: Variant = plan_result.value
	var codec := VfxPresetCodecModel.new()
	var source_result: VfxResult = codec.decode_text(plan.source_text())
	var runtime_result: VfxResult = codec.decode_text(plan.runtime_text())
	tests.expect_true(source_result.success and not source_result.value["phases"]["loop"]["layers"][0].has("space_mode"), "Source copy keeps omitted authoring space override absent")
	if not runtime_result.success:
		tests.expect_true(false, "Runtime Definition is valid deterministic JSON")
		return
	var runtime_layer: Dictionary = _runtime_layer_named(runtime_result.value, "loop", "loop.focus_core")
	tests.expect_true(runtime_layer["space_mode"] == "VEHICLE_LOCAL" and runtime_layer["enabled"] == true and runtime_layer["sort_order"] == 0, "Runtime Definition resolves effective space and Schema defaults")
	tests.expect_true(runtime_layer.get("id") == "loop.focus_core" and runtime_layer["transform"] == {"offset": [0.0, 0.0], "rotation_degrees": 0.0, "scale": [0.95, 1.4]}, "Runtime Definition retains the named Production focus-core normalized transform data")
	var runtime_particle: Dictionary = _runtime_layer_named(runtime_result.value, "loop", "loop.focus_motes")
	var source_particle: Dictionary = _source_layer_named(source_result.value, "loop", "loop.focus_motes")
	var source_parameters: Dictionary = source_particle.get("parameters", {}) if source_particle.get("parameters", {}) is Dictionary else {}
	tests.expect_true(runtime_particle.get("parameters", {}).get("size_multiplier_min") == 1.0 and runtime_particle.get("parameters", {}).get("size_multiplier_max") == 1.0 and source_parameters.get("size_multiplier_min", 1.0) == 1.0 and source_parameters.get("size_multiplier_max", 1.0) == 1.0, "Runtime Definition preserves the source's explicit or Schema-default size multiplier values without changing their effective contract")
	var coordinate_contract: Dictionary = runtime_result.value.get("coordinate_contract", {})
	tests.expect_true(coordinate_contract.get("origin") == "CENTER" and coordinate_contract.get("front_axis") == "-Y" and _is_expected_canvas_size(coordinate_contract.get("vehicle_source_canvas_size_px")), "Runtime Definition always carries the fixed vehicle source-coordinate contract")
	tests.expect_true(not source_result.value.has("coordinate_contract") and not plan.manifest_data().has("coordinate_contract"), "coordinate contract remains Runtime-only metadata instead of changing Source or Manifest")
	tests.expect_true(not plan.runtime_text().contains("res://") and not plan.runtime_text().contains("C:\\"), "Runtime Definition excludes Studio source and absolute paths")
	var manifest: Dictionary = plan.manifest_data()
	tests.expect_true(manifest["requirements"]["required_vehicle_anchors"] == ["CENTER"] and manifest["requirements"]["runtime_inputs"] == ["intensity"], "Manifest carries derived anchor and runtime-input requirements")


static func _test_compiler_is_deterministic_and_deduplicates_assets(tests: TestAssert) -> void:
	var compiler: Variant = _compiler(tests)
	if compiler == null:
		return
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Zero Zone must load before deterministic Export test")
		return
	var first: VfxResult = compiler.compile(document_result.value)
	var second: VfxResult = compiler.compile(document_result.value)
	tests.expect_true(first.success and second.success and first.value.source_text() == second.value.source_text() and first.value.runtime_text() == second.value.runtime_text() and first.value.manifest_text() == second.value.manifest_text(), "same saved input compiles to byte-identical Package JSON")
	if not first.success:
		return
	var dependencies: Array = first.value.manifest_data().get("asset_dependencies", [])
	var copies: Array = first.value.asset_copies()
	tests.expect_true(dependencies.size() == 2 and dependencies[0]["logical_id"] == "fx.zero_zone_focus_mote" and dependencies[1]["logical_id"] == "fx.zero_zone_tunnel_arc", "future Export compiles the simplified Zero Zone source to stable focus-mote and tunnel-arc logical-ID mappings")
	tests.expect_true(copies.size() == 2 and copies[0]["package_path"] == "assets/zero_zone_focus_mote.png" and copies[1]["package_path"] == "assets/zero_zone_tunnel_arc.png", "repeated focus-mote and tunnel-arc references would produce one physical copy of each required Package asset")
	var files: Array = first.value.files()
	var file_paths: Array[String] = []
	for entry in files:
		file_paths.append(str(entry["path"]))
	var sorted_paths := file_paths.duplicate()
	sorted_paths.sort()
	tests.expect_true(file_paths == sorted_paths and not file_paths.has("manifest.json"), "Manifest files are lexically ordered and exclude self-hash")
	for entry in files:
		tests.expect_true(str(entry["sha256"]).length() == 64 and str(entry["sha256"]).to_lower() == entry["sha256"] and int(entry["byte_size"]) > 0, "every listed Package file has lower-case SHA-256 and byte size")


static func _test_atomic_writer_preserves_final_package_on_staging_failure(tests: TestAssert) -> void:
	var compiler: Variant = _compiler(tests, "user://phase5_export_test/packages/", "user://phase5_export_test/.staging/", "user://phase5_export_test/.backup/")
	var writer_script := load("res://src/export/vfx_atomic_package_writer.gd") as Script
	var paths_script := load("res://src/export/vfx_export_paths.gd") as Script
	tests.expect_true(compiler != null and writer_script != null and writer_script.can_instantiate() and paths_script != null and paths_script.can_instantiate(), "Atomic Export Writer is available")
	if compiler == null or writer_script == null or not writer_script.can_instantiate() or paths_script == null or not paths_script.can_instantiate():
		return
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var plan_result: VfxResult = compiler.compile(document_result.value) if document_result.success else VfxResult.failure(document_result.issues)
	if not plan_result.success:
		tests.expect_true(false, "Atomic writer test requires compiled Zero Zone Package")
		return
	var final_path: String = plan_result.value.final_package_path()
	var backend := StagingFailureBackend.new(final_path)
	var writer: Variant = writer_script.new(backend, null, paths_script.new("user://phase5_export_test/packages/", "user://phase5_export_test/.staging/", "user://phase5_export_test/.backup/"))
	var written: VfxResult = writer.write(plan_result.value, "REPLACE_EXISTING")
	tests.expect_true(not written.success and backend.sentinel == "keep-existing-package" and backend.removed_paths.size() == 1, "injected staging write failure leaves the pre-existing final Package untouched")


static func _test_atomic_writer_writes_and_replaces_real_package(tests: TestAssert) -> void:
	var package_root := "user://phase5_export_write_test/packages/"
	var staging_root := "user://phase5_export_write_test/.staging/"
	var backup_root := "user://phase5_export_write_test/.backup/"
	var compiler: Variant = _compiler(tests, package_root, staging_root, backup_root)
	var writer_script := load("res://src/export/vfx_atomic_package_writer.gd") as Script
	var paths_script := load("res://src/export/vfx_export_paths.gd") as Script
	tests.expect_true(compiler != null and writer_script != null and writer_script.can_instantiate() and paths_script != null and paths_script.can_instantiate(), "Atomic Export Writer real filesystem dependencies are available")
	if compiler == null or writer_script == null or not writer_script.can_instantiate() or paths_script == null or not paths_script.can_instantiate():
		return
	var cleanup := VfxExportFileBackendModel.new()
	cleanup.remove_tree("user://phase5_export_write_test")
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var plan_result: VfxResult = compiler.compile(document_result.value) if document_result.success else VfxResult.failure(document_result.issues)
	if not plan_result.success:
		tests.expect_true(false, "Real writer test requires compiled Zero Zone Package")
		return
	var writer: Variant = writer_script.new(null, null, paths_script.new(package_root, staging_root, backup_root))
	var initial: VfxResult = writer.write(plan_result.value, "FAIL_IF_EXISTS")
	var replacement: VfxResult = writer.write(plan_result.value, "REPLACE_EXISTING")
	var manifest_path := "%smanifest.json" % str(plan_result.value.final_package_path())
	tests.expect_true(initial.success and replacement.success and FileAccess.file_exists(manifest_path), "real writer stages, installs, and atomically replaces a complete Package")
	cleanup.remove_tree("user://phase5_export_write_test")


static func _compiler(tests: TestAssert, package_root: String = "res://exports/packages/", staging_root: String = "res://exports/.staging/", backup_root: String = "res://exports/.backup/") -> Variant:
	var compiler_script := load("res://src/export/vfx_export_compiler.gd") as Script
	var asset_registry_script := load("res://src/export/vfx_export_asset_registry.gd") as Script
	var preset_policy_script := load("res://src/export/vfx_export_preset_policy.gd") as Script
	var paths_script := load("res://src/export/vfx_export_paths.gd") as Script
	var coordinate_contract_script := load("res://src/export/vfx_export_coordinate_contract.gd") as Script
	tests.expect_true(compiler_script != null and compiler_script.can_instantiate() and asset_registry_script != null and asset_registry_script.can_instantiate() and preset_policy_script != null and preset_policy_script.can_instantiate() and paths_script != null and paths_script.can_instantiate() and coordinate_contract_script != null and coordinate_contract_script.can_instantiate(), "Export compiler dependencies are instantiable")
	if compiler_script == null or not compiler_script.can_instantiate() or asset_registry_script == null or not asset_registry_script.can_instantiate() or preset_policy_script == null or not preset_policy_script.can_instantiate() or paths_script == null or not paths_script.can_instantiate() or coordinate_contract_script == null or not coordinate_contract_script.can_instantiate():
		return null
	var assets: Variant = asset_registry_script.new()
	var policy: Variant = preset_policy_script.new()
	var assets_loaded: VfxResult = assets.load()
	var policy_loaded: VfxResult = policy.load()
	if not assets_loaded.success or not policy_loaded.success:
		tests.expect_true(false, "Export compiler dependencies load their explicit policies")
		return null
	var coordinate_contract: Variant = coordinate_contract_script.new()
	var coordinate_loaded: VfxResult = coordinate_contract.load()
	if not coordinate_loaded.success:
		tests.expect_true(false, "Export compiler loads the fail-closed Coordinate Contract")
		return null
	return compiler_script.new(_registry(), assets, policy, paths_script.new(package_root, staging_root, backup_root), null, null, null, coordinate_contract)


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _is_expected_canvas_size(value: Variant) -> bool:
	return value is Array and value.size() == 2 and int(value[0]) == 256 and int(value[1]) == 512


static func _runtime_layer_named(runtime_definition: Dictionary, phase_name: String, layer_id: String) -> Dictionary:
	for phase_value in runtime_definition.get("phases", []):
		if not phase_value is Dictionary or phase_value.get("name") != phase_name:
			continue
		for layer_value in phase_value.get("layers", []):
			if layer_value is Dictionary and layer_value.get("id") == layer_id:
				return layer_value
	return {}


static func _source_layer_named(source_definition: Dictionary, phase_name: String, layer_id: String) -> Dictionary:
	var phase: Variant = source_definition.get("phases", {}).get(phase_name, {})
	if not phase is Dictionary:
		return {}
	for layer_value in phase.get("layers", []):
		if layer_value is Dictionary and layer_value.get("id") == layer_id:
			return layer_value
	return {}
