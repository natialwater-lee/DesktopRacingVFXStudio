class_name VfxEditorSaveService
extends RefCounted

var _pipeline: VfxPresetPipeline
var _codec: VfxPresetCodec
var _paths: VfxAuthoringPaths


func _init(pipeline: VfxPresetPipeline, codec: VfxPresetCodec, paths: VfxAuthoringPaths) -> void:
	_pipeline = pipeline
	_codec = codec
	_paths = paths


func save(session: VfxPresetEditSession, target_path: String) -> VfxResult:
	var policy := _validate_target_path(target_path)
	if not policy.success:
		return policy
	var document_result := _pipeline.build_document_from_value(session.working_copy(), target_path)
	if not document_result.success:
		return document_result
	var serialized := _pipeline.serialize_document(document_result.value)
	if not serialized.success:
		return serialized
	var written := _codec.write_text_file(target_path, serialized.value)
	if not written.success:
		return written
	session.mark_saved(document_result.value)
	return VfxResult.ok(document_result.value)


func _validate_target_path(target_path: String) -> VfxResult:
	var normalized := _paths.normalize_authoring_path(target_path)
	if not _paths.contains_preset_path(normalized):
		return _policy_failure("outside_authoring_root", "Preset files must be saved below the configured authoring root.", target_path)
	if not normalized.ends_with(".vfx.json"):
		return _policy_failure("invalid_preset_extension", "Preset files must use the .vfx.json extension.", target_path)
	return VfxResult.ok(normalized)


func _policy_failure(code: String, message: String, path: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EDITOR_POLICY", code, message, "", path)])
