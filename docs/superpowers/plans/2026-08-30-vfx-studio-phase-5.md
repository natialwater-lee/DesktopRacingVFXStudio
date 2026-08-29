# DesktopRacingVFXStudio Phase 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Export a saved, contract-valid Studio Preset as a deterministic,
self-contained portable VFX Package without coupling the Studio to the game
repository.

**Architecture:** VfxExportService reloads a saved Preset through the existing
Pipeline, compiles raw authoring and normalized runtime representations into an
immutable VfxExportPackagePlan, and gives that Plan to an atomic Writer. A
fail-closed Export Asset Registry and Preset policy are separate from Preview
assets. The runtime-created Workspace gets a compact Export panel.

**Tech Stack:** Godot 4.7.1 stable, standard GDScript, existing VfxResult,
VfxIssue, VfxPresetPipeline, JSON, HashingContext.HASH_SHA256, FileAccess, and
DirAccess.

**Spec:** docs/superpowers/specs/2026-08-30-vfx-studio-phase-5-design.md

## Global Constraints

- Keep schemas/vfx_schema_v1.json unchanged. No VFX Schema field, enum,
  default, lifecycle, or semantic-rule changes are permitted.
- Export only a saved authoring path reloaded and validated by the existing
  Pipeline. Never export an Editor working copy, Preview state, or Render Plan.
- Keep Studio -> Package -> DesktopIdleRacing importer/runtime one-way. Never
  access C:\GodotProjects\DesktopIdleRacing.
- Package data contains no absolute, res://, or user:// Studio path; Preview
  implementation; shader; scene; Profile; or Performance/Stress data.
- Production assets are fail-closed. Each referenced logical asset must be
  explicitly EXPORTABLE in the Export Asset Registry.
- Use res://exports/packages/ only. Ignore exports/.staging/ and
  exports/.backup/. Do not modify project.godot or
  src/editor/main/vfx_editor_main.tscn.
- Do not run git add or git commit. Keep all implementation and Package changes
  unstaged for SourceTree.
- Run focused Export tests during Tasks A-C. Run all suites and a Godot editor
  parse once in Task D. Do not produce a Windows Export.

---

## Planned file structure

- config/vfx_export_asset_policy_v1.json — explicit production asset policy.
- config/vfx_export_preset_policy_v1.json — Preset-specific eligibility.
- src/export/vfx_export_paths.gd — output roots and path safety.
- src/export/vfx_export_asset_registry.gd — fail-closed asset policy loader.
- src/export/vfx_export_preset_policy.gd — Studio-only Preset policy.
- src/export/vfx_export_requirement_deriver.gd — Schema-derived requirements.
- src/export/vfx_export_package_plan.gd — immutable Package inventory.
- src/export/vfx_export_hasher.gd — SHA-256 and byte size metadata.
- src/export/vfx_export_compiler.gd — Source, Runtime, Manifest compilation.
- src/export/vfx_export_file_backend.gd — testable filesystem seam.
- src/export/vfx_atomic_package_writer.gd — staging, replace, rollback.
- src/export/vfx_export_service.gd — saved-source orchestrator.
- src/editor/export/vfx_export_panel.gd — validation and result UI.
- tests/export/test_export_contract_and_assets.gd — policy/derivation tests.
- tests/export/test_export_compiler_and_writer.gd — Package/atomic tests.
- tests/export/test_export_ui.gd — Editor bridge and panel tests.
- tests/run_export_tests.gd — dedicated headless runner.
- docs/VFX_EXPORT_PACKAGE_V1.md — importer-facing contract.

### Task A: Export Contract and Asset Policy

**Files:**
- Create: config/vfx_export_asset_policy_v1.json
- Create: config/vfx_export_preset_policy_v1.json
- Create: src/export/vfx_export_paths.gd
- Create: src/export/vfx_export_asset_registry.gd
- Create: src/export/vfx_export_preset_policy.gd
- Create: src/export/vfx_export_requirement_deriver.gd
- Create: src/export/vfx_export_package_plan.gd
- Create: tests/export/test_export_contract_and_assets.gd
- Create: tests/run_export_tests.gd

**Interfaces:**

~~~gdscript
class_name VfxExportPaths
extends RefCounted

const PACKAGE_ROOT := "res://exports/packages/"
const STAGING_ROOT := "res://exports/.staging/"
const BACKUP_ROOT := "res://exports/.backup/"

func package_path_for(preset_id: String) -> VfxResult
func is_safe_package_relative_path(path: String) -> bool
~~~

~~~gdscript
class_name VfxExportAssetRegistry
extends RefCounted

func load() -> VfxResult
func resolve_exportable(logical_id: String) -> VfxResult
~~~

~~~gdscript
class_name VfxExportRequirementDeriver
extends RefCounted

func derive(document: VfxPresetDocument) -> VfxResult
# value = {
#   "required_vehicle_anchors": Array[String],
#   "runtime_inputs": Array[Dictionary],
#   "importance_summary": Dictionary,
#   "asset_logical_ids": Array[String]
# }
~~~

- [ ] **Step 1: Write failing contract tests**

Create the Export runner and import the contract test. Assert that
fx.energy_shard and fx.energy_spark resolve as EXPORTABLE. Assert that an absent
logical ID, fx.preview_texture_fixture, and fx.trail_streak return a failed
result. Load Zero Zone through VfxPresetPipeline and assert that requirements
are CENTER; intensity; asset IDs fx.energy_shard then fx.energy_spark; and
Importance counts CORE 3, DETAIL 6, EXTRA 2. Assert that
utility.renderer_showcase is rejected by Preset policy.

- [ ] **Step 2: Run the focused runner and verify red**

Run:

~~~powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_export_tests.gd'
~~~

Expected: missing Export class or runner import failures.

- [ ] **Step 3: Implement policy and derivation**

Add only fx.energy_shard and fx.energy_spark as EXPORTABLE TEXTURE_PNG entries
under res://assets/vfx/. Add fx.preview_texture_fixture as PREVIEW_ONLY and
utility.renderer_showcase as export_allowed false. Never load the Preview asset
catalog as an Export fallback. Reject missing, non-exportable, procedural,
fixture, unreadable, non-PNG, or tests/ assets.

Implement path rejection for drive letters, leading slash, backslash,
traversal, res://, user://, empty paths, and invalid Package IDs. Use the loaded
Schema rules and type-parameter Schemas to derive anchors, runtime inputs,
asset references, phases, and Importance order without a copied enum or field
list.

- [ ] **Step 4: Run the focused runner and verify green**

Run the Step 2 command. Expected: EXPORT_TEST_ASSERTIONS=<n> FAILURES=0.

- [ ] **Step 5: Leave work unstaged**

Run git diff --check and git status --short. Do not stage or commit.

### Task B: Compiler, Deterministic Package, and Atomic Writer

**Files:**
- Create: src/export/vfx_export_hasher.gd
- Create: src/export/vfx_export_compiler.gd
- Create: src/export/vfx_export_file_backend.gd
- Create: src/export/vfx_atomic_package_writer.gd
- Create: src/export/vfx_export_service.gd
- Modify: src/export/vfx_export_package_plan.gd
- Create: tests/export/test_export_compiler_and_writer.gd
- Modify: tests/run_export_tests.gd

**Interfaces:**

~~~gdscript
class_name VfxExportPackagePlan
extends RefCounted

func package_id() -> String
func final_package_path() -> String
func manifest_data() -> Dictionary
func files() -> Array[Dictionary]
func asset_copies() -> Array[Dictionary]
~~~

~~~gdscript
class_name VfxExportCompiler
extends RefCounted

func compile(document: VfxPresetDocument) -> VfxResult
# success value is VfxExportPackagePlan
~~~

~~~gdscript
class_name VfxAtomicPackageWriter
extends RefCounted

func write(plan: VfxExportPackagePlan, mode: String = "FAIL_IF_EXISTS") -> VfxResult
~~~

~~~gdscript
class_name VfxExportService
extends RefCounted

func validate_saved_source(source_path: String) -> VfxResult
func export_saved_source(source_path: String, mode: String = "FAIL_IF_EXISTS") -> VfxResult
~~~

- [ ] **Step 1: Write failing compiler and writer tests**

Load saved Zero Zone through VfxExportService. Assert the Source copy retains a
missing Layer space_mode while Runtime Definition has effective VEHICLE_LOCAL
and normalized enabled, sort_order, and transform defaults. Assert one planned
energy_shard.png physical file despite repeated references; lexical Manifest
files; lower-case 64-character SHA-256; and byte-identical JSON from two
compiles. Use an injected file backend that fails during staging and assert a
pre-existing final Package remains unchanged.

- [ ] **Step 2: Run the focused runner and verify red**

Run the Task A command. Expected: assertions fail because compiler, hasher,
writer, and service APIs do not exist.

- [ ] **Step 3: Implement compile, hash, and atomic rollback**

Use VfxPresetDocument.raw_data with VfxPresetCodec.encode for the Source copy.
Use normalized_data for Runtime compile and explicit effective space_mode per
Layer. Build the exact Manifest and Runtime Definition in the Spec. Hash exact
UTF-8 JSON and copied PNG bytes with HashingContext.HASH_SHA256, recording byte
sizes beside each listed file.

Populate and verify a staging Package. For replacement, rename existing final
to backup, rename staging to final, then remove backup. Restore backup on final
rename failure and return EXPORT_IO errors. Do not copy source paths,
Preview/Performance data, or renderer implementation into Package JSON.

- [ ] **Step 4: Run the focused runner and verify green**

Run the Task A command. Expected: Task A and Task B assertions pass, including
forced staging failure preservation and deterministic repeated Package output.

- [ ] **Step 5: Leave work unstaged**

Run git diff --check and git status --short. Do not stage or commit.

### Task C: Export Validation UI

**Files:**
- Create: src/editor/export/vfx_export_panel.gd
- Modify: src/preview/vfx_preview_workspace.gd
- Modify: src/editor/main/vfx_editor_controller.gd
- Create: tests/export/test_export_ui.gd
- Modify: tests/run_export_tests.gd

**Interfaces:**

~~~gdscript
class_name VfxExportPanel
extends VBoxContainer

func configure(controller: RefCounted) -> void
func present_validation(result: VfxResult) -> void
func present_export_result(result: VfxResult) -> void
func validation_status_text() -> String
~~~

~~~gdscript
# New narrow VfxEditorController bridge methods.
func active_export_source_path() -> String
func active_export_is_dirty() -> bool
func validate_active_export() -> VfxResult
func export_active_preset(replace_existing: bool) -> VfxResult
~~~

- [ ] **Step 1: Write failing Export-panel tests**

Instantiate VfxPreviewWorkspace and VfxEditorController. Assert the mode selector
lists AUTHORING PREVIEW, PERFORMANCE, EXPORT in that order; the Export panel
shows the fixed Studio Package root; dirty or unsaved sessions are BLOCKED and
do not call the service; saved Zero Zone is READY; and an existing Package
requires explicit replacement confirmation before REPLACE_EXISTING is passed.

- [ ] **Step 2: Run the focused runner and verify red**

Run the Task A command. Expected: missing Export mode, panel, and Controller
bridge assertions.

- [ ] **Step 3: Implement the compact runtime-created panel**

Add the third mode without modifying the main scene. The panel displays Preset
ID, fixed root, dirty gate, validation status, anchors, inputs, assets, and
session-only last result. Map error VfxIssue values to BLOCKED, warnings to
WARNING, and no issue to READY. Keep file work in VfxExportService. The panel
must not read Preset JSON, mutate the Session, or select an external directory.
Require a local confirmation only for an existing Package.

- [ ] **Step 4: Run the focused runner and verify green**

Run the Task A command. Expected: all Export tests pass with no change to
Preview renderer or Performance behavior.

- [ ] **Step 5: Leave work unstaged**

Run git diff --check and git status --short. Do not stage or commit.

### Task D: Zero Zone Package, Importer Docs, and Regression

**Files:**
- Create: docs/VFX_EXPORT_PACKAGE_V1.md
- Create: exports/packages/talent.zero_zone/manifest.json
- Create: exports/packages/talent.zero_zone/source/talent.zero_zone.vfx.json
- Create: exports/packages/talent.zero_zone/runtime/vfx_runtime_definition_v1.json
- Create: exports/packages/talent.zero_zone/assets/energy_shard.png
- Create: exports/packages/talent.zero_zone/assets/energy_spark.png
- Modify: .gitignore
- Modify: docs/VFX_STUDIO_ARCHITECTURE.md
- Modify: docs/VFX_EDITOR_ROADMAP.md
- Modify: tests/run_export_tests.gd

**Interface:**

~~~gdscript
var result: VfxResult = export_service.export_saved_source(
    "res://presets/examples/talent.zero_zone.vfx.json",
    "REPLACE_EXISTING"
)
~~~

- [ ] **Step 1: Extend failing acceptance tests**

Assert the real final Zero Zone Package contains Source, Runtime, Manifest, and
the two PNG files; CENTER; intensity; two Production assets; no procedural or
fixture dependency; no Studio shader/script; and no absolute, res://, user://,
leading-slash, or traversal string in Package JSON. Assert all listed files
exist and their byte sizes and SHA-256 values match disk bytes. Assert renderer
showcase remains blocked without a Package.

- [ ] **Step 2: Run the focused runner and verify red**

Run the Task A command. Expected: acceptance tests fail until final artifact,
ignore policy, and importer document exist.

- [ ] **Step 3: Produce artifact and permanent docs**

Add .gitignore entries only for /exports/.staging/ and /exports/.backup/. Use
the implemented service to write the final Zero Zone Package in the fixed root.
Write docs/VFX_EXPORT_PACKAGE_V1.md with layout, versions, exact data
semantics, logical asset mapping, path safety, checksum/byte-size importer
validation, and Studio-to-game boundary. Update architecture and roadmap to
identify derived reviewable Package artifacts and exclude Performance data.

- [ ] **Step 4: Run final regression and parse verification**

Run:

~~~powershell
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_contract_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_editor_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_preview_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_performance_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_export_tests.gd'
& 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --editor --quit
git diff --check
~~~

Expected: every suite reports FAILURES=0, the parse exits 0, and the
whitespace check exits 0.

- [ ] **Step 5: Report and leave work unstaged**

Report Package layout, validation, every command exit code, changed files, and
git status --short. Do not stage or commit.

## Plan self-review

- Coverage: Tasks A-D cover fail-closed assets, raw-vs-runtime split, safe
  paths, deterministic ordering, SHA-256, rollback, UI, Zero Zone, permanent
  docs, and final regression.
- Scope: no task creates an importer, game repository access, game renderer,
  dynamic LOD, Preview screenshot, or Performance export.
- Interface consistency: A produces policy, derivation, and Plan input; B
  produces the service used by C and D; D consumes the final service API.
- Git: user policy replaces the normal plan commit step with unstaged
  verification.

