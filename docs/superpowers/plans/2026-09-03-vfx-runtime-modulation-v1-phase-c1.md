# Runtime Modulation v1 Phase C-1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export modulated Presets as portable Runtime Definition v2 Packages while retaining byte-identical Runtime Definition v1 output for static Presets.

**Architecture:** `VfxExportCompiler` is the only version-selection seam. It classifies normalized source once, compiles either v1 or v2, and passes the chosen version/path/text to an immutable `VfxExportPackagePlan`; the existing atomic writer writes that plan without inferring a version. Runtime v2 projects only normalized portable modulation data and leaves Preview runtime objects and slots behind.

**Tech Stack:** Godot 4.7.1 stable, standard GDScript, existing JSON codec, SHA-256 package hashing, existing atomic writer.

**Spec:** `docs/superpowers/specs/2026-09-03-vfx-runtime-modulation-v1-design.md`; user-approved Phase C-1 request.

## Global Constraints

- Work only in `C:\GodotProjects\DesktopRacingVFXStudio`; do not access `DesktopIdleRacing`.
- Retain `package_format_version: 1` and `schema_version: 1`.
- Static source exports Runtime Definition v1 at `runtime/vfx_runtime_definition_v1.json` unchanged.
- Modulation-bearing source exports Runtime Definition v2 at `runtime/vfx_runtime_definition_v2.json`; no v2-to-v1 fallback.
- Do not alter Phase B `driving.headlights` visual authoring or any other production Preset.
- Do not use `git add`, commit, reset, revert, checkout, clean, Windows Export, or long stress runs.

---

### Task 1: Version-selection compiler contract

**Files:**
- Modify: `tests/export/test_headlight_export_policy.gd`
- Modify: `src/export/vfx_export_compiler.gd`

**Interfaces:**
- Consumes: `_is_modulation_bearing(data)` and validated `VfxPresetDocument`.
- Produces: compiler selection of `{ version: 1, path: runtime/vfx_runtime_definition_v1.json }` or `{ version: 2, path: runtime/vfx_runtime_definition_v2.json }`.

- [ ] Write RED assertions that modulated `driving.headlights` compiles successfully to v2 instead of the Phase A guard error, while static `talent.zero_zone` remains v1.
- [ ] Run `run_export_contract_tests.gd`; expect the new Headlight assertion to fail with the former fail-closed result.
- [ ] Replace the guard with explicit static/v2 selection; return an Export failure if v2 compilation fails and never call v1 in that path.
- [ ] Re-run the Export suite; expect the version-selection assertions to pass.

### Task 2: Portable Runtime Definition v2 projection

**Files:**
- Modify: `tests/export/test_headlight_export_policy.gd`
- Modify: `src/export/vfx_export_compiler.gd`

**Interfaces:**
- Consumes: normalized root `runtime_modulation_sources`, Layer `modulations`, `modulation_clamps`, and transform pivot.
- Produces: `_compile_runtime_definition_v2(data, requirements, coordinate_contract)` and `_runtime_v2_transform(layer)`.

- [ ] Write RED assertions for every Headlight phase/layer source, bindings, clamps, pivots, runtime inputs, output purity, and deterministic repeated compilation.
- [ ] Run the Export suite; expect v2 semantic-content assertions to fail.
- [ ] Project normalized source fields without recomputation, slots, Preview state, paths, or timing samples; retain phase/layer ordering.
- [ ] Re-run the Export suite; expect semantic equivalence, purity, and deterministic text assertions to pass.

### Task 3: Manifest and immutable package-plan runtime metadata

**Files:**
- Modify: `tests/export/test_headlight_export_policy.gd`
- Modify: `src/export/vfx_export_package_plan.gd`
- Modify: `src/export/vfx_export_compiler.gd`

**Interfaces:**
- Consumes: compiler-selected runtime version/path/text.
- Produces: `VfxExportPackagePlan.runtime_definition_version()` and `runtime_definition_path()`; Manifest points to the same hashed file.

- [ ] Write RED checks for v2 Manifest version/path/hash/size/files inventory and unchanged static-v1 Manifest fields.
- [ ] Run the Export suite; expect v2 Manifest checks to fail.
- [ ] Store compiler-selected metadata on the Plan and build text/file entries from that metadata, not a writer filename rule.
- [ ] Re-run the Export suite; expect Manifest metadata to match the compiled v2 text exactly.

### Task 4: Atomic writer dynamic runtime path

**Files:**
- Modify: `tests/export/test_export_compiler_and_writer.gd`
- Modify: `src/export/vfx_atomic_package_writer.gd` only if the existing generic `text_files()` loop proves insufficient.

**Interfaces:**
- Consumes: Plan `text_files()` and `files()` inventory.
- Produces: whole-package replacement containing only the selected runtime file.

- [ ] Write RED test that writes a Headlight v2 plan over a seeded stale v1 directory and verifies only v2 runtime remains.
- [ ] Run the focused Export suite; expect stale-v1 replacement assertion to fail before v2 Plan data exists.
- [ ] Keep the one writer and staging/verify/backup/restore flow; make only the Plan path data necessary for the test.
- [ ] Re-run focused Export tests; expect stale v1 removal and existing failure restoration tests to pass.

### Task 5: Static compatibility and pivot-only regression

**Files:**
- Modify: `tests/export/test_export_compiler_and_writer.gd`
- Modify: `tests/export/test_runtime_modulation_export_guard.gd` only if its Phase A expectation is superseded.

**Interfaces:**
- Consumes: static source and a test-local pivot-only static copy.
- Produces: byte-identical static v1 Runtime text and v1 export for pivot-only/no-program data.

- [ ] Write RED coverage for static v1 golden/path/version and pivot-only v1 behavior.
- [ ] Run Export tests; expect any changed static output or pivot-only promotion to fail.
- [ ] Preserve `_runtime_v1_transform` and version-selection classification exactly for non-bearing data.
- [ ] Re-run focused Export tests; expect static compatibility to remain green.

### Task 6: Contract documentation consistency

**Files:**
- Modify: `docs/VFX_EXPORT_PACKAGE_V1.md`
- Modify: `docs/VFX_SCHEMA_V1.md`
- Modify: `docs/VFX_STUDIO_ARCHITECTURE.md`

- [ ] Document Package Format v1's v1/v2 Runtime Definition selection, v2 portable modulation fields, oscillator time, ordered composition/clamp semantics, final opacity clamp, pivot formula, and importer minimization.
- [ ] Replace stale statements that imply current Schema v1 lacks input-to-Layer binding; list `longitudinal_load` as `[-1, 1]`, default `0`.

### Task 7: Full regression before physical Package write

- [ ] Run Contract, Editor, Preview, Performance, and Export suites; run Godot headless editor parse and `git diff --check`.
- [ ] Do not invoke the package writer unless every command exits zero.

### Task 8: Canonical Headlight Package write and physical verification

**Files:**
- Modify: only canonical output under `exports/packages/driving.headlights/` through the existing export command.
- Test: `tests/export/test_export_package_acceptance.gd` or focused physical verification coverage.

- [ ] Use the canonical compiler/writer once with `REPLACE_EXISTING` only after Task 7 succeeds.
- [ ] Verify Manifest paths, SHA-256, byte sizes, source/runtime/assets inventory, current source-copy modulation fields, v2 runtime semantic fields, and absence of stale v1 runtime.
- [ ] Re-run the Export suite after writing; report staged-file count as zero.

## Plan self-review

- Coverage: Tasks 1–5 implement version selection, portable v2 projection, Plan/Manifest metadata, writer replacement, static/pivot-only preservation, determinism, purity, and fail-closed behavior. Task 6 covers documentation. Tasks 7–8 cover the required pre-write and post-write verification.
- Scope: no Schema, Preview renderer/evaluator, game repository, or production authoring changes are included.
- Interfaces: compiler owns version/path choice; Plan owns immutable selected data; writer consumes generic Plan files and remains version-agnostic.
