# DesktopRacingVFXStudio Phase 1 Design

## Goal

Build the first desktop authoring surface for the frozen VFX Schema v1: a Preset Library and phase-aware Layer Stack editor that edits `.vfx.json` source through the existing Contract Pipeline. Phase 1 provides no VFX renderer, preview, game integration, export system, graph, or timeline.

## Product boundary

DesktopRacingVFXStudio owns how a Preset is authored and validated. Desktop Idle Racing will eventually decide when an already-exported VFX is triggered; this Phase neither reads nor depends on that project.

The editor is a Godot `Control` application with a Layer Stack, not a Node Graph. `schemas/vfx_schema_v1.json` remains the only declarative source for Schema v1 fields, enums, ranges, defaults, Layer Type mappings, Runtime Inputs, and semantic-rule configuration. No Phase 1 feature changes Schema v1.

## Scope

Included:

- Browse Presets only below the Studio authoring root, initially `res://presets/`.
- New, Open, Save, Save As, Undo, Redo, Validate, dirty state, and Save/Discard/Cancel protection.
- Phase-aware Layer Stack authoring for `ONE_SHOT` and `START_LOOP_END`.
- Common Preset/Layer editing, Schema-driven type-specific forms, Anchors, and Runtime Input declarations.
- Structured Contract diagnostics with practical field navigation.
- Headless editor-state tests and a real Godot scene instantiate/free smoke test.

Excluded:

- Any VFX rendering or preview, Vehicle Anchor Profiles, performance analysis, export, manifests, migration, game-project access, invalid-Preset repair mode, generic JSON Schema forms, graph editors, and generic timelines.

## Contract and persistence boundary

The editor has a mutable authoring state because an author needs to create a Preset before it can satisfy every Contract rule. A successful save is stricter:

```text
saved VfxPresetDocument
  -> VfxPresetEditSession (deep-copied working data)
  -> editor mutation / UndoRedo snapshot
  -> VfxPresetPipeline.build_document_from_value(...)
  -> VfxPresetPipeline.serialize_document(...)
  -> editor-owned text write
```

`build_document_from_value(value, source_path)` is a generic Phase 0 Pipeline seam, not an Editor API. It performs exactly: ensure cached Schema, deep-copy normalize, validate, and construct a `VfxPresetDocument` on success. `load_and_validate` keeps its existing file meaning by decoding a file and then delegating to that seam. `serialize_document` keeps its existing revalidation and deterministic JSON encoding meaning.

The Editor owns target-path choice, overwrite confirmation, dirty prompts, and the decision to write a validated serialized string. It must never write working data directly or use `VfxPresetCodec` to bypass Pipeline normalization/validation.

## Authoring root

`VfxAuthoringPaths` is the sole Phase 1 path-policy object. Its default constructor value is `res://presets/`; Library scans, New default locations, Open validation, Save, and Save As consume that object instead of duplicating the string. It provides:

```gdscript
class_name VfxAuthoringPaths
extends RefCounted

func preset_root() -> String
func contains_preset_path(path: String) -> bool
func default_save_path(preset_id: String) -> String
func normalize_authoring_path(path: String) -> String
```

`default_save_path("talent.zero_zone")` is `res://presets/talent.zero_zone.vfx.json`. A chosen path must be within the root and end in `.vfx.json`; external workspaces, multiple projects, and export destinations are explicitly absent.

## Application layout

`vfx_editor_main.tscn` is a desktop `Control` scene and becomes the project main scene. It contains named regions rather than a renderer or preview canvas:

```text
Toolbar: New | Open | Save | Save As | Undo | Redo | Validate | dirty indicator
--------------------------------------------------------------------------------
Library            | Preset common fields / Phase tabs / Layer Stack | Inspector
--------------------------------------------------------------------------------
Diagnostics (severity, code, message, JSON Pointer, source path)
```

- The Library lists only valid Presets from the authoring root with display name, id, category, and path. A small substring search and Category `OptionButton` filter are included; this is not an asset browser.
- Invalid files are visible as error rows with their diagnostic summary but cannot be opened as ordinary documents in Phase 1. They are not silently omitted and no repair mode is implemented.
- `ONE_SHOT` exposes only `one_shot`; `START_LOOP_END` exposes `start`, `loop`, and `end`. Start and End expose duration; Loop does not.
- The Layer Stack provides Add, Delete, Duplicate, Move Up, Move Down, Enabled, and Select. Reordering only reorders the active phase array. No drag-and-drop is required.

## Schema-aware presentation

`VfxSchemaRegistry`, loaded from the same Schema file used by the Pipeline, is a read-only source for editor presentation. `VfxSchemaInspectorFactory` deliberately interprets only the frozen v1 shapes:

- Schema `enum` -> `OptionButton`.
- `number` / `integer` with optional minimum/maximum -> `SpinBox`.
- `boolean` -> `CheckBox`.
- `string` -> `LineEdit`.
- two-number arrays -> Vector2 row.
- four-number arrays -> RGBA row of numeric controls.
- known nested objects -> nested labelled fields.

It resolves local `$defs` through the Registry and obtains type-specific `parameters` only through `x_vfx_layer_types`. It is not a generic JSON Schema form engine. Labels are generated from Schema property names for v1, and the Inspector displays Schema range information in tooltips. Phase 1 adds no `x_ui` metadata because the frozen contract is sufficient for the intended controls.

Runtime Input checkboxes come from `x_vfx_runtime_inputs`; selecting one only adds/removes its declared string in `/runtime_inputs`. No Phase 1 binding, calculation, target selection, or gameplay rule is created.

## Mutable session, dirty state, and history

`VfxPresetEditSession` contains `source_path`, a deep-copied `working_data`, and the deep-copied normalized data from its last successful save. It is intentionally not a `VfxPresetDocument`, since it can be temporarily invalid.

`VfxDirtyTracker` compares deterministic `VfxPresetCodec.encode` results for normalized working data and the normalized saved baseline. A new session with no source path is always dirty. The baseline changes only after successful Pipeline build, serialization, and write. Opening a valid document starts with its normalized data in both places, so omitted source defaults do not create a false dirty state.

`VfxPresetHistory` is a thin Godot `UndoRedo` wrapper. Each authoring-data action registers deep duplicates of both before and after Dictionaries; the restore target also duplicates the received snapshot before storing it. Whole-document snapshots are safe at Phase 1 scale and prevent Array/Dictionary aliasing from changing saved history. Numeric input coalesces one action from focus entry to valid commit on focus exit or Enter; typing individual characters does not produce history entries.

Selection is UI state, not authoring history. After every Undo, Redo, or structural replacement, the controller reconciles `selected_phase` and `selected_layer_id`: keep a selected layer only if that id still exists in the selected phase; otherwise retain a valid phase and clear the layer selection. Recreated Layers may be selected by the ordinary stack-selection action; stale references are never kept.

## New Preset and factory policy

New Preset creates a **minimum editable Preset Skeleton**, not a minimum valid Preset. Its root data comes from Schema v1 fields and the `LIFECYCLE_PHASE_STRUCTURE` rule's configured phase names:

- `ONE_SHOT`: `phases.one_shot = { duration_seconds, layers: [] }`.
- `START_LOOP_END`: `start`, `loop`, and `end` with empty Layer arrays; only Start and End have `duration_seconds`.

The explicit initial duration is a UI factory value, not a Schema `default`; it is selected to satisfy the declared `minimum`. Initial root choices come from user selections constrained by Schema enums. Empty phase stacks are permitted only in the in-memory session. The Contract Validator will report the existing `PRESET_HAS_LAYER` rule result (`preset_has_no_layers`) in Diagnostics, and normal Save/Save As is blocked until the user adds at least one valid Layer.

No hidden Glow, Particle, or other placeholder Layer is added. `fx.placeholder` is an explicit UI factory initial logical asset reference only when the author adds a Particle, Trail, or Shield Layer whose initial parameter set needs it.

`VfxLayerFactory` uses Schema enum values, defaults, the configured Layer Type mapping, and effective-space rule configuration to create valid initial Layers with globally unique ids such as `loop.particle`, then `loop.particle_2`. Required parameter values without a Schema `default` are documented **factory initial values**, not duplicate Contract defaults; the factory builds the value and immediately relies on the Pipeline validation path to confirm it remains valid. It does not add enum lists, ranges, or defaults to GDScript.

`VfxStructureChangeService` owns destructive replacements:

- Lifecycle replacement discards all phase stacks and creates the target mode's empty editable phase skeleton while preserving compatible root fields.
- Layer Type replacement preserves common Layer fields and id, then replaces `type` and `parameters` using `VfxLayerFactory`.

Both operations require an explicit confirmation dialog, are single deep-copy UndoRedo actions, and use no speculative field-by-field conversion.

## Common editing rules

- A Layer missing `space_mode` means **INHERIT DEFAULT**. The Inspector shows that state without writing the field. Choosing an override writes `space_mode`; choosing INHERIT removes it.
- For vehicle spaces, Anchor multi-selection writes a nonempty `anchors` array. For `WORLD_AREA` and `SCREEN_UI`, the Anchor editor is disabled/hidden and removes anchors when a confirmed common-property change switches away from a vehicle space. The normal Validator remains the authority for all effective-space errors.
- Common Layer edits cover id, importance, blend mode, render plane, sort order, enabled, effective space/override, anchors, and transform. Preset common edits cover id, display name, category, lifecycle, default space, and Runtime Input declarations.
- Validation runs after document load, New creation, every structural command, a committed Inspector field edit, explicit Validate, and Save. It does not run on every keystroke.

## Diagnostics and unsafe transitions

The Diagnostics Panel displays each `VfxIssue`'s severity, kind, code, message, JSON Pointer, source path, line, and column where available. `VfxDiagnosticsNavigator` routes root pointers to the common Preset Inspector and `/phases/<phase>/layers/<index>/...` pointers to the matching Phase, Layer, and common/type Inspector field. A known Layer id is reconciled from the selected array entry. Schema configuration or unsupported pointers remain display-only with their full diagnostics; navigation failure never hides an issue.

New, Open, application close, and quit use Save / Discard / Cancel if the session is dirty. Save invokes the normal valid-only pipeline flow. A failed validation leaves session data and dirty state unchanged, focuses Diagnostics, and performs no write. Save As additionally validates authoring-root containment and confirms an overwrite. Lifecycle and Layer Type replacement use separate destructive-change confirmation dialogs before creating history.

## Tests and verification

The existing `tests/run_contract_tests.gd` remains the Phase 0 Contract suite and must continue to report its 121 assertions without failures. Phase 1 receives a separate `tests/run_editor_tests.gd` runner for UI-independent state/controller tests and real scene smoke coverage.

The smoke test loads `res://src/editor/main/vfx_editor_main.tscn`, instantiates it, verifies the named main regions and controller connections, triggers no authoring save, and immediately frees it. It proves that the Godot scene, scripts, and signals can load; it is not a pixel or layout test. Final verification runs the two headless test runners and `--headless --editor --quit` with the already verified Godot 4.7.1 console executable.

## Phase 1 acceptance criteria

1. A valid stored Preset opens as a normalized session with no dirty marker and can save deterministically.
2. A newly created empty Skeleton remains editable, displays the existing no-layer Contract error, and cannot write a `.vfx.json` file.
3. Adding a valid Layer makes the no-layer error disappear; Save and Save As then write only inside `res://presets/`.
4. Every Layer Type, enum, default application, runtime-input choice, and parameter schema comes from `vfx_schema_v1.json`; no manual enum/default mirror exists in Editor code.
5. Undo/Redo snapshots do not alias subsequent Dictionary or Array mutations, and reconciliation prevents stale selected Layer references.
6. Lifecycle and Layer Type replacement require confirmation and can be undone in one action.
7. Invalid library files are visibly reported but are not opened into the normal editor.
8. Existing Contract tests, all Editor headless tests, scene smoke, and Godot editor parse exit successfully.

## No Schema or architecture contradiction found

Schema v1 can express Phase 1 without change. `PRESET_HAS_LAYER` makes an empty new Preset invalid as a stored Contract document, but it does not prevent a separate in-memory edit session. Its current emitted issue code is `preset_has_no_layers`; the UI will present it as the configured `PRESET_HAS_LAYER` rule failure without changing the frozen Schema. The existing Pipeline needs only generic `build_document_from_value`; no Editor-specific API is introduced.
