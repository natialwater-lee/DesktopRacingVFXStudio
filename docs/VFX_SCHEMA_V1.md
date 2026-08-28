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

- direction and spread in degrees
- speed minimum and maximum
- acceleration vector `[x, y]`
- initial rotation range
- angular velocity range in degrees per second
- start and end size
- RGBA color array

`BURST` requires `burst_count`; `CONTINUOUS` requires `emission_rate_per_second` and `max_particles`. Continuous `max_particles` means authoring capacity for concurrently alive particles, not a Godot renderer property.

`emitter` is a strict shape object:

```json
{ "shape": "POINT" }
{ "shape": "CIRCLE", "radius": 8.0 }
{ "shape": "BOX", "size": [12.0, 6.0] }
{ "shape": "CONE", "angle_degrees": 30.0, "radius": 8.0 }
{ "shape": "LINE", "length": 12.0 }
```

`PARTICLE_EMITTER_SHAPE` validates geometry for the selected shape. `PARTICLE_MOTION_RANGE_ORDER` validates each declared minimum/maximum pair.

### TRAIL

`TRAIL` parameters are `texture_asset_ref`, `width_start`, `width_end`, `max_points`, `lifetime_seconds`, and `color_rgba`. Its source comes from Layer Anchor and transform; v1 does not add a separate generic Trail emitter shape.

### RING

`RING` parameters are `radius_start`, `radius_end`, `width`, `duration_seconds`, optional `repeat_interval_seconds`, and `color_rgba`. A repeat interval of zero means a single ring at Layer activation.

### GLOW

`GLOW` parameters are `radius`, `opacity`, `pulse_hz`, and `color_rgba`.

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
- `RUNTIME_INPUT_NAMES`
- `EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS`
- `RENDER_PLANE_FOR_EFFECTIVE_SPACE`

An undeclared rule is never inferred. An unknown declared rule is a `SCHEMA_CONFIGURATION` error.

## Strictness and defaults

Known objects use `additionalProperties: false`, including Type-specific parameters. The explicit exception is no exception in v1: there is no metadata bag.

Array item contracts use the Schema `items` keyword. It is required to validate Anchor enums, numeric vectors, and RGBA values; it adds no authoring feature beyond the arrays already defined above.

`default` declares a value only. Validation never mutates input. `VfxPresetNormalizer` creates a deep-copied normalized Variant and applies defaults. Unknown keys remain in that copy until validation rejects them.

## Reference support

Only local `#/$defs/...` references are valid. The Registry rejects external references, missing local references, and reference cycles before a Preset is processed.

## Checked Phase 0 examples

`presets/examples/talent.zero_zone.vfx.json` is a `START_LOOP_END` Race Talent combining start Glow/Ring, loop Glow/Ring/continuous energy-shard Particle, and an end burst Particle. All Layers inherit `VEHICLE_LOCAL` and explicitly use the `CENTER` Anchor.

`presets/examples/finish.confetti_world.vfx.json` is a `ONE_SHOT` Finish effect with a World-area burst Particle and no vehicle Anchor. The logical references in these examples intentionally do not require a Godot texture or `.tres` resource in Phase 0.
