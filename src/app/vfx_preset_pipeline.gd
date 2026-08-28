class_name VfxPresetPipeline
extends RefCounted

const DEFAULT_SCHEMA_PATH := "res://schemas/vfx_schema_v1.json"

var _schema_path: String
var _codec: VfxPresetCodec
var _registry: VfxSchemaRegistry
var _normalizer: VfxPresetNormalizer
var _validator: VfxContractValidator
var _schema_loaded := false


func _init(schema_path: String = DEFAULT_SCHEMA_PATH) -> void:
	_schema_path = schema_path
	_codec = VfxPresetCodec.new()
	_registry = VfxSchemaRegistry.new(_codec, VfxRuleCatalog.new())
	_normalizer = VfxPresetNormalizer.new(_registry)
	_validator = VfxContractValidator.new(_registry, VfxSchemaSubsetValidator.new(_registry))


func load_and_validate(path: String) -> VfxResult:
	var decoded := _codec.decode_file(path)
	if not decoded.success:
		return decoded
	return build_document_from_value(decoded.value, path)


func build_document_from_value(value: Variant, source_path: String = "") -> VfxResult:
	var schema_result := _ensure_schema_loaded()
	if not schema_result.success:
		return schema_result

	var normalized := _normalizer.normalize(value, _registry.schema())
	if not normalized.success:
		return normalized

	var validation := _validator.validate(normalized.value)
	if not validation.success:
		return validation

	return VfxResult.ok(VfxPresetDocument.new(source_path, value, validation.value))


func serialize_document(document: VfxPresetDocument) -> VfxResult:
	var schema_result := _ensure_schema_loaded()
	if not schema_result.success:
		return schema_result

	var validation := _validator.validate(document.normalized_data)
	if not validation.success:
		return validation
	return _codec.encode(validation.value)


func _ensure_schema_loaded() -> VfxResult:
	if _schema_loaded:
		return VfxResult.ok(_registry.schema())
	var loaded := _registry.load(_schema_path)
	if loaded.success:
		_schema_loaded = true
	return loaded
