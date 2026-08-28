# DesktopRacingVFXStudio Phase 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the independent Godot 4.7.1 foundation that loads, normalizes, validates, and deterministically serializes strict Schema v1 VFX Presets.

**Architecture:** `schemas/vfx_schema_v1.json` is the sole declarative data contract. `VfxSchemaRegistry` checks and caches that Schema, `VfxPresetCodec` handles JSON and file I/O, `VfxPresetNormalizer` deep-copies and applies defaults, and `VfxContractValidator` combines a constrained structural validator with Schema-declared semantic rule handlers. `VfxPresetPipeline` exposes the ordered flow and returns a `VfxPresetDocument` only after successful validation.

**Tech Stack:** Godot 4.7.1 stable, GDScript, Godot `JSON`, `FileAccess`, and a dependency-free GDScript test runner.

**Spec:** `docs/superpowers/specs/2026-08-28-vfx-studio-phase-0-design.md`

## Global Constraints

- Use Godot 4.7.1 stable only; inspect `C:\Tools\Godot` before executing tests and use the exact installed executable path.
- Keep this project independent of `C:\GodotProjects\DesktopIdleRacing`.
- Add no external dependency and no generic JSON Schema engine.
- Support only the documented JSON Schema v1 subset (`type`, `properties`, `required`, `enum`, `default`, `minimum`, `maximum`, `minItems`, `maxItems`, `items`, `additionalProperties`, `pattern`, and local `$ref`) and local `#/$defs/...` references.
- Preserve raw decoded JSON as `Variant`; do not reject valid JSON top-level arrays or scalars in the codec.
- Validator functions never mutate input; normalizer returns a deep-copied value.
- `.vfx.json` is source data; do not create renderer, UI, export, generated VFX, migration, or asset-manager code.
- Use `additionalProperties: false` for all v1 authoring objects except where the approved Schema explicitly says otherwise.
- Do not create empty future-phase directories without a Phase 0 file that needs them.
- Do not perform Windows Export or long-running tests.

---

## File map

| File | Responsibility |
|---|---|
| `project.godot` | Godot 4.7 project metadata and test-compatible project root. |
| `.gitignore` | Ignore `.godot/` and editor-local temporary files while retaining authored sources and documents. |
| `schemas/vfx_schema_v1.json` | Sole machine-readable Schema v1 contract. |
| `src/model/vfx_issue.gd` | One structured diagnostic record. |
| `src/model/vfx_result.gd` | Success flag, Variant value, and diagnostic collection. |
| `src/model/vfx_preset_document.gd` | Raw and normalized independent Preset data plus source path. |
| `src/model/vfx_rule_catalog.gd` | Supported rule names, configuration requirements, and dispatch metadata. |
| `src/model/vfx_schema_registry.gd` | Schema loading, local ref resolution, configuration checks, and cache. |
| `src/model/vfx_schema_subset_validator.gd` | Read-only validation of the exact Schema subset used by v1. |
| `src/model/vfx_preset_normalizer.gd` | Schema-driven, non-mutating default application. |
| `src/model/vfx_contract_validator.gd` | Structural validation orchestration and semantic VFX rule handlers. |
| `src/model/vfx_preset_codec.gd` | JSON decode/encode and file read/write boundaries. |
| `src/app/vfx_preset_pipeline.gd` | Thin composition root for load, validate, and serialize operations. |
| `presets/examples/*.vfx.json` | Valid Zero Zone and one-shot examples. |
| `tests/support/test_assert.gd` | Minimal assertion accumulator. |
| `tests/unit/*.gd` | Focused test groups callable by the runner. |
| `tests/run_contract_tests.gd` | Headless test entry point and exit-code owner. |

## Task 1: Bootstrap the independent Godot project and test entry point

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `tests/support/test_assert.gd`
- Create: `tests/run_contract_tests.gd`
- Modify: `docs/VFX_STUDIO_ARCHITECTURE.md`

**Interfaces:**
- Produces: headless command entry `res://tests/run_contract_tests.gd` that calls `quit(exit_code)`.
- Produces: `TestAssert` with `expect_true(condition: bool, message: String)` and `failure_count() -> int`.

- [ ] **Step 1: Initialize Git and create the minimum Godot project files**

Run:

```powershell
git init
```

Create `project.godot` with Godot 4.7 compatibility metadata and create `.gitignore` that ignores `.godot/` without ignoring `src/`, `schemas/`, `docs/`, `presets/`, `tests/`, `project.godot`, or `assets/reference/`.

- [ ] **Step 2: Write the initial failing headless runner assertion**

```gdscript
var tests := TestAssert.new()
tests.expect_true(false, "test runner executes assertions")
quit(1 if tests.failure_count() > 0 else 0)
```

- [ ] **Step 3: Run the runner and verify a non-zero exit code**

Run the installed Godot 4.7.1 executable with `--headless --path <workspace> --script res://tests/run_contract_tests.gd`.

Expected: the process exits with code `1` and prints the assertion message.

- [ ] **Step 4: Implement the minimal assertion helper and passing smoke assertion**

```gdscript
var tests := TestAssert.new()
tests.expect_true(true, "test runner executes assertions")
quit(1 if tests.failure_count() > 0 else 0)
```

- [ ] **Step 5: Run the runner and project parser**

Run:

```powershell
& '<Godot-4.7.1-exe>' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_contract_tests.gd
& '<Godot-4.7.1-exe>' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --editor --quit
```

Expected: both commands exit with code `0`.

- [ ] **Step 6: Commit the bootstrap**

```powershell
git add project.godot .gitignore tests docs/VFX_STUDIO_ARCHITECTURE.md
git commit -m "chore: bootstrap VFX Studio contract project"
```

## Task 2: Add structured result and document models

**Files:**
- Create: `src/model/vfx_issue.gd`
- Create: `src/model/vfx_result.gd`
- Create: `src/model/vfx_preset_document.gd`
- Create: `tests/unit/test_result_models.gd`
- Modify: `tests/run_contract_tests.gd`

**Interfaces:**
- Produces: `VfxIssue.new(kind, code, message, json_pointer := "", source_path := "", line := -1, column := -1, severity := "ERROR")`.
- Produces: `VfxResult.success(value: Variant) -> VfxResult` and `VfxResult.failure(issues: Array[VfxIssue]) -> VfxResult`.
- Produces: `VfxPresetDocument.new(source_path: String, raw_data: Variant, normalized_data: Dictionary)`.

- [ ] **Step 1: Write failing model tests**

```gdscript
func test_error_issue_makes_result_unsuccessful(tests: TestAssert) -> void:
    var issue := VfxIssue.new("JSON_PARSE", "invalid_json", "bad JSON", "", "preset.vfx.json", 3, -1)
    var result := VfxResult.failure([issue])
    tests.expect_true(not result.success, "ERROR issue makes result unsuccessful")
    tests.expect_true(result.issues[0].column == -1, "unknown JSON column stays -1")
```

- [ ] **Step 2: Run the focused test group and verify failure**

Run the runner with only `test_result_models.gd` registered.

Expected: parse or missing-class failure because the model files do not yet exist.

- [ ] **Step 3: Implement immutable-style result construction and independent document data**

`VfxResult` calculates `success` as false whenever any Issue has severity `ERROR`. `VfxPresetDocument` stores deep duplicates of both raw and normalized values so the two values cannot alias one another.

- [ ] **Step 4: Add the document independence assertion and run tests**

```gdscript
var raw := {"layers": []}
var document := VfxPresetDocument.new("", raw, {"layers": [{"id": "loop.core"}]})
raw["layers"].append({"id": "mutated"})
tests.expect_true(document.raw_data["layers"].is_empty(), "document keeps independent raw data")
```

Expected: all registered tests pass.

- [ ] **Step 5: Commit the models**

```powershell
git add src/model tests/unit/test_result_models.gd tests/run_contract_tests.gd
git commit -m "feat: add structured VFX contract results"
```

## Task 3: Implement JSON codec behavior for Variant top levels

**Files:**
- Create: `src/model/vfx_preset_codec.gd`
- Create: `tests/unit/test_preset_codec.gd`
- Modify: `tests/run_contract_tests.gd`

**Interfaces:**
- Produces: `decode_text(text: String, source_path := "") -> VfxResult`.
- Produces: `decode_file(path: String) -> VfxResult`.
- Produces: `encode(value: Variant) -> VfxResult` and `write_file(path: String, value: Variant) -> VfxResult`.
- Consumes: `VfxIssue`, `VfxResult`.

- [ ] **Step 1: Write failing codec tests for valid scalar and array JSON**

```gdscript
var array_result := codec.decode_text("[]", "array.vfx.json")
tests.expect_true(array_result.success, "codec accepts JSON array syntax")
tests.expect_true(array_result.value is Array, "codec preserves array Variant")

var scalar_result := codec.decode_text("123", "scalar.vfx.json")
tests.expect_true(scalar_result.success, "codec accepts JSON scalar syntax")
tests.expect_true(typeof(scalar_result.value) == TYPE_INT, "codec preserves scalar Variant")
```

- [ ] **Step 2: Run codec tests and verify failure**

Expected: missing `VfxPresetCodec` failure.

- [ ] **Step 3: Implement decode and file-I/O boundaries**

Use Godot `JSON.parse_string` only for success values and `JSON.new().parse` when parse diagnostics are required. Preserve only API-provided parse line data; set `column` to `-1`. Return `FILE_IO` for unreadable or unwritable paths and `JSON_PARSE` for syntax errors.

- [ ] **Step 4: Implement deterministic normalized pretty JSON encoding**

Use `JSON.stringify(value, "  ", true)` so a normalized value is sorted and indented deterministically. Name this behavior “deterministic normalized pretty JSON”, not an RFC canonical JSON implementation.

- [ ] **Step 5: Add failure and determinism tests, then run the suite**

```gdscript
var first := codec.encode({"b": 1, "a": 2})
var second := codec.encode({"a": 2, "b": 1})
tests.expect_true(first.value == second.value, "sorted encoding is deterministic")
```

Also assert malformed JSON returns `JSON_PARSE` and a missing file returns `FILE_IO`.

- [ ] **Step 6: Commit the codec**

```powershell
git add src/model/vfx_preset_codec.gd tests/unit/test_preset_codec.gd tests/run_contract_tests.gd
git commit -m "feat: add Variant-preserving VFX JSON codec"
```

## Task 4: Author the frozen Schema v1 and rule catalog

**Files:**
- Create: `schemas/vfx_schema_v1.json`
- Create: `src/model/vfx_rule_catalog.gd`
- Create: `tests/unit/test_schema_artifact.gd`
- Modify: `tests/run_contract_tests.gd`
- Modify: `docs/VFX_SCHEMA_V1.md`

**Interfaces:**
- Produces: machine-readable Schema with local `$defs`, `x_vfx_layer_types`, `x_vfx_runtime_inputs`, and `x_vfx_rules`.
- Produces: `VfxRuleCatalog.supports(name: String) -> bool` and `validate_configuration(rule: Dictionary, pointer: String) -> Array[VfxIssue]`.

- [ ] **Step 1: Write failing Schema artifact tests**

```gdscript
var schema_result := codec.decode_file("res://schemas/vfx_schema_v1.json")
tests.expect_true(schema_result.success, "Schema file is JSON")
tests.expect_true(schema_result.value is Dictionary, "Schema root is an object")
tests.expect_true((schema_result.value as Dictionary).has("x_vfx_rules"), "Schema declares VFX rules")
```

- [ ] **Step 2: Run the test and verify failure**

Expected: `FILE_IO` because the Schema file does not exist.

- [ ] **Step 3: Author Schema v1 exactly from the approved design**

Define strict Preset, lifecycle, phase, common Layer, transform, parameter, emitter, and runtime-input structures. Put all enum values, defaults, ranges, logical-ID patterns, parameter definitions, and the supported rule configurations in this file. Define Layer Type mappings under `x_vfx_layer_types`; do not duplicate type-specific parameter selection in GDScript.

- [ ] **Step 4: Implement the rule catalog’s fixed handler inventory**

The catalog supports only `LIFECYCLE_PHASE_STRUCTURE`, `PRESET_HAS_LAYER`, `UNIQUE_LAYER_IDS_ACROSS_PHASES`, `TYPE_DISPATCHED_PARAMETER_SCHEMA`, `PARTICLE_EMISSION_CONFIGURATION`, `PARTICLE_EMITTER_SHAPE`, `PARTICLE_MOTION_RANGE_ORDER`, `RUNTIME_INPUT_NAMES`, `EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS`, and `RENDER_PLANE_FOR_EFFECTIVE_SPACE`. It validates the required configuration keys for each declared rule.

- [ ] **Step 5: Run Schema artifact tests**

Expected: the Schema is readable JSON and all named rule configurations are syntactically present.

- [ ] **Step 6: Commit Schema v1**

```powershell
git add schemas/vfx_schema_v1.json src/model/vfx_rule_catalog.gd tests/unit/test_schema_artifact.gd tests/run_contract_tests.gd docs/VFX_SCHEMA_V1.md
git commit -m "feat: define strict VFX Schema v1"
```

## Task 5: Build cached Schema configuration validation and subset validation

**Files:**
- Create: `src/model/vfx_schema_registry.gd`
- Create: `src/model/vfx_schema_subset_validator.gd`
- Create: `tests/unit/test_schema_registry.gd`
- Create: `tests/unit/test_schema_subset_validator.gd`
- Modify: `tests/run_contract_tests.gd`

**Interfaces:**
- Produces: `VfxSchemaRegistry.load(path: String) -> VfxResult` and `resolve_local_ref(reference: String) -> VfxResult`.
- Produces: `VfxSchemaRegistry.schema() -> Dictionary` after successful configuration validation.
- Produces: `VfxSchemaSubsetValidator.validate(value: Variant, schema: Dictionary, pointer := "") -> Array[VfxIssue]`.
- Consumes: `VfxPresetCodec`, `VfxRuleCatalog`, `VfxIssue`, `VfxResult`.

- [ ] **Step 1: Write failing registry tests for reference support and configuration errors**

```gdscript
tests.expect_true(registry.resolve_local_ref("#/$defs/layer").success, "local ref resolves")
tests.expect_true(not registry.resolve_local_ref("https://example.com/schema.json").success, "external ref is rejected")
```

Add temporary in-memory Schema fixtures for a missing `$ref`, a `$defs/a -> $defs/b -> $defs/a` cycle, and an unknown `x_vfx_rule`.

- [ ] **Step 2: Run the registry group and verify failure**

Expected: missing registry and subset validator class failures.

- [ ] **Step 3: Implement local reference resolution and cycle detection**

Accept only references beginning with `#/$defs/`. Reject all other strings as `SCHEMA_CONFIGURATION`. During Schema load, recursively inspect used references with an active-resolution set; report a cycle using the Schema JSON Pointer and do not recurse indefinitely.

- [ ] **Step 4: Implement the documented structural subset validator**

Implement only `type`, `properties`, `required`, `enum`, `minimum`, `maximum`, `minItems`, `maxItems`, `items`, `additionalProperties`, `pattern`, and local `$ref`. It returns `PRESET_VALIDATION` issues and never applies defaults or mutates values.

- [ ] **Step 5: Validate Schema configuration before caching**

Check required root sections, all used local references, cycles, rule names and configuration through `VfxRuleCatalog`, Layer Type-to-definition mappings, runtime input definition objects, and every Schema default against its own subschema. Cache only a successful Schema.

- [ ] **Step 6: Add strict property and default-conflict tests, then run the suite**

```gdscript
var issues := subset.validate({"unknown": true}, strict_object_schema, "")
tests.expect_true(issues.any(func(issue): return issue.code == "additional_property"), "unknown property is rejected")
```

Expected: local ref success, external ref rejection, cyclic ref configuration error, unknown rule configuration error, and strict property tests all pass.

- [ ] **Step 7: Commit Schema services**

```powershell
git add src/model/vfx_schema_registry.gd src/model/vfx_schema_subset_validator.gd tests/unit/test_schema_registry.gd tests/unit/test_schema_subset_validator.gd tests/run_contract_tests.gd
git commit -m "feat: validate and cache local VFX Schema configuration"
```

## Task 6: Implement non-mutating Schema default normalization

**Files:**
- Create: `src/model/vfx_preset_normalizer.gd`
- Create: `tests/unit/test_preset_normalizer.gd`
- Modify: `tests/run_contract_tests.gd`

**Interfaces:**
- Produces: `VfxPresetNormalizer.normalize(raw_value: Variant, schema: Dictionary) -> VfxResult`.
- Consumes: `VfxSchemaRegistry` for local refs and type-dispatched Layer parameter schemas.
- Produces: a deep-copied normalized Variant; raw input remains unchanged.

- [ ] **Step 1: Write failing default and mutation-isolation tests**

```gdscript
var raw := {"enabled": false, "transform": {"offset": [3.0, 0.0]}}
var result := normalizer.normalize(raw, layer_schema)
tests.expect_true(result.value["sort_order"] == 0, "Schema default is applied")
tests.expect_true(not raw.has("sort_order"), "normalizer does not mutate raw input")
```

- [ ] **Step 2: Run the normalizer group and verify failure**

Expected: missing normalizer class failure.

- [ ] **Step 3: Implement recursive deep-copy normalization**

For a matching object, duplicate the source, recursively normalize known properties, and append missing property defaults from the Schema. Preserve unknown keys for the validator to reject. For arrays, normalize each item. For a nonmatching scalar or array at the Preset root, return a deep copy unchanged so validation can report `/type`.

- [ ] **Step 4: Implement Layer Type parameter default dispatch**

When normalizing a Layer `parameters` object, obtain the selected parameter subschema only from the Schema’s `x_vfx_layer_types` mapping. Do not maintain a GDScript Layer Type table.

- [ ] **Step 5: Add nested transform and Particle Motion default tests, then run the suite**

```gdscript
tests.expect_true(normalized["transform"]["scale"] == [1.0, 1.0], "nested transform defaults apply")
tests.expect_true(normalized["parameters"]["spread_degrees"] == 0.0, "Particle Motion default applies")
```

Expected: defaults are present only in normalized output and raw data remains byte-for-byte equivalent by Dictionary comparison.

- [ ] **Step 6: Commit the normalizer**

```powershell
git add src/model/vfx_preset_normalizer.gd tests/unit/test_preset_normalizer.gd tests/run_contract_tests.gd
git commit -m "feat: normalize VFX presets without mutating source"
```

## Task 7: Implement contract and semantic-rule validation

**Files:**
- Create: `src/model/vfx_contract_validator.gd`
- Create: `tests/unit/test_contract_validator.gd`
- Modify: `tests/run_contract_tests.gd`

**Interfaces:**
- Produces: `VfxContractValidator.validate(value: Variant) -> VfxResult`.
- Consumes: cached `VfxSchemaRegistry`, `VfxSchemaSubsetValidator`, and `VfxRuleCatalog`.
- Produces: a successful result only when the normalized value is a valid top-level Preset `Dictionary`.

- [ ] **Step 1: Write failing contract tests for top-level Variant validation**

```gdscript
var array_result := validator.validate([])
tests.expect_true(not array_result.success, "array is not a Preset")
tests.expect_true(array_result.issues[0].json_pointer == "/type", "top-level type error has pointer")
```

- [ ] **Step 2: Run the contract group and verify failure**

Expected: missing contract validator class failure.

- [ ] **Step 3: Implement structural validation orchestration**

Call the subset validator on the root Schema. If the normalized root is not a Dictionary, return only a `PRESET_VALIDATION` type issue at `/type` and do not execute semantic rules.

- [ ] **Step 4: Implement lifecycle and Layer identity rule handlers**

Implement `LIFECYCLE_PHASE_STRUCTURE`, `PRESET_HAS_LAYER`, and `UNIQUE_LAYER_IDS_ACROSS_PHASES`. Collect Layers from all approved phase stacks and report duplicate IDs at the second duplicate’s JSON Pointer.

- [ ] **Step 5: Implement Type, Particle, and runtime-input handlers**

Implement `TYPE_DISPATCHED_PARAMETER_SCHEMA`, `PARTICLE_EMISSION_CONFIGURATION`, `PARTICLE_EMITTER_SHAPE`, `PARTICLE_MOTION_RANGE_ORDER`, and `RUNTIME_INPUT_NAMES` using only rule configuration and Schema data. Cover burst versus continuous fields, every emitter geometry shape, min/max ordering, and unknown input names.

- [ ] **Step 6: Implement effective-space and render-plane handlers**

Implement `EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS` and `RENDER_PLANE_FOR_EFFECTIVE_SPACE`. Resolve missing Layer `space_mode` against the Preset default without writing it back to the input data.

- [ ] **Step 7: Add semantic failure tests and run the suite**

```gdscript
tests.expect_true(has_code(validator.validate(vehicle_layer_without_anchor), "vehicle_anchor_required"), "vehicle Layer requires Anchor")
tests.expect_true(has_code(validator.validate(world_layer_with_anchor), "anchor_not_allowed"), "world Layer rejects vehicle Anchor")
tests.expect_true(has_code(validator.validate(invalid_continuous_particle), "continuous_emission_fields"), "continuous Particle has capacity and rate")
```

Also cover invalid enum, missing required field, invalid plane, invalid emitter shape, and incorrect one-shot/start-loop-end phase structures.

- [ ] **Step 8: Commit contract validation**

```powershell
git add src/model/vfx_contract_validator.gd tests/unit/test_contract_validator.gd tests/run_contract_tests.gd
git commit -m "feat: validate VFX Schema semantics"
```

## Task 8: Compose the pipeline, examples, fixtures, and full round-trip verification

**Files:**
- Create: `src/app/vfx_preset_pipeline.gd`
- Create: `presets/examples/talent.zero_zone.vfx.json`
- Create: `presets/examples/finish.confetti_world.vfx.json`
- Create: `tests/unit/test_preset_pipeline.gd`
- Create: `tests/fixtures/valid/zero_zone.vfx.json`
- Create: `tests/fixtures/invalid/` fixture files for every listed invalid case
- Modify: `tests/run_contract_tests.gd`
- Modify: `docs/VFX_STUDIO_ARCHITECTURE.md`
- Modify: `docs/VFX_SCHEMA_V1.md`
- Modify: `docs/VFX_EDITOR_ROADMAP.md`

**Interfaces:**
- Produces: `VfxPresetPipeline.load_and_validate(path: String) -> VfxResult`.
- Produces: `VfxPresetPipeline.serialize_document(document: VfxPresetDocument) -> VfxResult`.
- Consumes: codec, cached Registry, normalizer, validator, and all model types.

- [ ] **Step 1: Write the failing valid Zero Zone pipeline test**

```gdscript
var result := pipeline.load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
tests.expect_true(result.success, "Zero Zone completes load-normalize-validate")
tests.expect_true(result.value is VfxPresetDocument, "pipeline returns a document")
```

- [ ] **Step 2: Run the integration test and verify failure**

Expected: missing pipeline and example fixture failure.

- [ ] **Step 3: Implement the thin pipeline composition root**

Load and configuration-check the Schema once, decode a Preset as Variant, normalize its deep copy, validate it, then construct `VfxPresetDocument` only after success. On serialize, revalidate the normalized data before codec encoding.

- [ ] **Step 4: Add approved example Presets and invalid fixtures**

Create the final namespaced `talent.zero_zone` start/loop/end example with local CENTER energy shards and the `finish.confetti_world` one-shot World example. Add one focused invalid fixture per required test case instead of a custom fixture framework.

- [ ] **Step 5: Add full round-trip and deterministic serialization tests**

```gdscript
var loaded := pipeline.load_and_validate("res://tests/fixtures/valid/zero_zone.vfx.json")
var first := pipeline.serialize_document(loaded.value)
var decoded := codec.decode_text(first.value, "round_trip.vfx.json")
var second := codec.encode(decoded.value)
tests.expect_true(first.value == second.value, "normalized serialization is deterministic")
```

- [ ] **Step 6: Run the complete headless suite and Godot project parse**

Run the verified Godot 4.7.1 executable with the test runner, then run `--headless --editor --quit` against the project. Record exact commands and exit codes in the final Phase 0 report.

Expected: every fixture reports the expected issue code or successful result; both commands exit with code `0`.

- [ ] **Step 7: Review documentation against implementation and commit**

Confirm the documents describe the actual Schema fields, supported rules, test command, source/derived boundary, and Phase 0 limits. Then run:

```powershell
git add src presets tests docs schemas
git commit -m "feat: complete VFX Studio Phase 0 contract foundation"
```

## Plan self-review

- Specification coverage: Tasks 1 through 8 cover project bootstrap, Git initialization, strict Schema v1, local ref safety, raw Variant decoding, deep-copy normalization, structural and semantic validation, deterministic encoding, valid examples, all requested error categories, and headless verification.
- Dependency order: diagnostics precede codec; codec precedes Schema loading; Schema registry and subset validation precede normalization; normalization precedes contract validation; all services precede pipeline integration.
- Scope check: no task adds rendering, UI, asset management, migration, export, generated VFX, or a Desktop Idle Racing dependency.
- Type consistency: codec and normalizer return `VfxResult`; validator accepts `Variant`; only the successful pipeline creates `VfxPresetDocument` with a normalized `Dictionary`.
- Placeholder scan: all tasks name exact files, interfaces, test expectations, and verification commands.
