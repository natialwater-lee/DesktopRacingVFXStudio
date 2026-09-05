# Generic VFX Bend B2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fail-closed, portable `TEXTURED_SPRITE` Generic Bend v1
contract and Runtime Definition v2 projection without rendering deformation in
Studio Preview.

**Architecture:** Schema v1 declares optional static `visual_bend` and one
new existing-framework modulation target. The existing Runtime Modulation rule
validates it, the numeric program evaluates it without renderer consumption,
and `VfxExportCompiler` projects it only to Runtime Definition v2.
`VfxLayerInspector` receives only a compact static-metadata subsection;
binding authoring remains source-contract JSON.

**Tech Stack:** Godot 4.7.1 stable, GDScript, JSON Schema subset, existing
Preset pipeline, existing Runtime Modulation program/evaluator, existing
deterministic Package compiler/writer.

**Spec:** `docs/superpowers/specs/2026-09-05-generic-vfx-bend-b2-design.md`

## Global Constraints

- Work only in `C:\GodotProjects\DesktopRacingVFXStudio`; never access `DesktopIdleRacing`.
- Retain Schema v1, Package Format v1, and Runtime Definition v1/v2 only.
- Do not modify `VfxPreviewCanvasRenderHost`, `VfxVehiclePreview`, Preview packet routing/order, direct draw path, renderer classes, shaders, materials, or create Preview nodes/adapters.
- Do not create a bend-specific evaluator/service/manager or a Runtime Modulation editor.
- Do not change production Super Booster Presets or canonical Package output; use only a test fixture and test writer directory.
- Do not run a Package writer against a canonical Package, Windows Export, `git add`, `git commit`, reset, revert, checkout, clean, or stash. End with staged files `0`.

---

### Task 1: Schema-owned Bend contract and fail-closed validation

**Files:**
- Modify: `schemas/vfx_schema_v1.json`
- Modify: `src/model/vfx_rule_catalog.gd`
- Modify: `src/model/vfx_schema_registry.gd`
- Modify: `src/model/vfx_contract_validator.gd`
- Modify: `tests/unit/test_schema_registry.gd`
- Modify: `tests/unit/test_runtime_modulation_contract.gd`

**Interfaces:**
- Consumes: Schema `$defs.layer`, Runtime Modulation target enum, and `RUNTIME_MODULATION_CONFIGURATION`.
- Produces: optional Layer `visual_bend`, target `VISUAL_BEND_OFFSET_X`, and target-contract metadata requiring `TEXTURED_SPRITE`, `ADD`, static metadata, and a target clamp.

- [ ] **Step 1: Write the failing contract tests**

  Add test-local valid data plus mutations that assert explicit validation
  failure for non-`TEXTURED_SPRITE` metadata, invalid axis/curve,
  `start_ratio` `-0.01` and `1.0`, zero/negative/non-finite span,
  non-finite ratio, bend target without metadata, `MULTIPLY`, missing clamp,
  non-finite mapping, and malformed bend target configuration.

- [ ] **Step 2: Run tests to verify RED**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_contract_tests.gd
  ```

  Expected: the valid bend fixture or target-enum assertion fails because
  `visual_bend` and `VISUAL_BEND_OFFSET_X` are not declared yet.

- [ ] **Step 3: Write the minimal implementation**

  Add strict `$defs.visual_bend`; add the Layer property and target enum; add
  target contract constraints. Extend Rule Catalog/Registry configuration
  validation for target metadata. In the existing Runtime Modulation validator,
  validate static metadata and enforce configured metadata/clamp requirements
  after all Layer bindings and clamps have been read. Use Schema configuration
  for field/target names and do not add a rule handler or service.

- [ ] **Step 4: Run tests to verify GREEN**

  Re-run `run_contract_tests.gd`; expect the valid case and every rejection
  case to pass.

### Task 2: Static inspector authoring and source round-trip

**Files:**
- Modify: `src/editor/inspector/vfx_layer_inspector.gd`
- Modify: `src/editor/main/vfx_editor_controller.gd` only for existing working-copy add/remove commits if necessary
- Modify: `tests/editor/test_common_inspectors.gd`

**Interfaces:**
- Consumes: Schema `visual_bend` definition and existing Layer field-commit/JSON-pointer path.
- Produces: a `TEXTURED_SPRITE`-only Visual Bend subsection which creates/removes one strict object; optional Transform `modulation_pivot_local` Vector2 commit using the existing Transform controller path.

- [ ] **Step 1: Write the failing editor tests**

  Instantiate a schema-backed `TEXTURED_SPRITE` inspector and assert enabling
  Visual Bend writes the exact default object, field commits update its four
  JSON paths, disabling removes it, and a pivot field commit saves `[x, y]`
  through the existing edit session. Assert a non-textured inspector does not
  expose the section.

- [ ] **Step 2: Run tests to verify RED**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_editor_tests.gd
  ```

  Expected: missing controls/signals or absent working-copy `visual_bend`
  data causes the new assertions to fail.

- [ ] **Step 3: Write the minimal implementation**

  Reuse `VfxLayerInspector`, `VfxSchemaInspectorFactory`, and the current
  controller edit-session path. Add no panel/dialog/component and no
  modulation-binding UI. Create/remove only `visual_bend`; preserve every
  unrelated Layer field. If a Transform pivot control can use the current
  Vector2 control path without architecture changes, expose it; otherwise
  leave it source-contract-only and add a test documenting that no
  bend-specific transform UI was introduced.

- [ ] **Step 4: Run tests to verify GREEN and round-trip**

  Re-run `run_editor_tests.gd`, then load/normalize/validate the saved bend
  fixture through `VfxPresetPipeline` in its focused test. Expect exact
  metadata semantics after load.

### Task 3: Generic numeric evaluation with straight Preview fallback

**Files:**
- Create: `tests/fixtures/presets/utility.visual_bend_fixture.vfx.json`
- Modify: `tests/preview/test_runtime_modulation_program.gd`
- Modify: `tests/performance/test_runtime_modulation_structure.gd` only if structural counts require an explicit no-render-cost assertion

**Interfaces:**
- Consumes: Schema-declared target slots and the existing generic Program/Evaluator.
- Produces: numeric `VISUAL_BEND_OFFSET_X` evaluation from `turn_rate_normalized`, final clamp application, and an unchanged direct-draw textured packet.

- [ ] **Step 1: Write the failing Preview tests**

  Add the fixture with pivot `[0, 40]`, `LOCAL_Y_POSITIVE`, ratio
  `0.333333`, quadratic curve, span `240`, mapping
  `[-0.20, 0.20] -> [60, -60]`, and clamp `[-60, 60]`. Assert slot values
  for `-1/0/+1` are `60/0/-60`, clamp holds for saturated input, and its
  texture packet geometry remains equal to authored straight geometry.

- [ ] **Step 2: Run tests to verify RED**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_preview_tests.gd
  ```

  Expected: fixture validation/program construction fails because the target
  does not exist.

- [ ] **Step 3: Use existing generic slots; do not change a renderer**

  Confirm the existing program includes the Schema target and
  `VfxPreviewEffectiveLayerState` retains its zero base value for that
  unconsumed numeric slot. Add no bend-specific evaluator branch and change no
  Preview renderer, host, packet, or ordering file.

- [ ] **Step 4: Run tests to verify GREEN**

  Re-run `run_preview_tests.gd` and focused Performance tests. Expect numeric
  evaluation to work while the packet stays straight and steady-state
  renderer/entity inventory is unchanged.

### Task 4: Runtime Definition v2 projection and test-only writer portability

**Files:**
- Modify: `src/export/vfx_export_compiler.gd`
- Modify: `tests/export/test_runtime_modulation_export_guard.gd`
- Modify: `tests/export/test_export_compiler_and_writer.gd`
- Create or modify: a focused export test only if the existing guard suite cannot express fixture coverage clearly

**Interfaces:**
- Consumes: normalized bend fixture and compiler version classifier.
- Produces: Runtime Definition v2 containing `visual_bend`, generic binding/clamp arrays, and no Studio paths; test writer Package inventory selected by the immutable plan.

- [ ] **Step 1: Write the failing export tests**

  Assert bend metadata alone selects v2; compiled v2 contains exact
  metadata/binding/clamp; repeated compilation is byte-identical; a test-only
  writer Package has matching Manifest hash/size/inventory; and a non-bend
  static golden remains v1 without bend/pivot leakage.

- [ ] **Step 2: Run tests to verify RED**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_export_tests.gd
  ```

  Expected: the bend fixture incorrectly selects v1 or its v2 record has no
  `visual_bend` member.

- [ ] **Step 3: Write the minimal compiler projection**

  Treat a Layer with `visual_bend` as v2-bearing, add a deep-copied
  `visual_bend` member to the existing v2 Layer dictionary only when present,
  and leave `_runtime_v1_transform`/v1 Layer projection unchanged. Reuse the
  existing package plan and atomic writer without a writer architecture change
  or canonical write.

- [ ] **Step 4: Run tests to verify GREEN**

  Re-run `run_export_tests.gd` and `run_export_contract_tests.gd`; expect
  portable v2 fixture output and unchanged v1 golden behavior.

### Task 5: Contract documentation and final regression

**Files:**
- Modify: `docs/VFX_SCHEMA_V1.md`
- Modify: `docs/VFX_EXPORT_PACKAGE_V1.md`
- Modify: `docs/VFX_STUDIO_ARCHITECTURE.md`

**Interfaces:**
- Consumes: implemented Schema, validator, Preview boundary, and v2 compiler behavior.
- Produces: one consistent portable bend contract for a later Game BEND-C consumer.

- [ ] **Step 1: Document only the implemented contract**

  Record `visual_bend` fields, pivot/formula/unit/sign, required ADD target
  clamp, fail-closed invalid combinations, v2-selection/serialization, v1
  no-leak, and the explicit Preview-straight Runtime-only boundary. Do not
  document a shader or Game implementation.

- [ ] **Step 2: Run final evidence commands**

  Run Contract, Editor, Preview, Performance, Export Contract, and Export
  suites; then run `--headless --editor --quit` with Godot 4.7.1 and
  `git diff --check`. Inspect `git status --short` and
  `git diff --cached --name-only`.

- [ ] **Step 3: Verify scope invariants**

  Confirm no Preview renderer/host/routing file, production Super Booster
  Preset, canonical Super Booster Package, PNG, Package writer path,
  DesktopIdleRacing file, staged file, or commit changed. Report the test-only
  writer result separately from canonical Package output.

## Plan self-review

- Coverage: Task 1 owns strict Schema/validator/configuration checks; Task 2 owns only allowed static inspector authoring; Task 3 proves generic numeric evaluation and straight Preview fallback; Task 4 owns v2 selection/projection/writer portability and static v1 protection; Task 5 documents and verifies every explicit guard.
- Scope: no task changes Preview rendering, ordering, Runtime version/package format, production Presets/packages, assets, or game code.
- Type consistency: all tasks use the exact authored names `visual_bend`, `VISUAL_BEND_OFFSET_X`, `LOCAL_Y_POSITIVE`, `QUADRATIC`, and existing `modulation_clamps`.
- Placeholder scan: every task names files, interfaces, assertions, expected RED reason, and concrete command.
