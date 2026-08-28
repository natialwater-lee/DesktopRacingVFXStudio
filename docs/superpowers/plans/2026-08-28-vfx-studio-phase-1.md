# VFX Studio Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a valid-only-save, Layer Stack-oriented Godot desktop editor for Schema v1 Presets while allowing a newly created empty Skeleton to exist only in memory.

**Architecture:** The editor keeps mutable authoring state in `VfxPresetEditSession`, records deep-copy whole-document snapshots through Godot `UndoRedo`, and sends every validation/save candidate through the existing Contract Pipeline. A small editor schema reader consumes `VfxSchemaRegistry` data solely for presentation and factories; it never mirrors Contract enums, defaults, ranges, or type mappings. `VfxAuthoringPaths` centralizes the `res://presets/` policy.

**Tech Stack:** Godot 4.7.1 stable, standard GDScript, built-in Control UI, FileAccess/DirAccess, built-in `UndoRedo`, no external libraries.

**Spec:** `docs/superpowers/specs/2026-08-28-vfx-studio-phase-1-design.md`

## Global Constraints

- Keep `schemas/vfx_schema_v1.json` frozen; do not add enum values, fields, UI metadata, or generic Schema features for Phase 1 convenience.
- `.vfx.json` remains authoring source of truth; `.tres`, manifests, exports, renderer data, and generated assets are out of scope.
- Use the Schema as the only declarative source for enums, defaults, bounds, type-specific parameter selection, Runtime Inputs, and semantic-rule configuration.
- Add no Node Graph, 3D, Preview Renderer, Particle Renderer, performance analyzer, exporter, migration framework, game-project path, or dependency on `C:\\GodotProjects\\DesktopIdleRacing`.
- Save only Contract-valid data below the `VfxAuthoringPaths.preset_root()` default `res://presets/`; temporary invalid data is allowed only inside a `VfxPresetEditSession`.
- Preserve the current Phase 0 public meanings of `load_and_validate` and `serialize_document`.
- Retain `tests/run_contract_tests.gd` as the Phase 0 suite; it must continue to pass all 121 assertions.
- Use the verified executable `C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe` for every Godot test and parse command.

## Planned file structure

```text
src/
  app/
    vfx_preset_pipeline.gd                     # existing; generic in-memory build seam
  editor/
    application/vfx_authoring_paths.gd          # authoring root path policy
    main/vfx_editor_main.tscn                   # desktop Control scene and named regions
    main/vfx_editor_main.gd                     # root Control and safe close notification
    main/vfx_editor_controller.gd               # composes services and UI event flow
    session/vfx_preset_edit_session.gd          # source path, mutable data, save baseline
    session/vfx_dirty_tracker.gd                # canonical normalized dirty comparison
    session/vfx_preset_history.gd               # deep-copy UndoRedo snapshots
    factories/vfx_preset_skeleton_factory.gd    # Schema/rule-derived editable skeletons
    factories/vfx_layer_factory.gd              # Schema-aware valid initial Layer values
    factories/vfx_structure_change_service.gd   # lifecycle/type destructive replacements
    library/vfx_preset_library_entry.gd         # one valid/invalid library row model
    library/vfx_preset_library.gd               # recursive authoring-root scan and filter
    persistence/vfx_editor_save_service.gd      # valid-only build/serialize/write orchestration
    workspace/vfx_phase_tabs.gd                 # lifecycle phase selection and duration rows
    workspace/vfx_layer_stack.gd                # active-phase Layer Stack commands and view
    inspector/vfx_schema_reader.gd              # local ref/schema property access helpers
    inspector/vfx_schema_inspector_factory.gd   # limited v1 control creation
    inspector/vfx_preset_inspector.gd           # root fields and lifecycle request events
    inspector/vfx_layer_inspector.gd            # common Layer fields and type form host
    inspector/vfx_anchor_editor.gd              # vehicle-space multi-anchor controls
    inspector/vfx_runtime_inputs_editor.gd      # x_vfx_runtime_inputs checkboxes
    diagnostics/vfx_diagnostics_navigator.gd    # JSON Pointer to editor selection routing
    diagnostics/vfx_diagnostics_panel.gd        # VfxIssue list and activation signal
    dialogs/vfx_new_preset_dialog.gd            # Schema-constrained New choices
    dialogs/vfx_unsaved_changes_dialog.gd       # Save/Discard/Cancel transition decision
    dialogs/vfx_structure_change_dialog.gd      # destructive lifecycle/type confirmation
tests/
  run_editor_tests.gd                           # Phase 1 headless runner
  editor/                                       # service/controller/scene smoke test files
```

`project.godot`, `docs/VFX_STUDIO_ARCHITECTURE.md`, and `docs/VFX_EDITOR_ROADMAP.md` change only where needed to register the editor main scene and record implemented Phase 1 boundaries. `docs/VFX_SCHEMA_V1.md` and the Schema file do not change.

## Shared interfaces

```gdscript
# src/app/vfx_preset_pipeline.gd (additive, generic)
func build_document_from_value(value: Variant, source_path: String = "") -> VfxResult

# src/editor/application/vfx_authoring_paths.gd
func preset_root() -> String
func contains_preset_path(path: String) -> bool
func default_save_path(preset_id: String) -> String
func normalize_authoring_path(path: String) -> String

# src/editor/session/vfx_preset_edit_session.gd
func begin_new(initial_data: Dictionary) -> void
func open_document(document: VfxPresetDocument) -> void
func working_copy() -> Dictionary
func replace_working_data(next_data: Dictionary) -> void
func source_path() -> String
func mark_saved(document: VfxPresetDocument) -> void
func is_dirty() -> bool

# src/editor/session/vfx_preset_history.gd
func record_snapshot(label: String, before: Dictionary, after: Dictionary, restore: Callable) -> void
func undo() -> void
func redo() -> void
func can_undo() -> bool
func can_redo() -> bool

# src/editor/factories/vfx_preset_skeleton_factory.gd
func create(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String) -> VfxResult

# src/editor/factories/vfx_layer_factory.gd
func create(layer_type: String, phase_name: String, preset_data: Dictionary) -> VfxResult
func duplicate(source_layer: Dictionary, phase_name: String, preset_data: Dictionary) -> VfxResult

# src/editor/factories/vfx_structure_change_service.gd
func replace_lifecycle(preset_data: Dictionary, target_mode: String) -> VfxResult
func replace_layer_type(preset_data: Dictionary, phase_name: String, layer_index: int, target_type: String) -> VfxResult

# src/editor/persistence/vfx_editor_save_service.gd
func save(session: VfxPresetEditSession, target_path: String) -> VfxResult

# src/model/vfx_preset_codec.gd (additive generic I/O helper)
func write_text_file(path: String, text: String) -> VfxResult

# src/editor/main/vfx_editor_controller.gd
func create_new_preset(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String) -> VfxResult
func current_issues() -> Array[VfxIssue]
```

`VfxEditorController` owns selection reconciliation, dialog orchestration, Library refresh, validation timing, and toolbar enablement. `VfxSchemaReader` receives a successfully loaded `VfxSchemaRegistry` and is the only Editor helper allowed to resolve local Schema references.

---

### Task 1: Create the editor application shell and authoring-root seam

**Files:**
- Create: `src/editor/application/vfx_authoring_paths.gd`
- Create: `src/editor/main/vfx_editor_main.tscn`
- Create: `src/editor/main/vfx_editor_main.gd`
- Create: `src/editor/main/vfx_editor_controller.gd`
- Create: `tests/editor/test_authoring_paths.gd`
- Create: `tests/editor/test_main_scene_smoke.gd`
- Create: `tests/run_editor_tests.gd`
- Modify: `project.godot`

**Interfaces:**
- Produces the `VfxAuthoringPaths` methods in the shared-interface section.
- Produces a root `VfxEditorMain` `Control` with `editor_controller` property and named `Toolbar`, `LibraryPanel`, `PhaseTabs`, `LayerStack`, `InspectorPanel`, and `DiagnosticsPanel` children.
- `tests/run_editor_tests.gd` exposes `EDITOR_TEST_ASSERTIONS=<N> FAILURES=<N>`.

- [ ] **Step 1: Write the failing path-policy and scene smoke tests**

```gdscript
var paths := VfxAuthoringPaths.new()
tests.expect_true(paths.preset_root() == "res://presets/", "authoring root has one default")
tests.expect_true(paths.contains_preset_path("res://presets/examples/talent.zero_zone.vfx.json"), "nested Preset is inside root")
tests.expect_true(not paths.contains_preset_path("res://schemas/vfx_schema_v1.json"), "Schema is not an authoring Preset")
tests.expect_true(paths.default_save_path("boost.flame") == "res://presets/boost.flame.vfx.json", "default save path is root-contained")

var packed := load("res://src/editor/main/vfx_editor_main.tscn") as PackedScene
tests.expect_true(packed != null, "editor scene loads")
var editor := packed.instantiate()
tests.expect_true(editor.get_node_or_null("Toolbar") != null, "toolbar exists")
tests.expect_true(editor.get_node_or_null("LibraryPanel") != null, "library region exists")
tests.expect_true(editor.get_node_or_null("DiagnosticsPanel") != null, "diagnostics region exists")
editor.queue_free()
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Run:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_editor_tests.gd
```

Expected: failure because the runner, path seam, and editor scene do not exist.

- [ ] **Step 3: Implement the minimal shell and central path policy**

Implement `VfxAuthoringPaths` by normalizing slash direction, comparing resource paths with the root plus separator, and building only `<root><preset_id>.vfx.json`. Build the root scene as a named Control layout with all five regions, toolbar buttons, and placeholder `FileDialog`/`ConfirmationDialog` nodes. `VfxEditorMain._notification(NOTIFICATION_WM_CLOSE_REQUEST)` delegates only to `VfxEditorController.request_close()`; the controller may initially permit close. Set `run/main_scene="res://src/editor/main/vfx_editor_main.tscn"`.

- [ ] **Step 4: Implement the smoke runner with immediate instantiation/free**

```gdscript
extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const AuthoringPathsTests := preload("res://tests/editor/test_authoring_paths.gd")
const MainSceneSmokeTests := preload("res://tests/editor/test_main_scene_smoke.gd")

func _init() -> void:
	var tests := TestAssertHelper.new()
	AuthoringPathsTests.run(tests)
	MainSceneSmokeTests.run(tests)
	print("EDITOR_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)
```

The smoke test also asserts that the typed `editor_controller` is assigned and then frees the instance without saving.

- [ ] **Step 5: Run both headless suites**

Run the Task 1 Editor runner and:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_contract_tests.gd
```

Expected: Task 1 Editor tests pass; Contract runner remains `CONTRACT_TEST_ASSERTIONS=121 FAILURES=0`.

- [ ] **Step 6: Commit the shell**

```powershell
git add project.godot src/editor/application src/editor/main tests/editor/test_authoring_paths.gd tests/editor/test_main_scene_smoke.gd tests/run_editor_tests.gd
git commit -m "feat: add VFX editor application shell"
```

### Task 2: Add mutable edit session, canonical dirty state, and safe snapshot history

**Files:**
- Create: `src/editor/session/vfx_preset_edit_session.gd`
- Create: `src/editor/session/vfx_dirty_tracker.gd`
- Create: `src/editor/session/vfx_preset_history.gd`
- Create: `tests/editor/test_edit_session.gd`
- Create: `tests/editor/test_preset_history.gd`
- Modify: `tests/run_editor_tests.gd`

**Interfaces:**
- Produces all three session/history interfaces in the shared-interface section.
- Consumes `VfxPresetCodec` only for deterministic JSON comparison; dirty comparison does not validate or mutate data.
- `VfxPresetEditSession.replace_working_data` and every history restore deep-duplicate input Dictionaries.

- [ ] **Step 1: Write failing isolation, dirty, and undo tests**

```gdscript
var session := VfxPresetEditSession.new(VfxDirtyTracker.new(VfxPresetCodec.new()))
var source := {"preset_id": "test.one", "phases": {"one_shot": {"layers": []}}}
session.begin_new(source)
source["preset_id"] = "mutated.outside"
tests.expect_true(session.working_copy()["preset_id"] == "test.one", "session owns a deep copy")
tests.expect_true(session.is_dirty(), "new unsaved session is dirty")

var restored: Dictionary = {}
var history := VfxPresetHistory.new()
var before := {"layers": [{"id": "one"}]}
var after := {"layers": [{"id": "two"}]}
history.record_snapshot("rename", before, after, func(value: Dictionary): restored = value)
after["layers"][0]["id"] = "mutated.after.record"
history.undo()
tests.expect_true(restored["layers"][0]["id"] == "one", "undo snapshot is independent")
history.redo()
tests.expect_true(restored["layers"][0]["id"] == "two", "redo snapshot is independent")
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: missing session, dirty tracker, and history classes.

- [ ] **Step 3: Implement session and deterministic dirty comparison**

Have `begin_new` set an empty `source_path`, deep-copy the editable Skeleton, and deep-copy that Skeleton as its local baseline; `is_dirty` additionally returns true when `source_path` is empty. Have `open_document` and `mark_saved` copy `document.normalized_data` into both working state and baseline, while `mark_saved` also records `document.source_path`. `VfxDirtyTracker` calls `codec.encode` for the two normalized Dictionaries and compares encoded strings; an encode failure is treated as dirty so it cannot erase a warning.

- [ ] **Step 4: Implement deep-copy Godot UndoRedo actions**

```gdscript
func record_snapshot(label: String, before: Dictionary, after: Dictionary, restore: Callable) -> void:
	var before_snapshot := before.duplicate(true)
	var after_snapshot := after.duplicate(true)
	_undo_redo.create_action(label)
	_undo_redo.add_do_method(func() -> void: restore.call(after_snapshot.duplicate(true)))
	_undo_redo.add_undo_method(func() -> void: restore.call(before_snapshot.duplicate(true)))
	_undo_redo.commit_action()
```

Implement `undo`, `redo`, `can_undo`, and `can_redo` directly on the owned `UndoRedo`. The callback passed by the controller restores data through `session.replace_working_data`, which duplicates again.

- [ ] **Step 5: Extend tests and run both suites**

Add a test that opens a real valid Pipeline document, mutates `working_data`, calls `mark_saved`, and verifies clean state only after the saved normalized baseline matches. Add a nested-array mutation after `record_snapshot` and after `undo` to prove neither stored snapshot aliases session data. Run both test runners; all existing Contract assertions remain green.

- [ ] **Step 6: Commit session services**

```powershell
git add src/editor/session tests/editor/test_edit_session.gd tests/editor/test_preset_history.gd tests/run_editor_tests.gd
git commit -m "feat: add VFX editor edit session history"
```

### Task 3: Add the generic in-memory Contract Pipeline seam

**Files:**
- Modify: `src/app/vfx_preset_pipeline.gd`
- Modify: `tests/unit/test_preset_pipeline.gd`

**Interfaces:**
- Produces `VfxPresetPipeline.build_document_from_value(value: Variant, source_path: String = "") -> VfxResult`.
- Preserves `load_and_validate(path)` as decode-file then `build_document_from_value(decoded.value, path)`.
- Does not add `validate_working_copy`, `save_working_copy`, or any Editor-specific member to the Pipeline.

- [ ] **Step 1: Write failing generic build tests**

```gdscript
var codec := VfxPresetCodecModel.new()
var pipeline := VfxPresetPipelineModel.new()
var raw := codec.decode_file("res://tests/fixtures/valid/zero_zone.vfx.json").value
var built := pipeline.build_document_from_value(raw, "memory://zero_zone")
tests.expect_true(built.success, "in-memory valid value builds a document")
tests.expect_true(built.value.source_path == "memory://zero_zone", "generic build preserves supplied source path")
tests.expect_true(not raw["phases"]["loop"]["layers"][0].has("sort_order"), "generic build leaves raw value untouched")
var invalid := pipeline.build_document_from_value({"schema_version": 1}, "memory://invalid")
tests.expect_true(not invalid.success, "generic build reports Contract errors")
```

- [ ] **Step 2: Run the Contract runner and verify it fails**

Expected: `Invalid call. Nonexistent function 'build_document_from_value'`.

- [ ] **Step 3: Implement the reusable build boundary**

Move the existing ensure-Schema, normalize, validate, and `VfxPresetDocument.new(source_path, raw_value, normalized_value)` sequence into `build_document_from_value`. `load_and_validate` retains its decode error behavior and result classes. Do not write files or inspect editor state in this method.

- [ ] **Step 4: Verify deterministic serialize semantics remain unchanged**

Add a test that builds from a valid in-memory Variant, then calls `serialize_document`; decode its result and compare a second deterministic `codec.encode`. Keep the existing changed-document revalidation test. Run the Contract and Editor runners.

- [ ] **Step 5: Commit the generic Pipeline seam**

```powershell
git add src/app/vfx_preset_pipeline.gd tests/unit/test_preset_pipeline.gd
git commit -m "feat: build VFX documents from in-memory values"
```

### Task 4: Implement Schema-aware Skeleton, Layer, and structural-change factories

**Files:**
- Create: `src/editor/factories/vfx_preset_skeleton_factory.gd`
- Create: `src/editor/factories/vfx_layer_factory.gd`
- Create: `src/editor/factories/vfx_structure_change_service.gd`
- Create: `tests/editor/test_preset_skeleton_factory.gd`
- Create: `tests/editor/test_layer_factory.gd`
- Create: `tests/editor/test_structure_change_service.gd`
- Modify: `tests/run_editor_tests.gd`

**Interfaces:**
- Consumes a loaded `VfxSchemaRegistry` plus its local-ref resolver; it reads lifecycle phase names from `x_vfx_rules`, types from `x_vfx_layer_types`, and enum/default/range data from the Schema.
- Produces only mutable Dictionaries. The controller later validates them through `VfxPresetPipeline.build_document_from_value`.
- Produces `VfxStructureChangeService`, not `VfxLifecycleChangeService`, because it owns both lifecycle and Layer Type replacement.

- [ ] **Step 1: Write failing Skeleton and Layer creation tests**

```gdscript
var one_shot := skeleton_factory.create("utility.flash", "Flash", "UTILITY", "ONE_SHOT", "WORLD_AREA")
tests.expect_true(one_shot.success, "one-shot Skeleton is created")
tests.expect_true(one_shot.value["phases"]["one_shot"]["layers"].is_empty(), "new Skeleton has no hidden Layer")
tests.expect_true(not pipeline.build_document_from_value(one_shot.value).success, "empty Skeleton is transient-invalid")

var added := layer_factory.create("PARTICLE", "one_shot", one_shot.value)
tests.expect_true(added.success, "Particle factory creates a Layer")
tests.expect_true(added.value["parameters"]["sprite_asset_ref"] == "fx.placeholder", "Particle factory owns explicit asset initial value")
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: missing factory classes.

- [ ] **Step 3: Implement lifecycle Skeleton generation and distinct factory values**

Resolve the `LIFECYCLE_PHASE_STRUCTURE` configuration; add only phases listed for the selected mode. Add `{layers: []}` to all phases and an explicit valid `duration_seconds` only to phase schemas that require it. Select `schema_version` from the Schema enum and do not put a default Layer in any phase. Store required-without-default creation values in one private, documented factory helper that uses each Schema `minimum` where available; it is not a GDScript copy of Schema defaults or enum/range lists.

- [ ] **Step 4: Implement valid initial Layer creation, duplication, and ids**

Resolve the selected type through `x_vfx_layer_types` and its parameter `$ref`, normalize all Schema defaults, and supply only required missing values. Choose required enum values by reading their Schema enum; derive the allowed render plane from `RENDER_PLANE_FOR_EFFECTIVE_SPACE`; when effective space is vehicle-local/trail, choose Schema Anchor `CENTER`; omit `space_mode` so the initial Layer inherits the Preset default. Use `fx.placeholder` only in initial Particle/Trail/Shield asset fields. Generate ids from lowercase `phase_name.layer_type`, then suffix `_2`, `_3`, and so on after scanning all phase Layer ids. `duplicate` deep-copies the source, creates a unique id, and leaves every other common/type field intact.

- [ ] **Step 5: Implement destructive replacements and test their data policy**

```gdscript
var lifecycle_change := service.replace_lifecycle(valid_start_loop_end, "ONE_SHOT")
tests.expect_true(lifecycle_change.value["phases"].keys() == ["one_shot"], "lifecycle replacement discards old stacks")
var type_change := service.replace_layer_type(valid_with_glow, "one_shot", 0, "RING")
tests.expect_true(type_change.value["phases"]["one_shot"]["layers"][0]["id"] == "one_shot.glow", "type replacement retains Layer id")
tests.expect_true(type_change.value["phases"]["one_shot"]["layers"][0]["type"] == "RING", "type replacement changes type")
```

Preserve root fields on lifecycle replacement. Preserve all common Layer fields and replace only `type`/`parameters` on type replacement. Validate resulting add/duplicate/type-replacement data with `build_document_from_value`; assert the empty lifecycle replacement remains invalid only because it has no Layers.

- [ ] **Step 6: Run both suites and commit factories**

```powershell
git add src/editor/factories tests/editor/test_preset_skeleton_factory.gd tests/editor/test_layer_factory.gd tests/editor/test_structure_change_service.gd tests/run_editor_tests.gd
git commit -m "feat: add schema-aware VFX authoring factories"
```

Run the Contract and Editor runners before committing; expected: all factory and existing Contract assertions pass.

### Task 5: Add the Preset Library and valid-only New/Open/Save/Save As flow

**Files:**
- Create: `src/editor/library/vfx_preset_library_entry.gd`
- Create: `src/editor/library/vfx_preset_library.gd`
- Create: `src/editor/persistence/vfx_editor_save_service.gd`
- Create: `src/editor/dialogs/vfx_new_preset_dialog.gd`
- Create: `tests/editor/test_preset_library.gd`
- Create: `tests/editor/test_editor_save_service.gd`
- Modify: `src/editor/main/vfx_editor_main.tscn`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Modify: `tests/run_editor_tests.gd`

**Interfaces:**
- `VfxPresetLibrary.scan() -> Array[VfxPresetLibraryEntry]`, `filter(query: String, category: String) -> Array[VfxPresetLibraryEntry]`.
- `VfxPresetLibraryEntry` exposes `source_path`, `display_name`, `preset_id`, `category`, `document`, and `issues`; only an entry with a non-null `document` is openable.
- `VfxEditorSaveService.save` consumes `VfxPresetPipeline`, `VfxPresetCodec`, and `VfxAuthoringPaths`, builds a document, serializes through Pipeline, writes the serialized text, then marks the session saved.

- [ ] **Step 1: Write failing root-scan and save-block tests**

```gdscript
DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://presets/_phase1_library_test"))
var invalid_path := "res://presets/_phase1_library_test/invalid.vfx.json"
VfxPresetCodec.new().write_text_file(invalid_path, "{\"schema_version\": 1}")
var entries := library.scan()
tests.expect_true(entries.any(func(entry): return entry.preset_id == "talent.zero_zone" and entry.document != null), "valid example appears in library")
tests.expect_true(entries.any(func(entry): return entry.source_path == invalid_path and not entry.issues.is_empty()), "invalid file becomes an error row")

var result := save_service.save(empty_new_session, paths.default_save_path("utility.empty"))
tests.expect_true(not result.success, "empty transient-invalid Skeleton cannot save")
tests.expect_true(not FileAccess.file_exists(paths.default_save_path("utility.empty")), "invalid save performs no write")
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: missing Library and save service classes.

- [ ] **Step 3: Implement recursive Library scan and narrow filtering**

Scan only `VfxAuthoringPaths.preset_root()` recursively for filenames ending `.vfx.json`; call `pipeline.load_and_validate` for each candidate. Build a valid entry from `VfxPresetDocument.normalized_data`; build a non-openable error entry from returned issues. Sort valid rows deterministically by display name then id, retain invalid rows with an error state, and use case-insensitive display/id substring plus exact Schema category filter. Do not scan schemas, assets, generated files, or external paths.

- [ ] **Step 4: Implement session transitions and valid-only Save**

Wire New dialog choices from schema-derived category/lifecycle/space options, then call `VfxPresetSkeletonFactory.create` and `session.begin_new`. Open accepts only a valid Library entry or an authoring-root FileDialog selection that `pipeline.load_and_validate` accepts. Save selects `session.source_path()` when present; otherwise invokes Save As. Save As rejects an outside-root or non-`.vfx.json` path, confirms overwrite, then calls `save_service.save`.

`save_service.save` calls `pipeline.build_document_from_value(session.working_copy(), target_path)`, stops and returns its issues on failure, calls `pipeline.serialize_document(document)`, calls a Codec `write_text_file(path, serialized_text)` helper, and only then `session.mark_saved(document)`. Add `VfxPresetCodec.write_text_file` as generic raw-text I/O and preserve existing `write_file` behavior by delegating to it after encoding. No invalid session data reaches a write call.

- [ ] **Step 5: Add valid save, normalized reload, and error-row tests**

Save a valid created Preset into a temporary child directory below `res://presets/` created by the test, reload it through Pipeline, compare normalized data, then remove only that exact test file/directory in teardown. Create the focused invalid test file under that same root before scan and remove it in teardown. Verify Save As outside `res://presets/` returns `EDITOR_POLICY/outside_authoring_root` without writing. Verify invalid Library entries do not expose a document or open action. Run both runners.

- [ ] **Step 6: Commit Library and persistence**

```powershell
git add src/editor/library src/editor/persistence src/editor/dialogs/vfx_new_preset_dialog.gd src/editor/main src/model/vfx_preset_codec.gd tests/editor/test_preset_library.gd tests/editor/test_editor_save_service.gd tests/run_editor_tests.gd
git commit -m "feat: add VFX preset library persistence"
```

### Task 6: Implement phase tabs and active-phase Layer Stack commands

**Files:**
- Create: `src/editor/workspace/vfx_phase_tabs.gd`
- Create: `src/editor/workspace/vfx_layer_stack.gd`
- Create: `tests/editor/test_phase_tabs.gd`
- Create: `tests/editor/test_layer_stack.gd`
- Modify: `src/editor/main/vfx_editor_main.tscn`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Modify: `tests/run_editor_tests.gd`

**Interfaces:**
- `VfxPhaseTabs.set_preset(preset: Dictionary)`, `select_phase(phase_name: String)`, and `phase_selected(phase_name: String)` signal.
- `VfxLayerStack.set_phase(preset: Dictionary, phase_name: String)`, `layer_selected(layer_id: String)`, and command-request signals for add/delete/duplicate/move/toggle.
- The controller applies each command through `VfxPresetHistory.record_snapshot` and then validates/reconciles selection.

- [ ] **Step 1: Write failing phase availability and stack mutation tests**

```gdscript
tabs.set_preset(one_shot_data)
tests.expect_true(tabs.visible_phase_names() == ["one_shot"], "one-shot exposes one tab")
tabs.set_preset(start_loop_end_data)
tests.expect_true(tabs.visible_phase_names() == ["start", "loop", "end"], "start-loop-end exposes configured tabs")
tests.expect_true(not tabs.phase_has_duration("loop"), "loop has no duration control")

var moved := layer_stack.move_layer(data, "loop", 1, -1)
tests.expect_true(moved["phases"]["loop"]["layers"][0]["id"] == "loop.second", "move up changes only active phase order")
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: missing phase and Layer Stack scripts.

- [ ] **Step 3: Implement lifecycle-aware tab and duration rendering**

Read the current Preset's actual phase keys after it has been created by the Schema-aware Skeleton/Lifecycle factory. Render duration controls for `one_shot`, `start`, and `end` only; never create a Loop duration field. Selecting an absent phase is ignored and selection falls back to the first available configured phase.

- [ ] **Step 4: Implement Layer Stack commands as immutable input/output helpers plus UI events**

Implement `add_layer`, `delete_layer`, `duplicate_layer`, `move_layer`, and `set_layer_enabled` to return a deep-copied next Preset Dictionary. Add calls `VfxLayerFactory.create`; duplicate calls its `duplicate`; move clamps to legal neighboring indexes; delete removes exactly one active-phase item; enabled toggles only the requested Layer. The UI emits requests but does not edit arrays by reference.

- [ ] **Step 5: Connect controller history, selection, and validation**

For each request, deep-copy before/after, record one named history action, replace session state, run Pipeline validation, and call `reconcile_selection`. Test that deleting a selected Layer clears selection, then Undo restores data without retaining a stale id; test that duplicate receives an id unique across phases. Run both suites.

- [ ] **Step 6: Commit the workspace stack**

```powershell
git add src/editor/workspace src/editor/main tests/editor/test_phase_tabs.gd tests/editor/test_layer_stack.gd tests/run_editor_tests.gd
git commit -m "feat: add phase-aware VFX layer stack"
```

### Task 7: Implement Preset and common Layer Inspector editing

**Files:**
- Create: `src/editor/inspector/vfx_schema_reader.gd`
- Create: `src/editor/inspector/vfx_preset_inspector.gd`
- Create: `src/editor/inspector/vfx_layer_inspector.gd`
- Create: `tests/editor/test_schema_reader.gd`
- Create: `tests/editor/test_common_inspectors.gd`
- Modify: `src/editor/main/vfx_editor_main.tscn`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Modify: `tests/run_editor_tests.gd`

**Interfaces:**
- `VfxSchemaReader.resolve(schema_or_ref: Dictionary) -> VfxResult`, `property_schema(object_schema, property_name) -> VfxResult`, `enum_values(schema_or_ref: Dictionary) -> Array`, `default_value(schema_or_ref: Dictionary) -> Variant`.
- Preset Inspector emits `preset_field_commit(json_pointer: String, value: Variant)` and `lifecycle_change_requested(target_mode: String)`.
- Layer Inspector emits `layer_field_commit(json_pointer: String, value: Variant)`, `space_override_changed(mode_or_inherit: String)`, and `layer_type_change_requested(target_type: String)`.

- [ ] **Step 1: Write failing Schema-reader and inherit-mode tests**

```gdscript
var category_values := reader.enum_values(reader.property_schema(root_schema, "category").value)
tests.expect_true(category_values.has("UTILITY"), "category options come from Schema")
var particle_schema := reader.layer_parameter_schema("PARTICLE")
tests.expect_true(particle_schema.success, "type parameters resolve through x_vfx_layer_types")

var next := layer_inspector.apply_space_override(layer_without_override, "INHERIT_DEFAULT")
tests.expect_true(not next.has("space_mode"), "inherit removes Layer override")
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: missing Schema reader and inspector scripts.

- [ ] **Step 3: Implement read-only Schema helpers and root Inspector**

Construct the reader with a loaded `VfxSchemaRegistry`; resolve only supported local `$defs` through that Registry. Populate id, display name, category, lifecycle, and default-space UI from root properties. A lifecycle choice emits a request instead of mutating the Preset. Use Schema min/max for numeric control limits and Schema enum values for `OptionButton` entries; do not declare manual options arrays.

- [ ] **Step 4: Implement common Layer Inspector**

Populate id, importance, blend mode, render plane, sort order, enabled, transform, selected type, and the space override state. Display `INHERIT DEFAULT` when `space_mode` is absent; write an explicit selected override and remove `space_mode` when returning to inherit. Do not edit `parameters` in this task. Every committed control sends one proposed deep-copied value to the controller, which records one history action and validates after commit, not on each keystroke.

- [ ] **Step 5: Add controller commit tests and run both suites**

Assert root enum controls receive entries from an in-memory modified Schema fixture rather than a hard-coded UI list. Assert a numeric control exposes its Schema range and one focus-commit yields exactly one undo action. Assert unset Layer space remains absent after a refresh. Run both runners.

- [ ] **Step 6: Commit common Inspector support**

```powershell
git add src/editor/inspector/vfx_schema_reader.gd src/editor/inspector/vfx_preset_inspector.gd src/editor/inspector/vfx_layer_inspector.gd src/editor/main tests/editor/test_schema_reader.gd tests/editor/test_common_inspectors.gd tests/run_editor_tests.gd
git commit -m "feat: add schema-aware VFX common inspectors"
```

### Task 8: Add limited type-specific Schema Inspector forms

**Files:**
- Create: `src/editor/inspector/vfx_schema_inspector_factory.gd`
- Create: `tests/editor/test_schema_inspector_factory.gd`
- Modify: `src/editor/inspector/vfx_layer_inspector.gd`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Modify: `tests/run_editor_tests.gd`

**Interfaces:**
- `VfxSchemaInspectorFactory.build_fields(schema: Dictionary, value: Dictionary) -> Array[Control]`.
- `field_committed(json_pointer_suffix: String, value: Variant)` signal from each generated field.
- Supports only v1 scalar, enum, bool, Vector2, RGBA, and documented nested-object shapes; unsupported Schema nodes return a visible configuration diagnostic, not a fallback raw JSON editor.

- [ ] **Step 1: Write failing generated-form tests for every Layer Type**

```gdscript
for layer_type in ["PARTICLE", "TRAIL", "RING", "GLOW", "SHIELD"]:
	var fields := factory.build_fields(reader.layer_parameter_schema(layer_type).value, {})
	tests.expect_true(not fields.is_empty(), "%s has Schema-generated fields" % layer_type)
tests.expect_true(factory.control_kind_for({"type": "number", "minimum": 0.0, "maximum": 1.0}) == "SpinBox", "number range uses SpinBox")
tests.expect_true(factory.control_kind_for({"type": "array", "minItems": 4, "maxItems": 4, "items": {"type": "number"}}) == "RGBA", "four-number vector uses RGBA row")
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: missing type-specific Inspector factory.

- [ ] **Step 3: Implement the deliberate v1 form subset**

Map `enum` to `OptionButton`, bounded/unbounded numbers and integers to `SpinBox`, booleans to `CheckBox`, strings to `LineEdit`, two-number arrays to a Vector2 row, four-number arrays to an RGBA row, and Schema objects to labelled nested groups. Resolve `$ref` before control choice. Exclude fields which the current semantic rule makes structurally illegal: for Particle, rebuilding the form after `emission_mode` changes exposes only the configured fields for BURST versus CONTINUOUS, and after emitter shape changes exposes only configured geometry fields. This is rule-aware v1 presentation, not a generic expression evaluator.

- [ ] **Step 4: Integrate field commits with normalization and validation**

On a valid field commit, update the chosen `parameters` pointer in a deep-copied session Dictionary, normalize by calling `pipeline.build_document_from_value`, and retain the edited working data plus diagnostics if it remains structurally/semantically invalid during a commit. The normalizer's Schema defaults ensure optional defaults are present after a successful normal build; the controller never inserts a parallel defaults table. Rebuild the current type form after emission/shape selector commits.

- [ ] **Step 5: Add parameter validity and type-replacement confirmation tests**

Assert type factory values lead to a valid Pipeline document after a Layer exists. Assert Particle BURST UI drops continuous-only controls and CONTINUOUS UI drops `burst_count`. Assert a requested Layer Type change creates no history action until the destructive confirmation resolves `Confirm`, then produces one undoable snapshot. Run both runners.

- [ ] **Step 6: Commit type-specific forms**

```powershell
git add src/editor/inspector/vfx_schema_inspector_factory.gd src/editor/inspector/vfx_layer_inspector.gd src/editor/main/vfx_editor_controller.gd tests/editor/test_schema_inspector_factory.gd tests/run_editor_tests.gd
git commit -m "feat: add VFX type-specific schema inspectors"
```

### Task 9: Add Anchor multi-select and Runtime Input declaration controls

**Files:**
- Create: `src/editor/inspector/vfx_anchor_editor.gd`
- Create: `src/editor/inspector/vfx_runtime_inputs_editor.gd`
- Create: `tests/editor/test_anchor_editor.gd`
- Create: `tests/editor/test_runtime_inputs_editor.gd`
- Modify: `src/editor/inspector/vfx_layer_inspector.gd`
- Modify: `src/editor/inspector/vfx_preset_inspector.gd`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Modify: `tests/run_editor_tests.gd`

**Interfaces:**
- Anchor editor emits `anchors_committed(anchors: Array)` only in vehicle spaces and `anchors_cleared()` when non-vehicle space is selected.
- Runtime Input editor emits `runtime_inputs_committed(inputs: Array[String])` based on the Schema root `x_vfx_runtime_inputs` keys.

- [ ] **Step 1: Write failing space and Runtime Input tests**

```gdscript
anchor_editor.set_effective_space("VEHICLE_LOCAL")
tests.expect_true(anchor_editor.is_visible(), "vehicle space shows Anchors")
anchor_editor.commit_selection(["CENTER", "TIRE_RL"])
tests.expect_true(anchor_editor.selected_anchors() == ["CENTER", "TIRE_RL"], "multiple Anchors are retained")
anchor_editor.set_effective_space("WORLD_AREA")
tests.expect_true(not anchor_editor.is_visible(), "world space hides Anchors")
tests.expect_true(anchor_editor.selected_anchors().is_empty(), "world space clears Anchors")

runtime_editor.set_schema(schema)
tests.expect_true(runtime_editor.available_inputs().has("intensity"), "Runtime Inputs come from Schema")
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: missing Anchor and Runtime Input editor scripts.

- [ ] **Step 3: Implement Schema-driven multi-anchor and input selection**

Read Anchors from `$defs.anchor.enum`; read vehicle spaces from `EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS.vehicle_space_modes`; read Runtime Inputs from `x_vfx_runtime_inputs` keys. For vehicle space, require the user selection emitter to retain at least one Anchor in normal Layer editing. For world/screen effective space, hide/disable the Anchor controls and make the controller remove the `anchors` property in the same common-property commit that changes effective space. Never define a second Anchor or Runtime Input list in code.

- [ ] **Step 4: Integrate controller mutation/history/validation**

Apply a committed Anchors array or Runtime Input declaration list as one deep-copied history mutation, run Pipeline validation, and refresh diagnostics. Preserve Runtime Input order deterministically according to Schema key order. Do not add a binding field or gameplay configuration.

- [ ] **Step 5: Add Contract-oriented tests and run both suites**

Assert a vehicle Layer without Anchors produces the existing `vehicle_anchor_required` issue after commit. Assert changing to `WORLD_AREA` removes Anchors and selects a Schema-permitted render plane before validation. Assert unknown Runtime Input names cannot be selected by UI and a manually injected unknown value is still reported by Pipeline. Run both runners.

- [ ] **Step 6: Commit Anchors and Runtime Inputs**

```powershell
git add src/editor/inspector/vfx_anchor_editor.gd src/editor/inspector/vfx_runtime_inputs_editor.gd src/editor/inspector/vfx_layer_inspector.gd src/editor/inspector/vfx_preset_inspector.gd src/editor/main/vfx_editor_controller.gd tests/editor/test_anchor_editor.gd tests/editor/test_runtime_inputs_editor.gd tests/run_editor_tests.gd
git commit -m "feat: add VFX anchor and runtime input controls"
```

### Task 10: Add structured diagnostics, navigation, and unsafe-transition dialogs

**Files:**
- Create: `src/editor/diagnostics/vfx_diagnostics_panel.gd`
- Create: `src/editor/diagnostics/vfx_diagnostics_navigator.gd`
- Create: `src/editor/dialogs/vfx_unsaved_changes_dialog.gd`
- Create: `src/editor/dialogs/vfx_structure_change_dialog.gd`
- Create: `tests/editor/test_diagnostics_navigator.gd`
- Create: `tests/editor/test_transition_dialogs.gd`
- Modify: `src/editor/main/vfx_editor_main.tscn`
- Modify: `src/editor/main/vfx_editor_main.gd`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Modify: `tests/run_editor_tests.gd`

**Interfaces:**
- `VfxDiagnosticsPanel.set_issues(issues: Array[VfxIssue])` and `issue_activated(issue: VfxIssue)` signal.
- `VfxDiagnosticsNavigator.navigate(issue: VfxIssue, preset: Dictionary) -> Dictionary` returns `{handled, phase_name, layer_id, json_pointer}`.
- `VfxUnsavedChangesDialog.request(action_name: String) -> void` and `decision(decision_name: String)` signal where names are `SAVE`, `DISCARD`, `CANCEL`.
- `VfxStructureChangeDialog.request(kind: String, label: String) -> void` and `confirmed()` signal.

- [ ] **Step 1: Write failing JSON Pointer routing and transition tests**

```gdscript
var issue := VfxIssue.new("PRESET_VALIDATION", "required", "missing", "/phases/loop/layers/1/parameters/radius")
var route := navigator.navigate(issue, preset)
tests.expect_true(route["handled"], "Layer parameter pointer is navigable")
tests.expect_true(route["phase_name"] == "loop", "navigator selects phase")
tests.expect_true(route["layer_id"] == "loop.glow_2", "navigator resolves Layer id from array index")

unsaved_dialog.request("Open")
unsaved_dialog.emit_decision("CANCEL")
tests.expect_true(not controller.transition_performed(), "cancel leaves session untouched")
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: missing diagnostics/navigation and dialog scripts.

- [ ] **Step 3: Implement issue display and safe pointer navigation**

Show severity, kind, code, message, pointer, source path, line, and column in the panel. Route `/preset_id`, `/display_name`, `/category`, `/lifecycle`, `/default_space_mode`, and `/runtime_inputs` to root Inspector. Route phase/layer paths by parsing escaped pointer segments, range-checking each index, and resolving that Layer's current id. For configuration issues, invalid indexes, or unsupported pointers, return `{handled: false}` and keep the issue visible rather than guessing a target.

- [ ] **Step 4: Implement validation timing and transition orchestration**

Call `refresh_validation` after load, New Skeleton creation, structural commands, completed common/type/anchor/runtime field commit, explicit Validate, Undo, Redo, and before Save. Do not call it for every `LineEdit.text_changed`. If dirty, New/Open/close/quit requests show Save/Discard/Cancel. `SAVE` succeeds only if `VfxEditorSaveService.save` succeeds, then continues; failed save focuses Diagnostics and cancels transition. Lifecycle and Layer Type changes show the structure dialog before factory replacement and record no action on cancellation.

- [ ] **Step 5: Add transient-invalid and selection reconciliation tests**

Assert a New empty Skeleton displays `preset_has_no_layers` in the diagnostics panel and Save leaves it open. Assert adding a valid Layer removes that issue. Assert Undo after deleting the selected Layer clears stale selection; Redo and subsequent navigation still select by current Layer id. Assert `Cancel` in New/Open/close and type/lifecycle confirmations creates no write and no history entry. Run both runners.

- [ ] **Step 6: Commit diagnostics and dialogs**

```powershell
git add src/editor/diagnostics src/editor/dialogs src/editor/main src/editor/workspace src/editor/inspector tests/editor/test_diagnostics_navigator.gd tests/editor/test_transition_dialogs.gd tests/run_editor_tests.gd
git commit -m "feat: add VFX editor diagnostics and safe transitions"
```

### Task 11: Integrate the full editor, execute smoke coverage, and document the result

**Files:**
- Modify: `src/editor/main/vfx_editor_main.tscn`
- Modify: `src/editor/main/vfx_editor_main.gd`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Modify: `tests/editor/test_main_scene_smoke.gd`
- Modify: `tests/run_editor_tests.gd`
- Modify: `docs/VFX_STUDIO_ARCHITECTURE.md`
- Modify: `docs/VFX_EDITOR_ROADMAP.md`

**Interfaces:**
- Composes all prior services through `VfxEditorController` with one `VfxAuthoringPaths` instance.
- Main scene smoke verifies all named children, a controller instance, required toolbar signal connections, an initialized Schema registry/Pipeline, and immediate `queue_free` without parser/runtime errors.

- [ ] **Step 1: Write failing end-to-end controller smoke tests**

```gdscript
var editor := (load("res://src/editor/main/vfx_editor_main.tscn") as PackedScene).instantiate()
tests.expect_true(editor.editor_controller != null, "main scene composes controller")
var save_button := editor.get_node("Toolbar/SaveButton")
tests.expect_true(save_button.is_connected("pressed", Callable(editor.editor_controller, "_on_save_pressed")), "Save is connected")
editor.editor_controller.create_new_preset("utility.empty", "Empty", "UTILITY", "ONE_SHOT", "WORLD_AREA")
tests.expect_true(editor.editor_controller.current_issues().any(func(issue): return issue.code == "preset_has_no_layers"), "new session reports transient-invalid error")
editor.queue_free()
```

- [ ] **Step 2: Run the Editor runner and verify it fails**

Expected: at least one unintegrated controller signal or smoke helper fails before final composition.

- [ ] **Step 3: Compose one controller-owned application flow**

Instantiate one Pipeline, one loaded read-only Schema Registry/reader, paths, session, history, factories, Library, save service, diagnostics navigator, and controls. Make toolbar enablement derive from session/history state. Ensure all UI signals use named controller methods; `create_new_preset` is the production method used by the New dialog and the smoke test. Reconcile selection after every data replacement. Do not add Preview, rendering, export, or game-path access.

- [ ] **Step 4: Complete and execute headless scene smoke coverage**

Extend the smoke test to instantiate/free the scene twice, verify core signal connections with `is_connected`, run `create_new_preset`, request a transient-invalid Save, and assert no authoring file was written. It must then free the scene in the same process. This remains structural smoke coverage only; do not introduce screenshots or pixel assertions.

- [ ] **Step 5: Run final verification commands and inspect documentation**

Run exactly:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_contract_tests.gd
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script res://tests/run_editor_tests.gd
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --editor --quit
```

Expected: Phase 0 reports exactly `CONTRACT_TEST_ASSERTIONS=121 FAILURES=0`; Editor tests report zero failures; Godot parse exits `0`. Update architecture/roadmap prose to state the shipped Phase 1 editor boundary and keep every excluded future phase excluded.

- [ ] **Step 6: Perform manual non-renderer smoke and commit**

In a short Godot editor run, create an empty New Preset, observe its no-layer diagnostic, add one Layer, change a common field, Undo/Redo, Save As under `res://presets/`, reopen it, and discard an unsaved subsequent change. Do not perform Windows export or extended soak testing. Then commit:

```powershell
git add project.godot src tests docs
git commit -m "feat: complete VFX Studio Phase 1 editor"
```

## Plan self-review

- **Specification coverage:** Tasks 1-11 cover authoring-root policy, app shell, session/dirty/history, the generic Pipeline seam, editable transient-invalid Skeletons, schema-aware factories, Library and valid-only persistence, phase/layer commands, common/type-specific forms, Anchors/Runtime Inputs, diagnostics/navigation/dialogs, and final smoke coverage.
- **Transient-invalid policy:** Task 4 creates empty Skeletons, Task 5 blocks write, and Task 10 proves the existing no-layer issue is shown and cleared after Layer addition. No placeholder Layer is ever generated.
- **Contract drift prevention:** Task 3 adds only a generic in-memory Pipeline API. Tasks 4, 7, 8, and 9 use Registry/Schema values rather than duplicated GDScript enum/default lists.
- **Snapshot safety:** Task 2 mandates deep copies at registration and restoration; Tasks 6 and 10 cover selection reconciliation after a deleted/restored Layer.
- **Test order:** Every Task starts with a focused failing test, implements only the required minimal behavior, then runs the new Editor runner plus the unmodified Contract runner before its commit.
- **Placeholder scan:** This plan has no unspecified future implementation steps; every Task names concrete source/test files, public interfaces, expected failure, verification, and commit command.
