extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const ResultModelTests := preload("res://tests/unit/test_result_models.gd")
const PresetCodecTests := preload("res://tests/unit/test_preset_codec.gd")
const SchemaArtifactTests := preload("res://tests/unit/test_schema_artifact.gd")
const SchemaRegistryTests := preload("res://tests/unit/test_schema_registry.gd")
const SchemaSubsetValidatorTests := preload("res://tests/unit/test_schema_subset_validator.gd")
const PresetNormalizerTests := preload("res://tests/unit/test_preset_normalizer.gd")


func _init() -> void:
	var tests := TestAssertHelper.new()
	tests.expect_true(true, "test runner executes assertions")
	ResultModelTests.run(tests)
	PresetCodecTests.run(tests)
	SchemaArtifactTests.run(tests)
	SchemaRegistryTests.run(tests)
	SchemaSubsetValidatorTests.run(tests)
	PresetNormalizerTests.run(tests)
	quit(1 if tests.failure_count() > 0 else 0)
