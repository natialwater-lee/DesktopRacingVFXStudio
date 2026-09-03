# DesktopRacingVFXStudio Architecture

## Purpose and scope

DesktopRacingVFXStudio is an independent Godot 4.7.1 stable project for authoring 2D VFX used by Desktop Idle Racing. It is not a generic VFX package, a Node Graph editor, a 3D tool, or a gameplay-decision system.

The Studio owns how an effect looks. The game owns when an effect is created, which vehicle or world position receives it, gameplay targeting, and the lifetime of a START_LOOP_END loop.

Phase 0 establishes the project foundation and data contract. Phase 1 adds a contract-backed Layer Stack authoring surface for `.vfx.json` Presets. Phase 2 adds Studio-owned Vehicle Anchor Profiles and a miniature readability Preview. Phase 3 adds a focused Studio-only Canvas preview for the five Schema v1 Layer Types. None of these phases includes an export pipeline, generated game assets, or changes to the Desktop Idle Racing project.

## Source of truth and boundaries

Each authorable preset is a `.vfx.json` file. This file is the source of truth. Future Godot `.tres` resources, manifests, generated reports, and export packages are derived artifacts and must not become inputs required to reopen or edit a preset.

The contract has three separate representations:

- Raw data: the JSON-decoded `Variant`, preserved unchanged for diagnostics and comparison.
- Normalized data: a deep-copied `Variant` with only Schema-declared defaults applied.
- Usable preset: a validated normalized top-level `Dictionary` contained by `VfxPresetDocument`.

The normal flow is:

```text
.vfx.json file
  -> decode Variant
  -> normalize deep copy
  -> validate contract
  -> usable VfxPresetDocument
  -> deterministic normalized pretty JSON
```

## Studio and game repository isolation

The permanent integration direction is one-way:

```text
DesktopRacingVFXStudio
  -> VFX Export Package
  -> DesktopIdleRacing importer/runtime
```

The Studio must not read from, modify, format, stage, commit, or use the DesktopIdleRacing repository as an output directory. It owns authoring source, Studio reference assets, Preview Profiles, and derived export packages only. A DesktopIdleRacing-specific importer/runtime project is responsible for accepting an exported package and for gameplay activation, targets, ownership, and runtime lifecycle.

## Phase 5 export package boundary

Phase 5 adds a derived, reviewable VFX Package at the fixed Studio location
`res://exports/packages/<preset_id>/`. `VfxExportService` only accepts a saved
authoring path, reloads it through `VfxPresetPipeline`, and compiles an
immutable `VfxExportPackagePlan`. A dirty or unsaved editor session is blocked
before the service runs. The package contains a deterministic canonical source
copy, a normalized portable runtime definition, explicitly approved Production
assets, and a SHA-256 inventory Manifest. It is not a new source of truth.

The export writer validates a complete staging tree before atomically replacing
the final package. Temporary staging and backup directories are ignored; final
packages remain reviewable project artifacts. Export neither serializes Preview
or Performance data nor opens a game-project path. The full importer-facing
format and validation requirements are in `docs/VFX_EXPORT_PACKAGE_V1.md`.

Package Format v1 selects a Runtime Definition per Preset: static authoring
uses Runtime Definition v1 while a Preset with declared Runtime Modulation uses
portable Runtime Definition v2. The compiler decides this once in immutable
`VfxExportPackagePlan`; the existing atomic writer writes its selected relative
runtime path without inferring a version. A v2 Package is a complete replacement
tree, so it cannot retain a stale v1 runtime file. The derived Runtime contract
contains source declarations, mappings, clamps, pivots, and input requirements,
but never Preview elapsed time, UI values, evaluator slots, packets, or
performance state.

## Vehicle Preview and Anchor Profiles

Phase 2 adds four editable Studio-owned vehicle Profile categories: `FORMULA`, `SPORTS`, `GT`, and `HYPER`. Each strict Profile JSON maps every Schema v1 vehicle Anchor to unscaled source-local pixels of its 256 by 512 reference PNG; it is separate from Preset `.vfx.json` data and from game runtime resources.

The Preview always keeps its Game Canvas at native reference size multiplied only by `base_car_sprite_scale * car_visual_scale * selected_track_scale`. Its Edit Canvas independently uses 200% or 400% zoom with scrolling. Both project the same Profile and Preview-only transform state through their own stage centre and zoom. The Game Canvas is a readability inset, so it suppresses Anchor labels and edit handles; it shows only the vehicle, a tiny selected-Layer Anchor marker, and a Phase 3 insertion boundary.

`VfxEditorController` owns Preset selection. It sends only a resolved immutable `VfxPreviewLayerContext`—Layer id, effective Space, declared Anchors, local transform offset, and render plane—to the Preview. Preview code never reads or modifies Preset JSON. Each Edit and Game Canvas exposes a separate empty `FutureVfxHost` with the vehicle's source-local transform; these are coordinate boundaries for Phase 3, not a renderer, particle hierarchy, pool, shader, or lifecycle implementation.

The codec never assumes decoded JSON is a `Dictionary`. A valid JSON array, string, or number reaches validation and receives a `PRESET_VALIDATION` error at `/type`.

## Phase 3 Preview Renderer

The Preview accepts only a successful normalized `VfxPresetDocument` through a read-only `VfxPreviewRenderPlan`. The Editor controller builds that Plan after each content change; it does not pass a file path, a raw JSON value, or the mutable edit session to a renderer. Selecting a Layer still changes the independent overlay context but does not rebuild or mutate the active Plan.

If a working edit is temporarily contract-invalid, the last valid Plan remains rendered and the Preview reports `PREVIEW STALE — VALIDATION ERROR`. If no valid Plan has ever been built, all render hosts are cleared. The Preview neither clamps nor repairs invalid Layer data. Preview asset misses are separate non-contract warnings: a valid Plan stays active and the Studio-owned resolver uses a conspicuous magenta fallback.

One fixed-tick `VfxPreviewPlaybackController` drives Phase activation, residual drain, seeded Particle simulation, Trail sampling, and Preview motion. `ONE_SHOT` stops source emission at its declared duration and drains declared renderer residuals. Auto `START_LOOP_END` uses a Preview-only two-second Loop; it is not serialized. Manual playback isolates the selected Phase. Pause freezes both fixed simulation time and vehicle motion; Restart clears every active residual before beginning the selected route.

Canonical packets contain no Control size, DPI, Edit zoom, or Game inset fitting. `VEHICLE_LOCAL` remains source-local beneath `FutureVfxHost`; `VEHICLE_FOLLOW_WORLD_TRAIL` captures transformed world positions once per spawn/sample; `WORLD_AREA` is stage-world data; and `SCREEN_UI` is viewport-pixel data. Edit and Game hosts consume the same canonical packets and apply only their own projection: 200%/400% stage zoom for Edit and exactly 100% for Game.

Canvas ownership is deliberately concrete:

```text
VfxVehiclePreviewCanvas
  background draw
  StageWorldRoot (stage centre and Edit-only zoom)
    WorldPlaneHost
    UnderFollowWorldHost
    FutureVfxHost (vehicle transform)
      UnderVehicleLocalHost
      VehicleArtHost
      OverVehicleLocalHost
    OverFollowWorldHost
  OverlayHost
```

`WORLD`, under-vehicle, vehicle art, over-vehicle, and overlay therefore have observable ordering. The reusable Preview additionally owns per-view Screen UI host boundaries; these are viewport overlays rather than vehicle- or scroll-content descendants. `FutureVfxHost` remains the Phase 2 seam for a later game-facing Renderer architecture, but no game runtime node hierarchy is assumed by Phase 3.

`VfxPreviewRendererFactory` checks its small implementation mapping against Schema `x_vfx_layer_types` at startup. It dispatches `PARTICLE`, `TRAIL`, `RING`, `GLOW`, `TEXTURED_SPRITE`, and `SHIELD` only by Layer Type—never by Preset ID. Particle and Trail use compact deterministic CPU state; Ring and Glow produce direct Canvas geometry; `TEXTURED_SPRITE` keeps one persistent texture packet while its Phase is active, and Runtime Modulation updates its numeric transform/alpha in place without changing packet identity; a textured Shield uses a fixed polar-annulus shader adapter with immutable Alpha/Additive variants solely for Schema blend behavior and UV scrolling. There is no Shader Graph or material authoring surface. The renderer respects declared blend mode, transform, render plane, Source lifetime, and Layer order. `importance` remains present in immutable specs as the Phase 4 performance/LOD seam; Phase 3 does not add a LOD control or analyzer.

## Runtime Modulation v1 Preview boundary

Validated modulation authoring compiles once into an immutable program with numeric
source, input, target, and operation slots. LOD and disabled-Layer filtering happen
before evaluator activation; a second filter retains only successfully constructed
renderer entries. A zero-binding program allocates no evaluator state.

Phase A consumes that effective state only in the generic `TEXTURED_SPRITE`
renderer. The pivot is Layer-local texture geometry relative to texture center. For
base origin `O`, base matrix `M_base`, effective matrix `M_effective`, pivot `p`,
and dynamic offset `D`, the source-local origin is
`O + M_base*p + D - M_effective*p`. This preserves the selected attachment point;
offset modulation intentionally moves it. Session-only speed/load controls refresh
the canonical Preview runtime and never alter source JSON, dirty state, Undo/Redo,
or Export data.

Preview assets are declared in `assets/preview/vfx_preview_asset_catalog_v1.json` with logical IDs such as `fx.energy_shard` and `fx.trail_streak`. A catalog entry has a deliberately small `source`: `PROCEDURAL` retains the Studio primitive path, while `TEXTURE` resolves only its Studio-owned `texture_path` through `VfxPreviewAssetResolver`. Presets continue to serialize only logical IDs; they never serialize an `res://` texture path, and the catalog never discovers a game repository.

For a Texture Particle, `size_start` and `size_end` retain the procedural Particle half-size meaning. The Texture's longest displayed dimension is `2 × packet.size`; native PNG dimensions provide aspect ratio only. Existing packet geometry scale then applies the declared Layer transform and its effective Space projection, exactly as for a procedural Particle. `PARTICLE` and `RING` may author linear `alpha_start` / `alpha_end` factors; their Renderers write the resulting lifetime scalar to `packet.alpha` without changing `color_rgba`. Canvas modulation multiplies texture RGB/alpha by the declared Particle `color_rgba` and `packet.alpha`, so Texture alpha, color alpha, and lifetime alpha remain independent factors. It adds no color correction, automatic glow, curve, or easing. Missing or invalid texture paths remain Preview-only warnings with a cached magenta fallback, so they do not invalidate a Preset contract.

Studio production art lives under `assets/vfx/`. `fx.energy_shard` resolves `assets/vfx/energy_shard.png` and `fx.energy_spark` resolves `assets/vfx/energy_spark.png`; both remain logical IDs in Zero Zone Preset data. Their 64 by 64 and 32 by 32 native dimensions respectively affect only texture aspect, not the Particle display-size contract. The deliberately non-production `tests/fixtures/preview/texture_particle_test.png` entry remains for `utility.renderer_showcase` and regression coverage. The generic showcase continues to prove ordinary dispatch for all five v1 Layer Types.

## Phase 4 Studio Preview Stress and Authoring Budget

Phase 4 is a Studio-only authoring aid, not a DesktopIdleRacing performance
benchmark. Its permanent terms are **Authoring Budget**, **Studio Preview
Stress**, **Preview Frame Time**, **Preview Frame Time Delta**, and
**Uncalibrated Authoring Guidance**. A `SAFE`, `CAUTION`, or `HEAVY` policy
result describes only the current Studio policy applied to a derived Preview
workload. It never claims game performance, game FPS, game safety, target
hardware behavior, or GPU time; GPU time remains `N/A`.

The Studio policy in `config/vfx_performance_policy_v1.json` owns the manual
`HIGH`, `MEDIUM`, and `LOW` maps, named `VEHICLE_STRESS` scenarios, timing, and
initial thresholds. It is explicitly `UNCALIBRATED`. The policy loader checks
its Importance strings against the Schema Registry rather than maintaining a
second enum declaration. `VfxPreviewLodFilter` produces a new immutable Render
Plan for both normal Authoring Preview and Studio Stress: HIGH includes CORE,
DETAIL, EXTRA; MEDIUM includes CORE and DETAIL; LOW includes CORE. It never
mutates a Preset, edit session, source Plan, or saved JSON. Normal Preview and
Stress retain independent session LOD selections.

`VfxPerformanceBudgetAnalyzer` presents two non-interchangeable derived views.
The **Lifecycle Envelope** is a structural inventory across all filtered
lifecycle phases and can include disabled Layer records for authoring context.
The **Active Stress Workload Budget** includes only enabled instances in the
selected workload: `STEADY_LOOP` uses `loop` for `START_LOOP_END`, and
`REPEATED_ONE_SHOT` uses `one_shot` for `ONE_SHOT`. Scenario projection sums
enabled Slot workloads per vehicle and multiplies by vehicle count. Only that
active projection reaches SAFE/CAUTION/HEAVY guidance; no all-phase inventory
is mislabelled as a simultaneous renderer count.

The runtime-inserted `VfxPreviewWorkspace` keeps the existing Editor scene
unchanged and separates **AUTHORING PREVIEW** from **PERFORMANCE**. The latter
contains distinct **AUTHORING BUDGET** and **STUDIO PREVIEW STRESS RESULT**
regions. It currently supports only `VEHICLE_STRESS`; `CELEBRATION_STRESS` is
an explicit unavailable future seam, not a category-derived behavior.

One Studio Stress run uses `VfxPerformanceStressStage`, a dedicated minimal
vehicle grid rather than twenty editor controls. It preserves the Vehicle
Preview Game Scale Contract (`base_car_sprite_scale * car_visual_scale *
track_scale`) without fit scaling. The stage is prepared once, then follows:

```text
PREPARE
  -> BASELINE_WARMUP
  -> BASELINE_MEASURE
  -> VFX_WARMUP
  -> VFX_MEASURE
  -> COMPLETE | CANCELLED | ERROR
```

The baseline uses that same prebuilt stage, vehicle nodes, profiles, grid, and
asset/runtime allocations, but leaves every VFX slot disabled. It does not
advance playback, simulate particles or rings, sample trails, generate
packets, or route VFX draws. VFX warm-up then enables the same synchronized
slots and absorbs first-use work before VFX measurement.

`VfxRuntimeMetricAccumulator` collects only measurement frames. A session-only
`VfxPerformanceSnapshot` retains baseline/VFX average, maximum, P95, average
Preview FPS, runtime-instance and renderer peaks, Particle/Trail/Ring peaks,
the primary `Preview Frame Time Delta`, scenario/workload/synchronization
metadata, and observed VSync/frame-cap context. It has no Preset write path,
benchmark database, JSON report export, or game artifact. The default run
respects current VSync and `Engine.max_fps`; the opt-in temporary uncap control
captures and restores both on completion, cancellation, error, and teardown.

For a manual Studio check, load a valid Preset and Vehicle Profile, inspect
HIGH/MEDIUM/LOW at GAME 100%, open Performance, choose a named scenario and
Stress LOD, optionally replicate the current Preset into every active slot,
then run Studio Stress. A person records the paired Preview Frame Time values,
peaks, visual clutter, and VSync/cap context on the target PC. A future
DesktopIdleRacing integration must repeat any runtime conclusion with its own
renderer; Studio never reads or writes the game repository.

## Contract ownership

`schemas/vfx_schema_v1.json` is the only declarative source for VFX field names, enums, required fields, defaults, ranges, strict object properties, Layer Type parameter schemas, supported runtime input names, and rule configuration.

GDScript must not duplicate Schema enums, field lists, ranges, defaults, or semantic value relationships. It reads them through `VfxSchemaRegistry`. Code necessarily contains the small algorithms for the explicitly declared `x_vfx_rules`; the Schema selects which rules run and supplies their configuration, including lifecycle-to-phase mappings, particle mode field requirements, emitter shape geometry, vehicle-space anchor modes, and allowed render planes.

Only the JSON Schema subset used by v1 is implemented:

- `type`, `properties`, `required`, `enum`, `default`
- `minimum`, `maximum`, `minItems`, `maxItems`
- `items`, `additionalProperties`, `pattern`
- local `$defs` and local `$ref`

`$ref` supports only `#/$defs/...` references in the loaded Schema. External files, URLs, other Schema documents, unresolved references, reference cycles, malformed subset keyword values, and malformed nested rule configuration are Schema configuration errors. Before caching, the Registry resolves every rule path and field reference, verifies each handler’s expected Schema type and enum shape, then cross-checks rule maps against their declared Schema enums and referenced parameter fields. No malformed or incomplete Schema is cached.

No generic JSON Schema engine, `oneOf` processor, expression evaluator, dynamic code executor, Shader Graph, or Timeline editor is part of this project foundation.

## Lifecycle and phases

Lifecycle defines the permitted Phase Stack shape:

- `ONE_SHOT`: `phases.one_shot` with a required activation `duration_seconds`.
- `START_LOOP_END`: `phases.start`, `phases.loop`, and `phases.end`; start and end have required activation durations, while loop duration is supplied by gameplay and is not serialized.

Phase duration controls activation and new emission only. When a phase stops, new Particle emission and Trail sampling stop, but previously generated particles or trails may remain until their own lifetime expires. Cleanup mechanics are a renderer-phase responsibility.

Phase stacks are independent. A Layer ID remains unique across every phase of its Preset, so examples use names such as `start.deploy_flash`, `loop.core_glow`, and `end.fade_sparks`.

## Space, anchors, transforms, and planes

Each Preset has a required `default_space_mode`. A Layer may omit `space_mode` and inherit it. Absence is preserved in normalized source; an effective mode is resolved for validation and later rendering.

- `VEHICLE_LOCAL` and `VEHICLE_FOLLOW_WORLD_TRAIL` require at least one vehicle Anchor.
- `WORLD_AREA` and `SCREEN_UI` require no vehicle Anchor and reject one in v1, avoiding an ignored or ambiguous attachment.

Layer transform defaults are `offset: [0.0, 0.0]`, `rotation_degrees: 0.0`, and `scale: [1.0, 1.0]`. Offsets and sizes use Godot 2D canvas units; final vehicle-preview scale is a future preview concern.

Render placement is deliberately limited to `UNDER_VEHICLE`, `OVER_VEHICLE`, `WORLD`, and `SCREEN_UI`. Vehicle spaces use the two vehicle planes, World uses `WORLD`, and UI uses `SCREEN_UI`. `sort_order` is a bounded small integer used only within one plane; it is not a render graph or general z system.

## Runtime inputs

The Schema declares the common runtime input contract: `intensity`, `speed_normalized`, `vehicle_velocity`, `turn_strength`, `longitudinal_load`, `effect_radius`, and `surface_type`. A Preset lists only inputs it actually needs in `runtime_inputs`.

Phase 0 originally defined input names, value shapes, and default values only.
Runtime Modulation v1 adds explicit Schema-validated bindings for the supported
`TEXTURED_SPRITE` path; mappings are declared authoring data, not implicit
visual rules. It still adds no generic expression, curve, or automation system.

Gameplay target searches and effects such as Shockwave hit results remain game-owned inputs. They are not evaluated by the Studio contract.

## Performance and LOD

Desktop Idle Racing may display up to 20 vehicles with up to 3 simultaneous VFX each: roughly 60 active VFX instances. This is a design constraint for every renderer and preset review.

Preset JSON does not store manually authored particle counts or draw-call estimates because those are renderer-dependent derived data. A later Performance Analyzer derives costs for the Editor, generated reports, and export manifests.

Layer `importance` is authoring policy, not a measured cost:

- HIGH: `CORE`, `DETAIL`, `EXTRA`
- MEDIUM: `CORE`, `DETAIL`
- LOW: `CORE`

At actual game size, CORE layers must preserve effect identity before DETAIL or EXTRA is considered.

## Project responsibilities

Phase 1 implements `editor/` as a Godot `Control` application that composes one authoring-path policy, Contract Pipeline, loaded Schema Registry, mutable edit session/history, schema-aware factories, Library, valid-only save service, diagnostics navigator, and Layer Stack controls through `VfxEditorController`. It writes only validated `.vfx.json` documents under `res://presets/`; an empty new Skeleton is deliberately in-memory only until it passes the existing Contract rules.

The following boundaries remain intentionally reserved after Phase 2:

- `rendering/`: Layer renderers and cleanup behavior.
- `performance/`: Analyzer and LOD application.
- `export/`: derived Godot resources and game-facing manifests.

No dependency on `C:\GodotProjects\DesktopIdleRacing` is created.

## Phase 0 data services

- `VfxSchemaRegistry`: loads, checks, caches, and locally resolves the Schema.
- `VfxRuleCatalog`: owns the finite set of semantic rule handler names and their configuration shape; it does not duplicate authoring field contracts.
- `VfxSchemaSubsetValidator`: validates only the documented Schema subset without mutation.
- `VfxContractValidator`: applies structural validation and Schema-declared semantic rules.
- `VfxPresetNormalizer`: deep-copies raw data and applies Schema defaults.
- `VfxPresetCodec`: file I/O and JSON decode/encode only.
- `VfxPresetPipeline`: orchestrates the services in the documented order.

Structured `VfxIssue` diagnostics distinguish file I/O, JSON parse, Schema configuration, normalization, and preset validation failures. JSON parse diagnostics use only API-provided line information; unavailable columns use `-1`. Contract diagnostics use JSON Pointer paths and do not invent source positions.

## Phase 0 verification

`tests/run_contract_tests.gd` executes the small dependency-free contract suite. It covers JSON Variants, Schema configuration, Schema subset validation, non-mutating normalization, semantic rules, Pipeline composition, valid examples, focused invalid fixtures, and deterministic normalized serialization.

Use a Godot 4.7.1 stable console executable for short checks:

```powershell
& '<godot-4.7.1-console.exe>' --headless --path '<DesktopRacingVFXStudio>' --script res://tests/run_contract_tests.gd
& '<godot-4.7.1-console.exe>' --headless --path '<DesktopRacingVFXStudio>' --editor --quit
```

The approved examples are `presets/examples/talent.zero_zone.vfx.json` and `presets/examples/finish.confetti_world.vfx.json`. They demonstrate contract data only; they are not renderer output or exported game resources.
