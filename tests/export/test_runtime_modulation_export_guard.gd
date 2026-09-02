extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const ExportCompilerAndWriterTests := preload("res://tests/export/test_export_compiler_and_writer.gd")


static func run(tests: TestAssert) -> void:
	var compiler: Variant = ExportCompilerAndWriterTests._compiler(tests)
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.runtime_modulation_fixture.vfx.json")
	var result: VfxResult = compiler.compile(document_result.value) if compiler != null and document_result.success else VfxResult.failure(document_result.issues if document_result != null else [])
	tests.expect_true(not result.success and not result.issues.is_empty() and result.issues[0].code == "modulated_preset_requires_runtime_definition_v2", "modulation-bearing Presets fail closed before Runtime Definition v1 package compilation")
