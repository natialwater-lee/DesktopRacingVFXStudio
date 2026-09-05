# Generic VFX Bend B2 — Contract, Authoring, and Runtime v2 Export

## Status and scope

This design adds a deliberately small, portable Generic Bend v1 declaration to
Schema v1. DesktopRacingVFXStudio will author, normalize, validate, save/load,
and export the declaration. It will **not** render a bent texture in Studio
Preview. Actual deformation belongs to a later Game Runtime BEND-C task.

The design does not add a shader, material, Preview node, CanvasItem adapter,
packet-ordering field, compositor, renderer service, evaluator service, Package
Format version, or Runtime Definition v3. Existing production Super Booster
Presets and canonical Packages are specifically outside this change.

## Authoring contract

`visual_bend` is an optional Layer property. It is valid only on a
`TEXTURED_SPRITE` Layer:

```json
"visual_bend": {
  "axis": "LOCAL_Y_POSITIVE",
  "start_ratio": 0.333333,
  "curve": "QUADRATIC",
  "span_source_px": 250.0
}
```

All four fields are required when `visual_bend` is present, and the object is
strict (`additionalProperties: false`). There is no default `visual_bend`
object: omitted metadata means no bend capability and preserves every existing
Preset byte-for-byte after normalization.

`transform.modulation_pivot_local` is the bend origin. The metadata creates no
static displacement: its base `VISUAL_BEND_OFFSET_X` value is `0.0`
source-local pixels, so a metadata-only Layer remains straight.

### Fixed v1 semantics

`LOCAL_Y_POSITIVE` is the only accepted axis. From the existing pivot, bend
weight proceeds along local `+Y` over `span_source_px`; it never derives a
span from texture dimensions. `start_ratio` is finite and `0 <= start_ratio <
1`. `span_source_px` is finite and strictly greater than zero.
`QUADRATIC` is the only curve.

The later Runtime uses this fixed formula; B2 documents and serializes it but
does not execute it in Preview:

```text
t = clamp((local_y - pivot_y) / span_source_px, 0, 1)
u = clamp((t - start_ratio) / (1 - start_ratio), 0, 1)
weight = u * u
```

`VISUAL_BEND_OFFSET_X` is a Runtime Modulation target with source-local-pixel
units. Positive means canonical local `+X` tail displacement; negative means
local `-X`. The target accepts `ADD` only. It is valid only when the Layer
is `TEXTURED_SPRITE`, declares `visual_bend`, and declares one existing
target-level `modulation_clamps` entry. The generic `LINEAR_RANGE` mapping,
ordered binding composition, and one final target clamp are reused unchanged.

## Validation and Schema ownership

The JSON Schema owns property names, allowed enum values, and the Runtime
Modulation target table. `RUNTIME_MODULATION_CONFIGURATION` remains the one
Schema-owned semantic rule; it receives declarative target metadata such as
`requires_static_field: "visual_bend"` and
`requires_target_clamp: true`. `VfxRuleCatalog`, Registry, and Contract
Validator consume that configuration; they do not duplicate enum lists or
build a second bend subsystem.

The existing Schema subset validates object shape, enums, and standard bounds.
The existing Contract Validator adds strict semantic checks for finite numbers,
`start_ratio < 1`, `span_source_px > 0`, metadata/Layer-Type compatibility,
and required target clamps. Bad data remains a `PRESET_VALIDATION` failure;
malformed rule configuration remains a `SCHEMA_CONFIGURATION` failure.
Invalid data is never ignored or downgraded.

## Inspector boundary

`VfxLayerInspector` may gain one compact `Visual Bend` subsection, visible
only for `TEXTURED_SPRITE`. An enable/disable control creates/removes the
complete optional object, and four ordinary Schema-backed controls edit
`axis`, `start_ratio`, `curve`, and `span_source_px`. This is not a
panel, dialog, or new editor component.

The existing Transform area may expose the existing two-number
`modulation_pivot_local` field using the present controls and controller commit
path. No transform architecture changes are allowed.

There is intentionally no Bend binding editor and no generic Runtime Modulation
editor in B2. The Studio has no UI for authoring any `modulations` array;
bindings, mapping, and clamps remain valid source-contract JSON authoring. The
target enum, validator, generic evaluator, and export path fully support
`VISUAL_BEND_OFFSET_X` once such source is loaded.

## Preview boundary

No Preview rendering file changes. The existing generic modulation Program
already receives target names from Schema. Its packed numeric state initializes
an unrecognised target slot to `0.0`, the evaluator applies the normal mapping
and final clamp, and no textured-sprite renderer reads that slot. Thus a bend
fixture can be Preview-loaded and evaluated without a crash, but remains a
straight `draw_texture_rect()` texture. No Preview state, slider value,
packet, or renderer class enters exported data.

## Runtime Definition v2 and Package Format v1

A Preset selects Runtime Definition v2 when it contains any current modulation
surface **or** any `visual_bend` metadata. The v2 Layer record copies the
normalized `visual_bend` object only when present, alongside existing generic
`modulations`, `modulation_clamps`, and modulation pivot. It does not
contain shader implementation data, sampled bend amounts, Preview values, or
filesystem paths.

Static non-bend Presets retain Runtime Definition v1 and its existing golden
bytes/path. A v1 record never leaks `visual_bend`, the bend target, or a
pivot. Package Format remains v1; its existing Manifest and atomic writer
merely carry compiler-selected v2 text in a test-only Package plan.

## Test strategy

A small test-only `TEXTURED_SPRITE` fixture declares an explicit pivot,
`visual_bend`, a `turn_rate_normalized -> VISUAL_BEND_OFFSET_X` ADD mapping,
and a `[-60, 60]` target clamp. Tests cover valid data; invalid
axis/curve/ratio/span/non-finite values; non-sprite and missing-metadata
targets; wrong operation; missing clamp; generic evaluator mapping and
clamping; Inspector save/load; v2 serialization and writer portability; v1
no-leak; and Preview straight fallback. Existing Headlight, Super Booster,
static-v1, Contract, Editor, Preview, Performance, and Export suites remain
regressions.

## Non-goals and stop condition

If implementation requires a Preview renderer change, packet ordering change,
shader/material, Preview node/adapter, Runtime Definition v3, Package Format
change, generic modulation editor, or bend-specific service/manager/evaluator,
implementation stops and reports the dependency. No canonical Package write,
production Preset change, Windows Export, Game repository access, `git add`,
or Git commit is permitted.
