class_name VfxPerformancePanel
extends VBoxContainer

const VfxPerformancePolicyModel := preload("res://src/performance/vfx_performance_policy.gd")
const VfxPreviewLodFilterModel := preload("res://src/performance/vfx_preview_lod_filter.gd")
const VfxPerformanceBudgetAnalyzerModel := preload("res://src/performance/vfx_performance_budget_analyzer.gd")
const VfxStressScenarioModel := preload("res://src/performance/vfx_stress_scenario.gd")
const VfxScenarioProjectionModel := preload("res://src/performance/vfx_scenario_projection.gd")
const VfxBudgetThresholdEvaluatorModel := preload("res://src/performance/vfx_budget_threshold_evaluator.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxPerformanceStressPreviewModel := preload("res://src/preview/performance/vfx_performance_stress_preview.gd")

var _registry: RefCounted
var _source_plan: RefCounted
var _profile_data: Dictionary = {}
var _game_scale_contract: Dictionary = {}
var _track_scale := 1.0
var _policy: RefCounted
var _lod_level := "HIGH"
var _authoring_heading: Label
var _guidance_label: Label
var _budget_label: Label
var _stress_heading: Label
var _result_label: Label
var _scenario_select: OptionButton
var _lod_select: OptionButton
var _replicate_toggle: CheckBox
var _uncap_toggle: CheckBox
var _stress_preview: Variant


func _ready() -> void:
	_build_ui()


func configure(registry: RefCounted, source_plan: RefCounted, profile_data: Dictionary, game_scale_contract: Dictionary, track_scale: float) -> void:
	_registry = registry
	_source_plan = source_plan
	_profile_data = profile_data.duplicate(true)
	_game_scale_contract = game_scale_contract.duplicate(true)
	_track_scale = track_scale
	_load_policy()
	_ensure_stress_preview()
	_refresh_authoring_budget()


func set_lod_level(lod_level: String) -> void:
	_lod_level = lod_level
	if _lod_select != null:
		for index in _lod_select.item_count:
			if _lod_select.get_item_text(index) == lod_level:
				_lod_select.select(index)
	_refresh_authoring_budget()


func has_authoring_budget_section() -> bool:
	return _authoring_heading != null and _authoring_heading.text == "AUTHORING BUDGET"


func has_studio_stress_result_section() -> bool:
	return _stress_heading != null and _stress_heading.text == "STUDIO PREVIEW STRESS RESULT"


func guidance_text() -> String:
	return _guidance_label.text if _guidance_label != null else ""


func stress_result_text() -> String:
	return _result_label.text if _result_label != null else ""


func present_snapshot(snapshot: RefCounted) -> void:
	if snapshot == null or _result_label == null:
		return
	var baseline: Dictionary = snapshot.baseline_summary()
	var vfx: Dictionary = snapshot.vfx_summary()
	var environment: Dictionary = snapshot.environment_context()
	var environment_note := _environment_note(environment, snapshot.preview_frame_time_delta_ms())
	_result_label.text = "Baseline Avg %.3f ms | VFX Avg %.3f ms | Preview Frame Time Delta %.3f ms | VFX Max %.3f ms | P95 %.3f ms | Average Preview FPS %.1f | Particle Peak %d | Trail Point Peak %d | Ring Peak %d | Active VFX Peak %d | Active Layer Renderer Peak %d | Runtime Instance Count %d | GPU time: N/A%s" % [float(baseline.get("average_frame_time_ms", 0.0)), float(vfx.get("average_frame_time_ms", 0.0)), snapshot.preview_frame_time_delta_ms(), float(vfx.get("max_frame_time_ms", 0.0)), float(vfx.get("p95_frame_time_ms", 0.0)), float(vfx.get("average_fps", 0.0)), int(vfx.get("alive_particle_peak", 0)), int(vfx.get("trail_point_peak", 0)), int(vfx.get("ring_peak", 0)), int(vfx.get("active_vfx_instance_peak", 0)), int(vfx.get("active_layer_renderer_peak", 0)), int(vfx.get("active_runtime_instance_peak", 0)), environment_note]


func _environment_note(environment: Dictionary, preview_delta_ms: float) -> String:
	var before: Dictionary = environment.get("before_run", {}) if environment.get("before_run") is Dictionary else {}
	var after_uncap: Dictionary = environment.get("after_uncap_request", {}) if environment.get("after_uncap_request") is Dictionary else {}
	var after_restore: Dictionary = environment.get("after_restore", {}) if environment.get("after_restore") is Dictionary else {}
	var text := " | Environment Before: %s | Uncap Requested: %s | After Uncap: %s | Uncap Verification: %s | After Restore: %s" % [_state_label(before), "YES" if bool(environment.get("uncap_requested", false)) else "NO", _state_label(after_uncap), str(environment.get("uncap_verification", "NOT_REQUESTED")), _state_label(after_restore)]
	if bool(environment.get("external_cap_possible", false)):
		text += " | EXTERNAL CAP POSSIBLE — Actual headroom unknown"
	if bool(environment.get("cap_limited", false)) or (bool(environment.get("actual_headroom_unknown", false)) and is_zero_approx(preview_delta_ms)):
		text += " | CAP LIMITED — Preview cost below observable limiter; Actual headroom unknown"
	if environment.get("restore_verified") == false:
		text += " | ENVIRONMENT RESTORE WARNING"
	return text


func _state_label(state: Dictionary) -> String:
	var window_id: Variant = state.get("window_id")
	var max_fps: Variant = state.get("engine_max_fps")
	return "Window %s, VSync %s, Engine Cap %s" % [str(window_id) if window_id != null else "Unknown", _vsync_label(state.get("vsync_mode")), str(max_fps) if max_fps != null else "Unknown"]


func _vsync_label(mode: Variant) -> String:
	if mode == null:
		return "Unknown"
	if int(mode) == DisplayServer.VSYNC_DISABLED:
		return "Disabled"
	if int(mode) == DisplayServer.VSYNC_ENABLED:
		return "Enabled"
	return "Mode %s" % str(mode)


func _build_ui() -> void:
	if _authoring_heading != null:
		return
	custom_minimum_size = Vector2(0, 220)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_authoring_heading = Label.new()
	_authoring_heading.name = "AuthoringBudgetHeading"
	_authoring_heading.text = "AUTHORING BUDGET"
	add_child(_authoring_heading)
	_guidance_label = Label.new()
	_guidance_label.name = "Guidance"
	_guidance_label.text = "Authoring Guidance — UNCALIBRATED"
	add_child(_guidance_label)
	var controls := HBoxContainer.new()
	controls.name = "StressControls"
	add_child(controls)
	_scenario_select = OptionButton.new()
	_scenario_select.name = "ScenarioSelect"
	for scenario_id in ["1x1", "10x1", "20x1", "10x3", "20x3"]:
		_scenario_select.add_item(scenario_id)
	_scenario_select.select(4)
	_scenario_select.item_selected.connect(func(_index: int) -> void: _refresh_authoring_budget())
	controls.add_child(_scenario_select)
	_lod_select = OptionButton.new()
	_lod_select.name = "StressLodSelect"
	for lod_level in ["HIGH", "MEDIUM", "LOW"]:
		_lod_select.add_item(lod_level)
	_lod_select.item_selected.connect(func(index: int) -> void: set_lod_level(_lod_select.get_item_text(index)))
	controls.add_child(_lod_select)
	_replicate_toggle = CheckBox.new()
	_replicate_toggle.name = "ReplicateCurrent"
	_replicate_toggle.text = "Replicate current to all slots"
	_replicate_toggle.button_pressed = true
	_replicate_toggle.toggled.connect(func(_enabled: bool) -> void: _refresh_authoring_budget())
	controls.add_child(_replicate_toggle)
	_uncap_toggle = CheckBox.new()
	_uncap_toggle.name = "TemporaryUncap"
	_uncap_toggle.text = "Temporarily uncap this Studio Stress run"
	controls.add_child(_uncap_toggle)
	var run_button := Button.new()
	run_button.name = "RunStudioStress"
	run_button.text = "Run Studio Stress"
	run_button.pressed.connect(_on_run_pressed)
	controls.add_child(run_button)
	var cancel_button := Button.new()
	cancel_button.name = "CancelStudioStress"
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_pressed)
	controls.add_child(cancel_button)
	_budget_label = Label.new()
	_budget_label.name = "BudgetSummary"
	_budget_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_budget_label)
	_stress_heading = Label.new()
	_stress_heading.name = "StudioStressResultHeading"
	_stress_heading.text = "STUDIO PREVIEW STRESS RESULT"
	add_child(_stress_heading)
	_result_label = Label.new()
	_result_label.name = "StressResult"
	_result_label.text = "No Studio Stress result in this session. GPU time: N/A"
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_result_label)


func _load_policy() -> void:
	if _registry == null:
		return
	var result: VfxResult = VfxPerformancePolicyModel.new().load(_registry)
	_policy = result.value if result.success else null
	if not result.success and _guidance_label != null:
		_guidance_label.text = "Authoring Guidance unavailable — Performance Policy configuration error"


func _ensure_stress_preview() -> void:
	if _stress_preview != null or _registry == null:
		return
	_stress_preview = VfxPerformanceStressPreviewModel.new(_registry, VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	_stress_preview.name = "StudioPreviewStress"
	_stress_preview.visible = false
	add_child(_stress_preview)
	_stress_preview.studio_stress_completed.connect(_on_studio_stress_completed)


func _filtered_plan() -> RefCounted:
	if _source_plan == null or _policy == null:
		return null
	var result: VfxResult = VfxPreviewLodFilterModel.new().filter(_source_plan, _lod_level, _policy)
	return result.value if result.success else null


func _selected_scenario() -> RefCounted:
	if _policy == null or _scenario_select == null:
		return null
	var scenario_id := _scenario_select.get_item_text(_scenario_select.selected)
	var definition: Dictionary = _policy.scenario_definition(scenario_id)
	if definition.is_empty():
		return null
	var plan := _filtered_plan()
	var workload := "STEADY_LOOP" if plan != null and plan.lifecycle_mode() == "START_LOOP_END" else "REPEATED_ONE_SHOT"
	return VfxStressScenarioModel.new(scenario_id, int(definition.get("vehicle_count", 0)), int(definition.get("slots_per_vehicle", 0)), "VEHICLE_STRESS", workload)


func _slot_plans(scenario: RefCounted) -> Array:
	var plan := _filtered_plan()
	if plan == null or scenario == null:
		return []
	var plans: Array = [plan]
	if _replicate_toggle != null and _replicate_toggle.button_pressed:
		while plans.size() < scenario.slots_per_vehicle():
			plans.append(plan)
	return plans


func _refresh_authoring_budget() -> void:
	if _budget_label == null or _policy == null:
		return
	var scenario := _selected_scenario()
	var plan := _filtered_plan()
	if scenario == null or plan == null or _profile_data.is_empty():
		_budget_label.text = "Select a valid Preset and Vehicle Profile to calculate Authoring Budget."
		return
	var analysis: VfxResult = VfxPerformanceBudgetAnalyzerModel.new(_registry).analyze(plan, _profile_data, scenario.workload_type())
	if not analysis.success:
		_budget_label.text = "Authoring Budget unavailable: %s" % analysis.issues[0].message if not analysis.issues.is_empty() else "Authoring Budget unavailable."
		return
	var workload: RefCounted = analysis.value.active_workload()
	var projection := VfxScenarioProjectionModel.new().project(_slot_budgets(workload, scenario), scenario)
	var threshold := VfxBudgetThresholdEvaluatorModel.new().evaluate(projection, _policy)
	_budget_label.text = "Lifecycle inventory: %d Layer records | Active workload: %d instances, %d continuous Particles | Projected / Theoretical %s: %d instances, %d Particles | %s — Authoring Guidance, UNCALIBRATED" % [analysis.value.authoring_inventory().included_layer_count(), workload.expanded_instance_count(), workload.continuous_particle_capacity(), scenario.scenario_id(), projection.expanded_instance_count(), projection.continuous_particle_capacity(), threshold.severity()]


func _slot_budgets(workload: RefCounted, scenario: RefCounted) -> Array:
	var result: Array = [workload]
	if _replicate_toggle != null and _replicate_toggle.button_pressed:
		while result.size() < scenario.slots_per_vehicle():
			result.append(workload)
	return result


func _on_run_pressed() -> void:
	var scenario := _selected_scenario()
	var plans := _slot_plans(scenario)
	if _stress_preview == null or scenario == null or plans.is_empty():
		return
	var configured: VfxResult = _stress_preview.configure_stress_input({"scenario": scenario, "slot_plans": plans, "profile_data": _profile_data, "game_scale_contract": _game_scale_contract, "track_scale": _track_scale})
	if not configured.success:
		_result_label.text = "Studio Preview Stress configuration error."
		return
	_stress_preview.visible = true
	var started: VfxResult = _stress_preview.run_studio_stress(_uncap_toggle.button_pressed if _uncap_toggle != null else false)
	_result_label.text = "Studio Preview Stress running — %s" % _stress_preview.state_name() if started.success else "Studio Preview Stress could not start."


func _on_cancel_pressed() -> void:
	if _stress_preview != null:
		_stress_preview.cancel_studio_stress()
	_result_label.text = "Studio Preview Stress cancelled."


func _on_studio_stress_completed(snapshot: RefCounted) -> void:
	present_snapshot(snapshot)
