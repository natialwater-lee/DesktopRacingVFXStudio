extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")


static func run(tests: TestAssert) -> void:
	var codec := VfxPresetCodecModel.new()

	var array_result := codec.decode_text("[]", "array.vfx.json")
	tests.expect_true(array_result.success, "codec accepts JSON array syntax")
	tests.expect_true(array_result.value is Array, "codec preserves array Variant")

	var scalar_result := codec.decode_text("123", "scalar.vfx.json")
	tests.expect_true(scalar_result.success, "codec accepts JSON scalar syntax")
	tests.expect_true(not (scalar_result.value is Dictionary or scalar_result.value is Array), "codec preserves scalar Variant")

	var parse_error := codec.decode_text("{", "broken.vfx.json")
	tests.expect_true(not parse_error.success, "codec reports invalid JSON")
	tests.expect_true(parse_error.issues[0].kind == "JSON_PARSE", "invalid JSON has JSON_PARSE kind")
	tests.expect_true(parse_error.issues[0].column == -1, "unknown JSON column stays -1")

	var missing_file := codec.decode_file("res://tests/fixtures/missing.vfx.json")
	tests.expect_true(not missing_file.success, "codec reports missing file")
	tests.expect_true(missing_file.issues[0].kind == "FILE_IO", "missing file has FILE_IO kind")

	var first_encode := codec.encode({"b": 1, "a": 2})
	var second_encode := codec.encode({"a": 2, "b": 1})
	tests.expect_true(first_encode.success and second_encode.success, "codec encodes dictionaries")
	tests.expect_true(first_encode.value == second_encode.value, "sorted encoding is deterministic")
