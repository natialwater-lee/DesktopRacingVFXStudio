# DesktopRacingVFXStudio Phase 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` task-by-task. Do not use subagents, `git add`, or `git commit`; leave every change unstaged for SourceTree review.

**Goal:** Add immutable LOD Preview filtering, Authoring/Workload Budgets, and a measured Studio Preview Stress surface without treating Studio results as game-runtime performance.

**Architecture:** A Studio policy validates its LOD map against Schema Importance values. An immutable Render Plan filter feeds both the existing Vehicle Preview and a dedicated many-vehicle Stress Stage; a budget analyzer reports Lifecycle Envelope and active Workload values separately. The same prebuilt Stress Stage runs a vehicles-only baseline before enabling existing Preview runtimes, and a bounded metrics accumulator creates a session-only Snapshot.

**Tech Stack:** Godot 4.7.1 stable, standard GDScript, existing Preview Renderer/Render Plan/Playback/Asset Registry, dependency-free headless test runners.

**Spec:** `docs/superpowers/specs/2026-08-29-vfx-studio-phase-4-design.md`

## Global Constraints

- Preserve Schema v1 and all `.vfx.json` data; no derived performance value is serialized into a Preset.
- Use the terms `Studio Preview Stress`, `Preview Frame Time`, `Preview Baseline Delta`, and `Authoring Guidance`; never claim game performance or game safety.
- Keep Lifecycle Envelope / source inventory separate from active Stress Workload Budget. Threshold guidance uses the active workload only.
- Reuse existing Renderer Factory, Render Plan, Instance Resolver, Asset Registry, canonical packet routing, and Playback; do not create a game renderer.
- Keep `project.godot`, `src/editor/main/vfx_editor_main.tscn`, and Vehicle Profile JSON files unchanged.
- Do not access `C:\GodotProjects\DesktopIdleRacing`.
- Do not stage or commit. Preserve existing user modifications and leave all Phase 4 work unstaged.
- Use focused tests during Tasks A-C and run full regression only in Task D with `C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe`.
- Do not add auto LOD, Dynamic LOD, Export, game integration, a hardware database, a GPU-cost estimate, or an FPS pass/fail CI gate.

---

## Planned file structure

```text
config/
  vfx_performance_policy_v1.json       # Uncalibrated Studio policy, LOD map, scenarios, thresholds
src/performance/
  vfx_performance_policy.gd            # Focused policy loading/configuration checks
  vfx_preview_lod_filter.gd            # Immutable Plan filtering
  vfx_authoring_budget.gd               # Lifecycle Envelope budget value
  vfx_workload_budget.gd                # Active workload budget value
  vfx_preset_performance_budget.gd      # Immutable paired budget result
  vfx_performance_budget_analyzer.gd    # Plan/profile/asset aggregation
  vfx_stress_scenario.gd                # Scenario, slots, scope, workload input
  vfx_scenario_projection.gd            # Theoretical slot/vehicle multiplication
  vfx_budget_threshold_evaluator.gd     # Uncalibrated guidance and reasons
  vfx_runtime_metric_accumulator.gd     # Measurement-only aggregates and P95
  vfx_performance_snapshot.gd           # Session-only paired result
  vfx_stress_measurement_environment.gd # Optional VSync/cap guard and restoration
src/preview/performance/
  vfx_performance_stress_preview.tscn   # Dedicated performance surface
  vfx_performance_stress_preview.gd     # Paired-run state machine and presentation boundary
  vfx_performance_stress_stage.gd       # Stable vehicle grid and slot enable/reset
  vfx_stress_vehicle_slot.gd            # Minimal vehicle art/plane/runtime slot host
src/editor/performance/
  vfx_performance_panel.gd              # Authoring Budget and Studio Stress controls/results
src/preview/
  vfx_preview_workspace.gd              # Runtime-inserted Authoring/Performance switch
tests/performance/
  test_performance_policy_and_lod.gd
  test_performance_budget.gd
  test_stress_scenario_and_layout.gd
  test_runtime_metric_accumulator.gd
  test_stress_preview.gd
tests/run_performance_tests.gd
```

Existing Preview, Editor, and test-runner files are modified only where the
interfaces below require integration. `vfx_editor_main.tscn` is not modified;
the workspace is inserted into its existing `PreviewHost` at runtime.

### Task A: LOD + Derived / Workload Budget

**Files:**

- Create: `config/vfx_performance_policy_v1.json`
- Create: all `src/performance/` budget, policy, scenario, and threshold files listed above except runtime metric, Snapshot, and environment files
- Modify: `src/preview/rendering/vfx_preview_render_runtime.gd` only to expose read-only active-entry facts needed by later Stress collection
- Test: `tests/performance/test_performance_policy_and_lod.gd`
- Test: `tests/performance/test_performance_budget.gd`
- Create: `tests/run_performance_tests.gd`

**Interfaces:**

- Consumes: a valid immutable `VfxPreviewRenderPlan`, selected Vehicle Profile,
  `VfxSchemaRegistry`, and `VfxPreviewAssetRegistry` definitions.
- Produces:

  ```gdscript
  VfxPerformancePolicy.load(registry: RefCounted) -> VfxResult
  VfxPreviewLodFilter.filter(plan: RefCounted, lod_level: String, policy: RefCounted) -> VfxResult
  VfxPerformanceBudgetAnalyzer.analyze(plan: RefCounted, profile_data: Dictionary, scenario: RefCounted) -> VfxResult
  VfxScenarioProjection.project(slot_budgets: Array, scenario: RefCounted) -> RefCounted
  VfxBudgetThresholdEvaluator.evaluate(workload_projection: RefCounted, policy: RefCounted) -> RefCounted
  ```

- [ ] **Step 1: Write failing policy, LOD, and budget tests**

  Add assertions that the policy loads `policy_version: 1` and
  `calibration_state: UNCALIBRATED`; an unknown policy Importance fails against
  Schema; filtering never changes the original Plan; and Zero Zone has these
  exact one-vehicle values:

  ```text
  Lifecycle inventory: HIGH 11, MEDIUM 9, LOW 3
  STEADY_LOOP active instances: HIGH 5, MEDIUM 4, LOW 2
  STEADY_LOOP continuous particles: HIGH 10, MEDIUM 6, LOW 0
  ```

  Also assert a four-anchor Layer multiplies both inventory and workload
  instances by four; Burst values do not appear in a Zero Zone steady loop;
  Trail `max_points`, ring potential, texture ids, and render-plane counts are
  aggregated; and the 20x3 HIGH steady-loop projection is 300 active instances
  and 600 continuous particles.

- [ ] **Step 2: Run the focused Performance runner and confirm failure**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_performance_tests.gd'
  ```

  Expected before implementation: missing policy/filter/analyzer classes or
  expected assertion failures; do not interpret headless frame rate as a test.

- [ ] **Step 3: Implement config-backed immutable analysis**

  Implement the compact policy parser and cross-check its LOD Importance lists
  with the Schema registry. Build a new Plan per LOD without mutating Layer
  specs. Resolve anchors through the existing instance resolver, aggregate all
  phase records into `VfxAuthoringBudget`, and aggregate only `loop` for
  `STEADY_LOOP` or `one_shot` for `REPEATED_ONE_SHOT` into
  `VfxWorkloadBudget`. Make scenario multiplication sum Slot A/B/C before
  multiplying by vehicle count. Evaluate only workload projections and return
  `UNCALIBRATED` reasons with each status.

- [ ] **Step 4: Run focused budget tests and confirm pass**

  Expected: exact Zero Zone, multi-anchor, Trail, Ring, texture, plane,
  scenario, and threshold-reason assertions pass; no test checks FPS.

- [ ] **Step 5: Leave Task A unstaged**

  Inspect `git status --short`; do not add, reset, revert, or commit any file.

### Task B: Stress Preview + Scenario Replication

**Files:**

- Create: `src/preview/performance/vfx_performance_stress_preview.tscn`
- Create: `src/preview/performance/vfx_performance_stress_preview.gd`
- Create: `src/preview/performance/vfx_performance_stress_stage.gd`
- Create: `src/preview/performance/vfx_stress_vehicle_slot.gd`
- Modify: `src/preview/rendering/vfx_preview_render_runtime.gd` only if the
  Stage needs a non-mutating packet/active-entry accessor
- Test: `tests/performance/test_stress_scenario_and_layout.gd`
- Test: `tests/performance/test_stress_preview.gd`
- Modify: `tests/run_performance_tests.gd`

**Interfaces:**

- Consumes: Task A filtered Plans, `VfxStressScenario`, current Vehicle Profile
  and `VfxPreviewGameScale`, plus existing Render Runtime/Factory/Asset
  Resolver/Playback classes.
- Produces:

  ```gdscript
  VfxPerformanceStressStage.prepare(scenario: RefCounted, slots: Array, profile_data: Dictionary) -> VfxResult
  VfxPerformanceStressStage.set_vfx_enabled(enabled: bool) -> void
  VfxPerformanceStressStage.reset_workload() -> void
  VfxPerformanceStressStage.advance(delta_seconds: float) -> Dictionary
  VfxPerformanceStressPreview.configure_stress_input(input: Dictionary) -> VfxResult
  ```

- [ ] **Step 1: Write failing Stage and replication tests**

  Assert deterministic 1x1, 10x1, 20x1, 10x3, and 20x3 grid layouts construct
  exactly their vehicle and enabled-slot counts; Slot A defaults to the current
  Plan, B/C default to `None`; replicate-current produces three separate
  runtime slots per vehicle without changing the source Plan; and all Stress
  vehicle scales equal the existing effective game scale rather than Control
  size or Stage fit scale.

- [ ] **Step 2: Run focused Stage tests and confirm failure**

  Run the Performance runner. Expected before implementation: stress scene or
  Stage class cannot instantiate and scenario-layout assertions fail.

- [ ] **Step 3: Implement the dedicated same-scale Stress Stage**

  Build one minimal `VfxStressVehicleSlot` per vehicle with art, existing plane
  host semantics, and one existing Runtime/Playback pair per enabled Slot.
  Place the slots in a scrollable deterministic grid without changing the
  vehicle/effect scale. Construct all selected Plan/asset/runtime resources in
  `prepare`, retain them disabled for baseline, and use `set_vfx_enabled` plus
  `reset_workload` to switch the same Stage into the VFX run. Use manual loop
  Playback for `STEADY_LOOP`; restart an existing ONE_SHOT Playback only after
  it terminates for `REPEATED_ONE_SHOT`.

- [ ] **Step 4: Run focused Stage tests and confirm pass**

  Expected: the dedicated Stress Preview instantiates/frees headlessly,
  20x3 creates 20 vehicles and 60 enabled runtimes, and baseline/VFX toggling
  preserves the same vehicle-node identities and grid positions.

- [ ] **Step 5: Leave Task B unstaged**

  Inspect status only. Do not stage, commit, or change the main editor scene.

### Task C: Metrics + Performance UI

**Files:**

- Create: `src/performance/vfx_runtime_metric_accumulator.gd`
- Create: `src/performance/vfx_performance_snapshot.gd`
- Create: `src/performance/vfx_stress_measurement_environment.gd`
- Create: `src/editor/performance/vfx_performance_panel.gd`
- Create: `src/preview/vfx_preview_workspace.gd`
- Modify: `src/preview/vfx_vehicle_preview.tscn`
- Modify: `src/preview/vfx_vehicle_preview.gd`
- Modify: `src/preview/performance/vfx_performance_stress_preview.gd`
- Modify: `src/editor/main/vfx_editor_main.gd`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Test: `tests/performance/test_runtime_metric_accumulator.gd`
- Modify: `tests/performance/test_stress_preview.gd`
- Modify: `tests/preview/test_editor_preview_integration.gd`
- Modify: `tests/run_performance_tests.gd`
- Modify: `tests/run_preview_tests.gd`

**Interfaces:**

- Consumes: Task A budget/projection/evaluation values and Task B stable Stage
  packet/active-entry facts.
- Produces:

  ```gdscript
  VfxRuntimeMetricAccumulator.begin_measurement() -> void
  VfxRuntimeMetricAccumulator.sample(frame_delta_seconds: float, runtime_facts: Dictionary) -> void
  VfxRuntimeMetricAccumulator.finish() -> Dictionary
  VfxPerformanceStressPreview.run_studio_stress() -> VfxResult
  VfxPerformanceSnapshot.preview_frame_time_delta_ms() -> float
  ```

- [ ] **Step 1: Write failing metric and UI integration tests**

  Assert warm-up samples do not enter the measurement accumulator; a known
  sample set has exact average, max, and P95 frame time; average FPS is the
  reciprocal of average frame time; Particle/Trail/Ring values are peak packet
  counts; and a paired result reports `VFX average - baseline average` as
  Preview Frame Time Delta. Assert Snapshot includes `UNCALIBRATED`, workload,
  synchronization, VSync/cap context, and no Preset write path. Assert normal
  Preview LOD changes use filtered Plans and Performance mode keeps Authoring
  Budget and Studio Stress Result separate.

- [ ] **Step 2: Run focused metric/UI tests and confirm failure**

  Run the Performance and focused Preview runners. Expected before
  implementation: no accumulator/Snapshot state machine or workspace
  integration exists.

- [ ] **Step 3: Implement paired measurement, explicit environment context, and workspace UI**

  Implement the `PREPARE -> BASELINE_WARMUP -> BASELINE_MEASURE -> VFX_WARMUP
  -> VFX_MEASURE -> COMPLETE` state machine over Task B's unchanged Stage.
  Feed its existing rendered packet facts to the accumulator only in measure
  states. Record observed VSync and frame cap by default; make temporary
  uncapping opt-in and restore its captured settings on completion,
  cancellation, error, and teardown. Add an independent compact LOD row to
  `VfxVehiclePreview`. Runtime-insert an Authoring/Performance workspace into
  the existing PreviewHost, with a flexible Stage area and a scrollable result
  area. Label every status and value with Studio/Authoring terminology.

- [ ] **Step 4: Run focused metric/UI tests and confirm pass**

  Expected: known aggregate math, warm-up exclusion, same-stage paired order,
  restoration on cancellation, LOD routing, Snapshot boundaries, and UI text
  assertions all pass. No UI value calls itself game performance or game safe.

- [ ] **Step 5: Leave Task C unstaged**

  Inspect status only; preserve pre-existing modified files exactly where this
  Task does not require an intentional line-level integration change.

### Task D: Integration + Regression + Manual Benchmark Workflow

**Files:**

- Modify: `docs/VFX_STUDIO_ARCHITECTURE.md`
- Modify: `docs/VFX_EDITOR_ROADMAP.md` only if Phase 4 status/routing belongs there
- Modify: `tests/editor/test_main_scene_smoke.gd`
- Modify: `tests/run_editor_tests.gd` only if a dedicated performance workspace
  smoke test belongs with editor tests
- Modify: `tests/run_performance_tests.gd`
- Modify: `tests/run_preview_tests.gd`
- Modify: only affected Phase 4 test files from Tasks A-C

**Interfaces:**

- Consumes: the completed policy/filter/budget, Stress Stage, accumulator,
  Snapshot, and runtime-inserted workspace interfaces from Tasks A-C.
- Produces: durable Studio-versus-game documentation, final suite coverage,
  and a manual workflow without an Export or game-runtime artifact.

- [ ] **Step 1: Write final regression and smoke assertions**

  Assert the main editor scene creates the runtime-inserted workspace without
  modifying `vfx_editor_main.tscn`; Zero Zone uses a HIGH/MEDIUM/LOW filtered
  Plan in both Authoring and Stress paths; `20x3 + replicate current` exposes
  20 vehicles and 60 Preview runtime slots; `VEHICLE_STRESS` is explicit;
  `CELEBRATION_STRESS` remains unavailable rather than auto-derived from
  category; and Snapshot/Authoring Budget contain no `.vfx.json` persistence
  behavior.

- [ ] **Step 2: Run focused integration tests and confirm pass**

  Run the Performance, Preview, and Editor runners. Expected: all Phase 4
  focused assertions pass before full regression; no benchmark FPS threshold
  is used.

- [ ] **Step 3: Update durable architecture and workflow documentation**

  Record the permanent Studio Preview versus future game-runtime boundary,
  `UNCALIBRATED` policy meaning, Lifecycle Envelope versus Active Workload
  separation, synchronized workload types, same-stage baseline method,
  VSync/cap context, session-only Snapshot, Celebration seam, and the manual
  Zero Zone workflow. Do not add an export manifest or change Schema docs.

- [ ] **Step 4: Run final regression once**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_contract_tests.gd'
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_editor_tests.gd'
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_preview_tests.gd'
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_performance_tests.gd'
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path 'C:\GodotProjects\DesktopRacingVFXStudio' --quit
  ```

  Expected: all suites and the editor parse exit zero. Run no Windows Export.

- [ ] **Step 5: Report only unstaged working-tree state**

  Run `git diff --check`, `git diff --cached --quiet`, and `git status --short`.
  Report actual test exit codes, changed files, preserved user changes, and
  staged-state result. Do not run `git add`, `git commit`, reset, revert, or
  checkout.

## Plan self-review

- Task A covers the immutable shared LOD filter, policy validation,
  Lifecycle/Workload separation, exact Budget aggregation, scenario projection,
  and uncalibrated threshold reasons.
- Task B covers the dedicated many-vehicle Stage, shared renderer/runtime
  reuse, slots, replication, workload scheduling, and same-stage baseline
  preparation.
- Task C covers actual Studio Preview metric collection, paired timing,
  VSync/cap handling, Snapshot, and the separate Authoring/Stress UI regions.
- Task D covers durable boundaries, smoke/integration coverage, final
  regression, and the manual user-PC workflow.
- Every task has a focused test-first cycle and no Git commit step. No task
  changes Schema v1, Preset data, game integration, Export, or Dynamic LOD.
