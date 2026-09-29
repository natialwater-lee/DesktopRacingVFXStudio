# Static Ribbon F2 Implementation Plan

> Inline execution using superpowers:executing-plans; user approved complete scope. No commits, staging, Game writes or full regression.

**Goal:** Promote approved fixed ribbon and authored final widths into a separate Studio package.
**Architecture:** Profile2 branches at existing CURVE_FLOW adapter. Render-plan-owned immutable geometry, independent evaluators/materials, original Game shader.
**Tech Stack:** Godot4.7.1 GL Compatibility, GDScript, existing v3 export.
**Spec:** ../../contracts/curve_flow_static_ribbon_f2.md

## Tasks / interfaces

- [ ] Contract RED: new focused test loads `talent.solo_run.static_ribbon`; validates profile2, exact final widths, unchanged remainder. Add schema enum2; compiler derives F1/F2 capabilities; reader explicit fourth `capabilities` argument defaults F1 and checks layers match declarations. Unknown/mismatched profile rejects. Preserve old bytes.
- [ ] Preview GREEN: `vfx_curve_flow_static_geometry.gd.prepare(parameters)` returns read-only table/ArrayMesh entry; plan owns entries by geometry key. Existing layer renderer binds prepared entry before restart, shares tables but owns flow. New `vfx_curve_flow_static_host.gd` configures immutable mesh and independent ShaderMaterial, updates heads only. Existing canvas chooses profile by packet and keeps old F1 host.
- [ ] Focused comparison: read actual Game evaluator/build method/shader into test-only scripts (no Game project launch). Compare full mesh arrays, births/heads/stop/drain, representative GL at .095 and .418 scale, rotation, independent state and unchanged mesh identity. Test version rejection and ordinary editor playback. Run headless parse/diff only; no performance measurement.
- [ ] Delivery: initial-create `talent.solo_run.static_ribbon` once after GREEN; one verification of five-file inventory/bytes/hash/textures, runtime reload and packaged asset use. Record results/paths in spec. Preserve baseline hashes.

## Review focus

Capability downgrade; accidentally double width; mutable table/material sharing; geometry rebuild on gaps/restart; F1 compatibility. Tests cover each. Preparation belongs to Studio plan; Game SETUP warmup must not become a dependency.

## Ledger

Ruling: execute in supplied dirty workspace, no worktree/commit machinery, full tests explicitly excluded by user. Existing changes are preserved. Plan tasks share profile2/entry interface; no conflicting dependencies found.

Tasks 1–4 complete. RED: missing candidate, then missing static geometry. GREEN: final profile/width validation, source-driven Game parity. Final review Important finding fixed with RED→GREEN ordinary-editor and single-slot adapter identity tests. Plan change invalidation also RED→GREEN. Prepared entries use RefCounted references so packet copies do not clone tables. Focused static parity3891/F1 47/one export+integrity32 PASS, GL difference0. Headless parse/diff PASS. Initial-create and package integrity each once. User constraints override full-suite/commit workflow; no performance remeasurement. No remaining review findings.
