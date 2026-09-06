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
	_test_visual_bend_runtime_v2_projection_and_v1_isolation(tests, compiler)
	_test_linear_phase_runtime_v2_projection_and_static_v1_no_leak(tests, compiler)


static func _test_linear_phase_runtime_v2_projection_and_static_v1_no_leak(tests: TestAssert, compiler: Variant) -> void:
	var fixture: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.linear_phase_rotation_fixture.vfx.json")
	var first: VfxResult = compiler.compile(fixture.value) if compiler != null and fixture.success else VfxResult.failure(fixture.issues if fixture != null else [])
	var second: VfxResult = compiler.compile(fixture.value) if compiler != null and fixture.success else VfxResult.failure(fixture.issues if fixture != null else [])
	var runtime: Variant = JSON.parse_string(first.value.runtime_text()) if first.success else null
	var manifest: Dictionary = first.value.manifest_data() if first.success else {}
	var expected_sources: Array = fixture.value.normalized_data.get("runtime_modulation_sources", []) if fixture.success else []
	var portable: bool = first.success and runtime is Dictionary and not first.value.runtime_text().contains("res://") and not first.value.runtime_text().contains("C:\\")
	tests.expect_true(
		first.success and second.success and runtime is Dictionary and manifest.get("package_format_version") == 1 \
			and runtime.get("runtime_definition_version") == 2 and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" \
			and runtime.get("runtime_modulation_sources") == expected_sources and first.value.runtime_text() == second.value.runtime_text() and portable,
		"LINEAR_PHASE source records deep-copy deterministically into portable Runtime Definition v2 while Package Format remains v1"
	)

	var static_document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var static_result: VfxResult = compiler.compile(static_document.value) if compiler != null and static_document.success else VfxResult.failure(static_document.issues if static_document != null else [])
	var static_runtime: Variant = JSON.parse_string(static_result.value.runtime_text()) if static_result.success else null
	tests.expect_true(
		static_result.success and static_runtime is Dictionary and static_runtime.get("runtime_definition_version") == 1 \
			and not static_result.value.runtime_text().contains("LINEAR_PHASE") and not static_result.value.runtime_text().contains("frequency_hz"),
		"static Runtime Definition v1 remains free of LINEAR_PHASE source-table fields"
	)


static func _test_visual_bend_runtime_v2_projection_and_v1_isolation(tests: TestAssert, compiler: Variant) -> void:
	var bend_document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.visual_bend_fixture.vfx.json")
	var bend_result: VfxResult = compiler.compile(bend_document.value) if compiler != null and bend_document.success else VfxResult.failure(bend_document.issues if bend_document != null else [])
	var bend_runtime: Variant = JSON.parse_string(bend_result.value.runtime_text()) if bend_result.success else null
	var bend_manifest: Dictionary = bend_result.value.manifest_data() if bend_result.success else {}
	var bend_layer := _runtime_layer_named(bend_runtime, "one_shot.visual_bend_fixture")
	tests.expect_true(
		bend_result.success and bend_runtime is Dictionary and bend_runtime.get("runtime_definition_version") == 2 \
			and bend_manifest.get("package_format_version") == 1 and bend_manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" \
			and bend_layer.get("visual_bend") == bend_document.value.normalized_data["phases"]["one_shot"]["layers"][0]["visual_bend"] \
			and bend_layer.get("modulations") == bend_document.value.normalized_data["phases"]["one_shot"]["layers"][0]["modulations"] \
			and bend_layer.get("modulation_clamps") == bend_document.value.normalized_data["phases"]["one_shot"]["layers"][0]["modulation_clamps"],
		"Visual Bend metadata, generic binding, and required clamp serialize portably in Runtime Definition v2 without a Package Format change"
	)
	var portable: bool = bend_result.success and not bend_result.value.runtime_text().contains("res://") and not bend_result.value.runtime_text().contains("C:\\") and bend_result.value.text_files().has("runtime/vfx_runtime_definition_v2.json")
	tests.expect_true(portable, "Visual Bend v2 Package Plan remains portable and writer-ready without invoking the Package writer")

	var static_bend_source: Dictionary = bend_document.value.raw_data.duplicate(true) if bend_document.success else {}
	if not static_bend_source.is_empty():
		static_bend_source["runtime_inputs"] = []
		static_bend_source["runtime_modulation_sources"] = []
		var static_bend_layer_source: Dictionary = static_bend_source["phases"]["one_shot"]["layers"][0]
		static_bend_layer_source.erase("modulations")
		static_bend_layer_source.erase("modulation_clamps")
	var static_bend_document: VfxResult = VfxPresetPipelineModel.new().build_document_from_value(static_bend_source, "res://tests/fixtures/presets/utility.visual_bend_static_fixture.vfx.json")
	var static_bend_result: VfxResult = compiler.compile(static_bend_document.value) if compiler != null and static_bend_document.success else VfxResult.failure(static_bend_document.issues if static_bend_document != null else [])
	var static_bend_runtime: Variant = JSON.parse_string(static_bend_result.value.runtime_text()) if static_bend_result.success else null
	var static_bend_layer := _runtime_layer_named(static_bend_runtime, "one_shot.visual_bend_fixture")
	tests.expect_true(
		static_bend_result.success and static_bend_runtime is Dictionary and static_bend_runtime.get("runtime_definition_version") == 2 \
			and static_bend_layer.get("visual_bend") == bend_document.value.normalized_data["phases"]["one_shot"]["layers"][0]["visual_bend"] \
			and static_bend_layer.get("modulations") == [] and static_bend_layer.get("modulation_clamps") == [],
		"static Visual Bend metadata selects Runtime Definition v2 without inventing a modulation binding"
	)

	var static_document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var static_result: VfxResult = compiler.compile(static_document.value) if compiler != null and static_document.success else VfxResult.failure(static_document.issues if static_document != null else [])
	var static_runtime: Variant = JSON.parse_string(static_result.value.runtime_text()) if static_result.success else null
	tests.expect_true(static_result.success and static_runtime is Dictionary and static_runtime.get("runtime_definition_version") == 1 and not static_result.value.runtime_text().contains("visual_bend"), "static no-bend Presets retain the Runtime Definition v1 path without Visual Bend metadata leakage")


static func _runtime_layer_named(runtime: Variant, layer_id: String) -> Dictionary:
	if not runtime is Dictionary:
		return {}
	for phase_value in runtime.get("phases", []):
		if phase_value is Dictionary:
			for layer_value in phase_value.get("layers", []):
				if layer_value is Dictionary and layer_value.get("id") == layer_id:
					return layer_value
	return {}


static func _runtime_input_named(inputs: Array, input_name: String) -> Dictionary:
	for input_value in inputs:
		if input_value is Dictionary and str(input_value.get("name", "")) == input_name:
			return input_value
	return {}
