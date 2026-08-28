# DesktopRacingVFXStudio Architecture

## Purpose and scope

DesktopRacingVFXStudio is an independent Godot 4.7.1 stable project for authoring 2D VFX used by Desktop Idle Racing. It is not a generic VFX package, a Node Graph editor, a 3D tool, or a gameplay-decision system.

The Studio owns how an effect looks. The game owns when an effect is created, which vehicle or world position receives it, gameplay targeting, and the lifetime of a START_LOOP_END loop.

Phase 0 establishes the project foundation and data contract. Phase 1 adds a contract-backed Layer Stack authoring surface for `.vfx.json` Presets. Neither phase includes a Particle Renderer, preview rendering, an export pipeline, generated assets, or changes to the Desktop Idle Racing project.

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

The codec never assumes decoded JSON is a `Dictionary`. A valid JSON array, string, or number reaches validation and receives a `PRESET_VALIDATION` error at `/type`.

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

The Schema declares the common runtime input contract: `intensity`, `speed_normalized`, `vehicle_velocity`, `turn_strength`, `effect_radius`, and `surface_type`. A Preset lists only inputs it actually needs in `runtime_inputs`.

Phase 0 defines the input names, value shapes, and default values only. It does not define a generic binding, expression, curve, or automation system that maps an input to a Layer parameter. A listed input is therefore an interface promise from the game to a future renderer, not an implicit visual rule.

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

The following boundaries remain intentionally reserved after Phase 1:

- `preview/`: real-size vehicle readability checks.
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
