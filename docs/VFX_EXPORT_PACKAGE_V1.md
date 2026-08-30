# VFX Export Package v1

## Purpose and ownership

A VFX Export Package is a deterministic, self-contained artifact produced by
DesktopRacingVFXStudio from one **saved, contract-valid** `.vfx.json` Preset.
The Preset source remains the authoring source of truth. A package is derived
data for review and for a future DesktopIdleRacing importer/runtime.

The direction is strictly one way:

```text
DesktopRacingVFXStudio
  -> VFX Export Package
  -> DesktopIdleRacing importer/runtime
```

The Studio does not read, modify, or write into the game repository. An
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
    vfx_runtime_definition_v1.json
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

`runtime/vfx_runtime_definition_v1.json` is compiled from
`VfxPresetDocument.normalized_data`. It makes each Layer's effective
`space_mode` explicit and carries portable semantic data only:

- the mandatory `coordinate_contract` for the fixed vehicle source-local
  authoring frame;
- preset identity, category, lifecycle mode, and default space mode;
- ordered phases and ordered Layer records;
- Layer type, enabled state, importance, blend, plane, sort order, anchors,
  normalized transform, and normalized type-specific parameters;
- declared runtime-input contracts and required vehicle anchors.

It never contains a Studio or game filesystem path, Preview renderer class,
scene, shader, `.tres`, Vehicle Profile, Preview asset implementation detail,
Stress Snapshot, authoring budget, threshold, or other Performance data.

## Coordinate contract

Every Runtime Definition v1 contains this top-level metadata block, even when
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

The block is Runtime-only: it is not inserted into authoring Source JSON and
is not duplicated in the Manifest. `runtime_definition_version` remains `1`;
the contract was completed before a Game Importer was released.

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

## Importer validation requirements

Before consuming a Package, an importer must:

1. Require `package_format_version == 1` and supported runtime/VFX Schema
   versions.
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
