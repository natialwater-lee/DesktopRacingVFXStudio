class_name VfxExportService
extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxAuthoringPathsModel := preload("res://src/editor/application/vfx_authoring_paths.gd")
const VfxExportAssetRegistryModel := preload("res://src/export/vfx_export_asset_registry.gd")
const VfxExportPresetPolicyModel := preload("res://src/export/vfx_export_preset_policy.gd")
const VfxExportPathsModel := preload("res://src/export/vfx_export_paths.gd")
const VfxExportCompilerModel := preload("res://src/export/vfx_export_compiler.gd")
const VfxAtomicPackageWriterModel := preload("res://src/export/vfx_atomic_package_writer.gd")

var _pipeline: RefCounted
var _authoring_paths: RefCounted
var _registry: RefCounted
var _asset_registry: RefCounted
var _preset_policy: RefCounted
var _compiler: RefCounted
var _writer: RefCounted
var _ready := false


func _init(pipeline: RefCounted = null, authoring_paths: RefCounted = null, registry: RefCounted = null, asset_registry: RefCounted = null, preset_policy: RefCounted = null, compiler: RefCounted = null, writer: RefCounted = null) -> void:
	_pipeline = pipeline if pipeline != null else VfxPresetPipelineModel.new()
	_authoring_paths = authoring_paths if authoring_paths != null else VfxAuthoringPathsModel.new()
	_registry = registry
	_asset_registry = asset_registry if asset_registry != null else VfxExportAssetRegistryModel.new()
	_preset_policy = preset_policy if preset_policy != null else VfxExportPresetPolicyModel.new()
	_compiler = compiler
	_writer = writer if writer != null else VfxAtomicPackageWriterModel.new()


func validate_saved_source(source_path: String) -> VfxResult:
	var setup: VfxResult = _ensure_ready()
	if not setup.success:
		return setup
	var normalized: String = _authoring_paths.normalize_authoring_path(source_path)
	if not _authoring_paths.contains_preset_path(normalized) or not normalized.ends_with(".vfx.json"):
		return _failure("export_source_path", "Export source must be a saved .vfx.json below the Studio authoring root.", source_path)
	var document: VfxResult = _pipeline.load_and_validate(normalized)
	if not document.success:
		return document
	return _compiler.compile(document.value)


func export_saved_source(source_path: String, mode: String = "FAIL_IF_EXISTS") -> VfxResult:
	var plan: VfxResult = validate_saved_source(source_path)
	if not plan.success:
		return plan
	return _writer.write(plan.value, mode)


func _ensure_ready() -> VfxResult:
	if _ready:
		return VfxResult.ok(self)
	if _registry == null:
		_registry = VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
		var schema_loaded: VfxResult = _registry.load(VfxPresetPipeline.DEFAULT_SCHEMA_PATH)
		if not schema_loaded.success:
			return schema_loaded
	var assets_loaded: VfxResult = _asset_registry.load()
	if not assets_loaded.success:
		return assets_loaded
	var policy_loaded: VfxResult = _preset_policy.load()
	if not policy_loaded.success:
		return policy_loaded
	if _compiler == null:
		_compiler = VfxExportCompilerModel.new(_registry, _asset_registry, _preset_policy, VfxExportPathsModel.new())
	_ready = true
	return VfxResult.ok(self)


func _failure(code: String, message: String, source_path: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", code, message, "", source_path)])
