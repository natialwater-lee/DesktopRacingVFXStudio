# VFX Schema v1

## Status

Schema v1 is the Phase 0 authoring contract for `.vfx.json`. It is frozen for the Phase 0 implementation. A later renderer phase may add compatible fields when an observed renderer need justifies them; broad speculative configuration is intentionally excluded.

## Top-level Preset

Every valid Preset is an object with these required properties:

```json
{
  "schema_version": 1,
  "preset_id": "talent.zero_zone",
  "display_name": "Zero Zone",
  "category": "RACE_TALENT",
  "lifecycle": { "mode": "START_LOOP_END" },
  "default_space_mode": "VEHICLE_LOCAL",
  "runtime_inputs": ["intensity"],
  "phases": {}
}
```

Unknown top-level properties are rejected. `preset_id` is a logical namespace ID, matching `^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$`. It is not a file path.

`category` is one of `BOOST`, `SLIP`, `SPECIAL_EQUIPMENT`, `RACE_TALENT`, `WEATHER`, `FINISH`, `RESULT_UI`, or `UTILITY`.

## Lifecycle and Phase Stack

`LIFECYCLE_PHASE_STRUCTURE` selects the only permitted phase structure.

```json
{
  "lifecycle": { "mode": "ONE_SHOT" },
  "phases": {
    "one_shot": {
      "duration_seconds": 0.8,
      "layers": []
    }
  }
}
```

```json
{
  "lifecycle": { "mode": "START_LOOP_END" },
  "phases": {
    "start": { "duration_seconds": 0.12, "layers": [] },
    "loop": { "layers": [] },
    "end": { "duration_seconds": 0.20, "layers": [] }
  }
}
```

Each phase permits an empty Layer array, but `PRESET_HAS_LAYER` requires at least one Layer across the complete Preset.

## Common Layer Base

```json
{
  "id": "loop.core_glow",
  "type": "GLOW",
  "importance": "CORE",
  "blend_mode": "ADDITIVE",
  "render_plane": "UNDER_VEHICLE",
  "sort_order": 0,
  "anchors": ["CENTER"],
  "transform": {
    "offset": [0.0, 0.0],
    "rotation_degrees": 0.0,
    "scale": [1.0, 1.0]
  },
  "enabled": true,
  "parameters": {}
}
```

Required Layer fields are `id`, `type`, `importance`, `blend_mode`, `render_plane`, and `parameters`. `enabled`, `sort_order`, and `transform` have Schema defaults. `space_mode` and `anchors` are optional.

Layer `id` uses the same namespaced-ID pattern as Preset IDs and is unique across every Phase in the Preset. `importance` is `CORE`, `DETAIL`, or `EXTRA`. `blend_mode` is `ALPHA` or `ADDITIVE`.

Anchors are `CENTER`, `FRONT`, `REAR_CENTER`, `REAR_LEFT`, `REAR_RIGHT`, `LEFT_SIDE`, `RIGHT_SIDE`, `TIRE_FL`, `TIRE_FR`, `TIRE_RL`, `TIRE_RR`, `EQUIPMENT_CENTER`, `WING_LEFT`, or `WING_RIGHT`.

The effective Space Mode is the Layer override when present, otherwise the Preset default. Vehicle spaces require one or more Anchors. World and Screen spaces reject Anchors. `render_plane` is constrained by effective Space Mode.

## Layer Types and parameters

The Schema extension `x_vfx_layer_types` maps each Layer Type to a local parameter `$defs` entry. Parameter objects are strict and selected by `TYPE_DISPATCHED_PARAMETER_SCHEMA`.

### PARTICLE

Required authoring concepts are `emission_mode`, `emitter`, `sprite_asset_ref`, and `lifetime_seconds`. Motion fields have Schema defaults:

- `direction_degrees` and `spread_degrees` use the Layer's effective coordinate space: `0` is its negative Y axis, `90` is `+X`, `180` is `+Y`, and `270` is `-X`. `spread_degrees` is centred on `direction_degrees`. For `VEHICLE_LOCAL`, `0` is vehicle forward (`-Y`); for `VEHICLE_FOLLOW_WORLD_TRAIL`, it is vehicle-local `-Y` at spawn/capture; for `WORLD_AREA` and `SCREEN_UI`, it is the corresponding world/local or screen/UI `-Y` axis.
- speed minimum and maximum
- acceleration vector `[x, y]`
- initial rotation range
- angular velocity range in degrees per second
- start and end size
- optional `size_multiplier_min` and `size_multiplier_max`: a uniform, per-spawn scalar range applied to the interpolated size. Both default to `1.0`, each is constrained to `0.1` through `4.0`, and the minimum cannot exceed the maximum. The selected multiplier is lifetime-fixed: `lerp(size_start, size_end, age_ratio) * size_multiplier`. It scales the overall particle size rather than independent X/Y axes, so a texture's aspect ratio is preserved. A default `1.0` / `1.0` range consumes no additional seeded Preview RNG.
- RGBA color array
- optional linear `alpha_start` and `alpha_end` factors, each in the inclusive range 0 through 1 and defaulting to 1

`BURST` requires `burst_count`; `CONTINUOUS` requires `emission_rate_per_second` and `max_particles`. Continuous `max_particles` means authoring capacity for concurrently alive particles, not a Godot renderer property.

`emitter` is a strict shape object:

```json
{ "shape": "POINT" }
{ "shape": "CIRCLE", "radius": 8.0 }
{ "shape": "BOX", "size": [12.0, 6.0] }
{ "shape": "CONE", "angle_degrees": 30.0, "radius": 8.0 }
{ "shape": "LINE", "length": 12.0 }
```

`PARTICLE_EMITTER_SHAPE` validates geometry for the selected shape. `PARTICLE_MOTION_RANGE_ORDER` validates each declared motion minimum/maximum pair. `PARTICLE_SIZE_MULTIPLIER_RANGE_ORDER` validates the declared size-multiplier range order.

### TRAIL

`TRAIL` parameters are `texture_asset_ref`, `width_start`, `width_end`, `max_points`, `lifetime_seconds`, and `color_rgba`. Its source comes from Layer Anchor and transform; v1 does not add a separate generic Trail emitter shape.

### RING

`RING` parameters are `radius_start`, `radius_end`, `width`, `duration_seconds`, optional `repeat_interval_seconds`, optional linear `alpha_start` / `alpha_end` factors, and `color_rgba`. Alpha factors are in the inclusive range 0 through 1 and default to 1. A repeat interval of zero means a single ring at Layer activation.

### GLOW

`GLOW` parameters are `radius`, `opacity`, `pulse_hz`, and `color_rgba`.

### TEXTURED_SPRITE

`TEXTURED_SPRITE` is a generic one-texture persistent Layer. Its only
type-specific authoring field is required `texture_asset_ref`; `opacity`
uses the inclusive zero-through-one alpha range and defaults to `1.0` during
normalization. It has no emitter, count, lifetime, motion, beam, or
Preset-specific parameter. The common Layer `transform` supplies its source
local offset, rotation, and non-uniform scale, while common blend mode,
render plane, importance, enabled state, lifecycle Phase, Space Mode, and
Anchors apply unchanged.

The Preview holds one texture packet for the active Phase rather than spawning
Particle instances. A later dynamic behavior extension must be an explicit,
generic compatible contract addition; Schema v1 does not infer runtime input
bindings, modulation, easing, or per-frame overrides for this Layer.

### SHIELD

`SHIELD` parameters are `radius`, `arc_degrees`, `thickness`, `opacity`, `scroll_speed`, optional `texture_asset_ref`, and `color_rgba`. `arc_degrees` is in the inclusive range 1 through 360; transform rotation places a panel around the vehicle.

## Logical asset references

Asset fields use logical IDs such as `fx.energy_shard` and `fx.confetti_square`, validated by the same namespaced-ID pattern. They cannot contain absolute paths or resource paths. Asset lookup and exported Godot Resource mapping are outside v1.

## Runtime inputs

The Schema extension `x_vfx_runtime_inputs` contains the only accepted names and their value contracts:

| Input | Value contract |
|---|---|
| `intensity` | number, 0 through 1, default 1 |
| `speed_normalized` | number, 0 through 1, default 0 |
| `vehicle_velocity` | vector2 array, default `[0, 0]` |
| `turn_strength` | number, -1 through 1, default 0 |
| `effect_radius` | number, minimum 0, default 0 |
| `surface_type` | logical identifier string, default `surface.default` |

A Preset lists only inputs it requires. v1 does not describe input-to-parameter bindings.

## Semantic rules

The supported `x_vfx_rules` are:

- `LIFECYCLE_PHASE_STRUCTURE`
- `PRESET_HAS_LAYER`
- `UNIQUE_LAYER_IDS_ACROSS_PHASES`
- `TYPE_DISPATCHED_PARAMETER_SCHEMA`
- `PARTICLE_EMISSION_CONFIGURATION`
- `PARTICLE_EMITTER_SHAPE`
- `PARTICLE_MOTION_RANGE_ORDER`
- `PARTICLE_SIZE_MULTIPLIER_RANGE_ORDER`
- `RUNTIME_INPUT_NAMES`
- `EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS`
- `RENDER_PLANE_FOR_EFFECTIVE_SPACE`

An undeclared rule is never inferred. An unknown declared rule is a `SCHEMA_CONFIGURATION` error. The rule configuration also declares the lifecycle-to-phase mapping, Particle emission-mode field requirements, emitter shape-to-geometry mapping, vehicle Space Modes that require Anchors, and allowed render planes per Space Mode. Particle semantic rules explicitly bind their `type_field` and `parameters_field` to the type-dispatch rule. Before it caches the Schema, the Registry resolves every configured path and field, verifies each handler’s expected Schema type and enum shape, checks mapping coverage for the referenced Schema enum values, and allows only declared parameter fields. The GDScript handlers consume those values; they do not keep parallel enum or relationship tables.

## Strictness and defaults

Known objects use `additionalProperties: false`, including Type-specific parameters. The explicit exception is no exception in v1: there is no metadata bag.

Array item contracts use the Schema `items` keyword. It is required to validate Anchor enums, numeric vectors, and RGBA values; it adds no authoring feature beyond the arrays already defined above.

`default` declares a value only. Validation never mutates input. `VfxPresetNormalizer` creates a deep-copied normalized Variant and applies defaults. Unknown keys remain in that copy until validation rejects them.

`alpha_start` and `alpha_end` are a Schema v1 additive extension introduced by the Phase 3.4 implementation. Existing Presets normalize both values to `1.0`, preserving their visual result. `size_multiplier_min` and `size_multiplier_max` are likewise additive Schema v1 fields: omitted fields normalize to `1.0` / `1.0` without changing the seeded Preview particle sequence. `TEXTURED_SPRITE` is an additive generic Layer Type introduced after the same compatibility policy: it adds no behavior to an existing Layer Type or Preset, and no migration or Schema v2 is required. A Preset that explicitly uses any additive extension requires a Studio Schema v1 implementation that supports it.

### Runtime Modulation v1 — Studio Preview scope

`runtime_modulation_sources` is an optional root array (default `[]`). Each Layer
has optional `modulations` and `modulation_clamps` arrays (both default `[]`), and
`transform.modulation_pivot_local` defaults to `[0.0, 0.0]`. These defaults retain
the static authoring result. `longitudinal_load` is the signed scalar Runtime Input
(`-1.0..1.0`, default `0.0`).

The Schema-owned `RUNTIME_MODULATION_CONFIGURATION` rule is the contract for
`SINE` sources and `LINEAR_RANGE` mappings. In Phase A every modulation target is
compatible only with `TEXTURED_SPRITE`. A binding on `PARTICLE`, `TRAIL`, `RING`,
`GLOW`, or `SHIELD` is a `PRESET_VALIDATION` error; it is never silently ignored.
Target clamps are Layer-target contracts and run once after ordered binding
composition. `VISUAL_OPACITY_MULTIPLIER` must be finite and non-negative, has no
authoring upper bound, and only the final `TEXTURED_SPRITE` alpha application
clamps its rendered result to `[0, 1]`.

## Reference support

Only local `#/$defs/...` references are valid. The Registry rejects external references, missing local references, reference cycles, malformed supported keyword values, and malformed nested rule configuration before a Preset is processed. It also rejects JSON Schema keywords outside the documented v1 subset.

## Checked Phase 0 examples

`presets/examples/talent.zero_zone.vfx.json` is a `START_LOOP_END` Race Talent combining start Glow/Ring, loop Glow/Ring/continuous energy-shard Particle, and an end burst Particle. All Layers inherit `VEHICLE_LOCAL` and explicitly use the `CENTER` Anchor.

`presets/examples/finish.confetti_world.vfx.json` is a `ONE_SHOT` Finish effect with a World-area burst Particle and no vehicle Anchor. The logical references in these examples intentionally do not require a Godot texture or `.tres` resource in Phase 0.
