# DesktopRacingVFXStudio Runtime Modulation v1 Design

## Status and scope

This is a design-only pass. It defines a small, deterministic Runtime
Modulation contract for a later implementation. It changes no Schema, source
Preset, Preview renderer, Export Package, asset, or DesktopIdleRacing file.

The goal is not a graph, expression language, timeline, shader parameter
system, or Headlight-specific controller. The goal is a reusable Layer Stack
feature that computes effective visual values without mutating authored base
data.

```text
authored normalized Layer value
  -> compiled modulation program
  -> per-instance effective value
  -> existing Layer renderer packet
  -> Preview/Game projection
```

## Repository audit

### Existing Runtime Input contract

`schemas/vfx_schema_v1.json` declares the only current Runtime Input names in
`x_vfx_runtime_inputs`:

| Input | Current value contract |
| --- | --- |
| `intensity` | number, `[0, 1]`, default `1` |
| `speed_normalized` | number, `[0, 1]`, default `0` |
| `vehicle_velocity` | vector2, default `[0, 0]` |
| `turn_strength` | number, `[-1, 1]`, default `0` |
| `effect_radius` | number, minimum `0`, default `0` |
| `surface_type` | logical ID, default `surface.default` |

The Preset-level `runtime_inputs` array declares only required inputs. The
Schema rule `RUNTIME_INPUT_NAMES` validates their names. The Inspector exposes
those names as checkboxes in `VfxRuntimeInputsEditor`, and Export derives their
contracts into the Runtime Definition. There is currently no input-to-Layer
binding, no modulation source, and no per-frame effective parameter stage.

`longitudinal_load` is therefore a new additive input contract, not a value the
Studio calculates. Its proposed contract is a finite number in `[-1, 1]`,
default `0`: `-1` is maximum braking, `0` is no longitudinal load, and `+1` is
maximum acceleration. DesktopIdleRacing alone converts its simulation state to
this normalized scalar.

### Existing Preview and LOD flow

The actual Studio flow is:

```text
saved raw JSON
 -> VfxPresetPipeline decode -> normalize -> validate
 -> VfxPreviewRenderPlanBuilder
 -> immutable VfxPreviewRenderPlan / VfxPreviewLayerSpec
 -> VfxPreviewLodFilter
 -> VfxPreviewRenderRuntime / VfxPreviewPlaybackController fixed 1/60 tick
 -> concrete Layer renderer packets
 -> common Edit and GAME Canvas packet routing
```

`VfxPreviewLayerSpec` currently retains authored transform and parameters as
immutable copies. `VfxPreviewPlaybackController` owns deterministic simulation
time, advances it only while playing, resets it on restart, and adds
`preview_time` to its existing frame context. `VfxVehiclePreview` currently
supplies only vehicle translation, vehicle rotation, and effective game scale
in that context. Its vehicle Preview motion is therefore separate from any
future Layer modulation.

`VfxPreviewLodFilter` builds an immutable filtered plan before the render
runtime is created. This is the correct seam: a filtered-out Layer has no
render instance and must not evaluate a modulation binding.

The renderer's effective-value insertion point is immediately before packet
creation in `VfxPreviewLayerRenderer` and concrete Layer renderers. In
particular, `TEXTURED_SPRITE` currently creates one persistent packet at phase
activation; a later generic implementation must refresh that packet's
effective transform and alpha during a fixed tick. It must not mutate
`VfxPreviewLayerSpec`, normalized Preset data, or JSON.

The stored renderer packet is persistent, but the present public
`draw_packets()` API defensively deep-copies the renderer array/dictionaries
and `VfxPreviewRenderRuntime.draw_packets()` aggregates another output array.
Those presentation copies are an existing baseline for every renderer; this
design does not reclassify or expand them. The v1 allocation rule below applies
to the modulation evaluator and the renderer's stored packet/effective state:
modulation must add no per-tick allocations there. A later broad packet-handoff
optimization, if profiling warrants one, is deliberately out of scope.

### Attachment and pivot geometry audit

`VfxPreviewCoordinateResolver.canonical_origin()` currently resolves a Layer
origin as `anchor + transform.offset`; `geometry_scale()` and
`geometry_rotation_degrees()` apply the authored scale and rotation about that
origin. `VfxPreviewCanvasRenderHost._draw_textured_sprite()` then draws a
texture in `Rect2(native_size * -0.5, native_size)`. A `TEXTURED_SPRITE`
therefore has its texture centre at local `(0, 0)`: the renderer has no
attachment/pivot field today.

This is material for `driving.headlights`. Its authored offsets do not mark a
texture centre as the lamp root. They were calculated so a visible tip reaches
the bilateral lamp root after the *authored* scale and rotation:

| Beam | Native texture | visible tip in texture pixels | local point from texture centre |
| --- | --- | --- | --- |
| Core | `128 x 192` | approximately `[63.5, 185]` | `[-0.5, 89]` |
| Soft | `128 x 128` | approximately `[63.5, 113]` | `[-0.5, 49]` |

For example, the current left Core uses authored origin
`[-55.638927, -317.925671]`, scale `[1.55, 1.60]`, and rotation `355` degrees.
Applying that authored transform to `[-0.5, 89]` gives approximately
`[11.6389, 141.9257]`; their sum is the required lamp root
`[-44, -176]`. Applying an additional runtime scale or rotation about the
texture centre without compensating the packet origin would move that root.

The existing coordinate resolver is the correct canonical local-coordinate
seam for an effective-origin calculation, but it does not itself supply a
pivot. Its present centre-pivot behavior is therefore insufficient alone.

### Existing Export and game boundary

`VfxExportCompiler` compiles normalized data into
`runtime/vfx_runtime_definition_v1.json`; it preserves normalized common Layer
fields, type parameters, effective space, and declared Runtime Input contracts.
Manifest requirements contain only the input name inventory, anchor inventory,
and Importance summary. No mapping is currently exported.

The published direction remains:

```text
DesktopRacingVFXStudio -> VFX Export Package -> DesktopIdleRacing importer/runtime
```

This design used only Studio source, Package documentation, and exported
example artifacts. It does not read or assume implementation details from the
DesktopIdleRacing repository.

## Architecture options

### A. Fully layer-local source and binding lists

Every Layer owns its input mappings and any oscillator description.

This has the smallest JSON shape, but repeats one road-motion oscillator on
left and right headlights. Repetition risks drift, makes shared phase an
accident, and evaluates identical oscillators more than once. It is acceptable
only for simple input mappings and is not the recommended v1 architecture.

### B. Preset-level shared sources plus Layer-local bindings — recommended

The Preset owns a small ordered source table. Layers own ordered bindings that
refer either to a declared Runtime Input or to one shared source. This provides
one VFX-instance road oscillator for both headlights while keeping targets
beside the Layer they affect.

It adds three small optional authoring concerns (one shared source table,
Layer bindings/clamps, and an optional local pivot), preserves Layer Stack
ownership, compiles without JSON traversal at runtime, and has an obvious
portable Runtime Definition representation.

### C. Game or Preset-specific controllers — rejected

`HeadlightDynamicController`, a renderer branch on `preset_id`, or game-only
hardcoded responses would be quick for one effect but breaks Preview/Game
parity, bypasses source-of-truth authoring, and cannot safely serve Booster,
Wind, Forcefield, or later equipment effects.

### Attachment-preserving transform alternatives

Runtime `TRANSFORM_SCALE_*` and `TRANSFORM_ROTATION_DEGREES` need a separate
decision from the shared-source architecture. The decision applies to every
attached directional sprite, not only Headlights.

#### A. Centre pivot plus author-authored offset compensation — rejected

An author could add a second offset binding intended to cancel each scale or
rotation binding. This couples values that must remain mathematically linked,
is fragile when X/Y scale and rotation compose, depends on binding order, and
would require every Preset to repeat renderer geometry knowledge. It is also
not reliable for a sinusoidal rotation combined with a speed scale. v1 must
not make attachment preservation an authoring burden.

#### B. Optional Layer-local modulation pivot — recommended

Add an optional `transform.modulation_pivot_local` point. It identifies the
local geometry point held fixed while modulation changes scale or rotation.
The effective packet origin is derived from the authored transform, that
point, and the effective transform. This is generic: a beam tip, exhaust
root, flame nozzle, or any later directional attached sprite can use the same
mechanism without a Preset-ID branch.

The field is not an arbitrary pivot graph, bone, or per-frame anchor solve.
It is one finite two-number local point. Its default `[0, 0]` preserves the
current centre-pivot behavior exactly.

#### C. Reuse only the existing canonical-origin seam — insufficient alone

The resolver already owns source-local origin, geometry scale, and rotation,
so it is the correct implementation seam for B. However, it currently knows
only the texture centre. Reusing it without a declarative point is equivalent
to A with no compensation and cannot preserve the Headlight visible tip.

**Decision:** retain Architecture B (Preset shared sources plus Layer-local
bindings) and add option B at the existing canonical coordinate-resolver seam.
This is an attachment-preserving effective-transform rule, not a
Headlight-specific mechanism.

### Explicitly excluded alternative

An arbitrary JSON-pointer target plus formula strings would require an
expression evaluator, dynamic path lookup, and unclear type semantics. It is
not Runtime Modulation v1.

## Recommended v1 authoring model

Schema v1 receives only backward-compatible optional fields:

```json
{
  "runtime_modulation_sources": [
    {
      "id": "road_motion",
      "type": "OSCILLATOR",
      "wave": "SINE",
      "frequency_hz": 0.28,
      "phase_degrees": 0.0
    }
  ],
  "phases": {
    "loop": {
      "layers": [
        {
          "id": "loop.left_core_beam",
          "transform": {
            "modulation_pivot_local": [-0.5, 89.0]
          },
          "modulations": [
            {
              "id": "length_by_speed",
              "target": "TRANSFORM_SCALE_Y",
              "operation": "MULTIPLY",
              "source": { "type": "RUNTIME_INPUT", "input": "speed_normalized" },
              "mapping": {
                "type": "LINEAR_RANGE",
                "input_min": 0.0,
                "input_max": 1.0,
                "output_min": 1.0,
                "output_max": 1.06
              }
            },
            {
              "id": "length_by_longitudinal_load",
              "target": "TRANSFORM_SCALE_Y",
              "operation": "MULTIPLY",
              "source": { "type": "RUNTIME_INPUT", "input": "longitudinal_load" },
              "mapping": {
                "type": "LINEAR_RANGE",
                "input_min": -1.0,
                "input_max": 1.0,
                "output_min": 0.90,
                "output_max": 1.10
              }
            },
            {
              "id": "road_length_motion",
              "target": "TRANSFORM_SCALE_Y",
              "operation": "MULTIPLY",
              "source": { "type": "PRESET_SOURCE", "source_id": "road_motion" },
              "mapping": {
                "type": "LINEAR_RANGE",
                "input_min": -1.0,
                "input_max": 1.0,
                "output_min": 0.985,
                "output_max": 1.015
              }
            }
          ],
          "modulation_clamps": [
            {
              "target": "TRANSFORM_SCALE_Y",
              "min_effective": 1.408,
              "max_effective": 1.824
            }
          ]
        }
      ]
    }
  }
}
```

The example is explanatory only. It does not authorize a Headlight Preset edit.

`runtime_modulation_sources` is an ordered array rather than an object keyed by
arbitrary IDs because the supported Schema subset has no `patternProperties`.
It defaults to `[]`. Every Layer gets optional `modulations` and
`modulation_clamps` arrays, both defaulting to `[]`. Existing source JSON omits
them and remains visually identical after normalization.

`transform.modulation_pivot_local` is also optional and defaults to `[0, 0]`.
It is expressed in the Layer renderer's untransformed local geometry
coordinates, not vehicle/source-canvas coordinates. For the v1
`TEXTURED_SPRITE` renderer, one local unit is one native texture pixel and the
texture centre is `[0, 0]`; thus the Core Headlight tip is `[-0.5, 89]`. A
non-zero point is accepted only for Layer Types that declare this geometry
contract in Schema configuration; v1 initially enables it for
`TEXTURED_SPRITE`. Other current types retain only the default centre point
until their local geometry has an explicit compatible definition.

The field has no visual effect by itself. It is used only while evaluating an
effective scale or rotation. A Layer that has no such active binding retains
the existing packet path and its current authored rendering exactly.

### Sources

v1 supports exactly:

| Source type | Fields | Output domain |
| --- | --- | --- |
| `RUNTIME_INPUT` | binding-local `input` | declared input range |
| `PRESET_SOURCE` | binding-local `source_id` | source-defined range |
| `OSCILLATOR` | source-table `id`, `wave`, `frequency_hz`, `phase_degrees` | `[-1, 1]` |

Only `SINE` is valid for `OSCILLATOR` in v1. No random source, per-frame game
noise, curve, scripted function, or expression is included.

`RUNTIME_INPUT` and `PRESET_SOURCE` are mutually exclusive source shapes. The
small Schema subset does not need `oneOf`: both optional fields are structurally
declared, and one explicit `RUNTIME_MODULATION_CONFIGURATION` rule verifies the
chosen shape and rejects the irrelevant field.

### Targets and operations

The target enum is closed and Schema-owned:

| Target | Base value | Allowed operation | Meaning |
| --- | --- | --- | --- |
| `TRANSFORM_OFFSET_X` | authored `transform.offset[0]` | `ADD` | source-local pixels |
| `TRANSFORM_OFFSET_Y` | authored `transform.offset[1]` | `ADD` | source-local pixels |
| `TRANSFORM_ROTATION_DEGREES` | authored rotation | `ADD` | degrees |
| `TRANSFORM_SCALE_X` | authored scale X | `MULTIPLY` | positive scale factor |
| `TRANSFORM_SCALE_Y` | authored scale Y | `MULTIPLY` | positive scale factor |
| `VISUAL_OPACITY_MULTIPLIER` | `1.0` | `MULTIPLY` | final packet alpha multiplier |

`VISUAL_OPACITY_MULTIPLIER` deliberately is not a JSON pointer to
`parameters.opacity`. It multiplies the renderer's existing authored visual
alpha after type-specific alpha calculation: `TEXTURED_SPRITE.opacity`,
`GLOW.opacity`, `SHIELD.opacity`, particle alpha interpolation, ring alpha
interpolation, or trail color alpha. This avoids pretending that all Layer
Types have one identically-named parameter while preserving a single portable
visual-alpha target.

No `REPLACE` operation is allowed. Offset/rotation have only `ADD`; scale and
visual opacity have only `MULTIPLY`. This removes mixed-operation ambiguity in
v1 while still covering the target effects.

### Attachment-preserving effective transform

For a Layer with pivot `p`, authored origin `O_base`, authored scale/rotation
matrix `M_base`, effective scale/rotation matrix `M_effective`, and any
intentional effective offset contribution `D_offset`, the effective packet
origin is:

```text
attachment_root = O_base + M_base * p
O_effective = attachment_root + D_offset - M_effective * p
```

The renderer then draws local geometry using `O_effective` and
`M_effective`. Consequently `O_effective + M_effective * p` equals the same
authored attachment root plus any intentional `TRANSFORM_OFFSET_*` movement.
Scale and rotation therefore happen around the declared pivot, while an offset
binding still deliberately moves the attached visual as a whole.

`M_base` and `M_effective` both use the existing order: component-wise scale,
then rotation. Vehicle/world projection is applied after this source-local
calculation by the existing coordinate resolver, so the invariant also holds
for vehicle-follow world projection. This calculation uses only already
compiled numeric state; it does not inspect texture alpha or solve an anchor
per frame.

For the left Core example, a runtime scale-Y factor `1.06` and rotation delta
`+0.4` degrees give an approximate effective local tip transform
`[11.33, 150.52]`, instead of the base `[11.64, 141.93]`. The evaluator shifts
the packet origin from approximately `[-55.64, -317.93]` to
`[-55.33, -326.52]`; adding the effective tip vector still yields
`[-44, -176]`. The same formula handles both left/right sprites, Soft/Core
sizes, and future attached textures without a Headlight branch.

Each target contract declares its source-unit output range and target
compatibility in Schema configuration. GDScript must consume that configuration
through `VfxSchemaRegistry`; it must not duplicate target enums or operation
maps as independent constants.

### Mapping and clamp

`LINEAR_RANGE` is the only mapping type in v1:

```text
t = clamp((input - input_min) / (input_max - input_min), 0, 1)
mapped = lerp(output_min, output_max, t)
```

`input_min < input_max` is mandatory. A symmetric signed mapping needs no
three-point curve: `[-1, 1] -> [0.90, 1.10]` produces exactly `1.0` at zero.

For a target with one or more bindings, mappings are evaluated in authored
array order. Additive contributions are summed in that order; multiplicative
contributions are multiplied in that order. The v1 target/operation table
prevents mixing these operations for one target. The final native-unit value is
then constrained by one optional per-Layer target clamp:

```text
ADD:       clamp(base + sum(contributions), min_effective, max_effective)
MULTIPLY:  clamp(base * product(contributions), min_effective, max_effective)
```

When no explicit clamp exists, the target's Schema safety domain still applies:
scale remains positive and final packet alpha is clamped to `[0, 1]`. Duplicate
clamp targets, inverted clamps, non-finite values, invalid source ranges, or a
mapped output outside the configured target domain are authoring errors.

### Clamp operating policy

An explicit final clamp is an extreme-composition safety rail, not an ordinary
animation curve. Phase B authoring must choose speed, load, and oscillator
ranges whose normal combined values remain inside it. A deterministic authored
input sweep records the unclamped and effective min/max values and any clamp
hits for the candidate Headlight bindings. Repeated clamp occupancy during
ordinary `speed_normalized`, `longitudinal_load`, and oscillator combinations
means the mappings need adjustment; it is not accepted as a way to shape the
normal visual response. This inspection is a focused authoring/test result,
not a new runtime telemetry or UI subsystem.

## Lifecycle, LOD, and deterministic time

Modulation always starts from the active Phase's authored base. It never alters
START/LOOP/END durations, phase transitions, authored source JSON, or the base
value of another Phase. A START Core opacity therefore remains its authored
START opacity multiplied by the active visual-opacity bindings, not the LOOP
opacity.

Oscillator time is VFX-instance elapsed simulation time, not application wall
time:

```text
oscillator = sin(TAU * frequency_hz * instance_elapsed_seconds + phase_radians)
```

The Preview's existing fixed-tick simulation time is the canonical Studio
clock. Pause freezes it; restart resets it to zero. v1 uses only authored fixed
phase and intentionally has no random or per-anchor phase offset. Thus both
headlights can share `road_motion` exactly. A deterministic instance seed or
per-binding phase offset is a later extension only if a concrete VFX needs it.

LOD filtering happens before Runtime Modulation runtime construction. The
compiled filtered program retains only bindings reachable from included Layer
Specs. A LOW Headlight plan has its two Core renderers and their bindings; it
does not evaluate Soft-only bindings or allocate a Soft renderer.

## Preview and allocation boundary

The later Preview UI adds a compact session-only Runtime Inputs row when the
active plan uses modulation:

- `speed_normalized`: slider `[0, 1]`;
- `longitudinal_load`: signed slider `[-1, 1]`;
- oscillator: no slider; it follows playback time.

Controls do not dirty a Preset, do not become Studio authoring data, and are
not exported. Edit and GAME Canvas continue to route the same runtime packets;
their projection differs only by existing view scale/zoom rules.

At plan build, the Studio compiles source IDs, input slots, target identifiers,
operation, mapping numbers, and clamp numbers into immutable typed Specs. At
runtime construction, the filtered compiled program exposes its binding count.
When that count is zero, it creates no modulation evaluator/state, samples no
oscillator, traverses no Runtime Input binding, and uses the existing rendering
path unchanged. Static Presets are therefore a true no-modulation fast path,
not merely a program that evaluates empty arrays.

When binding count is non-zero, one
`VfxPreviewRuntimeModulationEvaluator` exists per active VFX runtime. It
samples each reachable shared source once per tick, then lets all consumer
bindings reuse that scalar. It writes into preallocated effective Layer state.
No modulation path may traverse JSON, parse a String path, load an asset,
allocate a Dictionary/Array, create a Node/Tween/Timer, or create a per-binding
Object during steady state.

`TEXTURED_SPRITE` keeps its one activation-time packet. On a modulated tick,
the renderer updates that packet's existing geometry scale, geometry rotation,
position, and alpha scalar values in place from the preallocated effective
state. The packet's authored `transform` diagnostic data remains immutable;
the geometry fields are the effective transform sent to the Canvas. It must
not clear/recreate the stored packet array, allocate a new stored packet
Dictionary/Object or replacement transform Dictionary, or create a Node. The
stored packet/state identity remains stable across ticks. The pre-existing
defensive copies at the public packet handoff remain an unchanged baseline, not
a modulation allocation. Other renderers may adopt equivalent in-place state
where their packet model supports it; no new allocation may be attributed to
modulation.

Preview vehicle translation/rotation remains `VfxPreviewSharedState` vehicle
motion. Runtime Modulation is only a Layer effective-value step and must not
modify vehicle motion state or Profile anchors.

## Validation and error policy

The Schema adds an explicit rule handler selected by a new
`RUNTIME_MODULATION_CONFIGURATION` rule. It validates:

- unique Preset source IDs and unique binding IDs within a Layer;
- source type shape and existing source references;
- known Runtime Input names that are also declared by this Preset;
- supported target, Layer-Type compatibility, and allowed operation;
- `LINEAR_RANGE` order and finite mapping values;
- oscillator `SINE` wave, finite non-negative frequency, and finite phase;
- unique clamp targets, finite clamp bounds, and `min_effective <= max_effective`;
- `modulation_pivot_local` is exactly two finite numbers and any non-zero pivot
  is permitted only for a Layer Type configured as attachment-pivot compatible;
- all configured target domains and no unsupported extra properties.

Malformed Schema rule configuration is a `SCHEMA_CONFIGURATION` error. A bad
Preset binding is a `PRESET_VALIDATION` error with the specific JSON pointer.
The compiler and renderer must not silently ignore invalid modulation.

The Schema-owned compatibility configuration also identifies whether a target
can affect attachment geometry and whether a Layer Type has a non-zero pivot
contract. GDScript may compile and consume those declarations but must not
carry a second manually-maintained Layer-Type/pivot compatibility list.

## Versioning and Export decision

### Preset Schema

Keep `schema_version: 1`. The top-level source table, Layer bindings, clamps,
and `longitudinal_load` input are additive optional Schema v1 fields, following
the existing additive `alpha_*`, size-multiplier, and `TEXTURED_SPRITE`
precedent. Old Presets omit them, normalize to empty arrays, and have effective
values equal to authored values. No source migration is required.

### Runtime Definition

Use `runtime_definition_version: 2` for a modulated Package. Runtime
modulation is executable renderer semantics, not safely ignorable descriptive
metadata. The existing v1 document names
`runtime/vfx_runtime_definition_v1.json` and has no modulation contract;
silently putting bindings into it could yield a visual mismatch in an existing
game importer.

Package layout/Manifest remains `package_format_version: 1`; Manifest points to
`runtime/vfx_runtime_definition_v2.json` and records version `2` plus its
actual hash and byte size. Runtime Definition v2 contains the normalized
`runtime_modulation_sources` and each Layer's normalized `modulations` and
`modulation_clamps`. It contains no Preview slider values, elapsed time,
Performance Snapshot, source paths, or compiled Studio object layout.

An importer keeps accepting v1 static packages unchanged and adds explicit v2
support before a modulated Package is used. This decision does not require
reading or changing DesktopIdleRacing during Studio design.

### Phase A/B Export fail-closed guard

The additive Preset Schema must not create a window in which a modulation-valid
Preset silently compiles to static Runtime Definition v1. Phase A therefore
adds a small Export compiler guard before any v2 writer exists:

| Normalized Preset state | Phase A/B Export result |
| --- | --- |
| no sources, bindings, or clamps | existing v1 compile path and output remain unchanged |
| any modulation surface present | fail before a Package plan/write with an explicit Export validation issue |

For this purpose, a Preset is modulation-bearing if
`runtime_modulation_sources`, any Layer `modulations`, or any Layer
`modulation_clamps` is non-empty. The recommended issue is kind
`EXPORT_VALIDATION`, code `modulated_preset_requires_runtime_definition_v2`,
following the compiler's existing lowercase code convention. It must explain
that a Runtime Definition v2 compiler is required; it must not strip bindings,
ignore them, downgrade to static v1, or emit a partial manifest.

Phase C replaces this guard only for a deterministic v2 compile path. It keeps
the v1 path for a static Preset and still fails closed if v2 data cannot be
compiled. The guard is intentionally an Export-only safety seam: it does not
block Phase A Studio Preview evaluation or Phase B Headlight authoring.

## Headlight and reuse examples

### Headlight illustration only

`driving.headlights` would later declare `speed_normalized` and
`longitudinal_load`, use shared `road_motion`, and apply:

- `transform.modulation_pivot_local`: Core `[-0.5, 89]`, Soft `[-0.5, 49]`;
- Core/Soft `TRANSFORM_SCALE_Y`: speed `1.00 -> 1.06`;
- Core/Soft `TRANSFORM_SCALE_Y`: longitudinal load `.90 -> 1.10`;
- Core/Soft `TRANSFORM_SCALE_Y`: road oscillator `.985 -> 1.015`;
- beam rotation: oscillator `ADD` around `±0.25–0.4°`;
- beam offset: oscillator `ADD` around `±0.2–0.5` source pixels;
- Soft `VISUAL_OPACITY_MULTIPLIER`: speed `1.00 -> 1.05`.

Those are examples, not final Headlight authoring values.

Phase B verifies all four beam Layers against their bilateral lamp roots. For
each Core/Soft left/right Layer, scale multiplier samples `0.90`, `1.00`, and
`1.10` plus rotation deltas `-0.4`, `0`, and `+0.4` degrees must resolve the
declared local pivot to its authored lamp root within a small source-space
epsilon (recommended `<= 0.001` source pixels). The test evaluates the generic
effective-origin math, never a Headlight-specific compensation branch.

### Reuse checks

- Standard Booster can map `speed_normalized` or `intensity` to
  `TRANSFORM_SCALE_Y` and `VISUAL_OPACITY_MULTIPLIER`.
- High-Speed Wind can map `speed_normalized` to streak scale and visual alpha
  without increasing spawn rate, lifetime, or capacity.
- A future Forcefield can map `intensity` and one shared oscillator to scale
  and visual alpha without a Shield-specific controller.

None of these Presets changes in Runtime Modulation v1 Phase A.

## Test strategy for a future implementation

### Contract

- modulation absent normalizes/evaluates to authored base values;
- valid input mapping, signed `longitudinal_load`, clamps, and ordered
  composition;
- invalid source, undeclared input, target, operation, ranges, clamp, duplicate
  ID, and non-finite number each yield an explicit issue;
- absent pivot normalizes to `[0, 0]`; malformed/non-finite pivots and a
  non-zero pivot on a non-compatible Layer Type are rejected;
- new Schema configuration is rejected when its declared target contract is
  malformed.

### Preview

- `speed_normalized` slider changes only effective values;
- `longitudinal_load` at `-1/0/+1` produces expected factors;
- oscillator is deterministic, pause freezes it, and restart resets it;
- Edit and GAME receive the same canonical effective packet values;
- a Headlight-style non-centre pivot preserves its attachment root across
  `0.90/1.00/1.10` scale and `-0.4/0/+0.4` degree rotation samples;
- static `TEXTURED_SPRITE` uses the unchanged no-evaluator path;
- modulated `TEXTURED_SPRITE` refreshes its stored persistent packet/effective
  state in place with stable identity and no Headlight branch; the test does
  not mistake the existing defensive public packet copy for a new modulation
  allocation.

### LOD and performance

- filtered Layers do not have evaluator bindings or source consumers;
- HIGH/MEDIUM/LOW retain their existing instance counts and particle capacity;
- a static filtered program has zero evaluator work, zero oscillator samples,
  and zero Runtime Input modulation traversal;
- a shared oscillator is sampled once per VFX instance/source per tick even
  when multiple Layers consume it;
- structural tests confirm evaluator/effective state is created at rebuild, not
  per tick, and modulated packet/state identity remains stable.

### Export and later parity

- static v1 packages remain byte-compatible when no v2 export is requested;
- before Phase C, each modulation-bearing Preset fails Export with
  `modulated_preset_requires_runtime_definition_v2`, creates no Package plan,
  and cannot emit a v1 Runtime Definition or manifest;
- v2 Runtime Definition and Manifest are deterministic;
- source/runtime contract round-trips without Studio paths;
- future Studio/Game tests use the same inputs and time to produce the same
  effective values.

## Implementation map and phased handoff

### Phase A — generic Studio contract and Preview evaluation

Expected files include:

- `schemas/vfx_schema_v1.json`: additive fields, enums, target configuration,
  `longitudinal_load`, `transform.modulation_pivot_local`, and the declared
  semantic rule;
- `src/model/vfx_rule_catalog.gd`, `vfx_schema_registry.gd`, and
  `vfx_contract_validator.gd`: one explicit configuration/authoring rule;
- new focused immutable Specs under `src/preview/runtime_modulation/`:
  `vfx_runtime_modulation_source_spec.gd`,
  `vfx_runtime_modulation_binding_spec.gd`,
  `vfx_runtime_modulation_program.gd`,
  `vfx_preview_runtime_modulation_evaluator.gd`, and
  `vfx_preview_effective_layer_state.gd`;
- Preview plan builder/plan/layer spec/LOD filter/runtime/base renderer and
  concrete renderers: compile, filter, evaluate, apply attachment-preserving
  effective transforms, and consume effective values;
- Preview input state/UI and focused unit, Preview, LOD, and performance tests.

Phase A also adds the small `VfxExportCompiler` fail-closed guard for any
modulation-bearing Preset. It neither writes Runtime Definition v2 nor changes
the static v1 export bytes.

Phase A implements the generic capability with no production Preset binding.

### Phase B — Headlight authoring and Studio verification

Modify only `presets/examples/driving.headlights.vfx.json` and focused
Headlight tests. Declare required inputs, bindings, and generic local pivots
after GUI review. Confirm attachment-root preservation, clamp occupancy, and
GAME 100% HIGH/MEDIUM/LOW visual behavior. The Phase A/B Export guard blocks
Package export until Phase C; do not re-export until separately approved.

### Phase C — Runtime Definition v2 and DesktopIdleRacing integration

Add deterministic v2 compilation, including sources, per-Layer bindings,
clamps, and `modulation_pivot_local`; add Manifest version/path handling,
Package docs, and Studio export tests. Replace the Phase A/B guard only after
the v2 plan is fully valid. In a separately authorized DesktopIdleRacing task,
add explicit v2 importer validation and the same evaluator semantics before
re-exporting or binding a modulated Headlight in game. Studio never writes the
game repository.

## Non-goals

- arbitrary parameter paths, JSON pointers, formulas, scripting, or `eval`;
- graph/timeline editors, shader parameters, curve editing, random jitter, or
  dynamic LOD;
- gameplay physics, brake calculation, steering adaptive headlights, lighting,
  shadows, target search, or game triggers;
- a Headlight-specific renderer/controller;
- Package re-export or DesktopIdleRacing changes during this design pass.
