# DesktopRacingVFXStudio Roadmap

## Phase 0: contract foundation

Create the independent Godot 4.7.1 project, strict Schema v1, examples, contract services, test runner, and architecture documents. Verify JSON decode, normalize, validate, and deterministic encode in short headless runs. No editor UI, rendering, runtime resource export, or Desktop Idle Racing integration is included.

## Phase 1: Preset library and Layer Stack authoring

Shipped: a Layer Stack-oriented editor around the frozen contract with authoring-root Preset browse/open, New, valid-only Save/Save As, dirty-state protection, Undo/Redo, validation diagnostics, lifecycle Phase tabs (`ONE SHOT` or `START | LOOP | END`), Layer ordering, schema-driven common/type-specific properties, anchors, and Runtime Input declarations. The editor writes `.vfx.json` source only and does not introduce a Node Graph, preview renderer, export system, performance analyzer, migration framework, or Desktop Idle Racing dependency.

## Phase 2: preview and real-size readability

Shipped: a Studio-owned top-down miniature vehicle Preview with 200%/400% Edit Canvas, scroll-safe authoring, and an always 100% Game Canvas for actual-size readability. It supports static, rotate, and simple source-local motion; multi-anchor highlights; vehicle-local offset ghosts; and separate empty FutureVfxHost transform boundaries for the later renderer. The Game Canvas deliberately suppresses Anchor labels and edit controls so a roughly 20 to 24 by 41 to 49 pixel vehicle remains readable.

Phase 2 also ships editable, storable Vehicle Anchor Profiles for exactly `FORMULA`, `SPORTS`, `GT`, and `HYPER`. Each Profile maps Schema v1 vehicle Anchors such as CENTER, FRONT, REAR, TIRE, and WING to its Studio-owned reference Sprite. Profile data is independent from Preset editing and is not a Schema v1 or game-runtime resource. Phase 2 adds no VFX rendering, LOD evaluator, or game-repository dependency.

## Phase 3: focused 2D Layer rendering

Shipped: a Studio-only, valid-Plan-only Canvas preview for Particle, Trail, Ring, Glow, and Shield. It uses a shared fixed-tick playback clock for Edit and Game, deterministic Particle/Trail residuals, Phase-aware Auto/manual playback, declared render-plane/blend routing, and a small Preview asset catalog with a visible missing-asset fallback. A temporary invalid edit keeps the last valid Plan visible and reports a stale validation state instead of sending unvalidated values to a renderer.

Phase 3 keeps the renderer mapping separate from Schema authoring data and retains Layer Importance on immutable Plan specs as the Phase 4 LOD/performance seam. It does not add a generic VFX runtime, game resources, Export, pools, a performance analyzer, LOD UI, Particle gameplay behavior, or a DesktopIdleRacing dependency.

## Phase 4: performance analysis

Shipped: a Studio-only, `UNCALIBRATED` Authoring Budget and Studio Preview
Stress workflow. It derives a Lifecycle Envelope separately from an enabled
Active Stress Workload Budget, applies immutable HIGH/MEDIUM/LOW Importance
filters, projects the named 1x1 through 20x3 `VEHICLE_STRESS` scenarios, and
shows SAFE/CAUTION/HEAVY only as Uncalibrated Authoring Guidance. A dedicated
same-scale Stress Stage compares a VFX-disabled vehicles-only baseline with
the synchronized selected workload and retains a session-only paired Snapshot.

The Phase 4 result is explicitly Preview Frame Time information from the
DesktopRacingVFXStudio renderer, not a DesktopIdleRacing game performance,
game FPS, game-safe, GPU-time, or target-hardware claim. It records VSync and
frame-cap context, supports an opt-in temporary uncapped Studio run, and keeps
the original settings on every completion path. Only `VEHICLE_STRESS` exists;
Celebration Stress, Dynamic/Auto LOD, a benchmark database, Export, and game
runtime integration remain future work. Generated cost reports and any later
exports remain derived artifacts rather than Preset source data.

## Phase 5: export contract

Shipped: a saved-source-only, fail-closed VFX Package exporter. A valid saved
Preset produces a deterministic, self-contained package under
`exports/packages/<preset_id>/` with a canonical raw Source copy, normalized
Runtime Definition, production PNG dependencies, and a SHA-256 Manifest. The
runtime-created Export workspace blocks unsaved or dirty sessions and requires
explicit confirmation before whole-package replacement.

The Studio remains one-way: `DesktopRacingVFXStudio -> VFX Export Package ->
DesktopIdleRacing importer/runtime`. Phase 5 creates no importer, game
repository dependency, game-trigger logic, renderer, dynamic LOD, Performance
export, Windows export, screenshot, or remote upload. Final Packages are
reviewable artifacts; only temporary `exports/.staging/` and
`exports/.backup/` paths are ignored.

## Advanced VFX Coverage: evidence-driven extension

After export is established and before broad Preset expansion, add an Advanced VFX Coverage step only for concrete needs discovered while authoring Presets or implementing focused renderers. Candidate capabilities are Beam or Ray, Electric Arc, extended Radial Burst, Shockwave Radius Preview, Target Dummy or Target Hit Preview, Screen/UI VFX Preview, Distortion or Heat Haze, and Orbit when justified.

This is not authorization to add these features to Schema v1 or Phase 0. Each accepted capability must be added compatibly, with a demonstrated authoring or renderer requirement, while preserving the YAGNI principle.

## Preset expansion

Author the planned 35 to 40 effects by combining common Layer Types and modules rather than by adding bespoke code paths. Add Schema fields only when a concrete renderer need proves the existing contract insufficient and the extension remains compatible with v1 authoring.

## Persistent non-goals

- No Node Graph.
- No 3D VFX authoring.
- No generic Shader Graph.
- No general-purpose Timeline Editor.
- No external JSON Schema dependency.
- No dependency on the existing Desktop Idle Racing project during Studio foundation work.
