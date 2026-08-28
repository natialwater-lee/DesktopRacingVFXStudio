# Phase 2 Vehicle Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Studio-only Vehicle Anchor Profile and Dual Preview foundation needed to judge future VFX at actual miniature game size.

**Architecture:** Vehicle Profiles and game-display scales are strict JSON reference contracts separate from Preset `.vfx.json`. A shared Preview state feeds an editable 2x/4x Canvas and an input-disabled, fixed-scale 100% Game Canvas; Editor selection reaches Preview only through a narrow resolved Layer context.

**Tech Stack:** Godot 4.7.1 stable, GDScript, existing dependency-free JSON codec/Schema subset services, Godot Controls, Image preflight, headless GDScript tests.

**Spec:** `docs/superpowers/specs/2026-08-28-vfx-studio-phase-2-design.md`

## Global Constraints

- Use `C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe`; do not install or download another Godot version.
- Work only in `C:\\GodotProjects\\DesktopRacingVFXStudio`; never access or depend on `C:\\GodotProjects\\DesktopIdleRacing`.
- Do not modify, stage, reset, revert, or commit `project.godot` or the pre-existing UID serialization changes in `src/editor/main/vfx_editor_main.tscn`.
- The four supplied `assets/reference/vehicles/*_reference.png` files are intentional Phase 2 inputs and may be committed with Task A.
- Keep VFX Schema v1 unchanged. Profile and Preview-scale schemas are separate Studio reference contracts.
- Build no VFX Renderer, lifecycle player, pooling, export, performance system, gameplay simulation, graph, or shader feature.
- Follow TDD per Task: focused test red, minimal implementation green, focused verification, then commit.
- Run full Contract, Editor, Preview, scene smoke, and headless editor parse only in Task D.

---

## Files and responsibilities

| Path | Responsibility |
|---|---|
| `schemas/vehicle_anchor_profile_v1.json` | Strict structure and category contract for Profile JSON. |
| `schemas/preview_game_scale_v1.json` | Strict Preview game-scale reference contract. |
| `profiles/vehicles/*.vehicle_profile.json` | Four editable starter Profiles, one per official category. |
| `profiles/preview/game_display_scale_v1.json` | Meaning-preserving scale inputs from the supplied game reference contract. |
| `src/model/vehicle_profiles/vfx_vehicle_profile_document.gd` | Immutable loaded Profile data and source path. |
| `src/model/vehicle_profiles/vfx_vehicle_profile_codec.gd` | Profile JSON decode, deterministic encode, and explicit file write only. |
| `src/model/vehicle_profiles/vfx_vehicle_profile_validator.gd` | Structure, category, and Schema-derived Anchor-name validation. |
| `src/model/vehicle_profiles/vfx_vehicle_profile_repository.gd` | Profile discovery/load plus PNG existence, load, size, and alpha preflight. |
| `src/model/vehicle_profiles/vfx_vehicle_profile_edit_session.gd` | Separate Profile working/baseline data, Save, Revert, and dirty state. |
| `src/preview/vfx_preview_game_scale.gd` | Component-wise effective-game-scale derivation. |
| `src/preview/vfx_preview_shared_state.gd` | Shared Profile, game scale, background, motion, and Layer context state. |
| `src/preview/vfx_preview_transform_resolver.gd` | Source-local to per-Canvas projection and inverse drag conversion. |
| `src/preview/vfx_preview_layer_context.gd` | Narrow resolved Layer value object. |
| `src/preview/vfx_preview_layer_context_resolver.gd` | Schema-aware conversion from selected Preset Layer to Preview context. |
| `src/preview/vfx_vehicle_preview_canvas.gd` | One Canvas's exact-scale draw/input policy and empty FutureVfxHost boundary. |
| `src/preview/vfx_vehicle_preview.tscn/.gd` | Dual Preview composition, compact controls, Profile edit controls, and scene API. |
| `tests/preview/*` | Focused real services/scene tests. |
| `tests/run_preview_tests.gd` | Focused Preview test runner. |

## Task A — Profile + Scale Contract

**Files:**
- Create: Profile/scale schemas, four Profile JSON files, scale JSON, Profile model services, `vfx_preview_game_scale.gd`, `tests/preview/test_vehicle_profiles.gd`, `tests/preview/test_preview_game_scale.gd`, `tests/run_preview_tests.gd`.
- Test assets: the four supplied `assets/reference/vehicles/*_reference.png`.

**Interfaces:**
- Produces `VfxVehicleProfileRepository.load_profile(path: String) -> VfxResult`.
- Produces `VfxVehicleProfileValidator.validate(value: Variant, source_path := "") -> Array[VfxIssue]`.
- Produces `VfxPreviewGameScale.effective_scale(config: Dictionary, track_scale: float) -> VfxResult`.
- Later tasks consume a loaded Profile Dictionary containing `reference_image.path`, `expected_source_size_px`, and full `anchors`.

- [ ] **Step 1: Write failing focused Profile and scale tests.**

Create tests that load each of the four expected paths and assert `FORMULA`, `SPORTS`, `GT`, and `HYPER`; reject an unknown Anchor and a mismatched expected image size; and verify hand-derived scale literals:

```gdscript
var scale := VfxPreviewGameScaleModel.effective_scale({
    "base_car_sprite_scale": [0.38, 0.38],
    "car_visual_scale": 0.25
}, 0.95)
tests.expect_true(scale.success and scale.value == Vector2(0.09025, 0.09025),
    "track scale 0.95 derives the supplied Sprite2D scale")
```

- [ ] **Step 2: Run the new Preview runner and verify red.**

Run:

```powershell
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --script res://tests/run_preview_tests.gd
```

Expected: non-zero because the Profile/scale classes and contracts do not exist yet.

- [ ] **Step 3: Implement the minimal strict contracts and services.**

Use existing `VfxResult`, `VfxIssue`, `VfxPresetCodec`, `VfxSchemaSubsetValidator`, and a loaded `VfxSchemaRegistry`. Keep Anchor enum ownership in Schema v1:

```gdscript
func validate(value: Variant, source_path: String = "") -> Array[VfxIssue]:
    # Validate Profile schema structure, then require the exact Anchor set
    # supplied by VfxSchemaRegistry; do not declare those Anchor strings here.
    return issues

static func effective_scale(config: Dictionary, track_scale: float) -> VfxResult:
    var base := Vector2(config["base_car_sprite_scale"][0], config["base_car_sprite_scale"][1])
    return VfxResult.ok(base * float(config["car_visual_scale"]) * track_scale)
```

Preflight only checks image existence, `Image.load_from_file`, expected dimensions, and alpha-capable format. It returns explicit `PROFILE_REFERENCE_*` issues without editing any Preset.

- [ ] **Step 4: Run focused tests and verify green.**

Run the Task A Preview runner. Expected: exit 0, assertion count printed, zero failures.

- [ ] **Step 5: Commit Task A only.**

Stage Profile/scale contracts, model services, focused tests, runner, and the four supplied reference PNGs. Do not stage `project.godot` or `vfx_editor_main.tscn`.

```powershell
git add schemas profiles src/model/vehicle_profiles src/preview/vfx_preview_game_scale.gd tests/preview tests/run_preview_tests.gd assets/reference/vehicles
git commit -m "feat: add vehicle profile preview contracts"
```

## Task B — Dual Preview Foundation

**Files:**
- Create: `vfx_preview_shared_state.gd`, `vfx_preview_transform_resolver.gd`, `vfx_vehicle_preview_canvas.gd`, `vfx_vehicle_preview.gd`, `vfx_vehicle_preview.tscn`, and focused scene/projection tests.
- Modify: `tests/run_preview_tests.gd` only to register the new focused tests.

**Interfaces:**
- Produces `VfxPreviewSharedState` with Profile, selected Track Scale, background, motion state/time, and `VfxPreviewLayerContext`; it has no edit zoom.
- Produces `VfxPreviewTransformResolver.project_source_local(local: Vector2, state, canvas_center: Vector2, zoom: float) -> Vector2`.
- Produces `VfxVehiclePreview.set_shared_state(state)`, `set_edit_zoom(zoom)`, and `get_future_vfx_host(canvas_name) -> Node2D`.
- Task C consumes Canvas marker projection and input conversion. Task D consumes `VfxVehiclePreview.set_layer_context(context)`.

- [ ] **Step 1: Write failing projection and scene tests.**

Assert independent hand-derived behavior: Game Canvas with zoom 1.0 maps a 256 by 512 reference image to 24.32 by 48.64 at Track Scale 1.00; Edit Canvas uses exactly 2x and 4x; Canvas inverse projection round-trips a fixed source coordinate; and the Preview scene instantiates with separate Edit/Game `FutureVfxHost` nodes.

```gdscript
tests.expect_true(is_equal_approx(edit_400.x, game_100.x * 4.0),
    "400 percent Edit projection is four times Game projection")
tests.expect_true(preview.get_future_vfx_host("EDIT") != preview.get_future_vfx_host("GAME"),
    "each Canvas owns a future renderer boundary")
```

- [ ] **Step 2: Run the focused Preview runner and verify red.**

Run the Task A command. Expected: non-zero because shared state, transform resolver, and Preview scene are absent.

- [ ] **Step 3: Implement exact-scale dual Preview.**

Use a lightweight `Control` Canvas rather than any VFX renderer. The Game Canvas always uses `zoom = 1.0`, is display-only, shows no Anchor names or edit controls, and can render only tiny selected-Layer markers. The Edit Canvas permits 2x/4x scale and lies inside a `ScrollContainer`; it never fits its content down. The two empty `FutureVfxHost` nodes only expose source-local transform boundaries and contain no renderer structure.

- [ ] **Step 4: Run focused tests and verify green.**

Run the Preview runner. Expected: exit 0 with Task A and Task B assertions passing.

- [ ] **Step 5: Commit Task B only.**

```powershell
git add src/preview tests/preview tests/run_preview_tests.gd
git commit -m "feat: add dual vehicle preview foundation"
```

## Task C — Anchor Editing + Multi Anchor + Motion

**Files:**
- Create: `vfx_vehicle_profile_edit_session.gd`, `vfx_preview_layer_context.gd`, and focused edit/context/motion tests.
- Modify: Preview scene/script, shared state, Canvas script, transform resolver, Profile repository/codec only where the public Save/Revert flow requires it, and Preview test runner.

**Interfaces:**
- Produces `VfxVehicleProfileEditSession.open(document)`, `set_anchor(name, source_position)`, `is_dirty()`, `save() -> VfxResult`, and `revert()`.
- Produces `VfxPreviewLayerContext.new(layer_id, anchors, effective_space, transform_offset, render_plane)`.
- Canvas emits selected Anchor and snapped source-local drag positions; Game Canvas emits neither.
- Task D supplies resolved context through `VfxVehiclePreview.set_layer_context(context)`.

- [ ] **Step 1: Write failing focused edit and projection tests.**

Use a real temporary `user://` Profile file to prove Save writes only Profile data and Revert restores baseline. Assert an Edit drag snaps to one source pixel, a four-Tire context produces four highlighted Anchor positions, a vehicle-local offset produces one ghost per Anchor, and the same motion state projects differently around each Canvas centre without changing source-local meaning.

```gdscript
var context := VfxPreviewLayerContextModel.new(
    "loop.tires", ["TIRE_FL", "TIRE_FR", "TIRE_RL", "TIRE_RR"],
    "VEHICLE_LOCAL", Vector2(3, -2), "UNDER_VEHICLE")
tests.expect_true(canvas.ghost_positions(context).size() == 4,
    "vehicle-local multi Anchor layer produces one offset ghost per Anchor")
```

- [ ] **Step 2: Run the focused Preview runner and verify red.**

Run the Preview runner. Expected: non-zero because Profile session, context, edit commands, and motion modes are absent.

- [ ] **Step 3: Implement the smallest authoring interaction surface.**

Implement marker selection, one-pixel snapped drag, integer X/Y controls, Save, and Revert in the Edit Canvas/Preview controls. Keep its dirty baseline wholly separate from `VfxPresetEditSession`; add no Profile Undo/Redo. Draw muted all-Anchor markers and labels in Edit Canvas, but suppress labels, drag affordances, and X/Y UI in Game Canvas. Support only `STATIC`, `ROTATE`, and `SIMPLE_MOTION`; motion state/time is shared while each Canvas projects it using its own centre, scale, and zoom.

- [ ] **Step 4: Run focused tests and verify green.**

Run the Preview runner. Expected: exit 0 with all Task A-C focused assertions and zero failures.

- [ ] **Step 5: Commit Task C only.**

```powershell
git add src/model/vehicle_profiles src/preview tests/preview tests/run_preview_tests.gd
git commit -m "feat: add vehicle anchor profile editing"
```

## Task D — Editor Integration + Regression

**Files:**
- Create: `vfx_preview_layer_context_resolver.gd`, Editor-to-Preview focused integration test.
- Modify: `src/editor/main/vfx_editor_main.gd`, `src/editor/main/vfx_editor_controller.gd`, `docs/VFX_STUDIO_ARCHITECTURE.md`, `docs/VFX_EDITOR_ROADMAP.md`, test runners and smoke tests as needed.
- Do not modify: `project.godot`, `src/editor/main/vfx_editor_main.tscn`.

**Interfaces:**
- Produces `VfxPreviewLayerContextResolver.resolve(preset: Dictionary, phase_name: String, layer_id: String) -> VfxPreviewLayerContext`.
- Adds `VfxEditorController.configure_preview(preview)` and a passive refresh path that passes context to Preview.
- `VfxEditorMain` instantiates `vfx_vehicle_preview.tscn` below the existing `PreviewHost` at runtime and removes/hides only the runtime placeholder.

- [ ] **Step 1: Write failing focused integration tests.**

Create a vehicle-local Preset through the real Controller, select a multi-Anchor Layer, and assert its Preview context has Schema-derived effective space, declared Anchors, transform offset, and render plane. Instantiate the main scene and assert Preview is present beneath `PreviewHost` while the original scene path remains unchanged.

```gdscript
tests.expect_true(context.anchors == ["TIRE_FL", "TIRE_FR"],
    "selected Layer sends every declared Anchor to Preview")
tests.expect_true(editor.get_node_or_null(
    "EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PreviewHost/VfxVehiclePreview") != null,
    "main scene inserts Preview at runtime below PreviewHost")
```

- [ ] **Step 2: Run the focused Preview runner and verify red.**

Run the Preview runner. Expected: non-zero because the resolver and runtime Editor connection are absent.

- [ ] **Step 3: Implement the narrow Editor bridge and documentation.**

The resolver reads effective-space/Anchor/render-plane fields through `VfxSchemaRegistry` rule configuration. Preview receives only resolved values and never reads or writes Preset JSON. Runtime insertion leaves `vfx_editor_main.tscn` untouched. Add the permanent Studio -> VFX Export Package -> DesktopIdleRacing importer/runtime rule and the explicit repository modification prohibition to the Architecture document. Update the Roadmap Phase 2 entry to record the shipped Vehicle Preview, editable Profiles, 100% Game View, and Multi Anchor visualization while preserving the Renderer as Phase 3 work.

- [ ] **Step 4: Run focused integration tests and then final regression.**

Run:

```powershell
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --script res://tests/run_preview_tests.gd
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --script res://tests/run_contract_tests.gd
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --script res://tests/run_editor_tests.gd
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --editor --quit
```

Expected: each command exits 0 and every runner reports zero failures.

- [ ] **Step 5: Commit Task D only.**

```powershell
git add src/editor/main/vfx_editor_main.gd src/editor/main/vfx_editor_controller.gd src/preview tests docs
git commit -m "feat: connect vehicle preview to layer selection"
```
