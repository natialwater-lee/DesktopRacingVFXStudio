# DesktopRacingVFXStudio Phase 3: Focused 2D Layer Rendering Design

## Goal

Phase 3 adds an actual, Studio-only 2D VFX Preview for the five Schema v1
Layer Types: `PARTICLE`, `TRAIL`, `RING`, `GLOW`, and `SHIELD`. It makes the
existing Edit and Game views evaluate the same Preset lifecycle, vehicle
transform, anchors, and track scale while preserving their distinct projection
rules.

The Phase is a focused authoring Preview. It is not a Desktop Idle Racing
runtime, renderer export pipeline, generic VFX framework, performance
analyzer, Node Graph, Shader Graph, or gameplay simulation.

## Confirmed constraints

- `.vfx.json` and Schema v1 remain unchanged and remain the authoring
  contract. No Schema enum, field, rule, default, or parameter is added.
- The Preview never reads a `.vfx.json` path directly and never mutates
  Preset working data.
- The data path is `working data -> valid document -> Render Plan -> playback
  and canonical simulation -> per-canvas projection and drawing`.
- Type dispatch is generic by Layer Type. No code path branches on Preset ID,
  including `talent.zero_zone` and `utility.renderer_showcase`.
- The game repository is not read, modified, staged, or used as an output
  directory.
- `project.godot`, `src/editor/main/vfx_editor_main.tscn`, and the four
  Vehicle Profile JSON files are pre-existing user changes. Phase 3 does not
  reset, revert, overwrite, stage, or commit them.
- Phase 3 does not automatically run `git add` or `git commit`. The working
  tree is left for SourceTree-managed commits.

## Valid working data and stale Preview policy

Phase 1 intentionally allows a transient-invalid `VfxPresetEditSession`
working copy. A Preview renderer must never receive that invalid value or
silently repair it.

On a content-changing editor commit, `VfxEditorController` performs this
sequence:

```text
working copy
  -> VfxPresetPipeline.build_document_from_value(...)
  -> normalized + contract-valid VfxPresetDocument
  -> VfxPreviewRenderPlanBuilder.build(document.normalized_data)
  -> VfxVehiclePreview.apply_render_plan(plan)
```

Only a successful pipeline result may replace the active Preview Plan. The
builder receives a deep-copied normalized Dictionary owned by the document;
it does not load files and does not normalize or validate input itself.

If contract validation reports an error:

- no invalid value reaches a Renderer;
- the renderer performs no clamping, correction, or invalid-Layer skipping;
- the last successful valid Render Plan remains active;
- the Preview displays a compact `PREVIEW STALE — VALIDATION ERROR` state;
- when there has never been a successful Plan, the Renderer Hosts are cleared
  and the validation state is displayed instead.

The stale marker is Preview presentation only. It changes neither Contract
validation nor Save/Save As policy. Logical asset lookup failures are different:
they keep a valid Plan active, display a `preview_asset_missing` Preview
warning, and use the explicit magenta fallback.

The last valid Plan is content data only. Selecting another Phase or Layer may
still update playback selection and the existing selection overlay. A
content-invalid state must not cause the renderer to resolve a new Layer from
the invalid working Dictionary.

## Render Plan boundary

The following focused Preview models live under `src/preview/rendering/`.

- `VfxPreviewRenderPlan`: immutable preset id, lifecycle mode, phase plans,
  and a monotonically increasing content revision.
- `VfxPreviewPhasePlan`: phase name, optional declared duration, and ordered
  Layer specs.
- `VfxPreviewLayerSpec`: immutable normalized common Layer values,
  type-specific parameter Dictionary, effective Space Mode, and source array
  order.
- `VfxPreviewRenderInstanceSpec`: a Layer spec expanded for one resolved
  Anchor, or one anchorless World/Screen instance.
- `VfxPreviewRenderPlanBuilder`: reads Schema-derived field and lifecycle
  configuration through `VfxSchemaRegistry`, then builds a Plan from valid
  normalized data.
- `VfxPreviewInstanceResolver`: combines a Plan with the selected Vehicle
  Profile and produces canonical runtime instances. Profile coordinates never
  become Preset data.

The builder preserves disabled Layers and their `importance`, `sort_order`,
and source array order in the Plan. The runtime excludes disabled instances
from drawing. Stable order within the same render plane is:

```text
sort_order -> phase Layer array index -> declared Anchor index
```

Every vehicle-space Anchor produces one independent runtime instance. A
missing Profile Anchor is a Preview configuration diagnostic; it is never
replaced with `CENTER`.

`VfxPreviewLayerContextResolver` remains responsible for the selected-Layer
anchor/ghost overlay. It is not the renderer's source of Preset data.

## Canonical simulation and per-canvas projection

There is one canonical Phase 3 simulation per active valid Plan. It stores no
Edit zoom, Control size, DPI, or Game inset size. `VfxPreviewPlaybackController`
advances it on one fixed Preview tick and produces canonical draw packets.
Edit and Game Canvas renderer hosts project the same packets independently.

This avoids duplicate particle/trail simulation and guarantees that the two
views share time, seeded sampling, phase activation, residual age, and vehicle
motion. Canvas-specific values are applied only at the final projection step.

`VfxPreviewPlaybackController` also drives the existing Preview motion modes.
Therefore Pause freezes both VFX state and the preview vehicle transform;
ROTATE and SIMPLE_MOTION cannot continue changing a supposedly paused frame.

### Coordinate spaces and units

All angle semantics use Godot 2D coordinates: `+X` is right, `+Y` is down,
zero degrees points to `+X`, and positive degrees rotate clockwise on screen.

| Effective Space Mode | Canonical simulation unit and origin | Vehicle scale at simulation | Canvas projection |
|---|---|---|---|
| `VEHICLE_LOCAL` | source-local pixels; each instance origin is `anchor + transform.offset` | vehicle translation, vehicle rotation, and effective game scale remain inherited | Game: effective scale × 1. Edit: effective scale × 2 or ×4 |
| `VEHICLE_FOLLOW_WORLD_TRAIL` | canonical preview-world coordinates captured at each spawn/sample | effective vehicle scale and transform are used once to convert spawn/sample into preview world | both views apply only their view zoom after capture |
| `WORLD_AREA` | preview-world units around the stage origin; `transform.offset` is a world displacement | never | Game: ×1. Edit: ×2 or ×4; this is world-scene magnification, not vehicle scaling |
| `SCREEN_UI` | viewport pixel coordinates around that view's viewport center; `transform.offset` is a UI displacement | never | neither vehicle/track scale nor Edit 200/400% zoom applies |

Layer transform semantics are uniform. `offset` moves a Layer origin. Its
`rotation_degrees` and non-uniform `scale` transform emitter geometry,
velocity/acceleration vectors, radii, widths, and sprite geometry in that
Layer's coordinate space. They do not introduce an additional hidden offset.

For `VEHICLE_FOLLOW_WORLD_TRAIL`, Particle positions and Trail samples stop
inheriting vehicle translation, rotation, and scale immediately after capture.
Their residual life can therefore be inspected while the vehicle continues to
move. `WORLD_AREA` and `SCREEN_UI` never receive an Anchor because Schema v1
already rejects one.

### Concrete canvas host layout

`VfxVehiclePreviewCanvas` is refactored internally so vehicle art is a real
child render host rather than an inseparable parent draw operation. This makes
Schema render planes observable instead of decorative. The main editor scene
is not changed.

```text
VfxVehiclePreviewCanvas
  BackgroundHost
  StageWorldRoot (position: stage centre, scale: view_zoom)
    WorldPlaneHost
    UnderFollowWorldHost
    FutureVfxHost / VehicleRoot
      UnderVehicleLocalHost
      VehicleArtHost
      OverVehicleLocalHost
    OverFollowWorldHost
  ScreenUiPlaneHost
```

The resulting draw order is fixed as `WORLD -> UNDER_VEHICLE -> vehicle art ->
OVER_VEHICLE -> SCREEN_UI`. `WORLD` is intentionally its own world-plane
context, not an alias for Under/Over vehicle ordering. `SCREEN_UI` is always
topmost and not part of the scrollable Edit Canvas stage: the Edit host is an
overlay sibling of `EditScroll` inside `PreviewSurface`; the Game host is an
overlay within the Game inset. This preserves viewport-pixel semantics.

`FutureVfxHost` remains the vehicle source-local transform boundary promised
by Phase 2. It contains only vehicle-local Under/Over hosts. World-follow
residuals are sibling world hosts because putting them under `FutureVfxHost`
would incorrectly move them with the vehicle.

## Renderer registry and interfaces

`x_vfx_layer_types` remains the source of truth for authorable Layer Types.
Renderer class registration is an implementation mapping, not a duplicate
authoring contract:

```text
PARTICLE -> VfxParticleLayerRenderer
TRAIL    -> VfxTrailLayerRenderer
RING     -> VfxRingLayerRenderer
GLOW     -> VfxGlowLayerRenderer
SHIELD   -> VfxShieldLayerRenderer
```

`VfxPreviewRendererFactory` reads the Schema list and compares it with the
explicitly registered implementation map at startup. A Schema type with no
renderer, or a registered renderer absent from Schema, produces a clear
Preview configuration error. There is no reflection, plug-in discovery, or
generic runtime system.

Each renderer is a small type-specific canonical simulator/draw-packet
producer with this common responsibility surface:

- configure an immutable `VfxPreviewRenderInstanceSpec` and resolved asset;
- restart at a canonical frame context;
- fixed-tick advance while its source is active;
- stop new emission/sampling when a Phase ends;
- report and clear residual state;
- return draw packets without Canvas zoom or viewport placement.

`VfxPreviewCanvasRenderHost` owns only per-canvas Node/CanvasItem projection,
plane routing, materials, and drawing. It does not own particle age, Trail
points, lifecycle timing, or random state.

## Type-specific rendering semantics

### PARTICLE

Particle preview uses a compact deterministic CPU simulator and batched
custom drawing rather than `GPUParticles2D`. This keeps v1's emitter shape,
fixed-tick playback, explicit capacity, exact Restart behavior, and
world-follow residuals visible without treating Godot node settings as hidden
authoring parameters.

- `BURST` creates exactly `burst_count` particles on activation.
- `CONTINUOUS` uses a rate accumulator and never exceeds declared
  `max_particles`.
- `POINT` emits at the origin; `CIRCLE` distributes inside its radius;
  `BOX` distributes around its centered size; `CONE` distributes in its
  centered `+X` sector; `LINE` distributes along its centered `+X` length.
- Direction/spread, speed ranges, initial rotation ranges, and angular
  velocity ranges use a stable seed derived from plan revision, phase, Layer
  id, Anchor index, and playback generation.
- `size_start` to `size_end` is linear over `lifetime_seconds`.
- `color_rgba` remains fixed for a particle lifetime. There is no implicit
  fade, noise, velocity bias, or gameplay input binding.

### TRAIL

Trail uses one `Line2D` projection adapter per active runtime instance. Its
canonical samples are owned by the shared renderer, then projected into each
Canvas host.

- newest point/source head uses `width_start`; oldest tail uses `width_end`;
- samples older than `lifetime_seconds` are removed and count never exceeds
  `max_points`;
- the phase ending stops new samples but does not delete valid residual
  points;
- `texture_asset_ref` resolves through the Preview Asset Registry; the Line
  adapter uses the resolved texture and a generated two-point width curve.

### RING

Ring is a draw-based arc/circle renderer. An activation creates one Ring;
`radius_start` to `radius_end` interpolates linearly for its declared
`duration_seconds`. `repeat_interval_seconds = 0` means activation-only; a
positive interval creates new Rings while the source Phase remains active.
The ring's color is constant `color_rgba`; it has no undeclared fade.

### GLOW

Glow uses a small generated radial gradient texture and a normal CanvasItem
material, not a Shader Graph. `radius` sets its geometry and `opacity` sets
its alpha. Phase 3 defines the existing `pulse_hz` field precisely:

```text
alpha(t) = opacity * (0.5 + 0.5 * sin(2 * PI * pulse_hz * t))
```

`pulse_hz = 0` is constant opacity. The formula ranges from zero to opacity.
There is no hidden pulse amplitude, noise, or fade parameter; a future need
for a non-zero pulse floor requires a Schema extension approved at that time.

### SHIELD

Shield is a polar annulus. `arc_degrees = 360` creates a full bubble; smaller
values create an arc centered on local `+X`, then placed by Layer rotation.
`radius`, `thickness`, `opacity`, and `color_rgba` are direct geometry/color
values. An optional texture is sampled along arc UVs, and `scroll_speed`
advances only that texture coordinate. With no texture, the Shield is a solid
colored arc and scroll has no visual effect.

A single fixed, non-editable CanvasItem shader is permitted for Shield UV
scrolling and its two Schema blend modes. It is not a Shader Graph or a
general material authoring surface.

## Lifecycle and playback

`VfxPreviewPlaybackController` owns the states `IDLE`, `PLAYING`, `PAUSED`,
`DRAINING`, and `TERMINATED`.

- `ONE_SHOT`: activate `one_shot` at zero, stop sources at its declared
  duration, then remain in `DRAINING` only while declared Particle/Trail/Ring
  residuals remain.
- `START_LOOP_END`, Auto Playback enabled: activate `start`, then `loop` for
  a Preview-only default of 2.0 seconds, then `end`, then drain. The loop
  duration is Preview state and is never serialized into the Preset.
- Auto Playback disabled: the current editor Phase is isolated. Selecting a
  phase resets it at time zero; Play advances only that phase. A loop phase
  continues until Pause or Restart, while timed phases stop new sources at
  their declared duration.
- Pause freezes simulation time, motion time, source emission, and residual
  aging.
- Restart clears every particle, Trail sample, and active Ring before
  returning the chosen Auto/manual route to time zero.

Glow and Shield have no Schema lifetime after deactivation, so they do not
create an invented residual tail. Particle, Trail, and Ring persist only by
their declared lifetime/duration.

## Preview Asset Registry

`assets/preview/vfx_preview_asset_catalog_v1.json` is Studio-owned data,
separate from Presets and game resource paths. `VfxPreviewAssetRegistry` loads
the catalog and `VfxPreviewAssetResolver` returns generated or static Preview
resources by logical ID. Initial entries are:

- `fx.energy_shard`: procedural diamond;
- `fx.confetti_square`: procedural square;
- `fx.trail_streak`: generated narrow streak texture;
- `fx.placeholder`: neutral fallback dot.

The catalog maps logical ids to Preview primitive/resource definitions. It
does not know a game path, exported `.tres`, or Preset ID. A missing id returns
a clearly magenta fallback plus the non-contract `preview_asset_missing`
warning; it does not invalidate the Preset Contract.

## Presets, LOD, and Phase 4 seam

`presets/examples/utility.renderer_showcase.vfx.json` is added as a valid
`UTILITY` Studio verification Preset using all five Layer Types through the
ordinary factory. It is not a special renderer case and has no Phase 3 export
policy.

The Preview evaluates all enabled `CORE`, `DETAIL`, and `EXTRA` Layers, but
retains Importance on every Plan/instance spec. The Plan also exposes a
read-only expanded-instance view containing Multi Anchor counts, Particle
capacity, and Trail max points. This is a Phase 4 performance-inspection seam,
not an analyzer, LOD control, 20-car simulation, or pooling system.

## Focused verification strategy

Phase 3 adds Preview tests without screenshot comparison:

- valid normalized working data builds a Plan; invalid data preserves the last
  valid Plan or clears an initially empty Preview;
- Schema Layer Types and renderer registrations have exact one-to-one
  coverage;
- plan ordering, enabled state, Multi Anchor expansion, plane routing, and
  all four Space Mode projection rules are asserted;
- asset catalog resolution, missing fallback, and warning behavior are
  asserted;
- Particle burst/continuous capacity, Trail expiry, Ring repeat, Glow pulse,
  and Shield arc packet semantics are asserted in canonical coordinates;
- lifecycle Auto/manual routes, pause, restart, and drain residual behavior
  are asserted;
- both Canvas hosts consume the same canonical frame with their respective
  projection only;
- renderer scene/host instantiate/free remains safe in headless mode.

Final implementation verification runs the existing Contract, Editor, and
Preview suites, a Preview scene instantiate/free smoke check, and Godot 4.7.1
headless editor parse. Windows export is out of scope.

## Scope exclusions

Phase 3 does not change Schema v1, implement game runtime resources, export,
Performance Analyzer, LOD controls, pooling, GPUParticles2D hierarchy,
Target/Hit Preview, Beam/Ray, Electric Arc, Distortion, Orbit, a generic
timeline, Shader Graph, or DesktopIdleRacing integration.
