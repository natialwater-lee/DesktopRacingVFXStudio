# DesktopRacingVFXStudio Phase 4: Performance Budget, Studio Stress, and LOD Design

## Goal

Phase 4 adds three Studio-only authoring tools:

- a derived **Authoring Budget** for a valid Render Plan;
- a dedicated **Studio Preview Stress** surface for the expected 1/10/20-car
  vehicle scenarios, including the 20 cars x 3 VFX conservative case; and
- a manual `HIGH` / `MEDIUM` / `LOW` LOD filter shared by normal Preview and
  Studio Stress.

The purpose is to reveal structurally expensive Presets early, compare LOD
levels at actual Preview game scale, observe synchronized visual clutter, and
measure relative Studio Preview cost. It is not a game-performance benchmark.

## Non-negotiable performance boundary

Every Phase 4 label, document, Snapshot, and diagnostic uses Studio-specific
language:

- `Authoring Budget`
- `Studio Preview Stress`
- `Preview Frame Time`
- `Preview Baseline Delta`
- `Uncalibrated Authoring Guidance`

Phase 4 measures the **DesktopRacingVFXStudio Preview Renderer**. Its current
CPU simulation, Canvas drawing, asset adapters, and editor UI can differ from
a future DesktopIdleRacing runtime renderer. A Phase 4 result must never be
called `Game Performance`, `Game FPS`, `Game Safe`, or a guarantee of target
hardware performance.

It is useful for relative comparisons and early authoring decisions only:

- identifying a Preset whose structure expands too far;
- comparing HIGH, MEDIUM, and LOW work at one common Preview workload;
- detecting 20 x 3 visual clutter; and
- observing whether a Studio Preview workload changes frame time relative to
  an equal vehicles-only baseline.

DesktopIdleRacing runtime performance remains a future integration-phase
measurement using the actual game renderer. Studio never reads, writes, stages,
or selects a directory in the game repository.

## Confirmed constraints

- Godot 4.7.1 stable and standard dependency-free GDScript only.
- Schema v1 and `.vfx.json` remain unchanged. No estimated cost, LOD state,
  threshold, or Snapshot is serialized into a Preset.
- Existing Render Plan, Instance Resolver, Renderer Factory, Asset Registry,
  canonical packet routing, and Playback implementations are reused. Phase 4
  creates no second Renderer implementation.
- A filtered Plan is immutable. It never mutates the working document, edit
  session, original Render Plan, or saved Preset.
- Only `VEHICLE_STRESS` is implemented. `CELEBRATION_STRESS` is a future seam,
  not a category-derived automatic behavior.
- Auto LOD, FPS-reactive LOD changes, GPU benchmark databases, game export,
  game integration, and a generic timeline benchmark are excluded.
- `project.godot`, `src/editor/main/vfx_editor_main.tscn`, and existing Vehicle
  Profile JSON files remain untouched. The runtime-inserted Preview host is the
  UI integration seam.
- Do not use `git add` or `git commit`; leave all work unstaged for SourceTree.

## LOD contract

The existing Schema v1 `importance` field is the only Preset-side LOD input.

| LOD | Included importance |
| --- | --- |
| `HIGH` | `CORE`, `DETAIL`, `EXTRA` |
| `MEDIUM` | `CORE`, `DETAIL` |
| `LOW` | `CORE` |

`VfxPreviewLodFilter.filter(plan, lod_level)` creates a new
`VfxPreviewRenderPlan` with the same preset id, lifecycle mode, phase names,
durations, layer order, and immutable Layer specs, but with only eligible Layer
specs in each phase. It neither changes `enabled` nor manufactures a different
Layer spec. Disabled Layers remain present in a filtered Plan but are excluded
by the existing runtime, exactly as they are today.

The LOD strings and their included Importance values are Studio policy data,
not Schema v1 fields. They live in the Studio policy file and are validated
against the `importance` enum retrieved from `VfxSchemaRegistry`; GDScript does
not maintain a duplicate authoring enum list. A malformed policy or an
Importance value unavailable in the loaded Schema produces a configuration
issue and prevents analysis or Stress startup.

The normal `VfxVehiclePreview` and `VfxPerformanceStressPreview` both consume
the same filtered-Plan result. Their selected LOD controls are independent
session UI state, each initially `HIGH`, so inspecting normal Preview at LOW
does not silently alter a pending Stress scenario.

## Studio performance policy

`config/vfx_performance_policy_v1.json` is small, Studio-owned configuration.
It is not a JSON Schema document, Preset source data, game resource, or export
manifest. A focused `VfxPerformancePolicy` loader validates its exact required
shape and cross-checks LOD Importance values with `VfxSchemaRegistry`.

Its mandatory metadata is:

```json
{
  "policy_version": 1,
  "calibration_state": "UNCALIBRATED",
  "scope": "VEHICLE_STRESS"
}
```

The initial policy has four scenario-level **authoring guidance** dimensions.
The values are intentionally editable project data rather than GDScript
constants or claims about a GPU:

| Projected active-workload metric | SAFE | CAUTION | HEAVY |
| --- | ---: | ---: | ---: |
| Expanded runtime instances | <= 360 | <= 720 | > 720 |
| Particle workload envelope | <= 600 | <= 1,200 | > 1,200 |
| Trail point capacity | <= 1,200 | <= 2,400 | > 2,400 |
| Transparent renderer instances | <= 360 | <= 720 | > 720 |

The threshold evaluator returns the highest severity reached by any metric and
the exact triggering metrics. It must display `Authoring Guidance —
Uncalibrated` beside the result. `SAFE` therefore means only that the selected
project policy did not flag the active workload; it does not mean the future
game is proven safe.

The policy also owns the five named vehicle scenarios and default timing:

```text
1x1, 10x1, 20x1, 10x3, 20x3
baseline warm-up: 1.0 seconds
baseline measurement: 3.0 seconds
VFX warm-up: 1.0 seconds
VFX measurement: 3.0 seconds
```

## Authoring inventory versus active workload budget

A single `VfxPresetPerformanceBudget` exposes two deliberately separate views.

### Authoring / Lifecycle Envelope

This is a structural inventory across every lifecycle phase after the selected
LOD filter and Vehicle Profile anchor expansion. It reports:

- source Layer count, enabled Layer count, and LOD-included Layer count;
- lifecycle expanded instance inventory;
- Particle Layer count, continuous capacity, Burst maximum, and conservative
  Particle envelope;
- Trail instance count and maximum point capacity;
- Ring Layer inventory and per-phase active-ring potential;
- Glow and Shield instance inventory;
- unique logical texture asset ids and texture-backed renderer-instance count;
- per-render-plane instance inventory.

It is intentionally conservative and useful for authoring review. A total
over `start`, `loop`, and `end` must never be labelled as a simultaneously
active runtime count.

For a positive ring repeat interval, the ring potential within one active
phase is `ceil(duration_seconds / repeat_interval_seconds)`. An activation-only
ring has potential one. This mirrors the current `VfxRingLayerRenderer`
semantics, not an invented visual estimate.

### Active Stress Workload Budget

This is the subset that a selected benchmark workload will activate together.
It has the same metric shape as the inventory but is explicitly named with the
workload type and synchronization mode. Scenario threshold evaluation uses
this budget, not lifecycle inventory.

The two Phase 4 workload types are deliberately small:

- `STEADY_LOOP`: for `START_LOOP_END`, activate and retain only `loop` for the
  whole benchmark. It measures ongoing attached-effect work. `start` and
  `end` remain visible in Lifecycle Envelope but are not represented as
  steady active work.
- `REPEATED_ONE_SHOT`: for `ONE_SHOT`, activate `one_shot`, let declared
  residuals drain, then restart. It measures repeated event pressure without
  inventing a timeline editor or randomized spawn schedule.

`FULL_LIFECYCLE_STRESS`, randomized timing, and staggered vehicle activation
are future seams. Phase 4 starts every selected VFX workload synchronously;
the UI and Snapshot identify it as `SYNCHRONIZED` conservative stress.

## Scenario projection

`VfxScenarioProjection` accepts one active-workload budget per enabled Slot,
sums those budgets per vehicle, then multiplies them by vehicle count.

```text
per vehicle = Slot A workload + Slot B workload + Slot C workload
projected scenario = per vehicle x vehicle count
```

All scenario labels include `Projected / Theoretical`. No projection is
presented as a measured frame time. A unique texture asset count remains a
distinct resource count and is not multiplied by vehicles; texture-backed
renderer instances are multiplied and shown separately.

The Stress panel has three simple slots:

- Slot A defaults to the currently selected valid Preset Plan.
- Slot B and Slot C default to `None` and may choose an available valid
  library Preset.
- `Replicate current preset to all slots` sets the three slots to the current
  immutable filtered Plan for a conservative 20 x 3 check.

This is not a Race Entry editor. A one-slot scenario ignores B/C; a three-slot
scenario uses its enabled selections. Invalid or stale Presets cannot be
selected for Stress work.

## Stress Preview architecture

The Stress surface is dedicated and intentionally minimal:

```text
VfxPerformanceStressPreview
  VfxPerformanceStressStage
    VfxStressVehicleSlot x vehicle_count
      VehicleArtHost
      Preview plane hosts / source-local vehicle boundary
      VfxPreviewRenderRuntime + VfxPreviewPlaybackController per enabled slot
```

It does not instantiate twenty `VfxVehiclePreview` controls. A
`VfxStressVehicleSlot` owns only vehicle art, the shared Preview plane-host
semantics, and its runtime slots; it has no edit canvas, game inset, anchor
editor, Preview controls, or selected-Layer overlay.

Vehicle art, Profile coordinates, effective `VfxPreviewGameScale`, renderer
factory, asset resolver, canonical coordinate resolver, render-plane ordering,
and packet projection retain their existing semantics. The Stage is a
deterministic 5 x 4 grid for 20 cars. It can scroll when needed but never
fit-scales the vehicles or VFX to its Control size. The result remains a
readability/clutter preview at the existing game-scale contract.

For a `STEADY_LOOP`, each slot configures the existing playback controller in
manual `loop` phase mode and keeps it advancing. For a `REPEATED_ONE_SHOT`, a
small scheduler restarts the existing controller after `TERMINATED`; it does
not reproduce Particle, Trail, Ring, or lifecycle logic.

## Same-stage paired baseline

One Run builds the complete Stress Stage once before baseline timing:

1. build vehicle grid and placement once;
2. resolve selected Plans and logical assets, construct disabled runtime
   slots, and allow Preview resources to preload;
3. run the vehicles-only baseline with VFX slots disabled;
4. reset and enable the existing runtime slots on that exact Stage;
5. run the VFX workload measurement; and
6. retain one session-only Snapshot.

No vehicle, layout, or sprite is rebuilt between Baseline and VFX. VFX asset
resolution and runtime construction occur before the baseline measurement.
Shader/resource initialization that cannot be resolved eagerly is absorbed by
the VFX warm-up, not the VFX measurement interval.

The timing state machine is:

```text
PREPARE
-> BASELINE_WARMUP (1.0 s)
-> BASELINE_MEASURE (3.0 s)
-> VFX_WARMUP (1.0 s)
-> VFX_MEASURE (3.0 s)
-> COMPLETE | CANCELLED | ERROR
```

Cancellation, invalid setup, or Preview teardown clears runtime residuals and
restores the optional measurement environment guard before reporting a result.

## VSync and frame-cap context

Frame delta can be limited by display VSync or a frame cap. Phase 4 must not
change `project.godot` to benchmark differently.

The default is **respect current environment**. Each Snapshot records the
observed VSync mode and `Engine.max_fps`; if VSync is enabled or a non-zero cap
is active, the UI shows `VSYNC/CAP LIMITED — frame-time headroom may be
hidden`.

An explicit, opt-in `Temporarily uncap this Studio Stress run` control may use
a small `VfxStressMeasurementEnvironment` guard. In a GUI-capable run it
captures the current window VSync mode and `Engine.max_fps`, temporarily sets
VSync disabled and the cap to zero, then restores both on normal completion,
cancellation, error, and node teardown. If the platform cannot provide or set
one of those values, the Run continues in the current environment with a
warning; it never silently claims an uncapped result.

This is a scoped guard, not a benchmark-environment manager. Driver-level
limits, external overlays, and operating-system scheduling remain outside the
tool's control.

## Runtime metrics and Snapshot

Only actual Studio Preview runtime observations are collected. During a
measurement interval, `VfxRuntimeMetricAccumulator` stores frame deltas and
receives one already-rendered packet summary per Stress frame.

The result contains:

- average Preview frame time;
- maximum Preview frame time;
- P95 Preview frame time, calculated by sorting the bounded measurement
  samples only at completion;
- average Preview FPS calculated as `1 / average frame time`, never the mean
  of instantaneous FPS values;
- active VFX preset-instance count;
- active layer-renderer count;
- active runtime-instance count;
- peak alive Particle packet count;
- peak active Trail point count; and
- peak active Ring packet count.

In the current implementation, one active renderer entry is normally one
expanded runtime instance. Both are retained because they describe different
boundaries and may diverge in a future adapter implementation. The UI does not
pretend otherwise.

The most prominent comparison is:

```text
Preview Frame Time Delta = VFX average Preview frame time
                           - baseline average Preview frame time
```

Both sides include Studio UI and Preview overhead. The paired same-Stage method
makes the delta more informative than an isolated FPS number, but it remains a
Studio Preview measurement. GPU time is `N/A`. Godot draw-call, object, or
video-memory monitors are optional future diagnostics only after GUI runtime
stability is verified; they do not participate in threshold guidance.

`VfxPerformanceSnapshot` is a session-only immutable record containing the
Preset/slot signature, profile, scenario, workload, synchronization mode,
LOD, policy version and calibration state, environment context, baseline
summary, VFX summary, delta, peaks, threshold reasons, and Preview warnings.
There is no benchmark database, JSON report export, or Preset mutation.

## Performance Mode UI

The existing runtime-inserted `PreviewHost` gains a small workspace switch,
without narrowing the Layer Stack or Inspector:

```text
[ AUTHORING PREVIEW | PERFORMANCE ]
```

`AUTHORING PREVIEW` retains the current Vehicle Preview and gains a separate
compact LOD row. It does not overfill the existing display row. Changing it
reapplies a filtered Plan to the normal Edit/Game hosts immediately.

`PERFORMANCE` uses the full PreviewHost area and visually separates data:

```text
AUTHORING BUDGET
  Lifecycle Envelope | Active Workload Budget | Projected scenario
  SAFE / CAUTION / HEAVY — Authoring Guidance, Uncalibrated

STUDIO PREVIEW STRESS
  Profile | Scenario | Workload | LOD | Slots A/B/C | Replicate
  [Run Studio Stress] [Cancel] [Temporarily uncap this run]
  grid Stage
  Baseline Avg | VFX Avg | Preview Frame Time Delta | Max | P95 | peaks
```

The Stage is the flexible vertical region. Budget/result details are in a
scrollable lower region, keeping a constrained editor window usable without
changing project display settings. `STUDIO STRESS RESULT` never shares a table
with Authoring Budget values.

## Zero Zone example

Zero Zone uses only the `CENTER` Anchor, so its LOD source-layer count and
expanded instance inventory are equal.

### Lifecycle Envelope / source inventory

| Metric | HIGH | MEDIUM | LOW |
| --- | ---: | ---: | ---: |
| Included Layer inventory | 11 | 9 | 3 |
| Lifecycle expanded inventory | 11 | 9 | 3 |
| Particle Layers | 4 | 2 | 0 |
| Continuous Particle capacity | 10 | 6 | 0 |
| Burst maximum | 13 | 5 | 0 |
| Conservative Particle envelope | 23 | 11 | 0 |
| Ring Layer inventory | 3 | 3 | 0 |
| Glow instances | 4 | 4 | 3 |
| Unique texture assets | 2 | 1 | 0 |
| Under / Over plane instances | 4 / 7 | 4 / 5 | 3 / 0 |

The eleven HIGH layers include Start, Loop, and End records. They are not
labelled as eleven simultaneous active renderer instances.

### `STEADY_LOOP` active workload

The Loop phase consists of Soft Outer Aura, Inner Focus Glow, Inner Energy
Ring, Slow Shards, and Fast Sparks.

| Metric | HIGH | MEDIUM | LOW |
| --- | ---: | ---: | ---: |
| Active Loop Layers / instances | 5 | 4 | 2 |
| Continuous Particle capacity | 10 | 6 | 0 |
| Burst maximum | 0 | 0 | 0 |
| Ring active potential | 1 | 1 | 0 |
| Glow instances | 2 | 2 | 2 |
| Unique texture assets | 2 | 1 | 0 |
| Under / Over plane instances | 2 / 3 | 2 / 2 | 2 / 0 |

For the synchronized `20 x 3` steady-loop Stress projection this becomes:

| Metric | HIGH | MEDIUM | LOW |
| --- | ---: | ---: | ---: |
| Active renderer/runtime instances | 300 | 240 | 120 |
| Continuous Particle capacity | 600 | 360 | 0 |
| Ring active potential | 60 | 60 | 0 |
| Glow instances | 120 | 120 | 120 |

This table is the direct input to the initial vehicle-stress threshold policy.
It is distinct from the 660/540/180 lifecycle inventory multiplication. The
initial policy consequently marks the HIGH steady loop as SAFE at its stated
threshold edges, while displaying `Uncalibrated`; that is neither a GPU claim
nor a game-runtime guarantee.

## Celebration seam

`VfxBudgetScope` supports named policy and scenario scopes. Phase 4 constructs
only `VEHICLE_STRESS`. A later `CELEBRATION_STRESS` can provide a different
placement strategy, simultaneous-instance assumption, and threshold group for
Finish Confetti, Fireworks, World, or Screen/UI effects without creating a
second Renderer or inferring scope from Preset category.

## Test strategy

Headless tests assert deterministic structure and arithmetic, never a machine
FPS threshold:

- policy metadata/configuration validation and Schema Importance cross-check;
- non-mutating HIGH/MEDIUM/LOW filtering;
- Lifecycle Envelope and active-workload budget separation;
- Multi Anchor expansion multiplication;
- Particle, Burst, Trail, Ring, texture, and plane aggregation;
- one-slot, mixed-slot, and replicate-current scenario multiplication;
- threshold reasons and explicit `UNCALIBRATED` state;
- grid layout vehicle/slot counts;
- same-stage baseline-to-VFX state transitions;
- warm-up exclusion, average/max/P95 calculations, peak collection, and
  cancellation/reset behavior; and
- Stress Preview instantiate/free and Editor wiring.

No test fails because FPS is below a target. Final verification runs Contract,
Editor, Preview, and new Performance suites, then Godot headless editor parse
with `C:\\Tools\\Godot\\Godot_v4.7.1-stable_win64_console.exe`.

## GUI benchmark workflow

On the user's actual PC:

1. load a valid Preset such as Zero Zone and choose the intended Vehicle
   Profile;
2. inspect HIGH, MEDIUM, and LOW in Authoring Preview at GAME 100%;
3. open Performance mode and compare the five named scenarios;
4. for each desired LOD, run Studio Stress and retain the latest paired
   Snapshot; and
5. interpret the Preview Frame Time Delta, peaks, clutter, VSync/cap context,
   and Uncalibrated Authoring Guidance together.

The user, not headless CI, evaluates the absolute Studio Preview values. A
future game integration repeats the relevant scenarios using the actual game
runtime renderer.

## Scope exclusions

Phase 4 does not modify Schema v1, Preset JSON, renderer type semantics,
vehicle profiles, particle art, export resources, performance manifests,
DesktopIdleRacing, game Dynamic LOD, game auto-LOD policy, hardware database,
GPU-time estimates, full-lifecycle/randomized benchmarks, or a generic race
simulation.
