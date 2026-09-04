extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const ExportCompilerAndWriterTests := preload("res://tests/export/test_export_compiler_and_writer.gd")


static func run(tests: TestAssert) -> void:
	var compiler: Variant = ExportCompilerAndWriterTests._compiler(tests)
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.runtime_modulation_fixture.vfx.json")
	var result: VfxResult = compiler.compile(document_result.value) if compiler != null and document_result.success else VfxResult.failure(document_result.issues if document_result != null else [])
	var manifest: Dictionary = result.value.manifest_data() if result.success else {}
	var runtime: Variant = JSON.parse_string(result.value.runtime_text()) if result.success else null
	var runtime_inputs: Array = runtime.get("runtime_inputs", []) if runtime is Dictionary else []
	var turn_rate_contract: Dictionary = _runtime_input_named(runtime_inputs, "turn_rate_normalized")
	tests.expect_true(result.success and manifest.get("runtime_definition", {}).get("version") == 2 and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json", "modulation-bearing Presets select Runtime Definition v2 rather than silently compiling a v1 runtime")
	tests.expect_true(turn_rate_contract == {"name": "turn_rate_normalized", "value_type": "number", "default": 0.0, "minimum": -1.0, "maximum": 1.0} and manifest.get("requirements", {}).get("runtime_inputs", []).has("turn_rate_normalized"), "used turn-rate input serializes as a portable signed Runtime Definition v2 contract")


static func _runtime_input_named(inputs: Array, input_name: String) -> Dictionary:
	for input_value in inputs:
		if input_value is Dictionary and str(input_value.get("name", "")) == input_name:
			return input_value
	return {}
