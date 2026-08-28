# DesktopRacingVFXStudio Phase 0 Design

## Goal

Establish a standalone Godot 4.7.1 stable project and a strict, testable `.vfx.json` VFX authoring contract without implementing VFX editor UI, rendering, export, or game integration.

## Architecture

The machine-readable `schemas/vfx_schema_v1.json` is the declarative contract source. It contains all authoring field constraints and configuration for the small semantic-rule handler set. GDScript reads that Schema to decode, normalize, validate, and deterministically serialize Presets; it does not duplicate Schema data as parallel enum or default tables.

The data pipeline preserves raw decoded JSON as a `Variant`, normalizes a deep copy, validates the normalized value, then exposes a validated top-level Dictionary through `VfxPresetDocument`. Errors are structured with categories and JSON Pointer paths.

## Contract decisions

- `.vfx.json` is authoring source; exported resources are derived artifacts.
- Lifecycle uses independent Phase Layer Stacks: one-shot or start/loop/end.
- Layers support default-space inheritance, optional Space Mode override, vehicle anchors when applicable, transforms, limited render planes, blend, and importance LOD.
- Particle supports an explicit emitter object, simple motion, burst or continuous emission, and authoring particle capacity.
- Layer Type parameter schemas are selected from Schema configuration, not through a generic `oneOf` implementation.
- Local `#/$defs/...` references are the only reference form.
- Preset performance measurements are derived later; importance is source authoring policy.
- Runtime input declarations identify required inputs but do not create bindings or expressions.

## Validation and normalization

The validator implements only the JSON Schema vocabulary used by v1 plus the declared `x_vfx_rules`. Validation is read-only. The normalizer deep-copies its input and applies Schema defaults only. Schema configuration is checked and cached before Preset processing, including local references, cycles, rule definitions, type registry entries, runtime input definitions, and default compatibility.

## Verification

The project uses a dependency-free GDScript test runner. It checks codec failures and variant top levels, Schema configuration, default application without raw mutation, structural validation, all semantic rules, example round trips, and deterministic normalized pretty JSON output. Tests run with the installed Godot 4.7.1 stable executable in headless mode.

## Scope boundary

Phase 0 creates no renderer, no UI, no export package, no generated VFX files, no asset manager, no migration framework, and no Desktop Idle Racing project dependency.
