# VFX Export Package v1

공용 작업 경계·확인 순서·인계 형식: [Game 공용 VFX 작업 안내](../../DesktopIdleRacing/docs/VFX_EXPORT_PACKAGE_V1.md#shared-vfx-workflow).

## Purpose and ownership

A VFX Export Package is a deterministic, self-contained artifact produced by
DesktopRacingVFXStudio from one **saved, contract-valid** `.vfx.json` Preset.
The Preset source remains the authoring source of truth. A package is derived
data for review and the DesktopIdleRacing importer/runtime.

The direction is strictly one way:

```text
DesktopRacingVFXStudio
  -> VFX Export Package
  -> DesktopIdleRacing importer/runtime
```

The Studio application/export pipeline does not depend on or write into the game repository. Agent read-only inspection follows the shared workflow linked above. An
importer owns game resource creation, gameplay trigger timing, target results,
ownership, and lifecycle activation. The Package contains no gameplay decision
logic.

## Fixed layout

```text
exports/packages/<preset_id>/
  manifest.json
  source/
    <preset_id>.vfx.json
  runtime/
    vfx_runtime_definition_v1.json | vfx_runtime_definition_v2.json
  assets/
    <approved-production-png>.png
```

`package_format_version`, `runtime_definition_version`, and
`vfx_schema_version` are independent compatibility fields. Package directory
names are the validated `preset_id`; Export rejects an unsafe ID rather than
silently sanitising it. Phase 5 does not create `preview.png`.

## Source and runtime representations

`source/<preset_id>.vfx.json` is a deterministic JSON encoding of
`VfxPresetDocument.raw_data`, after the saved file has successfully decoded,
normalized, and validated. It preserves authoring meaning, including omitted
Schema defaults, but does not preserve original whitespace or key order.

Every Runtime Definition is compiled from `VfxPresetDocument.normalized_data`.
Static Presets use `runtime/vfx_runtime_definition_v1.json`; a
modulation-bearing Preset uses `runtime/vfx_runtime_definition_v2.json`. The
v2 selection is additive to Package Format v1 and does not change the source
or Manifest layout. Both versions make each Layer's effective
`space_mode` explicit and carries portable semantic data only:

- the mandatory `coordinate_contract` for the fixed vehicle source-local
  authoring frame;
- preset identity, category, lifecycle mode, and default space mode;
- ordered phases and ordered Layer records;
- Layer type, enabled state, importance, blend, plane, sort order, anchors,
  normalized transform, and normalized type-specific parameters;
- declared runtime-input contracts and required vehicle anchors.

`TEXTURED_SPRITE` Runtime Layer records are compiled generically from their
normalized `type`, common Layer fields, and `parameters` object. The asset
dependency is derived from `texture_asset_ref` through the Schema just like
other logical texture fields. Package compilation does not create a Godot
Sprite resource or imply that an importer already renders this Layer Type.
Runtime Definition v2 adds the documented portable Runtime Modulation contract
below. It does not export Preview state or an executable Studio evaluator.

It never contains a Studio or game filesystem path, Preview renderer class,
scene, shader, `.tres`, Vehicle Profile, Preview asset implementation detail,
Stress Snapshot, authoring budget, threshold, or other Performance data.

## Coordinate contract

Every Runtime Definition v1 or v2 contains this top-level metadata block, even when
a Preset currently has only `WORLD_AREA` or `SCREEN_UI` Layers:

```json
"coordinate_contract": {
  "vehicle_source_canvas_size_px": [256, 512],
  "origin": "CENTER",
  "front_axis": "-Y"
}
```

It is the source-local coordinate frame for `VEHICLE_LOCAL` and
`VEHICLE_FOLLOW_WORLD_TRAIL`: source canvas `256 × 512` pixels, local `[0, 0]`
at the source canvas centre, `+X` to the vehicle's right, `+Y` rear/down, and
`-Y` toward the vehicle front. Vehicle-local Anchor values and
`transform.offset` use these source-local pixel coordinates.

This is not an instruction to render a vehicle at `256 × 512` screen pixels.
Actual display size, vehicle scale, and projection remain the
DesktopIdleRacing Runtime Renderer's responsibility. The Package exposes this
metadata so the game does not need duplicate hidden coordinate constants.

`PARTICLE.parameters.direction_degrees` uses the Layer's effective coordinate
space: `0` is its negative Y axis, `90` is `+X`, `180` is `+Y`, and `270` is
`-X`. `spread_degrees` is centered on that direction. For `VEHICLE_LOCAL`, `0`
is vehicle forward (`-Y`); for `VEHICLE_FOLLOW_WORLD_TRAIL`, it is vehicle-local
`-Y` at spawn/capture; for `WORLD_AREA` and `SCREEN_UI`, it is the corresponding
world/local or screen/UI `-Y` axis. Vehicle-space angles are not screen-space
angles, so vehicle rotation preserves their authored forward meaning in both
Preview and Runtime.

`PARTICLE.parameters.size_multiplier_min` and
`size_multiplier_max` are normalized Runtime Definition v1 fields. They define
one uniform scalar sampled per particle spawn, then held for that particle's
entire lifetime after the linear `size_start`/`size_end` interpolation. Both
default to `1.0`; an omitted Source authoring field therefore still appears as
`1.0` in the Runtime Definition without changing Source JSON. The scalar is not
independent X/Y scale and preserves the texture aspect ratio. A `1.0` / `1.0`
range consumes no additional deterministic Preview RNG; a non-degenerate range
uses exactly one seeded sample per spawn.

The block is Runtime-only: it is not inserted into authoring Source JSON and
is not duplicated in the Manifest. The Manifest selects the Runtime Definition
version and relative path whose bytes it hashes.

## Manifest v1

`manifest.json` includes these required semantic sections:

| Field | Meaning |
| --- | --- |
| `package_format_version` | This Package layout and Manifest contract version (`1`). |
| `package_id` | The validated Preset ID. |
| `preset` | Display metadata plus VFX Schema/lifecycle/default-space values. |
| `source` | Source package-relative path, SHA-256, and byte size. |
| `runtime_definition` | Runtime version, path, SHA-256, and byte size. |
| `requirements` | Required vehicle Anchors, runtime input names, and semantic Importance summary. |
| `asset_dependencies` | Logical asset ID to physical package-file mapping and metadata. |
| `files` | Every hashed payload file except `manifest.json` itself. |

`files` never hashes `manifest.json`, avoiding a self-referential checksum.
`asset_dependencies` may map more than one logical ID to the same byte-identical
physical asset. Each physical asset is copied once per Package; there is no
shared external asset store.

## Asset policy

Only explicit `EXPORTABLE` `TEXTURE_PNG` entries from
`config/vfx_export_asset_policy_v1.json` may be copied. Preview availability is
not Export eligibility. Missing, unregistered, procedural, fixture,
non-production, unreadable, or non-PNG dependencies fail Export. No magenta
Preview fallback is exported.

`config/vfx_export_preset_policy_v1.json` contains narrow Preset exceptions.
For example, `utility.renderer_showcase` remains a Studio validation fixture
and is blocked without treating all `UTILITY` Presets as non-exportable.

## Runtime Definition v1/v2 selection and Runtime Modulation v1

The compiler selects Runtime Definition v2 when any validated authoring array is
non-empty—root `runtime_modulation_sources`, a Layer's `modulations`, or a
Layer's `modulation_clamps`—or when a `TEXTURED_SPRITE` Layer declares static
`visual_bend` metadata. Other static Presets compile to Runtime Definition v1 at
`runtime/vfx_runtime_definition_v1.json`; v2-bearing Presets compile to Runtime
Definition v2 at `runtime/vfx_runtime_definition_v2.json`.
`modulation_pivot_local` alone does not promote a static Preset to v2.

Static v1 compatibility remains intentional: v1 transforms contain only
`offset`, `rotation_degrees`, and `scale`. A pivot-only static Source copy
retains its authored pivot, but the v1 Runtime Definition does not export it.
If v2 compilation cannot produce a valid portable Runtime Definition, Export
fails before a Package Plan, Manifest, asset copy, or writer operation exists;
it never falls back to v1.

Runtime Definition v2 retains every v1 field and adds only portable declarative
modulation data:

- root `runtime_modulation_sources` in source order;
- each Layer's `modulations` and target-level `modulation_clamps` in source
  order; and
- `transform.modulation_pivot_local`; and
- optional `TEXTURED_SPRITE.visual_bend` metadata exactly when authored.

`visual_bend` is portable declarative metadata: `LOCAL_Y_POSITIVE` axis,
quadratic curve, start ratio, and source-pixel span. Its
`VISUAL_BEND_OFFSET_X` bindings use the existing generic mapping/ADD/clamp
rules. Runtime Definition v2 carries the data but does not carry Preview packet
state, a shader, a material, an evaluated bend curve, or any instruction that a
consumer must infer behavior without a validated binding.

It retains all authoring Layer records, including disabled Layers and their
`CORE`/`DETAIL`/`EXTRA` importance; Export never bakes Studio LOD filtering.
It excludes Preview slider values, elapsed time, sampled oscillator values,
compiled numeric slots, effective states, packets, performance data, Studio or
game paths, and Godot Node paths.

For one active Phase, an importer evaluates v2 as:

```text
authored base
  -> binding mappings in declared order
  -> ordered ADD/MULTIPLY target composition
  -> one target clamp after composition
  -> attachment-preserving effective transform
  -> renderer
```

`OSCILLATOR/SINE` evaluates as
`sin(TAU * frequency_hz * instance_elapsed_seconds + phase_radians)`, where
`instance_elapsed_seconds` is the VFX lifecycle simulation time, not wall-clock
time. `VISUAL_OPACITY_MULTIPLIER` produces final alpha
`clamp(authored_or_animated_alpha * multiplier, 0, 1)`.

Runtime Definition v2 may also carry a strict portable `LINEAR_PHASE` source
record containing only `id`, `type: "LINEAR_PHASE"`, and a finite positive
`frequency_hz`. It carries no `wave` or `phase_degrees`. A compatible consumer
evaluates it from the same effect-local elapsed time as
`fposmod(instance_elapsed_seconds * frequency_hz, 1.0)`, whose result is in
`[0.0, 1.0)`. Continuous rotation direction is authored through an existing
`LINEAR_RANGE` mapping and `TRANSFORM_ROTATION_DEGREES` `ADD`, not through a
negative frequency. This is declarative v2 data only; it does not change
Package Format v1 or export Preview runtime state. Static v1 definitions do not
contain `LINEAR_PHASE`, `frequency_hz`, or an empty source-table placeholder.

For pivot `p`, authored origin `O_base`, authored matrix `M_base`, effective
matrix `M_effective`, and intentional dynamic offset `D`, the attachment is
preserved by:

```text
attachment_root = O_base + M_base * p
O_effective = attachment_root + D - M_effective * p
```

This is a generic source-local transform contract, not a Headlight-specific
offset rule.

## Importer validation requirements

Before consuming a Package, an importer must:

1. Require `package_format_version == 1`, a supported Runtime Definition
   version/path pair (`v1` or `v2`), and VFX Schema version.
2. Reject an unsafe package-relative path: empty, absolute, drive-qualified,
   backslash-separated, `res://`, `user://`, or traversing (`.`/`..`) paths.
3. Verify every Manifest-listed file exists beneath the Package root.
4. Verify each listed file's exact byte size and lower-case SHA-256.
5. Verify source/runtime role paths and logical asset mappings before using
   Runtime Definition content.
6. Treat missing or mismatched data as an import failure, not a fallback.

The importer may decide how to transform this portable semantic data into game
resources. It must not infer gameplay targeting or activation from the Package.

## Determinism and atomic writes

For identical saved source, Schema, policy, asset bytes, and format versions,
Package bytes are identical: JSON uses sorted keys, two-space indentation, and
a final LF; phases use lifecycle order; Layers keep source order; logical asset
dependencies and Manifest file inventory are lexical.

The writer creates and verifies a complete same-root staging Package under
`exports/.staging/` before replacement. An existing final Package is moved to
`exports/.backup/` only after staging succeeds, then restored if the final
rename fails. `REPLACE_EXISTING` is a whole-package replacement and is only
reached after local Editor confirmation. Temporary staging and backup paths are
ignored by Git; final Packages remain reviewable artifacts.
