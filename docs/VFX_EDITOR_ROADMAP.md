# DesktopRacingVFXStudio Roadmap

## Phase 0: contract foundation

Create the independent Godot 4.7.1 project, strict Schema v1, examples, contract services, test runner, and architecture documents. Verify JSON decode, normalize, validate, and deterministic encode in short headless runs. No editor UI, rendering, runtime resource export, or Desktop Idle Racing integration is included.

## Phase 1: Preset library and Layer Stack authoring

Shipped: a Layer Stack-oriented editor around the frozen contract with authoring-root Preset browse/open, New, valid-only Save/Save As, dirty-state protection, Undo/Redo, validation diagnostics, lifecycle Phase tabs (`ONE SHOT` or `START | LOOP | END`), Layer ordering, schema-driven common/type-specific properties, anchors, and Runtime Input declarations. The editor writes `.vfx.json` source only and does not introduce a Node Graph, preview renderer, export system, performance analyzer, migration framework, or Desktop Idle Racing dependency.

## Phase 2: preview and real-size readability

Add a top-down miniature vehicle preview, 100% game-size inspection, multi-anchor visualization, and LOD visibility review. This phase emphasizes whether CORE layers remain recognizable at the actual vehicle size instead of only at zoomed inspection size.

Phase 2 also introduces editable, storable Vehicle Anchor Profiles for the `Formula`, `Sports`, `GT`, and `Hyper` vehicle categories. A Profile maps the Schema v1 vehicle Anchors such as CENTER, FRONT, REAR, TIRE, and WING to positions on the actual vehicle Sprite for that category. It is preview authoring data, not a Schema v1 or Phase 0 feature.

## Phase 3: focused 2D Layer rendering

Implement the approved Particle, Trail, Ring, Glow, and Shield Layer renderers. Resolve Phase activation, effective Space Mode, Layer residual lifetime, blend, transform, render plane, and importance-based LOD. Keep renderer mapping separate from authoring data and avoid a generic VFX runtime.

## Phase 4: performance analysis

Derive renderer-aware cost estimates from Presets, preview worst-case 20 cars by 3 VFX, and surface LOD behavior. Generated cost reports are derived artifacts, not source data.

## Phase 5: export contract

Generate game-facing resources and manifests from validated `.vfx.json`. Decide Git policy for generated files and export packages here. The game receives exported runtime data and decides trigger timing, targets, and ownership.

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
