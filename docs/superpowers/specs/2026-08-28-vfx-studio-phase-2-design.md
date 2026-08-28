# DesktopRacingVFXStudio Phase 2 Design

## Goal

Phase 2 adds the Studio-owned foundation for evaluating a VFX Preset at a real miniature vehicle size. It introduces editable Vehicle Anchor Profiles, a top-down vehicle Preview, an always-visible 100% Game View, an enlarged Edit View, Multi Anchor visualization, and simple vehicle transform motion.

The goal is to establish the coordinate, selection, and readability surfaces that a later focused Layer Renderer can use. It does **not** render Particles, Trails, Rings, Glows, Shields, or any VFX output.

## Confirmed inputs and boundaries

The Studio repository owns these reference-copy assets. Each is a 256 by 512 PNG with an alpha-capable ARGB format:

- `res://assets/reference/vehicles/formula_reference.png`
- `res://assets/reference/vehicles/sports_reference.png`
- `res://assets/reference/vehicles/gt_reference.png`
- `res://assets/reference/vehicles/hyper_reference.png`

The supported Profile categories are exactly `FORMULA`, `SPORTS`, `GT`, and `HYPER`. `PROTO` is not a Studio category.

Phase 2 has no dependency on `C:\\GodotProjects\\DesktopIdleRacing`. It neither reads from nor writes to that repository. The reference PNGs are managed copies in this repository; there is no automatic sync, file watcher, absolute game-project path, or direct game-repository export.

The existing uncommitted `project.godot` change and the unrelated Godot UID reserialization change in `src/editor/main/vfx_editor_main.tscn` are user work. They are not reset, reverted, staged, or committed by Phase 2. The existing `PreviewHost` remains the insertion boundary, but `VfxEditorMain` instantiates the new Preview scene at runtime so the main scene does not need a Phase 2 edit.

## Non-goals

Phase 2 does not add a VFX Renderer, VFX playback, procedural textures, performance analysis, 20-car stress simulation, export, manifest generation, game runtime integration, a Node Graph, a Shader Graph, a Timeline, Beam, Arc, Orbit, Distortion, or gameplay/track simulation.

## Vehicle Profile contract

Vehicle Profiles are Studio reference/authoring data, separate from Preset `.vfx.json` source. They use readable JSON rather than Godot `.tres`:

- JSON gives small, reviewable Git diffs for Anchor adjustments.
- The Profile is not a Godot runtime Resource or a game-facing export input.
- The Profile must remain usable without serialized Studio UI state.

Profiles live under `res://profiles/vehicles/`. A Profile has a strict, versioned format, with unknown root fields rejected. The final v1 shape is:

```json
{
  "profile_version": 1,
  "profile_id": "formula",
  "display_name": "Formula",
  "category": "FORMULA",
  "reference_image": {
    "path": "res://assets/reference/vehicles/formula_reference.png",
    "expected_source_size_px": [256, 512]
  },
  "anchors": {
    "CENTER": [0, 0],
    "FRONT": [0, -220],
    "REAR_CENTER": [0, 210],
    "REAR_LEFT": [-42, 205],
    "REAR_RIGHT": [42, 205],
    "LEFT_SIDE": [-78, 0],
    "RIGHT_SIDE": [78, 0],
    "TIRE_FL": [-104, -122],
    "TIRE_FR": [104, -122],
    "TIRE_RL": [-104, 132],
    "TIRE_RR": [104, 132],
    "EQUIPMENT_CENTER": [0, 20],
    "WING_LEFT": [-80, 198],
    "WING_RIGHT": [80, 198]
  }
}
```

`expected_source_size_px` is deliberately an integrity expectation, not a copy of derived image metadata. It lets the repository detect that a replacement reference image changed the coordinate frame. Loading a Profile whose actual image size differs is a Profile/reference mismatch and does not silently use its Anchors. Alpha information is not saved; it is inspected from the real image during preflight.

The shown Anchor values are starter authoring values only. They are not canonical vehicle geometry: each category Profile is expected to be adjusted against its own Reference PNG.

`schemas/vehicle_anchor_profile_v1.json` declares the Profile's structural shape, Profile version, and Category enum. Its `anchors` values are typed two-number arrays. `VfxVehicleProfileValidator` obtains the valid Anchor-name set from `VfxSchemaRegistry`, requires every Schema v1 vehicle Anchor exactly once, and rejects unknown names. This avoids manually maintaining VFX Anchor enums in two schemas while retaining strict Profile validation.

No Profile migration framework is added. Any unsupported `profile_version` returns an explicit Profile configuration/validation issue.

## Game display-scale reference contract

`res://profiles/preview/game_display_scale_v1.json` is a small Studio Preview reference contract, not a copy of gameplay configuration or a Track database:

```json
{
  "version": 1,
  "base_car_sprite_scale": [0.38, 0.38],
  "car_visual_scale": 0.25,
  "track_scales": [1.0, 0.95, 0.9, 0.85]
}
```

`VfxPreviewGameScale` owns the calculation, rather than Profile data or UI layout code:

```text
effective_game_scale
  = base_car_sprite_scale * car_visual_scale * selected_track_scale
```

The Vector2 multiplication is component-wise. With the supplied uniform values, the results are `[0.095, 0.095]`, `[0.09025, 0.09025]`, `[0.0855, 0.0855]`, and `[0.08075, 0.08075]`. These derived values are never stored in JSON.

The Preview UI exposes the supplied four scalar values as `1.00 - Default`, `0.95`, `0.90`, and `0.85`. It does not name tracks or replicate a game Track database.

`schemas/preview_game_scale_v1.json` describes this narrow JSON format. It does not add generic configuration loading or a dependency on the game.

## Source coordinate system and scale rules

Every Reference PNG has the same vehicle-local coordinate convention:

- Sprite origin: the image centre, `(0, 0)`.
- For a 256 by 512 image, source pixel `(128, 256)` is local `(0, 0)`.
- `+X` points right, `-X` left, `-Y` front, and `+Y` rear.
- Profile Anchor coordinates are unscaled local source pixels.
- A `VEHICLE_LOCAL` Layer `transform.offset` is interpreted in this same source-local canvas space for preview projection.

For each selected Anchor, the Preview computes:

```text
local_effect_position = anchor_source_position + layer_transform.offset

preview_position = stage_center
  + vehicle_rotation
    * (local_effect_position * effective_game_scale * view_zoom)
```

`view_zoom` is `1.0` for Game View and is `2.0` or `4.0` for Edit View. Vehicle translation is added at the stage level after this calculation. The same rotation and translation are applied to the vehicle sprite, Anchor markers, and local-offset ghost markers.

At 100%, the vehicle image must be drawn at exactly:

```text
native source image size * effective_game_scale
```

It must never be fit, expanded, automatically downscaled, or influenced by the `Control` layout size, Godot UI scale, Windows DPI, the Game inset size, or Edit View zoom. A small approximately 20 to 24 by 41 to 49 pixel vehicle is correct and is the readability target. If the Edit View's 400% content exceeds its available panel, a `ScrollContainer` exposes the full fixed-scale canvas; it does not reduce the scale.

## Shared Preview state and scene

`res://src/preview/vfx_vehicle_preview.tscn` is a reusable Preview component instantiated under the existing `PreviewHost`. Its high-level structure is:

```text
VfxVehiclePreview
  PreviewControls
    Profile / Background row
    Track Scale / Edit Zoom / Motion / Show Anchors row
    Selected Layer context label
  PreviewSurface
    EditScroll
      EditCanvas
        FutureVfxHost
    GameSizeInset
      GameCanvas
        FutureVfxHost
```

`VfxPreviewSharedState` is the only mutable state shared by both canvases. It contains the selected Profile/session data, loaded display-scale contract, selected Track Scale, background mode, motion/vehicle transform, and selected Layer context. `edit_zoom` is intentionally not shared: Edit Canvas owns its 2x or 4x choice and Game Canvas always uses 1x.

`VfxVehiclePreviewCanvas` is a lightweight `Control` drawing the background, reference texture, markers, and diagnostic ghost geometry. It is not a VFX Renderer. It exposes a transform for its empty `FutureVfxHost` so Phase 3 can attach a focused renderer to both views without changing Profile coordinate rules. The Game Canvas is display-only and never accepts Anchor editing input.

The selected Background is one of `DARK`, `LIGHT`, or `TRACK_GRAY`, applied to both canvases. The compact controls must not impose a new fixed horizontal minimum on the existing 320-pixel Center workspace. Long selected-layer text uses ellipsis and tooltip text.

## Anchor editing and visualization

The Edit Canvas supplies a focused Profile editor, not a generic 2D level editor:

- Each known Anchor has a muted marker and short label.
- Clicking an Edit marker selects it for Profile editing.
- The active Profile Anchor is distinguished from Layer selection highlighting.
- An Anchor picker plus integer X/Y SpinBoxes provide accessible precise edits.
- Dragging a selected Edit marker converts the pointer with the inverse Preview transform and snaps the source-local coordinate to a whole pixel.

The selected Layer does not change Profile data. Its declared Anchor list is visualized independently:

- all selected Layer Anchors receive the Layer-highlight colour;
- multiple Anchors are highlighted simultaneously;
- `VEHICLE_LOCAL` draws one ghost output marker per selected Anchor at `anchor + transform.offset`;
- `VEHICLE_FOLLOW_WORLD_TRAIL` highlights its Anchors but draws no Trail;
- `WORLD_AREA` and `SCREEN_UI` receive no Layer Anchor or ghost marker;
- the selected Layer's effective space and render plane are shown as text; render plane produces no rendering behaviour in Phase 2.

## Profile editing lifetime

`VfxVehicleProfileEditSession` is separate from `VfxPresetEditSession`. It owns a source path, saved baseline, deep-copied working Profile, dirty state, Save, and Revert.

- Save validates the Profile and its reference preflight, then writes only the selected Profile JSON through `VfxVehicleProfileCodec`.
- Revert restores the saved baseline without changing the Preset.
- A dirty Profile selection change or editor close offers Profile-specific Save / Discard / Cancel handling; it never consumes or clears Preset dirty state.
- Phase 2 intentionally has no independent Profile Undo/Redo history. Save/Revert gives reliable recovery while avoiding a second history system.

## Reference integrity preflight

`VfxVehicleProfileRepository` performs the smallest useful preflight while loading a Profile:

1. reference path exists under `res://assets/reference/vehicles/`;
2. the image can be loaded;
3. actual source dimensions equal `expected_source_size_px`;
4. the loaded format has an alpha channel.

Failures produce explicit local Profile diagnostics such as `PROFILE_REFERENCE_MISSING`, `PROFILE_REFERENCE_LOAD_FAILED`, `PROFILE_REFERENCE_SIZE_MISMATCH`, and `PROFILE_REFERENCE_NO_ALPHA`. These are surfaced through the Preview status/Diagnostics route and do not mutate a Preset or its validation result. This is not an asset manager, an importer, or a replacement for Godot's normal reference-asset import.

## Layer-selection integration

`VfxEditorController` remains the sole owner of current Preset selection. Whenever selected Phase, selected Layer, session data, or common Layer properties refresh, it requests a narrow immutable `VfxPreviewLayerContext`:

```text
VfxEditorController
  -> VfxPreviewLayerContextResolver
  -> VfxPreviewLayerContext {
       layer_id, anchors, effective_space,
       transform_offset, render_plane
     }
  -> VfxVehiclePreview / VfxPreviewSharedState
```

The resolver reads VFX Schema rule configuration through the existing Registry; Preview code does not parse Preset JSON or duplicate field names, space enums, or Anchor rules. With no selected Layer, the context is empty and the Preview continues to show the Profile without Layer highlighting.

## Motion modes

The Preview has only these display modes:

- `STATIC`: centred vehicle, zero rotation.
- `ROTATE`: centred vehicle rotating at a fixed Preview-only rate.
- `SIMPLE_MOTION`: short horizontal Preview-only translation with fixed orientation.

These modes have no physics, speed, track curve, cornering, or gameplay meaning. Both canvases sample the same transform state so their vehicle, Anchors, and local ghost markers remain synchronized.

## Architecture documentation rule

Task D updates `docs/VFX_STUDIO_ARCHITECTURE.md` with this permanent boundary:

```text
DesktopRacingVFXStudio
  -> VFX Export Package
  -> DesktopIdleRacing importer/runtime
```

The Studio must not modify game source, scenes, resources, files, Git state, or formatting; use the game repository as an output directory; or directly export generated VFX into it. Applying exported artifacts belongs only to a DesktopIdleRacing-specific development project.

## Implementation bundles

### Task A — Profile and scale contract

Create the two small JSON contracts, four editable starter Profiles, Profile document/codec/validator/repository services, image preflight, and preview scale calculation.

Primary files:

- `schemas/vehicle_anchor_profile_v1.json`
- `schemas/preview_game_scale_v1.json`
- `profiles/vehicles/*.vehicle_profile.json`
- `profiles/preview/game_display_scale_v1.json`
- `src/model/vehicle_profiles/vfx_vehicle_profile_document.gd`
- `src/model/vehicle_profiles/vfx_vehicle_profile_codec.gd`
- `src/model/vehicle_profiles/vfx_vehicle_profile_validator.gd`
- `src/model/vehicle_profiles/vfx_vehicle_profile_repository.gd`
- `src/preview/vfx_preview_game_scale.gd`

Focused tests cover all four categories, JSON load/save round-trip, missing or unloadable assets, expected-size mismatch, alpha validation, and exact uniform scale derivation.

### Task B — Preview foundation

Create the Preview scene, shared state, background modes, exact fixed-scale Canvas drawing, Game View inset, Edit View 2x/4x scale, internal scrolling, and empty future renderer hosts.

Primary files:

- `src/preview/vfx_preview_shared_state.gd`
- `src/preview/vfx_preview_transform_resolver.gd`
- `src/preview/vfx_vehicle_preview_canvas.gd`
- `src/preview/vfx_vehicle_preview.gd`
- `src/preview/vfx_vehicle_preview.tscn`

Focused tests cover source-to-preview projection, Game View 1x invariance, Edit View 2x/4x conversion, background selection, and scene instantiate/free.

### Task C — Anchor editing, multi-anchor, and motion

Add Profile Save/Revert flow, marker picking/dragging, numeric coordinate editing, multi-Anchor highlighting, local-offset ghosts, and the three Preview-only motion modes.

Primary files are the Task A Profile session plus Task B Preview scripts and:

- `src/model/vehicle_profiles/vfx_vehicle_profile_edit_session.gd`
- `src/preview/vfx_preview_layer_context.gd`

Focused tests cover inverse drag projection, source-coordinate round-trip, Save/Revert isolation from Preset data, multi-Anchor resolution, local-offset ghost resolution, and rotation/translation projection.

### Task D — Editor connection, documentation, and regression

Instantiate Preview under `PreviewHost` at runtime, configure it from the Editor controller, create the Layer-context resolver, add isolation policy documentation, and run final verification.

Primary files:

- `src/editor/main/vfx_editor_main.gd`
- `src/editor/main/vfx_editor_controller.gd`
- `src/preview/vfx_preview_layer_context_resolver.gd`
- `docs/VFX_STUDIO_ARCHITECTURE.md`
- `docs/VFX_EDITOR_ROADMAP.md`
- `tests/preview/*`
- `tests/run_preview_tests.gd`

The implementation must not modify `project.godot` or `src/editor/main/vfx_editor_main.tscn` unless the user first approves an unavoidable reason.

## Test and final verification strategy

Each Task runs only its new focused Preview/Profile tests. Task D runs once:

```powershell
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --script res://tests/run_contract_tests.gd
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --script res://tests/run_editor_tests.gd
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --script res://tests/run_preview_tests.gd
& 'C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\\GodotProjects\\DesktopRacingVFXStudio' --editor --quit
```

No Windows Export is run. UI smoke verification is instantiate/free only; it does not claim subjective visual quality. Final validation reports actual commands, exit codes, and assertion counts.

## Acceptance criteria

1. FORMULA, SPORTS, GT, and HYPER Profiles load, validate, save, and revert independently of Preset working data.
2. Every Profile uses a Studio-owned reference asset and rejects missing, unreadable, non-alpha, or expected-size-mismatched imagery.
3. Game View always draws native image dimensions multiplied solely by the derived effective game scale, with zoom fixed to 1.0.
4. Edit View draws the same coordinate system at exactly 2x or 4x Game View scale and scrolls rather than fitting down.
5. Both canvases share Profile, transform, Track Scale, background, and Layer context; Game inset does not receive edit input.
6. Selected Layer Anchors all highlight, and vehicle-local Layers show an offset ghost at every resolved Anchor.
7. Static, Rotate, and Simple Motion keep vehicle, Anchors, and ghost markers synchronized without simulating gameplay.
8. The Studio/game one-way isolation policy is documented and no code contains a DesktopIdleRacing repository dependency.
9. Phase 2 adds no VFX Renderer, playback, export, analyzer, or runtime integration.
10. Existing user changes to `project.godot` and the main-scene UID reserialization remain outside Phase 2 commits.
11. Contract, Editor, Preview, scene smoke, and Godot headless editor parse complete successfully.

## Schema v1 decision

VFX Schema v1 remains unchanged. Vehicle Profile and Preview display-scale contracts are separate Studio reference-data schemas. They neither alter `.vfx.json` fields nor create a new VFX Layer Type, Space Mode, Anchor, or runtime input.
