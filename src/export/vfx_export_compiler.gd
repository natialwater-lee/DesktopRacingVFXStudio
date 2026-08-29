class_name VfxExportCompiler
extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxExportHasherModel := preload("res://src/export/vfx_export_hasher.gd")
const VfxExportRequirementDeriverModel := preload("res://src/export/vfx_export_requirement_deriver.gd")
const VfxExportPackagePlanModel := preload("res://src/export/vfx_export_package_plan.gd")

var _registry: RefCounted
var _asset_registry: RefCounted
var _preset_policy: RefCounted
var _paths: RefCounted
var _codec: RefCounted
var _hasher: RefCounted
var _deriver: RefCounted


func _init(registry: RefCounted, asset_registry: RefCounted, preset_policy: RefCounted, paths: RefCounted, codec: RefCounted = null, hasher: RefCounted = null, deriver: RefCounted = null) -> void:
	_registry = registry
	_asset_registry = asset_registry
	_preset_policy = preset_policy
	_paths = paths
	_codec = codec if codec != null else VfxPresetCodecModel.new()
	_hasher = hasher if hasher != null else VfxExportHasherModel.new()
	_deriver = deriver if deriver != null else VfxExportRequirementDeriverModel.new(registry)


func compile(document: VfxPresetDocument) -> VfxResult:
	if document == null or _registry == null or _asset_registry == null or _preset_policy == null or _paths == null:
		return _failure("export_compiler_input", "Export compiler requires a validated document and configured dependencies.")
	var data := document.normalized_data
	var preset_id := str(data.get("preset_id", ""))
	var policy: VfxResult = _preset_policy.require_export_allowed(preset_id)
	if not policy.success:
		return policy
	var final_path: VfxResult = _paths.package_path_for(preset_id)
	if not final_path.success:
		return final_path
	var requirements: VfxResult = _deriver.derive(document)
	if not requirements.success:
		return requirements
	var source_text: VfxResult = _encode_json(document.raw_data)
	if not source_text.success:
		return source_text
	var runtime_data: VfxResult = _compile_runtime_definition(data, requirements.value)
	if not runtime_data.success:
		return runtime_data
	var runtime_text: VfxResult = _encode_json(runtime_data.value)
	if not runtime_text.success:
		return runtime_text
	var assets: VfxResult = _compile_assets(requirements.value.get("asset_logical_ids", []))
	if not assets.success:
		return assets
	var source_path := "source/%s.vfx.json" % preset_id
	var runtime_path := "runtime/vfx_runtime_definition_v1.json"
	var source_metadata: VfxResult = _hasher.metadata_for_text(source_text.value)
	var runtime_metadata: VfxResult = _hasher.metadata_for_text(runtime_text.value)
	if not source_metadata.success:
		return source_metadata
	if not runtime_metadata.success:
		return runtime_metadata
	var files: Array[Dictionary] = [
		_file_entry(source_path, source_metadata.value),
		_file_entry(runtime_path, runtime_metadata.value)
	]
	for asset_copy in assets.value["copies"]:
		files.append(_file_entry(str(asset_copy["package_path"]), asset_copy))
	files.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left["path"]) < str(right["path"]))
	var manifest := {
		"package_format_version": 1,
		"package_id": preset_id,
		"preset": {
			"preset_id": preset_id,
			"display_name": str(data.get("display_name", "")),
			"category": str(data.get("category", "")),
			"vfx_schema_version": int(data.get("schema_version", 0)),
			"lifecycle_mode": str(data.get("lifecycle", {}).get("mode", "")),
			"default_space_mode": str(data.get("default_space_mode", ""))
		},
		"source": _file_entry(source_path, source_metadata.value),
		"runtime_definition": {
			"version": 1,
			"path": runtime_path,
			"sha256": runtime_metadata.value["sha256"],
			"byte_size": runtime_metadata.value["byte_size"]
		},
		"requirements": {
			"required_vehicle_anchors": requirements.value["required_vehicle_anchors"],
			"runtime_inputs": requirements.value["runtime_input_names"],
			"importance_summary": requirements.value["importance_summary"]
		},
		"asset_dependencies": assets.value["dependencies"],
		"files": files
	}
	var manifest_text: VfxResult = _encode_json(manifest)
	if not manifest_text.success:
		return manifest_text
	var text_files := {
		"manifest.json": manifest_text.value,
		source_path: source_text.value,
		runtime_path: runtime_text.value
	}
	return VfxResult.ok(VfxExportPackagePlanModel.new(
		preset_id,
		final_path.value,
		_paths.staging_root(),
		_paths.backup_root(),
		source_text.value,
		runtime_text.value,
		manifest,
		manifest_text.value,
		text_files,
		files,
		assets.value["copies"]
	))


func _compile_runtime_definition(data: Dictionary, requirements: Dictionary) -> VfxResult:
	var schema: Dictionary = _registry.schema()
	var lifecycle_rule := _rule_named(schema, "LIFECYCLE_PHASE_STRUCTURE")
	var anchor_rule := _rule_named(schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	if lifecycle_rule.is_empty() or anchor_rule.is_empty():
		return _failure("export_runtime_schema", "Runtime compilation requires lifecycle and anchor Schema rules.")
	var phase_names := _phase_names(data, lifecycle_rule)
	if phase_names.is_empty():
		return _failure("export_runtime_lifecycle", "Runtime compilation could not resolve lifecycle phases.")
	var phases: Array[Dictionary] = []
	for phase_name in phase_names:
		var phase: Variant = data.get("phases", {}).get(phase_name, {})
		if not phase is Dictionary:
			return _failure("export_runtime_phase", "Runtime compilation is missing a configured phase.")
		var layers_value: Variant = phase.get("layers", [])
		if not layers_value is Array:
			return _failure("export_runtime_layers", "Runtime compilation requires Layer arrays.")
		var layers: Array[Dictionary] = []
		for layer_value in layers_value:
			if not layer_value is Dictionary:
				return _failure("export_runtime_layer", "Runtime compilation requires Layer objects.")
			var layer: Dictionary = layer_value
			layers.append({
				"id": str(layer.get("id", "")),
				"type": str(layer.get("type", "")),
				"enabled": bool(layer.get("enabled", true)),
				"importance": str(layer.get("importance", "")),
				"blend_mode": str(layer.get("blend_mode", "")),
				"render_plane": str(layer.get("render_plane", "")),
				"sort_order": int(layer.get("sort_order", 0)),
				"space_mode": _effective_space(data, layer, anchor_rule),
				"anchors": (layer.get(str(anchor_rule.get("anchors_field", "")), []) as Array).duplicate(),
				"transform": (layer.get("transform", {}) as Dictionary).duplicate(true),
				"parameters": (layer.get("parameters", {}) as Dictionary).duplicate(true)
			})
		var compiled_phase := {"name": phase_name, "layers": layers}
		if phase.has("duration_seconds"):
			compiled_phase["duration_seconds"] = phase["duration_seconds"]
		phases.append(compiled_phase)
	return VfxResult.ok({
		"runtime_definition_version": 1,
		"preset": {
			"preset_id": str(data.get("preset_id", "")),
			"display_name": str(data.get("display_name", "")),
			"category": str(data.get("category", "")),
			"lifecycle_mode": str(data.get("lifecycle", {}).get("mode", "")),
			"default_space_mode": str(data.get("default_space_mode", ""))
		},
		"required_vehicle_anchors": requirements["required_vehicle_anchors"],
		"runtime_inputs": requirements["runtime_inputs"],
		"phases": phases
	})


func _compile_assets(logical_ids: Array) -> VfxResult:
	var dependencies: Array[Dictionary] = []
	var copies: Array[Dictionary] = []
	var physical_by_hash: Dictionary = {}
	var hash_by_package_path: Dictionary = {}
	for logical_id_value in logical_ids:
		var logical_id := str(logical_id_value)
		var resolved: VfxResult = _asset_registry.resolve_exportable(logical_id)
		if not resolved.success:
			return resolved
		var definition: Dictionary = resolved.value
		var metadata: VfxResult = _hasher.metadata_for_file(str(definition["source_path"]))
		if not metadata.success:
			return metadata
		var package_path := "assets/%s" % str(definition["package_file_name"])
		if hash_by_package_path.has(package_path) and hash_by_package_path[package_path] != metadata.value["sha256"]:
			return _failure("export_asset_collision", "Different asset bytes require the same Package path: %s" % package_path)
		hash_by_package_path[package_path] = metadata.value["sha256"]
		if physical_by_hash.has(metadata.value["sha256"]):
			package_path = physical_by_hash[metadata.value["sha256"]]
		else:
			physical_by_hash[metadata.value["sha256"]] = package_path
			copies.append({
				"source_path": str(definition["source_path"]),
				"package_path": package_path,
				"sha256": metadata.value["sha256"],
				"byte_size": metadata.value["byte_size"]
			})
		dependencies.append({
			"logical_id": logical_id,
			"kind": str(definition["kind"]),
			"package_path": package_path,
			"sha256": metadata.value["sha256"],
			"byte_size": metadata.value["byte_size"]
		})
	dependencies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left["logical_id"]) < str(right["logical_id"]))
	copies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left["package_path"]) < str(right["package_path"]))
	return VfxResult.ok({"dependencies": dependencies, "copies": copies})


func _encode_json(value: Variant) -> VfxResult:
	var encoded: VfxResult = _codec.encode(value)
	if not encoded.success:
		return encoded
	return VfxResult.ok("%s\n" % encoded.value)


func _file_entry(path: String, metadata: Dictionary) -> Dictionary:
	return {"path": path, "sha256": metadata["sha256"], "byte_size": metadata["byte_size"]}


func _phase_names(data: Dictionary, lifecycle_rule: Dictionary) -> Array[String]:
	var lifecycle: Variant = _value_at_pointer(data, str(lifecycle_rule.get("lifecycle_path", "")))
	var result: Array[String] = []
	if not lifecycle is Dictionary:
		return result
	var mode: Variant = lifecycle.get(str(lifecycle_rule.get("mode_field", "")))
	var names: Variant = lifecycle_rule.get("phase_names_by_mode", {}).get(mode, [])
	if names is Array:
		for name in names:
			result.append(str(name))
	return result


func _effective_space(data: Dictionary, layer: Dictionary, anchor_rule: Dictionary) -> String:
	return str(layer.get(str(anchor_rule.get("layer_space_field", "")), data.get(str(anchor_rule.get("default_space_field", "")), "")))


func _rule_named(schema: Dictionary, name: String) -> Dictionary:
	for rule in schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == name:
			return rule
	return {}


func _value_at_pointer(root: Variant, pointer: String) -> Variant:
	if pointer.is_empty() or pointer == "/":
		return root
	var current: Variant = root
	for segment in pointer.trim_prefix("/").split("/"):
		var key := segment.replace("~1", "/").replace("~0", "~")
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null
	return current


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", code, message)])
