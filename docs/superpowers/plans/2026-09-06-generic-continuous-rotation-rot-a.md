# Generic Continuous Rotation ROT-A Implementation Plan

> **For agentic workers:** Execute this plan task-by-task with TDD. Every
> checkbox is a review point. Do not implement any task until the owner has
> separately approved execution of this plan.

**Goal:** Add the minimal generic `LINEAR_PHASE` Runtime Modulation source that
reuses effect-local elapsed time to drive continuous `TEXTURED_SPRITE` rotation
through existing mapping and rotation contracts.

**Architecture:** The Schema defines strict source alternatives for preserved
`OSCILLATOR/SINE` and new `LINEAR_PHASE`. The existing compiled source spec
stores an integer kind resolved by the builder, and the existing evaluator
samples the kind with either the preserved SINE formula or `fposmod`. Existing
v2 export already copies the source table; it is verified, not rearchitected.

**Tech Stack:** Godot 4.7.1 stable, GDScript, JSON Schema subset, existing
Runtime Modulation program/evaluator, and current Godot headless test runners.

**Spec:** `docs/superpowers/specs/2026-09-06-generic-continuous-rotation-rot-a-design.md`

## Global Constraints

- Use `LINEAR_PHASE` with the exact strict fields `id`, `type`, and
  `frequency_hz`; accept only finite `frequency_hz > 0`.
- Reuse `VfxPreviewRuntimeModulationEvaluator._sample_sources` elapsed-time
  parameter. Add no clock, Timer, Tween, Node, timeline, history, or RNG.
- Reuse `LINEAR_RANGE`, `TRANSFORM_ROTATION_DEGREES`, and `ADD`; add no target.
- Do not alter `OSCILLATOR/SINE` source shape or numerical semantics.
- Do not change any Preview renderer, shader, packet ordering, Package writer,
  Package Format v1, or Runtime Definition v3.
- Do not edit `equipment.rotor_lift.downwash`, Rotor Lift package files, Rotor
  Lift PNGs, another production preset, or any DesktopIdleRacing path.
- Do not run canonical export or Package writer.
- Never stage, commit, reset, checkout, revert, clean, or stash. Preserve the
  existing dirty worktree and leave staged file count at zero.

---

## File map

| File | Responsibility during ROT-A |
| --- | --- |
| `schemas/vfx_schema_v1.json` | strict `OSCILLATOR` and `LINEAR_PHASE` authoring alternatives plus Schema-owned source contract metadata |
| `src/model/vfx_rule_catalog.gd` | validates optional wave/phase requirements in the declared source-type metadata |
| `src/model/vfx_contract_validator.gd` | applies type-specific finite/positive source validation after schema decode |
| `src/preview/runtime_modulation/vfx_runtime_modulation_source_spec.gd` | immutable compiled source-kind slot and scalar data |
| `src/preview/runtime_modulation/vfx_runtime_modulation_program_builder.gd` | resolves authored source type exactly once into the compiled source spec |
| `src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd` | samples SINE or LINEAR_PHASE using the existing elapsed-time argument |
| `tests/fixtures/presets/utility.linear_phase_rotation_fixture.vfx.json` | test-only v2 fixture with shared opposite mappings and a second frequency |
| `tests/unit/test_runtime_modulation_contract.gd` | strict valid/invalid source contract cases |
| `tests/preview/test_runtime_modulation_program.gd` | numeric, mapping, wrap, pivot, packet-path, and SINE regression cases |
| `tests/performance/test_runtime_modulation_structure.gd` | two-source/four-binding steady-state structural budget assertion |
| `tests/export/test_runtime_modulation_export_guard.gd` | v2 source serialization/round-trip and static-v1 no-leak assertions |
| `tests/run_export_tests.gd` | includes the focused export guard in the Export suite |
| `docs/VFX_SCHEMA_V1.md` | authoring and evaluation contract documentation |
| `docs/VFX_EXPORT_PACKAGE_V1.md` | portable v2 serialization and static-v1 boundary documentation |

No new production file or class is created. `src/export/vfx_export_compiler.gd`
is intentionally not modified: it already selects v2 for modulation-bearing
presets and deep-copies the normalized source table. Export tests must prove
that this remains sufficient.

### Task 1: Strict Schema and validator contract

**Files:**
- Modify: `schemas/vfx_schema_v1.json:191-201, 890-940`
- Modify: `src/model/vfx_rule_catalog.gd:84-113`
- Modify: `src/model/vfx_contract_validator.gd:258-270`
- Modify: `tests/unit/test_runtime_modulation_contract.gd:run and source fixtures`

**Interfaces:**
- Consumes: existing `runtime_modulation_sources`, the rule name
  `RUNTIME_MODULATION_CONFIGURATION`, and `VfxPresetPipeline` validation.
- Produces: two strict source shapes and a normalized source table that the
  existing program builder can consume without optional-field guessing.

- [ ] **Step 1: Write the failing contract assertions**

  Add a helper that replaces the valid fixture source with:

  ```gdscript
  {
      "id": "linear.phase",
      "type": "LINEAR_PHASE",
      "frequency_hz": 1.0
  }
  ```

  Assert it validates after implementation. Add separate assertions that
  `0.0`, `-0.5`, `NAN`, `INF`, a missing `frequency_hz`, and extra
  `wave`/`phase_degrees` fields are rejected. Retain a valid
  `OSCILLATOR/SINE` fixture and assert its original `wave`, phase, and zero
  frequency behavior remain valid.

- [ ] **Step 2: Run the Contract suite to verify RED**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_contract_tests.gd
  ```

  Expected: the valid `LINEAR_PHASE` assertion fails because the current
  source schema accepts only `OSCILLATOR` and requires `wave` plus
  `phase_degrees`.

- [ ] **Step 3: Implement the smallest strict source alternative**

  In `runtime_modulation_source`, use strict Schema alternatives so:

  ```json
  { "id": "...", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 0.0, "phase_degrees": 0.0 }
  ```

  remains the only oscillator shape, while:

  ```json
  { "id": "...", "type": "LINEAR_PHASE", "frequency_hz": 1.0 }
  ```

  is the only linear-phase shape. Configure source metadata with explicit
  `requires_wave`, `requires_phase`, and positive-frequency requirements for
  the linear source. Update the rule catalog to validate those flags and allow
  no wave list only when `requires_wave` is false. Update
  `_validate_modulation_source` to preserve the existing oscillator checks and
  require finite `frequency_hz > 0` only for `LINEAR_PHASE`.

  Do not introduce a generic source-expression evaluator, source manager, or
  source-specific preset branch.

- [ ] **Step 4: Re-run the Contract suite to verify GREEN**

  Re-run `res://tests/run_contract_tests.gd`. Expected: all strict source
  assertions pass, the old SINE fixture remains valid, and no unrelated
  contract assertion changes.

### Task 2: Compiled LINEAR_PHASE source and evaluator

**Files:**
- Create: `tests/fixtures/presets/utility.linear_phase_rotation_fixture.vfx.json`
- Modify: `src/preview/runtime_modulation/vfx_runtime_modulation_source_spec.gd:1-34`
- Modify: `src/preview/runtime_modulation/vfx_runtime_modulation_program_builder.gd:54-63`
- Modify: `src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd:41-46`
- Modify: `tests/preview/test_runtime_modulation_program.gd:run and new linear-phase helpers`

**Interfaces:**
- Consumes: normalized strict source dictionaries from Task 1 and the existing
  `instance_elapsed_seconds` parameter of `_sample_sources`.
- Produces: immutable compiled source specs with an integer source kind and
  one scalar sampled output per shared source slot.

- [ ] **Step 1: Write the failing numeric and Preview assertions**

  Create a test-only `ONE_SHOT` preset fixture containing:

  ```json
  "runtime_modulation_sources": [
    { "id": "rotation.one_hz", "type": "LINEAR_PHASE", "frequency_hz": 1.0 },
    { "id": "rotation.half_hz", "type": "LINEAR_PHASE", "frequency_hz": 0.5 }
  ]
  ```

  Use two `TEXTURED_SPRITE` layers with the existing preview fixture texture,
  `modulation_pivot_local`, and bindings from the shared 1 Hz source to
  `0 -> +360` and `0 -> -360` degrees. Add a second-frequency binding and an
  authored base rotation on one layer.

  Assert numeric sequences:

  ```text
  1 Hz: 0=.0, .125=.125, .25=.25, .5=.5, .999≈.999, 1=.0, 1.25=.25
  2 Hz: .125=.25, .25=.5, .5=.0
  .5 Hz: .5=.25, 1=.5, 2=.0
  ```

  Assert every sampled value is `>= 0` and `< 1`; shared source sampling is
  once per tick; mappings yield opposite rotations; base rotation is added;
  the wrapped delta between mapped 1 Hz rotation at `.999` and `1.001` is
  approximately `.72` degrees; and pivot root error at `0/90/180/270/359`
  degrees is `<= .001` source pixels.

- [ ] **Step 2: Run the Preview suite to verify RED**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_preview_tests.gd
  ```

  Expected: the fixture can validate after Task 1 but program compilation or
  evaluator sampling fails because the current source spec has no source-kind
  and builder tries to read missing `phase_degrees`.

- [ ] **Step 3: Implement the compiled source-kind branch**

  Add `SOURCE_OSCILLATOR_SINE` and `SOURCE_LINEAR_PHASE` integer constants to
  `VfxRuntimeModulationSourceSpec`. Preserve the immutable slot/id/frequency
  fields and retain oscillator radians only for SINE. Extend `with_slot()` to
  retain the source kind.

  In the builder, resolve `source["type"]` once and construct the matching
  source spec. Supply phase radians only for `OSCILLATOR`; use neutral `0.0`
  for `LINEAR_PHASE`.

  In `_sample_sources`, retain the exact SINE expression for
  `SOURCE_OSCILLATOR_SINE`; add the only new branch:

  ```gdscript
  fposmod(instance_elapsed_seconds * source.frequency_hz(), 1.0)
  ```

  Write only to the existing pre-sized `_source_values` slot. Do not allocate
  a collection, use source id strings, or change renderer code.

- [ ] **Step 4: Re-run the Preview suite to verify GREEN**

  Re-run `res://tests/run_preview_tests.gd`. Expected: numeric sweeps,
  wrap-continuity, pivot preservation, shared opposite mappings, two-frequency
  behavior, and existing SINE assertions all pass. Confirm the synthetic
  layers continue to use the existing textured-sprite packet path and no
  renderer file changed.

### Task 3: Steady-state structural budget and v2 export projection

**Files:**
- Modify: `tests/performance/test_runtime_modulation_structure.gd:8-14`
- Modify: `tests/export/test_runtime_modulation_export_guard.gd:7-58`
- Modify: `tests/run_export_tests.gd:top-level preloads and _run`

**Interfaces:**
- Consumes: Task 2's two-source fixture, immutable program source specs, and
  the existing `VfxExportCompiler` v2 projection.
- Produces: evidence that two sources/four bindings have a stable compiled
  identity and that `LINEAR_PHASE` serializes portably without compiler or
  writer changes.

- [ ] **Step 1: Write the failing Performance and Export assertions**

  In the structural performance test, build the test fixture program, retain
  its two source object references and program reference, refresh 100 times,
  then assert program identity is unchanged, source object identity is
  unchanged, sampled source count is exactly `2` each tick, and binding count
  is exactly `4`.

  In the export guard, compile the same fixture in memory and assert:

  ```text
  runtime_definition_version == 2
  package_format_version == 1
  runtime path == runtime/vfx_runtime_definition_v2.json
  runtime_modulation_sources equals the normalized LINEAR_PHASE source array
  no res:// or absolute path occurs
  repeated compilation has byte-identical runtime text
  ```

  Compile the existing static Zero Zone document and assert its Runtime
  Definition remains v1 and contains neither `LINEAR_PHASE` nor
  `frequency_hz` source placeholders. Add the focused guard to
  `tests/run_export_tests.gd` so the Export suite actually executes it.

- [ ] **Step 2: Run Performance and Export suites to verify RED**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_performance_tests.gd
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_export_tests.gd
  ```

  Expected: before Task 2 is complete, the fixture cannot compile; before
  adding the runner preload/call, the guard is not part of the Export suite.

- [ ] **Step 3: Keep Export compiler and writer untouched**

  Do not modify `src/export/vfx_export_compiler.gd` or any writer. The existing
  modulation-bearing classifier and v2 deep-copy are the implementation.
  Make only the focused runner registration needed to exercise the test.
  Verify the evaluator implementation from Task 2 keeps its fixed
  `PackedFloat64Array` and does not add per-tick Dictionary, Array, or String
  work.

- [ ] **Step 4: Re-run Performance and Export suites to verify GREEN**

  Re-run both commands. Expected: the 100-tick structural assertions and v2
  round-trip/portability checks pass; static v1 remains clean; no Package
  writer runs.

### Task 4: Contract documentation and complete verification

**Files:**
- Modify: `docs/VFX_SCHEMA_V1.md:Runtime Modulation section`
- Modify: `docs/VFX_EXPORT_PACKAGE_V1.md:Runtime Definition v2 section`

**Interfaces:**
- Consumes: the exact implemented strict source shape, source evaluation, and
  existing v2 deep-copy projection.
- Produces: concise durable contract documentation for future Studio and Game
  implementation work.

- [ ] **Step 1: Document only implemented behavior**

  In `VFX_SCHEMA_V1.md`, document the exact `LINEAR_PHASE` object, positive
  finite frequency requirement, `fposmod(elapsed * frequency_hz, 1.0)` output,
  no `wave`/`phase_degrees`, no negative-frequency direction behavior, wrap
  equivalence, and intended use with existing rotation ADD mapping. State that
  it reuses effect-local elapsed time and adds no timing subsystem.

  In `VFX_EXPORT_PACKAGE_V1.md`, document v2 source serialization, unchanged
  Package Format v1, and the static-v1 no-leak rule. Do not document Game
  runtime support as implemented.

- [ ] **Step 2: Run all requested regression evidence**

  Run each command once after all focused tests are green:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_contract_tests.gd
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_editor_tests.gd
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_preview_tests.gd
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_performance_tests.gd
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_export_tests.gd
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path 'C:\GodotProjects\DesktopRacingVFXStudio' --quit
  git diff --check
  git status --short
  git diff --cached --name-only
  ```

  Expected: all suites pass, the editor parse exits `0`, diff check exits `0`,
  staged output is empty, and existing dirty worktree files remain preserved.

- [ ] **Step 3: Verify immutable scope boundaries**

  Confirm `git diff --` shows no changes to `presets/examples/equipment.rotor_lift.downwash.vfx.json`, `exports/packages/equipment.rotor_lift.downwash/`,
  `assets/vfx/rotor_lift_downwash_*.png`, Preview renderer files, Package
  writer files, or a DesktopIdleRacing path. Confirm no canonical export was
  called and no source/test helper remains outside the planned files.

## Plan self-review

- **Coverage:** Task 1 owns strict source forms and rejection cases; Task 2
  owns exact numeric/effective-transform behavior; Task 3 owns fixed-cost
  structure plus portable v2 output and v1 isolation; Task 4 owns durable
  docs and complete verification.
- **Complexity:** no task introduces a manager, service, renderer, shader,
  clock, Node, timer, tween, state accumulator, new target, Runtime v3, or
  Package Format change.
- **TDD:** every production-file change follows a focused test and an observed
  expected RED before the minimal GREEN change.
- **Git policy:** this plan deliberately contains no stage or commit step.
