# DesktopRacingVFXStudio Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` task-by-task. Do not use subagents, `git add`, or `git commit`; leave every change unstaged for SourceTree review.

**Goal:** Build a Studio-only, contract-backed 2D Preview Renderer for the five Schema v1 Layer Types with shared Edit/Game playback.

**Architecture:** `VfxEditorController` first produces a valid normalized document, then `VfxPreviewRenderPlanBuilder` produces an immutable Plan. One canonical fixed-tick renderer simulation produces packets that Edit and Game Canvas hosts project independently; each Canvas routes packets through concrete Schema render planes.

**Tech Stack:** Godot 4.7.1 stable, standard GDScript, built-in CanvasItem/Line2D/GradientTexture2D/ShaderMaterial only, dependency-free project test runners.

**Spec:** `docs/superpowers/specs/2026-08-29-vfx-studio-phase-3-design.md`

## Global Constraints

- Keep `schemas/vfx_schema_v1.json` and Schema v1 behavior unchanged.
- Renderer input is only a successful normalized document/Render Plan; never raw file JSON or invalid working data.
- Preserve `project.godot`, `src/editor/main/vfx_editor_main.tscn`, and all four Vehicle Profile JSON user changes exactly.
- Do not access `C:\GodotProjects\DesktopIdleRacing`.
- Do not stage or commit. Inspect Git status/diff only when needed.
- Do not add Renderer special cases for Preset IDs, export, game integration, LOD UI, performance analysis, or generic graph/timeline systems.
- Use focused Preview tests during Tasks A-D. Run full suites only in Task E with `C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe`.

---

### Task A: Render Plan, Asset Registry, and Plane Hosts

**Files:**

- Create: `src/preview/rendering/vfx_preview_render_plan.gd`
- Create: `src/preview/rendering/vfx_preview_phase_plan.gd`
- Create: `src/preview/rendering/vfx_preview_layer_spec.gd`
- Create: `src/preview/rendering/vfx_preview_render_instance_spec.gd`
- Create: `src/preview/rendering/vfx_preview_render_plan_builder.gd`
- Create: `src/preview/rendering/vfx_preview_instance_resolver.gd`
- Create: `src/preview/rendering/vfx_preview_renderer_factory.gd`
- Create: `src/preview/rendering/vfx_preview_plane_hosts.gd`
- Create: `src/preview/rendering/vfx_preview_asset_registry.gd`
- Create: `src/preview/rendering/vfx_preview_asset_resolver.gd`
- Create: `assets/preview/vfx_preview_asset_catalog_v1.json`
- Modify: `src/preview/vfx_vehicle_preview_canvas.gd`
- Modify: `src/preview/vfx_vehicle_preview.gd`
- Modify: `src/preview/vfx_vehicle_preview.tscn`
- Test: `tests/preview/test_preview_render_plan.gd`
- Test: `tests/preview/test_preview_asset_registry.gd`
- Test: `tests/preview/test_preview_plane_hosts.gd`
- Modify: `tests/run_preview_tests.gd`

**Interfaces:**

- Consumes: valid `VfxPresetDocument.normalized_data`, `VfxSchemaRegistry`, Vehicle Profile anchor data, current effective game scale, and existing `VfxPreviewTransformResolver` rules.
- Produces: `VfxPreviewRenderPlanBuilder.build(normalized_data: Dictionary) -> VfxResult`, `VfxPreviewInstanceResolver.resolve(plan, profile_data: Dictionary) -> VfxResult`, and `VfxPreviewRendererFactory.validate_configuration(registry) -> VfxResult`.

- [ ] **Step 1: Write focused failing Plan and registry tests**

  Assert that Zero Zone builds ordered, effective-space Layer specs from a
  normalized valid document; Finish Confetti builds one anchorless WORLD spec;
  a TIRE multi-anchor Layer expands into four ordered instances; a factory
  registration mismatch returns a configuration failure; the four catalog ids
  resolve; and an unknown logical id returns the magenta fallback plus one
  Preview warning.

- [ ] **Step 2: Run the focused tests and confirm failure**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_preview_tests.gd'
  ```

  Expected before implementation: test load/undefined-interface failure for
  the new Plan, asset, and plane host classes.

- [ ] **Step 3: Implement immutable planning, data-driven asset lookup, and plane ownership**

  Build Plans only from normalized valid values, derive field/lifecycle rules
  through `VfxSchemaRegistry`, preserve declared Layer order, and expand
  vehicle anchors only in the instance resolver. Validate exact Schema Type ↔
  renderer registration coverage. Generate the four Preview primitives from
  catalog data and return a magenta fallback for missing ids. Refactor the
  canvas internally into Background, StageWorld, VehicleRoot/FutureVfxHost,
  world-follow, and Screen UI host boundaries without editing the main scene.

- [ ] **Step 4: Run focused Plan, asset, and plane tests**

  Expected: all new focused assertions pass and existing Phase 2 anchor/
  projection behavior remains available through the preserved Canvas API.

- [ ] **Step 5: Leave the completed Task unstaged**

  Inspect `git status --short` only. Do not add or commit files.

### Task B: Glow, Ring, and Shield

**Files:**

- Create: `src/preview/rendering/vfx_preview_layer_renderer.gd`
- Create: `src/preview/rendering/vfx_glow_layer_renderer.gd`
- Create: `src/preview/rendering/vfx_ring_layer_renderer.gd`
- Create: `src/preview/rendering/vfx_shield_layer_renderer.gd`
- Create: `src/preview/rendering/vfx_preview_canvas_render_host.gd`
- Create: `src/preview/rendering/materials/vfx_shield_arc.gdshader`
- Modify: `src/preview/rendering/vfx_preview_renderer_factory.gd`
- Test: `tests/preview/test_static_layer_renderers.gd`
- Modify: `tests/run_preview_tests.gd`

**Interfaces:**

- Consumes: `VfxPreviewRenderInstanceSpec`, resolved Preview asset, canonical frame context, and plane host routing from Task A.
- Produces: the common renderer operations `restart`, `advance`,
  `stop_emission`, `has_residual`, `clear`, and canonical draw packets accepted
  by `VfxPreviewCanvasRenderHost.apply_packets(...)`.

- [ ] **Step 1: Write failing renderer semantic tests**

  Assert GLOW opacity is constant at `pulse_hz = 0` and follows the documented
  zero-to-opacity sine formula otherwise; RING has exact activation/repeat and
  radius interpolation behavior; SHIELD produces full/partial arc geometry,
  applies its optional texture scroll only when textured, and routes Alpha and
  Additive output to the correct concrete plane.

- [ ] **Step 2: Run focused tests and confirm failure**

  Expected before implementation: renderer factory cannot construct the three
  registered Layer implementations.

- [ ] **Step 3: Implement the three static Layer Renderers**

  Keep Ring geometry draw-based, Glow procedural-gradient based, and Shield
  limited to one fixed polar-annulus CanvasItem shader. Apply Schema blend
  mode through the Canvas render adapter. Do not introduce Shader Graph,
  undeclared fade/noise, or Preset-specific branches.

- [ ] **Step 4: Run focused static-renderer tests**

  Expected: exact timing/geometry assertions pass, including `UNDER_VEHICLE`,
  `OVER_VEHICLE`, `WORLD`, and `SCREEN_UI` routing where valid.

- [ ] **Step 5: Leave the completed Task unstaged**

  Inspect status only; do not stage or commit.

### Task C: Deterministic Particle and Trail

**Files:**

- Create: `src/preview/rendering/vfx_particle_layer_renderer.gd`
- Create: `src/preview/rendering/vfx_trail_layer_renderer.gd`
- Modify: `src/preview/rendering/vfx_preview_renderer_factory.gd`
- Modify: `src/preview/rendering/vfx_preview_canvas_render_host.gd`
- Test: `tests/preview/test_dynamic_layer_renderers.gd`
- Modify: `tests/run_preview_tests.gd`

**Interfaces:**

- Consumes: factory configuration and canonical instance specs from Task A,
  plus common lifecycle operations from Task B.
- Produces: deterministic canonical Particle packets and Trail point packets;
  no packet contains Edit/Game zoom or Control coordinates.

- [ ] **Step 1: Write failing Particle and Trail tests**

  Assert each emitter shape sample lies in declared geometry; BURST creates its
  exact count; CONTINUOUS uses its rate accumulator without exceeding
  `max_particles`; equal seeds generate equal canonical packets; source end
  stops new particles but keeps lifetime residuals; Trail preserves only
  unexpired points, caps count, tapers head/tail width, and stops sampling when
  its phase ends.

- [ ] **Step 2: Run focused tests and confirm failure**

  Expected before implementation: no dynamic renderer implementation is
  registered and no canonical residual state exists.

- [ ] **Step 3: Implement canonical dynamic simulation and projection adapters**

  Use deterministic CPU state for Particles and canonical point state for
  Trails. Capture VEHICLE_FOLLOW_WORLD_TRAIL positions through the vehicle
  transform once per spawn/sample, before Canvas zoom. Project Trail packets
  through per-canvas `Line2D` adapters with the catalog texture and a
  two-point width curve. Keep VEHICLE_LOCAL state under `FutureVfxHost` and
  never let captured world residuals inherit later vehicle motion.

- [ ] **Step 4: Run focused dynamic-renderer tests**

  Expected: source-local, follow-world, WORLD_AREA, and SCREEN_UI packet
  positions match the documented canonical-unit rules and all residual tests
  pass.

- [ ] **Step 5: Leave the completed Task unstaged**

  Inspect status only; do not stage or commit.

### Task D: Playback and Live Refresh

**Files:**

- Create: `src/preview/rendering/vfx_preview_playback_controller.gd`
- Create: `src/preview/rendering/vfx_preview_render_runtime.gd`
- Modify: `src/preview/vfx_preview_shared_state.gd`
- Modify: `src/preview/vfx_vehicle_preview.gd`
- Modify: `src/preview/vfx_vehicle_preview.tscn`
- Modify: `src/editor/main/vfx_editor_controller.gd`
- Test: `tests/preview/test_preview_playback.gd`
- Test: `tests/preview/test_preview_stale_state.gd`
- Modify: `tests/preview/test_editor_preview_integration.gd`
- Modify: `tests/run_preview_tests.gd`

**Interfaces:**

- Consumes: valid Plans and canonical renderer operations from Tasks A-C,
  existing editor commit/Undo/Redo refresh boundaries, selected editor phase,
  and vehicle motion mode.
- Produces: Auto/manual lifecycle routes, fixed-tick frame contexts, compact
  Preview status, and `VfxVehiclePreview.apply_render_plan(plan)` /
  `set_preview_validation_state(...)` boundaries.

- [ ] **Step 1: Write failing playback and stale-state tests**

  Assert ONE_SHOT source duration then drain; Auto START/LOOP/END uses an
  unsaved 2.0-second loop; manual mode activates only the selected phase;
  Pause freezes VFX and vehicle motion; Restart clears all residuals; a failed
  pipeline refresh retains the last valid Plan and displays stale state; an
  initially invalid document clears the host and displays validation error.

- [ ] **Step 2: Run focused tests and confirm failure**

  Expected before implementation: no playback state machine or last-valid-Plan
  policy is exposed by the Preview.

- [ ] **Step 3: Implement fixed-tick playback, controls, and controller refresh boundary**

  Add compact Play, Pause, Restart, and Auto Playback controls inside the
  reusable Preview scene. Make controller refresh build a document first and
  replace the active Plan only on success. Preserve the last Plan on error;
  never clamp or pass invalid Layer values to renderers. Keep selection overlay
  and playback state separate from document mutation. Do not modify
  `vfx_editor_main.tscn`.

- [ ] **Step 4: Run focused playback and integration tests**

  Expected: valid commit refreshes Preview immediately without Save; invalid
  commit reports stale/empty state without changing Renderer input; all
  lifecycle controls and pause/restart assertions pass.

- [ ] **Step 5: Leave the completed Task unstaged**

  Inspect status only; do not stage or commit.

### Task E: Renderer Showcase, Integration, and Regression

**Files:**

- Create: `presets/examples/utility.renderer_showcase.vfx.json`
- Create: `tests/preview/test_renderer_showcase.gd`
- Modify: `tests/preview/test_preview_foundation.gd`
- Modify: `tests/preview/test_editor_preview_integration.gd`
- Modify: `tests/editor/test_main_scene_smoke.gd` only if its existing smoke
  fixture needs to observe the runtime-inserted Preview; otherwise leave it unchanged
- Modify: `tests/run_preview_tests.gd`
- Modify: `docs/VFX_STUDIO_ARCHITECTURE.md`
- Modify: `docs/VFX_EDITOR_ROADMAP.md`

**Interfaces:**

- Consumes: all complete rendering, playback, asset, and host boundaries from
  Tasks A-D.
- Produces: a generic UTILITY example, durable architecture documentation,
  and final regression evidence without an Export system.

- [ ] **Step 1: Write failing showcase and end-to-end tests**

  Assert `utility.renderer_showcase` validates through the existing Contract
  pipeline; its five Layer Types each dispatch through the ordinary factory;
  Zero Zone exercises START/LOOP/END; Finish Confetti remains WORLD_AREA;
  Edit/Game consume a shared canonical frame; and Preview scene instantiate/
  free succeeds without the main scene file changing.

- [ ] **Step 2: Run focused showcase tests and confirm failure**

  Expected before implementation: showcase fixture does not exist and the
  complete five-renderer integration cannot dispatch.

- [ ] **Step 3: Add the generic showcase and update durable docs**

  Add no renderer special branch for the fixture. Update architecture and
  roadmap text with the valid-Plan/stale policy, canonical simulation versus
  projection boundary, render-plane host ordering, Preview-only assets, and
  continuing Studio-to-game repository isolation. Do not add Export policy.

- [ ] **Step 4: Run final regression once**

  Run:

  ```powershell
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_contract_tests.gd'
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_editor_tests.gd'
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\GodotProjects\DesktopRacingVFXStudio' --script 'res://tests/run_preview_tests.gd'
  & 'C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path 'C:\GodotProjects\DesktopRacingVFXStudio' --quit
  ```

  Expected: every suite passes, Preview scene smoke succeeds, and editor parse
  exits zero. Do not run Windows export.

- [ ] **Step 5: Leave the completed Phase unstaged**

  Inspect `git status --short` and `git diff --check`; report changed files,
  test exit codes, and preserved user changes. Do not stage or commit.

## Plan self-review

- Valid-working-state handling is Task D and is deliberately before renderer
  application; Tasks A-C never receive arbitrary working data.
- Canonical simulation and all four projection rules are established in Task A
  and exercised dynamically in Task C and end-to-end in Task E.
- All five Schema v1 Layer Types are covered by Tasks B and C, then by the
  generic showcase in Task E.
- Asset registry/missing behavior is Task A; playback/residual semantics are
  Task D; no task changes Schema, export, performance, or game integration.
- Every task has a focused fail-first/pass cycle and contains no Git commit
  step because SourceTree owns Git commits for this Phase.
