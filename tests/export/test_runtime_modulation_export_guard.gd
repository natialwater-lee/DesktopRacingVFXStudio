extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const ExportCompilerAndWriterTests := preload("res://tests/export/test_export_compiler_and_writer.gd")


static func run(tests: TestAssert) -> void:
	var compiler: Variant = ExportCompilerAndWriterTests._compiler(tests)
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.runtime_modulation_fixture.vfx.json")
	var result: VfxResult = compiler.compile(document_result.value) if compiler != null and document_result.success else VfxResult.failure(document_result.issues if document_result != null else [])
	var manifest: Dictionary = result.value.manifest_data() if result.success else {}
	tests.expect_true(result.success and manifest.get("runtime_definition", {}).get("version") == 2 and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json", "modulation-bearing Presets select Runtime Definition v2 rather than silently compiling a v1 runtime")
