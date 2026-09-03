extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const PerformancePolicyAndLodTests := preload("res://tests/performance/test_performance_policy_and_lod.gd")
const PerformanceBudgetTests := preload("res://tests/performance/test_performance_budget.gd")
const StressScenarioAndLayoutTests := preload("res://tests/performance/test_stress_scenario_and_layout.gd")
const RuntimeMetricAccumulatorTests := preload("res://tests/performance/test_runtime_metric_accumulator.gd")
const StressPreviewTests := preload("res://tests/performance/test_stress_preview.gd")
const PerformanceUiTests := preload("res://tests/performance/test_performance_ui.gd")
const StressMeasurementEnvironmentTests := preload("res://tests/performance/test_stress_measurement_environment.gd")
const StandardBoosterBudgetTests := preload("res://tests/performance/test_standard_booster_budget.gd")
const HighSpeedWindBudgetTests := preload("res://tests/performance/test_high_speed_wind_budget.gd")
const RainTireSprayBudgetTests := preload("res://tests/performance/test_rain_tire_spray_budget.gd")
const SnowTireSprayBudgetTests := preload("res://tests/performance/test_snow_tire_spray_budget.gd")
const TexturedSpriteBudgetTests := preload("res://tests/performance/test_textured_sprite_budget.gd")
const HeadlightBudgetTests := preload("res://tests/performance/test_headlight_budget.gd")
const RuntimeModulationStructureTests := preload("res://tests/performance/test_runtime_modulation_structure.gd")
const SuperBoosterBudgetTests := preload("res://tests/performance/test_super_booster_budget.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests := TestAssertHelper.new()
	PerformancePolicyAndLodTests.run(tests)
	PerformanceBudgetTests.run(tests)
	StressScenarioAndLayoutTests.run(tests)
	RuntimeMetricAccumulatorTests.run(tests)
	StressPreviewTests.run(tests)
	PerformanceUiTests.run(tests)
	StressMeasurementEnvironmentTests.run(tests)
	StandardBoosterBudgetTests.run(tests)
	HighSpeedWindBudgetTests.run(tests)
	RainTireSprayBudgetTests.run(tests)
	SnowTireSprayBudgetTests.run(tests)
	TexturedSpriteBudgetTests.run(tests)
	HeadlightBudgetTests.run(tests)
	RuntimeModulationStructureTests.run(tests)
	SuperBoosterBudgetTests.run(tests)
	print("PERFORMANCE_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)
