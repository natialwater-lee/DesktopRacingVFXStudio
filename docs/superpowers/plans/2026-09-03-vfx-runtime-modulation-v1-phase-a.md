# Runtime Modulation v1 Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a generic, deterministic Studio-only Runtime Modulation capability that previews validated Layer modulation without changing production Presets or exporting a modulated package.

**Architecture:** Phase A keeps the approved Layer Stack architecture: a Preset-level ordered source table compiles with Layer-local bindings and target-level clamps into an immutable program, then LOD/enabled and successful-renderer reachability produce the active evaluator program. A single per-VFX evaluator produces preallocated effective Layer state, consumed only by `TEXTURED_SPRITE`; its final alpha seam alone clamps alpha. Existing renderer packets consume that state; no Preset-specific controller or renderer branch is introduced. Static or unreachable programs with zero bindings bypass evaluator work completely, while the Export compiler fail-closes any modulation-bearing Preset until Phase C supplies Runtime Definition v2.

**Tech Stack:** Godot 4.7.1 stable, GDScript, project-owned JSON Schema subset validator, focused headless GDScript suites; no external dependency.

**Spec:** [Runtime Modulation v1 Design](../specs/2026-09-03-vfx-runtime-modulation-v1-design.md)

## Global Constraints

- Work only in `C:\GodotProjects\DesktopRacingVFXStudio`; never read, write, or assume code in `DesktopIdleRacing`.
- Use `C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe`; do not install another Godot version or run Windows Export.
- Preserve the user-owned dirty worktree. Never run reset, revert, checkout, clean, `git add`, or `git commit`; every review checkpoint confirms staged files remain `0`.
- `.vfx.json` stays authoring source of truth. Phase A changes no production Preset, including `presets/examples/driving.headlights.vfx.json`.
- Schema v1 additions are optional and defaulted. A source Preset that omits all modulation data must normalize and render identically to its current static behavior.
- Phase A supports every Runtime Modulation target only for `TEXTURED_SPRITE`. `PARTICLE`, `TRAIL`, `RING`, `GLOW`, and `SHIELD` bindings fail authoring validation; their renderer files remain unchanged.
- No graph, timeline, expression/eval, arbitrary JSON path, random modulation source, dynamic LOD, Runtime Definition v2 writer, package re-export, or game integration.
- Runtime input UI is session-only: no Preset dirty state, Undo/Redo entry, Save output, or Export data.
- LOD filtering removes omitted and disabled Layer bindings before runtime activation; a second activation-time renderer-backed filter removes missing-asset, unsupported, and failed-renderer bindings before evaluator construction.
- All modulation code must avoid JSON traversal, string comparison, Dictionary/Array allocation, asset loading, Node/Tween/Timer creation, and per-binding object creation during steady-state ticks.
- Current `draw_packets()` defensive copies remain an existing rendering baseline. The Phase A allocation contract covers evaluator state and renderer-owned persistent packet state only.

## File and interface map

| Path | Phase A responsibility |
| --- | --- |
| `schemas/vfx_schema_v1.json` | Optional Schema fields, `longitudinal_load`, strict modulation `$defs`, and Schema-owned `RUNTIME_MODULATION_CONFIGURATION` metadata. |
| `src/model/vfx_rule_catalog.gd` | Accept and structurally validate the new rule's exact configuration keys. |
| `src/model/vfx_schema_registry.gd` | Validate rule coverage against Schema fields and expose a validated `runtime_modulation_contract()` copy. |
| `src/model/vfx_contract_validator.gd` | Apply the one explicit modulation semantic rule; report `PRESET_VALIDATION` pointers. |
| `src/preview/runtime_modulation/vfx_runtime_modulation_source_spec.gd` | Immutable oscillator source spec. |
| `src/preview/runtime_modulation/vfx_runtime_modulation_binding_spec.gd` | Immutable numeric source-slot, mapping, operation, and target binding spec; it owns no clamp bounds. |
| `src/preview/runtime_modulation/vfx_runtime_modulation_clamp_spec.gd` | Immutable Layer-target clamp contract applied once after all contributions for that target compose. |
| `src/preview/runtime_modulation/vfx_runtime_modulation_program.gd` | Immutable source/input/binding/clamp program with filtered copies and zero-binding query. |
| `src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd` | Session-only numeric input slots; named access only at UI/rebuild time. |
| `src/preview/runtime_modulation/vfx_preview_effective_layer_state.gd` | Preallocated per-renderer base/effective transform and visual-opacity state. |
| `src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd` | Per-VFX fixed-tick oscillator sampling, ordered composition, clamp, and state mutation. |
| `src/preview/rendering/vfx_preview_render_plan_builder.gd` | Compile normalized modulation JSON once into a base immutable program. |
| `src/preview/rendering/vfx_preview_render_plan.gd` | Own the base `VfxRuntimeModulationProgram`. |
| `src/preview/rendering/vfx_preview_layer_spec.gd` | Hold typed authored offset/scale/rotation and `modulation_pivot_local` without tick-time Dictionary copies. |
| `src/performance/vfx_preview_lod_filter.gd` | Filter Layer specs first, then derive a reachable-source/binding program. |
| `src/preview/rendering/vfx_preview_coordinate_resolver.gd` | Single attachment-preserving effective-origin helper. |
| `src/preview/rendering/vfx_preview_render_runtime.gd` | Own optional evaluator and per-renderer effective state; route fixed-tick and immediate input refresh. |
| `src/preview/rendering/vfx_preview_layer_renderer.gd` | Consume optional effective state in shared packet metadata and alpha multiplier. |
| `src/preview/rendering/vfx_textured_sprite_layer_renderer.gd` | Applies the effective transform and final-alpha multiplier in place; it is the only Phase A Renderer modulation consumer. |
| `src/preview/vfx_vehicle_preview.gd`, `src/preview/vfx_vehicle_preview.tscn` | Session-only speed/load sliders; synchronize state to the one canonical render runtime. |
| `src/export/vfx_export_compiler.gd` | Fail before v1 plan/manifest/runtime generation when modulation data is non-empty. |
| `tests/fixtures/presets/utility.runtime_modulation_fixture.vfx.json` | Dedicated non-production fixture with exactly three `TEXTURED_SPRITE` Layers: two CORE parity Layers sharing an oscillator and one EXTRA LOD Layer. |
| `tests/fixtures/export/talent.zero_zone_runtime_definition_v1.golden.json` | Pre-Phase-A static Runtime Definition v1 byte-for-byte golden used to prove compiler projection preserves existing static output. |
| `tests/unit/test_runtime_modulation_contract.gd` | Schema defaults, semantic rule, invalid cases, and Schema-config failure tests. |
| `tests/preview/test_runtime_modulation_program.gd` | Program compilation, slots, mappings, oscillator, composition, pivot, packet identity, parity, and static bypass tests. |
| `tests/editor/test_runtime_modulation_preview_controls.gd` | Preview UI visibility and session-only slider behavior. |
| `tests/performance/test_runtime_modulation_structure.gd` | Structural evaluator/source-sampling/count/capacity assertions; not an FPS benchmark. |
| `tests/export/test_runtime_modulation_export_guard.gd` | Static v1 preservation and explicit pre-v2 export rejection. |
| `tests/run_contract_tests.gd`, `tests/run_preview_tests.gd`, `tests/run_editor_tests.gd`, `tests/run_performance_tests.gd`, `tests/run_export_contract_tests.gd` | Register the focused suite modules. |
| `docs/VFX_SCHEMA_V1.md`, `docs/VFX_STUDIO_ARCHITECTURE.md`, `docs/VFX_EXPORT_PACKAGE_V1.md` | Document the implemented Schema semantics, fast path, and Phase A Export block without claiming v2 support. |

## Exact Phase A contracts

### Schema-owned rule metadata

Add one `x_vfx_rules` entry named `RUNTIME_MODULATION_CONFIGURATION`. Its configuration is the sole declaration of the authored enum compatibility and includes these string fields:

```json
{
  "name": "RUNTIME_MODULATION_CONFIGURATION",
  "phases_path": "/phases",
  "runtime_inputs_path": "/runtime_inputs",
  "runtime_input_contract_path": "/x_vfx_runtime_inputs",
  "sources_field": "runtime_modulation_sources",
  "layers_field": "layers",
  "bindings_field": "modulations",
  "clamps_field": "modulation_clamps",
  "transform_field": "transform",
  "pivot_field": "modulation_pivot_local",
  "source_id_field": "id",
  "binding_id_field": "id",
  "target_field": "target",
  "operation_field": "operation",
  "source_field": "source",
  "mapping_field": "mapping",
  "source_types": { "OSCILLATOR": { "waves": ["SINE"], "output_min": -1.0, "output_max": 1.0 } },
  "binding_source_types": ["RUNTIME_INPUT", "PRESET_SOURCE"],
  "mapping_types": ["LINEAR_RANGE"],
  "target_contracts": {
    "TRANSFORM_OFFSET_X": { "operation": "ADD", "compatible_layer_types": ["TEXTURED_SPRITE"] },
    "TRANSFORM_OFFSET_Y": { "operation": "ADD", "compatible_layer_types": ["TEXTURED_SPRITE"] },
    "TRANSFORM_ROTATION_DEGREES": { "operation": "ADD", "compatible_layer_types": ["TEXTURED_SPRITE"] },
    "TRANSFORM_SCALE_X": { "operation": "MULTIPLY", "minimum_effective": 0.001, "compatible_layer_types": ["TEXTURED_SPRITE"] },
    "TRANSFORM_SCALE_Y": { "operation": "MULTIPLY", "minimum_effective": 0.001, "compatible_layer_types": ["TEXTURED_SPRITE"] },
    "VISUAL_OPACITY_MULTIPLIER": { "operation": "MULTIPLY", "minimum_effective": 0.0, "compatible_layer_types": ["TEXTURED_SPRITE"] }
  },
  "pivot_compatible_layer_types": ["TEXTURED_SPRITE"]
}
```

The literal enum strings appear in Schema JSON only. GDScript consumes the loaded rule configuration and compiles implementation-private numeric slots; it does not duplicate authored enum lists as constants.

### Normalized data and semantic rules

The root adds optional `runtime_modulation_sources` with default `[]`. Every Layer adds optional `modulations` and `modulation_clamps`, both defaulting to `[]`. `transform` adds optional `modulation_pivot_local`, default `[0.0, 0.0]`. `x_vfx_runtime_inputs` adds numeric `longitudinal_load`, minimum `-1`, maximum `1`, default `0`.

`RUNTIME_INPUT` is v1 scalar-only: its named contract must have Schema `type: number`, and the Preset must declare that name in `runtime_inputs`. `vehicle_velocity` and `surface_type` remain legal Runtime Input declarations but are rejected as scalar modulation sources. This is required by the scalar `LINEAR_RANGE` contract and does not remove their existing non-modulation meanings.

`VISUAL_OPACITY_MULTIPLIER` is non-negative and intentionally has no authored upper bound: an output such as `1.05` is legal for a small visibility lift. Negative or non-finite mapped multiplier output is a `PRESET_VALIDATION` error. The evaluator preserves every legal multiplier above `1.0`; only a renderer's final authored-or-animated alpha application clamps: `final_visual_alpha = clamp(existing_authored_or_animated_alpha * multiplier, 0.0, 1.0)`.

`modulation_clamps` are Layer target-level contracts, not Binding fields. For one active Layer target, the evaluator starts from the authored base, composes all applicable binding contributions in authored binding order, then applies that target's one declared clamp exactly once. The Schema rule permits at most one clamp per `(layer_id, target)` pair and validates `minimum <= maximum` when both bounds are present.

Every target contract declares `compatible_layer_types` in the Schema-owned `RUNTIME_MODULATION_CONFIGURATION`. In Phase A every list is exactly `["TEXTURED_SPRITE"]`; the validator reads that metadata and rejects a binding on `PARTICLE`, `TRAIL`, `RING`, `GLOW`, or `SHIELD` with `PRESET_VALIDATION/runtime_modulation_target_layer_type_incompatible`. Unsupported authoring never reaches the Preview Runtime.

### Runtime interfaces

```gdscript
class_name VfxRuntimeModulationProgram
func binding_count() -> int
func runtime_input_count() -> int
func runtime_input_slot(input_name: String) -> int # rebuild/UI only; -1 if unused
func runtime_input_name(slot: int) -> String
func runtime_input_default(slot: int) -> float
func bindings_for_layer(layer_id: String) -> Array[VfxRuntimeModulationBindingSpec]
func clamps_for_layer(layer_id: String) -> Array[VfxRuntimeModulationClampSpec]
func filtered_to_reachable_layer_ids(layer_ids: Dictionary) -> VfxRuntimeModulationProgram

class_name VfxRuntimeModulationClampSpec
func layer_id() -> String
func target_slot() -> int
func has_minimum() -> bool
func minimum_effective() -> float
func has_maximum() -> bool
func maximum_effective() -> float

class_name VfxPreviewRuntimeInputState
func set_slot(slot: int, value: float) -> void
func value_at(slot: int) -> float
func set_named_value(program: VfxRuntimeModulationProgram, input_name: String, value: float) -> bool # UI/rebuild only

class_name VfxPreviewEffectiveLayerState
func reset_from(layer_spec: VfxPreviewLayerSpec) -> void
func apply_composed_values(offset_delta: Vector2, rotation_delta: float, scale_multiplier: Vector2, opacity_multiplier: float) -> void
func effective_offset() -> Vector2
func effective_scale() -> Vector2
func effective_rotation_degrees() -> float
func visual_opacity_multiplier() -> float

class_name VfxPreviewRuntimeModulationEvaluator
func _init(program: VfxRuntimeModulationProgram, input_state: VfxPreviewRuntimeInputState) -> void
func create_effective_state(layer_spec: VfxPreviewLayerSpec) -> VfxPreviewEffectiveLayerState
func advance(instance_elapsed_seconds: float, active_states: Array[VfxPreviewEffectiveLayerState]) -> void
func refresh(instance_elapsed_seconds: float, active_states: Array[VfxPreviewEffectiveLayerState]) -> void
func sampled_source_count_last_tick() -> int
```

`advance()` and `refresh()` use compiled integer input/source/target slots only. `refresh()` resamples deterministic values at the current playback time after a UI slider change; it does not advance time. A zero-binding program never constructs this evaluator or any effective state.

### Effective transform rule

For an authored source-local origin `O_base`, pivot `p`, base scale/rotation matrix `M_base`, effective matrix `M_effective`, and intentional dynamic offset `D`, the coordinate resolver mutates the state to:

```text
attachment_root = O_base + M_base * p
O_effective = attachment_root + D - M_effective * p
```

The existing order remains component-wise scale then rotation. With `[0, 0]` pivot and zero modulation, the result is exactly the old origin. For Core Headlight `p = [-0.5, 89]`, Soft Headlight `p = [-0.5, 49]`; the Phase A fixture tests this generic math but does not edit the production Headlight Preset.

---

### Task 1: Add the additive Schema contract and semantic validation

**Files:**
- Modify: `schemas/vfx_schema_v1.json`
- Modify: `src/model/vfx_rule_catalog.gd`
- Modify: `src/model/vfx_schema_registry.gd`
- Modify: `src/model/vfx_contract_validator.gd`
- Modify: `tests/unit/test_schema_artifact.gd`
- Modify: `tests/unit/test_schema_registry.gd`
- Create: `tests/unit/test_runtime_modulation_contract.gd`
- Create: `tests/fixtures/export/talent.zero_zone_runtime_definition_v1.golden.json`
- Modify: `tests/run_contract_tests.gd`

**Interfaces:**
- Produces `VfxSchemaRegistry.runtime_modulation_contract() -> VfxResult`, returning a deep copy of the validated `RUNTIME_MODULATION_CONFIGURATION` rule or `SCHEMA_CONFIGURATION/runtime_modulation_contract_unavailable`.
- Produces the optional normalized fields described above and rule handler `_validate_runtime_modulation_configuration(preset, rule, issues)`.
- Consumes existing `VfxPresetNormalizer`, `VfxSchemaSubsetValidator`, `VfxRuleCatalog`, and `VfxContractValidator` behavior.

- [ ] **Step 1: Capture the static v1 golden and write focused failing contract/Schema-configuration tests**

Before changing the Schema, compile the existing static `talent.zero_zone` document in memory (never run the package writer) and save its exact existing Runtime Definition text as `tests/fixtures/export/talent.zero_zone_runtime_definition_v1.golden.json`. This fixture is the pre-Phase-A byte baseline consumed by Task 9; it must contain no Runtime Modulation fields.

Create `tests/unit/test_runtime_modulation_contract.gd` with a direct valid one-shot `TEXTURED_SPRITE` fixture dictionary and assertions for all of the following:

```gdscript
tests.expect_true(validated.success, "runtime modulation fixture validates")
tests.expect_true(normalized["runtime_modulation_sources"] == [], "source table defaults empty")
tests.expect_true(layer["modulations"] == [] and layer["modulation_clamps"] == [], "Layer modulation arrays default empty")
tests.expect_true(layer["transform"]["modulation_pivot_local"] == [0.0, 0.0], "pivot defaults to center")
tests.expect_true(registry.runtime_modulation_contract().success, "registry exposes the Schema-owned modulation contract")
```

Clone the valid fixture and assert exact `PRESET_VALIDATION` codes for duplicate source ID, duplicate binding ID in one Layer, duplicate target clamp in one Layer, undeclared input, non-number input source, missing preset source, unknown target, wrong operation, reversed mapping range, non-SINE oscillator, negative frequency, invalid clamp order, `runtime_modulation_opacity_multiplier_negative`, `runtime_modulation_opacity_multiplier_nonfinite`, non-finite pivot, non-zero pivot on `GLOW`, and `runtime_modulation_target_layer_type_incompatible`. For the incompatibility assertion, replace the otherwise valid modulated `TEXTURED_SPRITE` fixture Layer type independently with `PARTICLE`, `TRAIL`, `RING`, `GLOW`, and `SHIELD`; every variant must fail before Preview construction. Confirm a multiplier mapping output above `1.0` validates. Clone Schema data and assert `SCHEMA_CONFIGURATION` for a target contract with an operation not declared by the binding enum, a missing `compatible_layer_types` key, an unknown compatible Layer Type, and a missing pivot-compatible Layer Type.

- [ ] **Step 2: Run the new contract module and confirm RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_contract_tests.gd'
```

Expected: the new preload or `runtime_modulation_contract()` is missing, or the new fixture fails structural validation because the Schema has not declared the fields/rule.

- [ ] **Step 3: Add strict Schema definitions and defaults**

Add `$defs` for `runtime_modulation_source`, `runtime_modulation_binding`, `runtime_modulation_source_ref`, `runtime_modulation_mapping`, and `runtime_modulation_clamp`. Each object uses `additionalProperties: false`; fixed arrays use `minItems: 2` and `maxItems: 2`; numeric fields are number typed. Keep clamps as `{target, minimum?, maximum?}` at Layer scope; do not put optional clamp bounds in a binding. Add root/Layer/transform properties and defaults exactly as declared in the contract section. Add numeric `longitudinal_load` to `x_vfx_runtime_inputs`.

Add the one Schema rule metadata object. Extend `VfxRuleCatalog` with its exact required string/complex keys, and extend `VfxSchemaRegistry` coverage validation so all configured paths resolve, every target key is a declared target enum, every configured operation is a declared operation enum, every target `compatible_layer_types` entry exists in `x_vfx_layer_types`, and the configured pivot Layer Types exist in `x_vfx_layer_types`.

- [ ] **Step 4: Implement semantic validation and Registry access**

Implement `runtime_modulation_contract()` and `_validate_runtime_modulation_configuration()`. Iterate phases/layers using the rule paths, never fixed JSON paths. Verify every cross-field condition from Step 1, return individual `VfxIssue.new("PRESET_VALIDATION", code, message, pointer)`, and use `SCHEMA_CONFIGURATION` only for malformed Schema metadata. Before compiling a binding, resolve its target's `compatible_layer_types` from the Registry-owned contract and reject the enclosing Layer type when absent. Verify scalar input source types by resolving the named entry from `x_vfx_runtime_inputs` and requiring its resolved Schema `type` to be `number`. For `VISUAL_OPACITY_MULTIPLIER`, require finite mapped outputs with lower bound `0.0` and deliberately do not impose an upper bound.

- [ ] **Step 5: Run focused GREEN and Contract regression**

Run the Contract suite command from Step 2. Expected: exit `0`, existing contract tests unchanged, and all new valid/default/error assertions pass.

- [ ] **Step 6: Review checkpoint**

Run `git diff --check` and `git diff --cached --name-only`. Expected: no whitespace error and no staged files. Do not stage or commit.

### Task 2: Compile immutable modulation specs with stable numeric slots

**Files:**
- Create: `src/preview/runtime_modulation/vfx_runtime_modulation_source_spec.gd`
- Create: `src/preview/runtime_modulation/vfx_runtime_modulation_binding_spec.gd`
- Create: `src/preview/runtime_modulation/vfx_runtime_modulation_clamp_spec.gd`
- Create: `src/preview/runtime_modulation/vfx_runtime_modulation_program.gd`
- Create: `src/preview/runtime_modulation/vfx_runtime_modulation_program_builder.gd`
- Create: `tests/fixtures/presets/utility.runtime_modulation_fixture.vfx.json`
- Create: `tests/preview/test_runtime_modulation_program.gd`
- Modify: `src/preview/rendering/vfx_preview_render_plan_builder.gd`
- Modify: `src/preview/rendering/vfx_preview_render_plan.gd`
- Modify: `tests/run_preview_tests.gd`

**Interfaces:**
- Consumes `registry.runtime_modulation_contract()` and normalized Preset data from Task 1.
- Produces `VfxRuntimeModulationProgramBuilder.build(normalized_data: Dictionary, layer_ids_by_phase: Dictionary) -> VfxResult`.
- Produces an immutable `VfxRuntimeModulationProgram`; stored binding and target-clamp references contain numeric runtime-input/source/target slots and no JSON paths.

- [ ] **Step 1: Write RED program compilation tests**

Create the dedicated fixture with `preset_id: "utility.runtime_modulation_fixture"`, `ONE_SHOT`, and exactly three `TEXTURED_SPRITE` Layers: `one_shot.left_core` (CORE), `one_shot.right_core` (CORE), and `one_shot.lod_extra` (EXTRA). Declare `speed_normalized` and `longitudinal_load`, and one shared `road_motion` SINE source. The two CORE Layers use matching pivots and matching bindings for scale-Y multiplication by speed, load, and the shared oscillator; rotation ADD by the shared oscillator; offset-X ADD by the shared oscillator; and `VISUAL_OPACITY_MULTIPLIER` by speed. This gives left/right parity over scale, rotation, offset, opacity, pivot, and the same sampled oscillator. `lod_extra` contains one minimal opacity-by-speed binding. Declare one target-level scale-Y clamp on each CORE Layer so the evaluator test can prove final clamping; no binding embeds clamp bounds.

In `test_runtime_modulation_program.gd`, assert:

```gdscript
tests.expect_true(program.binding_count() == 13, "twelve CORE parity bindings plus one EXTRA binding compile once")
tests.expect_true(program.runtime_input_slot("speed_normalized") >= 0, "used input has a stable slot")
tests.expect_true(program.runtime_input_slot("longitudinal_load") >= 0, "signed load has a stable slot")
tests.expect_true(program.runtime_input_slot("surface_type") == -1, "unused nonnumeric input has no slot")
tests.expect_true(program.bindings_for_layer("one_shot.left_core").size() == 6, "left CORE bindings remain Layer-local")
tests.expect_true(program.bindings_for_layer("one_shot.right_core").size() == 6, "right CORE parity bindings remain Layer-local")
tests.expect_true(program.bindings_for_layer("one_shot.lod_extra").size() == 1, "EXTRA binding remains Layer-local")
tests.expect_true(program.clamps_for_layer("one_shot.left_core").size() == 1, "clamp belongs to the Layer target, not a binding")
```

Also assert the static Zero Zone plan has a non-null program with `binding_count() == 0`.

- [ ] **Step 2: Run Preview suite and confirm RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_preview_tests.gd'
```

Expected: missing modulation program classes/methods or the render plan has no program accessor.

- [ ] **Step 3: Implement immutable Specs and builder**

Implement `VfxRuntimeModulationSourceSpec` with `source_id()`, `frequency_hz()`, and `phase_radians()`. Implement `VfxRuntimeModulationBindingSpec` with numeric source kind/slot, numeric target slot, operation slot, mapping bounds, and `layer_id()` only. Implement `VfxRuntimeModulationClampSpec` with numeric target slot plus independently optional minimum/maximum values. These integers are compiled implementation tags, not duplicate authored enum declarations.

Implement `VfxRuntimeModulationProgram` with immutable arrays/maps constructed once; `runtime_input_slot()` is called only during build/UI setup. `filtered_to_reachable_layer_ids()` returns a new immutable program containing only retained Layer bindings and target clamps, and only sources referenced by retained bindings. It exposes `bindings_for_layer()` and `clamps_for_layer()` without allocating during ticks.

Implement the builder by reading field names and contracts from `runtime_modulation_contract()`, assigning stable runtime input slots in declared Preset `runtime_inputs` order, source slots in source-table order, and binding slots in authored Layer-array order.

- [ ] **Step 4: Attach the base program to the Preview Render Plan**

Extend `VfxPreviewRenderPlan` with an optional `runtime_modulation_program()` accessor. `VfxPreviewRenderPlanBuilder.build()` invokes the program builder after ordinary phase/layer construction, fails with `PREVIEW_CONFIGURATION` if compilation cannot proceed, and creates an empty immutable program for static Presets.

- [ ] **Step 5: Run GREEN and regression**

Run the Preview suite command from Step 2. Expected: fixture compiles, static plans expose zero bindings, and all existing Preview tests still pass.

- [ ] **Step 6: Review checkpoint**

Run `git diff --check` and confirm staged file count is `0`.

### Task 3: Add evaluator, numeric input state, deterministic composition, and static bypass

**Files:**
- Create: `src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd`
- Create: `src/preview/runtime_modulation/vfx_preview_effective_layer_state.gd`
- Create: `src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd`
- Modify: `tests/preview/test_runtime_modulation_program.gd`
- Create: `tests/performance/test_runtime_modulation_structure.gd`
- Modify: `tests/run_performance_tests.gd`

**Interfaces:**
- Consumes Task 2 immutable program and `VfxPreviewLayerSpec` authored values.
- Produces evaluator methods in the global interface map and mutable `VfxPreviewEffectiveLayerState` instances created only during runtime activation/rebuild.
- Does not yet alter renderer packet output; Task 5 consumes the computed state.

- [ ] **Step 1: Write RED evaluator and structure tests**

Add assertions for the exact mapping/composition-and-target-clamp contract:

```gdscript
# LINEAR_RANGE [-1, 1] -> [0.90, 1.10]
tests.expect_true(is_equal_approx(load_factor(-1.0), 0.90), "braking endpoint maps exactly")
tests.expect_true(is_equal_approx(load_factor(0.0), 1.00), "neutral load maps exactly")
tests.expect_true(is_equal_approx(load_factor(1.0), 1.10), "acceleration endpoint maps exactly")
var unclamped_scale := base_scale * speed_factor * load_factor * oscillator_factor
tests.expect_true(is_equal_approx(unclamped_scale, base_scale * speed_factor * load_factor * oscillator_factor), "multiply bindings compose in authored order")
tests.expect_true(is_equal_approx(composed_scale, clampf(unclamped_scale, 1.40, 1.70)), "one target clamp is applied once after speed, load, and oscillator compose")
tests.expect_true(is_equal_approx(composed_offset_x, base_offset_x + offset_contribution), "offset bindings add to authored base")
```

Use a fixed `instance_elapsed_seconds` value to assert `sin(TAU * frequency_hz * time + phase_radians)`. Assert pause-equivalent repeated `refresh()` at the same time returns the same scalar, restart time `0` returns the same initial scalar, and two consumers of `road_motion` observe one source sample. In the performance module assert a zero-binding static program creates no evaluator, samples zero sources, and creates zero effective states.

- [ ] **Step 2: Run Preview and Performance suites and confirm RED**

Run the Preview command from Task 2 and:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_performance_tests.gd'
```

Expected: evaluator/input-state classes and the requested sample-count/static-bypass APIs are absent.

- [ ] **Step 3: Implement numeric input state and effective Layer state**

Use `PackedFloat64Array` (or fixed numeric arrays if Godot typing requires it) in `VfxPreviewRuntimeInputState`; initialize slots from `VfxRuntimeModulationProgram.runtime_input_default(slot)`. The tick API reads only `value_at(slot)`. `set_named_value()` resolves a name outside the tick path and clamps to the declared numeric input range during UI use.

`VfxPreviewEffectiveLayerState.reset_from(layer_spec)` copies base numeric transform values once. It stores base/effective offset, scale, rotation, opacity multiplier, and pivot as `Vector2`/`float`, never as transform Dictionaries.

- [ ] **Step 4: Implement evaluator composition**

At `advance()`/`refresh()`, reset each active state to its base values, sample each reachable `VfxRuntimeModulationSourceSpec` once into a preallocated numeric source-values array, then compose its Layer bindings in authored order by target. Apply `ADD` as base plus contribution and `MULTIPLY` as base times contribution. After every contribution for one Layer target has composed, apply that target's single `VfxRuntimeModulationClampSpec` exactly once, then apply the Schema safety domain. Preserve a legal visual-opacity multiplier above `1.0`; never clamp that multiplier in the evaluator. Reject invalid negative/non-finite multiplier mapping output in validation, and continue to reject/avoid non-positive effective scale through the validated target floor. Store a numeric `sampled_source_count_last_tick` for structural tests only.

- [ ] **Step 5: Run GREEN and regression**

Run the Preview and Performance commands from Step 2. Expected: deterministic mapping, one-sample shared oscillator reuse, no-evaluator static fast path, and all existing suite assertions pass.

- [ ] **Step 6: Review checkpoint**

Run `git diff --check` and confirm staged file count is `0`.

### Task 4: Compile typed Layer transforms and preserve an attachment point

**Files:**
- Modify: `src/preview/rendering/vfx_preview_layer_spec.gd`
- Modify: `src/preview/rendering/vfx_preview_coordinate_resolver.gd`
- Modify: `src/preview/runtime_modulation/vfx_preview_effective_layer_state.gd`
- Modify: `tests/preview/test_runtime_modulation_program.gd`
- Modify: `tests/preview/test_textured_sprite_layer_renderer.gd`

**Interfaces:**
- Produces `VfxPreviewLayerSpec.authored_offset() -> Vector2`, `authored_scale() -> Vector2`, `authored_rotation_degrees() -> float`, and `modulation_pivot_local() -> Vector2`.
- Produces `VfxPreviewCoordinateResolver.apply_effective_transform(instance, effective_state, frame_context) -> void`, which writes effective source-local/canonical packet geometry values into the existing state.
- Consumes Task 3 effective values and no renderer-specific identity.

- [ ] **Step 1: Write RED root-preservation tests**

Add a generic texture fixture representing the Core dimensions and pivot `[-0.5, 89]`. Use base origin `[-55.638927, -317.925671]`, scale `[1.55, 1.60]`, rotation `355`, and expected root `[-44, -176]`. For scale multipliers `.90`, `1.00`, `1.10` and rotation deltas `-.4`, `0`, `.4`, assert:

```gdscript
tests.expect_true(
    root.distance_to(Vector2(-44.0, -176.0)) <= 0.001,
    "generic pivot compensation preserves the attached local point"
)
```

Add the equivalent Soft pivot `[-0.5, 49]`, both left/right rotation signs, default pivot `[0, 0]`, and an offset binding check proving the root moves exactly by the intended dynamic offset.

- [ ] **Step 2: Run Preview suite and confirm RED**

Run the Preview suite command. Expected: typed transform/pivot accessors or effective-transform helper do not exist and root-preservation assertions fail.

- [ ] **Step 3: Implement the canonical helper once**

Store authored transform values typed in `VfxPreviewLayerSpec`; retain `transform()` for current callers as an immutable diagnostic copy. In the coordinate resolver, build base/effective local vectors as component-wise scale followed by rotation. Compute:

```gdscript
var attachment_root := base_origin + _rotate(base_pivot * base_scale, base_rotation)
var effective_origin := attachment_root + dynamic_offset - _rotate(pivot * effective_scale, effective_rotation)
```

Then apply existing vehicle-follow world scale/rotation projection exactly once. No renderer recalculates this math and no Headlight/Preset-ID conditional is allowed.

- [ ] **Step 4: Run GREEN and static transform regression**

Run the Preview suite. Expected: all pivot combinations preserve their root within epsilon; zero pivot and no modulation reproduce the prior static position/scale/rotation test expectations.

- [ ] **Step 5: Review checkpoint**

Run `git diff --check` and confirm staged file count is `0`.

### Task 5: Integrate runtime evaluator into the Render Runtime and TEXTURED_SPRITE persistent packet

**Files:**
- Modify: `src/preview/rendering/vfx_preview_render_runtime.gd`
- Modify: `src/preview/rendering/vfx_preview_layer_renderer.gd`
- Modify: `src/preview/rendering/vfx_textured_sprite_layer_renderer.gd`
- Modify: `tests/preview/test_runtime_modulation_program.gd`
- Modify: `tests/preview/test_textured_sprite_layer_renderer.gd`

**Interfaces:**
- `VfxPreviewRenderRuntime` gains `set_runtime_input_state(state: VfxPreviewRuntimeInputState) -> void`, `refresh_modulation(frame_context: Dictionary) -> void`, `has_modulation_evaluator() -> bool`, `active_runtime_modulation_binding_count() -> int`, and `modulation_sample_count_last_tick() -> int`. Its private `_rebuild_runtime_modulation_for_renderer_entries()` derives the active program only from successfully constructed renderer entries.
- Renderer constructors remain source-compatible: `renderer_script.new(instance, asset, effective_state = null)`.
- `VfxPreviewLayerRenderer` exposes protected typed helpers for effective packet origin/scale/rotation/final alpha; null state keeps the current static values.

- [ ] **Step 1: Write RED runtime/packet identity tests**

Create a runtime from the dedicated fixture, activate its phase, advance two fixed ticks, and assert `active_runtime_modulation_binding_count() == 13`, a non-null evaluator, one sampled shared source, unchanged active renderer count, and no particle capacity change. Add a `TEXTURED_SPRITE` test hook that returns its renderer-owned packet/state identity without calling public `draw_packets()`; assert the identity remains the same across input changes/ticks while position, geometry scale, geometry rotation, and alpha values change.

Also assert a static Zero Zone runtime has `has_modulation_evaluator() == false`, reports sample count `0`, and preserves current static packet values.

- [ ] **Step 2: Run Preview suite and confirm RED**

Run the Preview suite command. Expected: runtime evaluator attachment, refresh API, or renderer-owned identity test hook is missing.

- [ ] **Step 3: Construct evaluator only for renderer-backed non-zero binding count**

At runtime construction, retain the plan's LOD-filtered base program but do not create evaluator/state fields. In `activate_phase()`, append an entry only after it is enabled, its asset resolves, and `renderer_script.new()` succeeds; then `_rebuild_runtime_modulation_for_renderer_entries()` gathers those successful entry `layer_id` values and calls `filtered_to_reachable_layer_ids()`. If that active program has binding count `0`, retain no evaluator/state fields. Otherwise allocate exactly one evaluator and one effective state per active renderer entry. `advance()` updates evaluator state before renderer `advance()`; `refresh_modulation()` recomputes at the current `preview_time` without advancing playback time. Task 8 extends the same rebuild seam to every entry-removal transition; no evaluator is ever created from a merely authored Layer.

- [ ] **Step 4: Update TEXTURED_SPRITE in place**

Keep its activation-time `_packets` array and stored packet dictionary. On a modulated advance/refresh, mutate only stored numeric packet fields: `position`, `geometry_scale`, `geometry_rotation_degrees`, and `alpha`. Keep authored `transform` diagnostic data unchanged. Do not call `_packets.clear()`, append a replacement packet, duplicate a transform Dictionary, or allocate a Node during tick refresh. Keep the current public `draw_packets()` defensive-copy behavior unchanged.

- [ ] **Step 5: Run GREEN and regression**

Run the Preview suite. Expected: packet/state identity is stable internally, static Presets use no evaluator, fixture packets update at fixed ticks and immediate UI refresh, and current TEXTURED_SPRITE tests still pass.

- [ ] **Step 6: Review checkpoint**

Run `git diff --check` and confirm staged file count is `0`.

### Task 6: Enforce TEXTURED_SPRITE-only modulation capability

**Files:**
- Modify: `src/preview/rendering/vfx_textured_sprite_layer_renderer.gd`
- Modify: `tests/preview/test_runtime_modulation_program.gd`
- Modify: `tests/unit/test_runtime_modulation_contract.gd`

**Interfaces:**
- Consumes `VfxPreviewLayerRenderer.final_visual_alpha(authored_alpha: float) -> float` from Task 5.
- Produces no new Layer Type parameters, no renderer registration, and no type/Preset-specific branch. `TEXTURED_SPRITE` is the sole caller in Phase A; all other Layer Types are rejected by the Task 1 Schema-owned compatibility validation before Preview Runtime construction.

- [ ] **Step 1: Write RED TEXTURED_SPRITE-only capability tests**

For a shared effective state with multiplier `.5`, assert a `TEXTURED_SPRITE` packet alpha is halved exactly. Assert multiplier `1.0` produces its existing static packet alpha and multiplier `0.0` produces a transparent packet without removing its renderer. Add a legal `1.05` case proving an authored alpha `.80` becomes `.84`, and an above-one saturation case proving authored alpha `.75` with multiplier `2.0` becomes `1.0` only at the final visual-alpha seam. Keep the five explicit incompatible-Layer validation variants from Task 1 as this Task's regression boundary.

- [ ] **Step 2: Run Preview suite and confirm RED**

Run the Preview and Contract suite commands. Expected: `TEXTURED_SPRITE` has no final-alpha consumer yet, while incompatible Layer variants are rejected before any runtime/evaluator construction.

- [ ] **Step 3: Apply the helper at final alpha seams**

Implement `final_visual_alpha(authored_or_animated_alpha: float) -> float` as exactly `clampf(authored_or_animated_alpha * effective_state.visual_opacity_multiplier(), 0.0, 1.0)` and call it only from `vfx_textured_sprite_layer_renderer.gd` after its current static alpha calculation. Do not modify `vfx_particle_layer_renderer.gd`, `vfx_glow_layer_renderer.gd`, `vfx_ring_layer_renderer.gd`, `vfx_trail_layer_renderer.gd`, or `vfx_shield_layer_renderer.gd`; no phase-specific Layer Type branch, particle emission, lifetime, cap, motion, Trail sample, Ring repeat, Shield geometry, asset loading, or Canvas blend behavior changes are permitted.

- [ ] **Step 4: Run GREEN and visual regression**

Run the Preview and Contract suites. Expected: `TEXTURED_SPRITE` respects the multiplier, all old `1.0` static packet values remain exact, and every non-`TEXTURED_SPRITE` modulation fixture fails authoring validation.

- [ ] **Step 5: Review checkpoint**

Run `git diff --check` and confirm staged file count is `0`.

### Task 7: Add session-only Preview Runtime Input controls and canonical Edit/GAME refresh

**Files:**
- Modify: `src/preview/vfx_vehicle_preview.tscn`
- Modify: `src/preview/vfx_vehicle_preview.gd`
- Create: `tests/editor/test_runtime_modulation_preview_controls.gd`
- Modify: `tests/run_editor_tests.gd`
- Modify: `tests/preview/test_runtime_modulation_program.gd`

**Interfaces:**
- Scene adds hidden `PreviewControls/RuntimeInputsRow` with `SpeedNormalizedSlider` (`0..1`, step `.01`) and `LongitudinalLoadSlider` (`-1..1`, step `.01`).
- `VfxVehiclePreview.set_runtime_input_value(input_name: String, value: float) -> bool` writes only its `VfxPreviewRuntimeInputState`, calls `refresh_modulation(_frame_context())`, then presents packets.

- [ ] **Step 1: Write RED UI/session tests**

Instantiate `vfx_vehicle_preview.tscn` with a static plan and assert `RuntimeInputsRow.visible == false`. Apply the dedicated modulation fixture and assert the row becomes visible, both slider ranges/defaults are correct, and setting `speed_normalized`/`longitudinal_load` changes runtime packet values without changing the edit session working copy, dirty state, history size, source JSON, or active render-plan revision.

Add a parity assertion that the one canonical runtime packet used to route Edit and GAME has the same effective source-local position, geometry scale, rotation, and alpha before canvas-specific projection.

- [ ] **Step 2: Run Editor and Preview suites and confirm RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_editor_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_preview_tests.gd'
```

Expected: the controls, session setter, and no-dirty/parity behavior are absent.

- [ ] **Step 3: Implement minimal session UI plumbing**

Create the row in the scene with both sliders hidden by default. After LOD application/rebuild, inspect only `active_render_plan.runtime_modulation_program()` to show the row when its binding count is positive; show an individual slider only if the program has that input slot. Initialize values from the program's Schema defaults, preserve session values by input name across runtime rebuild, and connect slider changes once. Keep the state on `VfxVehiclePreview`, not `VfxPreviewSharedState`, so vehicle/profile/anchor motion state remains separate.

- [ ] **Step 4: Run GREEN and regression**

Run the Editor and Preview suite commands from Step 2. Expected: static plans expose no new visible UI/evaluator work; fixture controls are session-only and Edit/GAME consume the same canonical effective packet.

- [ ] **Step 5: Review checkpoint**

Run `git diff --check` and confirm staged file count is `0`.

### Task 8: Enforce LOD-before-evaluator behavior and structural Performance safeguards

**Files:**
- Modify: `src/performance/vfx_preview_lod_filter.gd`
- Modify: `src/preview/rendering/vfx_preview_render_plan.gd`
- Modify: `src/preview/rendering/vfx_preview_render_runtime.gd`
- Modify: `tests/preview/test_runtime_modulation_program.gd`
- Modify: `tests/performance/test_runtime_modulation_structure.gd`

**Interfaces:**
- `VfxPreviewLodFilter.filter()` returns a Render Plan carrying `program.filtered_to_reachable_layer_ids(lod_enabled_layer_ids)`, where IDs are included only when LOD eligible and `VfxPreviewLayerSpec.is_enabled()`.
- `VfxPreviewRenderRuntime` creates its active evaluator from a second `filtered_to_reachable_layer_ids(renderer_backed_layer_ids)` result after asset resolution and renderer construction succeed. It refreshes this runtime-reachable program only on activation, source-stop/teardown, or residual-entry removal; never each tick.
- Consumes Task 2 program and Task 3 structural sample counters.

- [ ] **Step 1: Write RED LOD and capacity tests**

Use the three-layer fixture. Assert HIGH retains `13` bindings and one shared source; MEDIUM and LOW retain only the two CORE Layers (`12` bindings) and still sample the shared source once; `one_shot.lod_extra` is absent at MEDIUM and LOW. Create a disabled-only derivative (all three Layers `enabled: false`) and assert the LOD-filtered program has binding count `0`; after activation it has no evaluator, samples `0` sources, and creates `0` effective states. Inject an asset resolver failure for an otherwise enabled modulated Layer and assert the renderer-backed runtime program likewise has binding count `0`, no evaluator, and zero samples. Assert active renderer counts and Particle capacity facts before/after modulation plumbing equal the existing filtered plan's counts; do not assert FPS.

- [ ] **Step 2: Run Preview and Performance suites and confirm RED**

Run the Preview and Performance suite commands. Expected: filtering retains bindings for disabled/LOD-omitted Layers, or activation leaves a modulation evaluator alive after asset or renderer construction fails.

- [ ] **Step 3: Filter program after Layer filtering**

While building each LOD-filtered phase, collect a `Dictionary` set of `layer_id` values only after both the Importance policy includes that Layer and `layer_spec.is_enabled()` is true. Construct the filtered Render Plan with `program.filtered_to_reachable_layer_ids(lod_enabled_layer_ids)`. This removes bindings/clamps for omitted or disabled Layers, rebuilds source consumer reachability, and retains a source only when a retained binding references it.

In `VfxPreviewRenderRuntime.activate_phase()`, retain each entry's `layer_id` only after asset resolution succeeds and `renderer_script.new()` succeeds. After activation, and again after source-stop, clear, or residual-entry retirement changes `_entries`, construct the evaluator program from every active/residual renderer-backed `layer_id`. Create evaluator/effective states only when that program has bindings. This second reachability pass prevents a disabled, missing-asset, unsupported, or failed-renderer Layer from consuming modulation state or oscillator samples. It must not change Layer order, phase duration, revision, Importance policy, renderer counts, or particle caps.

- [ ] **Step 4: Run GREEN and regression**

Run the Preview and Performance suites. Expected: LOD and activation remove unreachable evaluator work, disabled-only and failed-renderer paths have zero bindings/evaluator/samples, shared source sample counts stay one per reachable source, and existing Phase 4 budgets/count projections are unchanged.

- [ ] **Step 5: Review checkpoint**

Run `git diff --check` and confirm staged file count is `0`.

### Task 9: Add the pre-v2 Export fail-closed guard

**Files:**
- Modify: `src/export/vfx_export_compiler.gd`
- Create: `tests/export/test_runtime_modulation_export_guard.gd`
- Modify: `tests/run_export_contract_tests.gd`
- Modify: `tests/export/test_export_compiler_and_writer.gd`

**Interfaces:**
- `VfxExportCompiler.compile(document)` returns `VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", "modulated_preset_requires_runtime_definition_v2", ...)])` before source/runtime/manifest/package-plan construction when the document is modulation-bearing.
- `_runtime_v1_transform(layer: Dictionary) -> Dictionary` is the sole Runtime Definition v1 transform projection and returns only `{ "offset": [...], "rotation_degrees": number, "scale": [...] }`. `_compile_runtime_definition()` uses this helper instead of duplicating the normalized authoring transform.
- A Preset is modulation-bearing only when non-empty `runtime_modulation_sources`, non-empty Layer `modulations`, or non-empty Layer `modulation_clamps` exists. A non-default pivot alone does not block export because it has no active visual behavior without scale/rotation binding.

- [ ] **Step 1: Write RED export guard tests**

Load the dedicated validated fixture and call the compiler. Assert `success == false`, issue kind is `EXPORT_VALIDATION`, code is exactly `modulated_preset_requires_runtime_definition_v2`, value is null, and no plan/manifest/runtime text is exposed.

Compile the existing static Zero Zone document in memory and assert `runtime_text` is byte-for-byte equal to `tests/fixtures/export/talent.zero_zone_runtime_definition_v1.golden.json`; this proves the existing static Runtime Definition v1 snapshot and byte size remain unchanged. Parse that output and assert it contains none of `runtime_modulation_sources`, `modulations`, `modulation_clamps`, or `modulation_pivot_local` at the root, phase, Layer, or transform level.

Build a second valid fixture with only `modulation_pivot_local: [-0.5, 89]` but empty source/binding/clamp arrays. Assert it compiles as Runtime Definition v1, its runtime transform omits the pivot, and its source JSON copy preserves the explicit authoring pivot under the existing source-copy policy. Assert an equivalent default-pivot static document produces the same v1 runtime shape. Keep the existing Zero Zone deterministic v1 byte assertions unchanged.

- [ ] **Step 2: Run Export compile-only suite and confirm RED**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_export_contract_tests.gd'
```

Expected: the modulation fixture currently enters the v1 compile path instead of failing with the required issue; after Task 1 it may also reveal normalized `modulation_pivot_local` leakage from the current transform deep copy.

- [ ] **Step 3: Implement one early classifier and guard**

Add private `VfxExportCompiler._is_modulation_bearing(data: Dictionary) -> bool`. It checks only the three approved non-empty data surfaces across configured lifecycle phase Layers. Call it immediately after export-policy/path validation and before `_deriver.derive(document)`, `_encode_json(document.raw_data)`, `_compile_runtime_definition`, asset compilation, hashing, manifest creation, or `VfxExportPackagePlan` construction. Return the specified `EXPORT_VALIDATION` issue. Do not treat a pivot alone as modulation-bearing.

Add private `_runtime_v1_transform(layer: Dictionary) -> Dictionary` and replace `(layer.get("transform", {}) as Dictionary).duplicate(true)` inside `_compile_runtime_definition()` with that explicit projection. Never add root `runtime_modulation_sources`, Layer `modulations`/`modulation_clamps`, or `transform.modulation_pivot_local` to v1 output. Preserve the existing raw `.vfx.json` source copy without projection. Do not add v2 path selection, manifest version 2, runtime file name changes, writer behavior, or package writes.

- [ ] **Step 4: Run GREEN and static Export regression**

Run the Export suite command from Step 2. Expected: modulation fixture fails closed, pivot-only static fixture remains v1 while omitting its pivot from runtime output, the static Zero Zone runtime text matches the pre-Phase-A golden bytes exactly, and current static package compile-only/determinism tests pass unchanged.

- [ ] **Step 5: Review checkpoint**

Run `git diff --check` and confirm staged file count is `0`.

### Task 10: Update Phase A documentation and perform final regression

**Files:**
- Modify: `docs/VFX_SCHEMA_V1.md`
- Modify: `docs/VFX_STUDIO_ARCHITECTURE.md`
- Modify: `docs/VFX_EXPORT_PACKAGE_V1.md`
- Modify: test runners only if a task above did not register its module

**Interfaces:**
- Documents only implemented Phase A behavior: additive Schema v1 fields, Schema-owned `TEXTURED_SPRITE`-only target compatibility, target-level clamps, non-negative unbounded opacity multipliers with `TEXTURED_SPRITE` final-alpha clamping, static bypass, attachment-preserving pivot, session-only Preview input controls, Runtime Definition v1 projection, and fail-closed export.
- Explicitly excludes Runtime Definition v2 and all Phase B Headlight authoring.

- [ ] **Step 1: Write documentation review assertions/checklist**

Before editing docs, list these exact claims to verify against code: `longitudinal_load` is `[-1,1]` default `0`; source/binding/clamp/pivot defaults preserve static data; every Phase A target's Schema-owned compatible Layer list is exactly `TEXTURED_SPRITE`; `PARTICLE`, `TRAIL`, `RING`, `GLOW`, and `SHIELD` bindings are authoring-validation errors; clamps are target-level and apply once after all contributions; `VISUAL_OPACITY_MULTIPLIER >= 0` has no upper bound and `TEXTURED_SPRITE` final alpha alone clamps to `[0,1]`; v1 non-zero pivot support is `TEXTURED_SPRITE`; `LINEAR_RANGE` and `SINE` are the only mapping/wave; no-modulation plans bypass evaluator work; disabled or renderer-unreachable Layers create no evaluator work; `modulated_preset_requires_runtime_definition_v2` blocks v1 export; static Runtime Definition v1 omits every Phase A modulation field including pivots; Runtime Definition v2 is not implemented in Phase A.

- [ ] **Step 2: Confirm RED documentation gap**

Search the three documentation files for `RUNTIME_MODULATION_CONFIGURATION` and `modulated_preset_requires_runtime_definition_v2`. Expected: the implemented Phase A contract is not yet fully documented.

- [ ] **Step 3: Update only Phase A documentation**

Add concise contract sections matching the implementation exactly. State that each Phase A target is compatible only with `TEXTURED_SPRITE`, and other Layer Types fail validation rather than being ignored. State that pivot coordinates are untransformed Layer-local geometry coordinates; `TEXTURED_SPRITE` uses native texture pixels relative to texture center. State the effective-origin formula and that offset modulation intentionally moves the attachment root. Define `VISUAL_OPACITY_MULTIPLIER` as non-negative and unbounded, with only `TEXTURED_SPRITE` final rendered alpha clamped to `[0,1]`; define target clamps as single post-composition Layer-target operations. Describe public packet defensive copies as existing baseline, not a Phase A allocation claim. Document Phase A Export failure for modulation-bearing Presets, v1 static compatibility, and the explicit v1 transform projection that omits all modulation fields and pivot; do not claim an exported v2 file exists.

- [ ] **Step 4: Run all final verification commands**

Run, once, after every focused task is green:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_contract_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_editor_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_preview_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_performance_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_export_contract_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path 'C:\GodotProjects\DesktopRacingVFXStudio' --quit
git diff --check
git diff --cached --name-only
```

Expected: all five suites and editor parse exit `0`, no `git diff --check` error, and no staged path. Do not run Package writer, re-export, Windows Export, long stress measurement, or a DesktopIdleRacing command.

- [ ] **Step 5: Final scope review**

Confirm changed production Presets count is `0`, `runtime_definition_version` remains `1` in compiler output for static Presets, static v1 text matches the pre-Phase-A golden and contains no modulation/pivot field, no Runtime Definition v2 path exists, no Package was re-exported, and no game repository was accessed. Report any existing user-owned dirty files separately from Phase A changes.

## Task dependency order

```text
Task 1 Schema/validation
  -> Task 2 compiled program
    -> Task 3 evaluator/static bypass
      -> Task 4 generic pivot math
        -> Task 5 runtime + persistent textured packet
      -> Task 6 TEXTURED_SPRITE-only final alpha
          -> Task 7 Preview controls/parity
          -> Task 8 LOD/performance structure
          -> Task 9 Export guard
            -> Task 10 docs + full regression
```

Tasks 6, 7, 8, and 9 may begin only after Task 5 is green; they do not require each other's implementation output. During execution they should be reviewed serially to preserve the shared dirty worktree.

## Spec coverage review

| Approved Phase A requirement | Plan task |
| --- | --- |
| Additive Schema, `longitudinal_load`, source/binding/clamp/pivot defaults, Schema-owned compatibility | 1 |
| Immutable program, stable runtime-input slots, shared SINE, target-level post-composition clamp | 2–3 |
| Generic attachment-preserving transform | 4 |
| Persistent `TEXTURED_SPRITE`, `TEXTURED_SPRITE` opacity, static fast path | 3, 5–6 |
| Session-only Preview input controls and Edit/GAME parity | 7 |
| LOD/disabled/renderer-reachability modulation filtering and structural Performance safeguards | 8 |
| Pre-v2 fail-closed Export guard, static v1 transform projection, and static-v1 golden compatibility | 9 |
| Phase A documentation and final suites | 10 |
| No Phase B Headlight authoring or Phase C Runtime Definition v2 | Global Constraints and Tasks 9–10 |

## Plan self-review

- Scope is one implementation phase: generic Studio contract/Preview plus its mandatory Export safety guard.
- Every approved Phase A item maps to a testable task above.
- Opacity multipliers are non-negative and unbounded in Tasks 1 and 3; Task 6 alone applies `clampf(authored_or_animated_alpha * multiplier, 0.0, 1.0)` at final output.
- Target clamps are Schema-owned Layer contracts in Task 1, compiled separately in Task 2, and tested as one post-composition operation in Task 3.
- Task 1 captures the pre-change static v1 golden; Task 9 projects only legacy transform fields, rejects active modulation for v1, permits pivot-only source authoring, and proves no Phase A field leaks into static runtime JSON.
- Task 8 applies reachability twice: LOD plus enabled status first, then successful renderer-backed activation, with disabled-only and failed-asset tests proving zero bindings, evaluator, and samples.
- Task 1 owns Schema compatibility and rejection tests; Tasks 5–6 consume modulation only in `TEXTURED_SPRITE`, leaving Particle/Trail/Ring/Glow/Shield renderer files untouched.
- The fixture contract is exact and consistent: three `TEXTURED_SPRITE` Layers, twelve symmetric CORE bindings, one EXTRA binding, `13` at HIGH, and `12` at MEDIUM/LOW.
- Production Presets, Package writer behavior, Runtime Definition v2, and game integration are explicitly excluded.
- Interface names, ownership, slot semantics, pivot math, and error code are defined before consuming tasks.
- Every task starts with a focused failing test, names the expected failure, implements the smallest boundary, runs focused green verification, and ends with a no-stage review checkpoint.
