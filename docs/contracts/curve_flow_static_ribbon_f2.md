# CURVE_FLOW static ribbon F2 — approved Game handoff

2026-09-27. Source of truth: read-only `C:/GodotProjects/DesktopIdleRacing/docs/CURVE_FLOW_STATIC_RIBBON_STUDIO_HANDOFF.md` and its actual renderer/shader/evaluator. User approved Studio implementation and one delivery package without further design gates.

## Design and compatibility

New ID `talent.solo_run.static_ribbon`. Final approval retires unused P3.2/F1 user artifacts and prototypes; minimum compatibility fixtures and common implementations remain. Runtime Definition **3**, Package Format **1**, layer `profile_version: 2`, required capability **CURVE_FLOW_STATIC_RIBBON_F2**. Existing F1 retains profile 1 and CURVE_FLOW_F1. Reader must opt into F2 explicitly and reject profile/capability mismatch, unknown capabilities and downgrade. No v4 is needed: the v3 layer table carries the profile and required capabilities.

All eight F paths, seed 0 (no RNG), cadence, cap, length, speed, brightness, texture/UV data, colors, fade and lifecycle remain unchanged. Only profile and final half_width change: main **45**, auxiliary **17.1 / 13.5**, top **18** source px. Full widths **90 / 34.2 / 27 / 36**. Game MUST remove WIDTH_FACTOR=1.5 for this package; final widths are already authored. Vehicle scale applies once. Coordinates remain CENTER, forward -Y, 256x512 vehicle source pixels.

## Immutable geometry and per-instance state

Plan-owned prepared geometry is reused by renderers/vehicles using that plan; no process-global unbounded cache or Game SETUP dependency. Tables and table arrays are read-only. A RefCounted prepared entry exposes getter-only mesh/tables, preventing packet deep-copy from cloning them. ArrayMesh is constructed once and never mutated. Per-renderer flow time, schedules, segments, heads and material remain independent. Releasing a plan and its renderers releases prepared resources. Game owns its own preparation lifetime, SETUP barrier and actual render warming.

Reuse de Casteljau .05px/cubic error, max chord 4px, depth20, cumulative arc-distance interpolation (epsilon .000001). Prepare full path with max(2,ceil(path_length/3)) subdivisions. Tangent is normalized sample(d+1)-sample(d-1). One full-path primitive copy per cap slot (64 shader head capacity). Vertex=center +/- normal*final half_width. UV=(distance,side 0..1). COLOR.r=slot/64, COLOR.g=1-smoothstep(235,end_y,center_y). No per-frame curve query or mesh/UV/index rebuild.

CPU only advances the existing deterministic emission schedule and sends heads/active_count. Shader computes u=(d-(head-length))/length; discard inactive slot and u outside [0,1]. Taper=smoothstep(0,.30,u)*(1-smoothstep(.74,1,u)); width ratio=mix(.04,1,taper)*mix(.18,1,rear_release). Remap signed cross=(2*V-1)/ratio. Evaluate texture before cross>1 discard, preserving approved derivative order.

Native PNG: u and cropped V=38/171..148/171, source_color, mipmap, clamp; original RGB/alpha only. Procedural RG: U=(d-head)/1024+texture_phase, repeat/data sampler, R*1.65 core, G halo, original champagne/gold tint, .72..1 edge and .0..38/.68..1 envelope. Path fade=smoothstep(0,16,d)*smoothstep(0,28,path_length-d); alpha=brightness*path_fade*rear_release, then original texture/envelope alpha. Independent additive primitives preserve overlap energy. Bind only the active sampler. No shader TIME/modulo, max compositing or duplicate draw.

Stop disables new births, not movement; remove after head>=path_length+length. END emits nothing and drains beyond its duration. Zero active heads hides mesh. Force clear immediately hides and clears; restart resets schedule/time. No wrap or history/Bend. F1 contract document supplies unchanged eight-path numeric table; new preset is the authoritative full F2 table.

## Verification / delivery scope

Focused source-driven Game comparison at equal time/seed/scale (geometry, shader and birth/drain), shared immutable geometry and independent materials, editor selection/playback, profile rejection, parse/diff, then canonical initial-create once and package reload/inventory once. No Game edits/performance measurements/full regression. Game formal loader/factory/Solo Run selection and SETUP/render warmup remain follow-up work.

## Delivered / run / Game connection

- Preset: `C:/GodotProjects/DesktopRacingVFXStudio/presets/examples/talent.solo_run.static_ribbon.vfx.json`
- Package: `C:/GodotProjects/DesktopRacingVFXStudio/exports/packages/talent.solo_run.static_ribbon/`
- Run: `C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe --path C:/GodotProjects/DesktopRacingVFXStudio res://src/editor/main/vfx_editor_main.tscn`. Select **Solo Run Static Ribbon**, LOOP, disable Auto, Play. Auto retains normal start/loop/end demonstration.
- Game references: `src/preview/curve_flow/vfx_curve_flow_static_geometry.gd`, `vfx_curve_flow_static_host.gd`, `vfx_curve_flow_static.gdshader`, existing `vfx_curve_flow_evaluator.gd`; explicit gate `src/export/vfx_runtime_definition_reader.gd`.
- Game must opt into profile2/capability, route to static renderer, consume final half widths without WIDTH_FACTOR=1.5, resolve both existing PNG assets, and explicitly select the new package for Solo Run. Keep F1/P3.2 compatibility. SETUP geometry preparation, real GPU draw warmup, readiness gate and ownership/cleanup remain Game work; Studio has no dependency on that fixture or Game service.

Results: static GL/lifecycle/editor focused 3891 assertions PASS; .30/1.50/2.50/4.00s reference captures at .095 and .418 scale, equal seed0 and .16rad vehicle rotation: maximum channel difference **0**, including stopped/drained state. F1 focused 47 PASS and F1 GL parity remains zero. Headless script/dependency parse and git diff check PASS. Export+package focused 32 PASS, canonical FAIL_IF_EXISTS once, inventory exactly five files (manifest/source/runtime v3/two PNGs), manifest payload bytes/SHA and source PNG identity pass; package-only asset decoding/reload renders eight lanes. No repeated export/integrity run.

Final review found per-frame clear/recreate in existing presentation. Unrouted-only clearing now preserves host/material identities; changing a plan explicitly replaces adapters and force clear hides stale nodes immediately. Ordinary editor and single-slot two-tick identity tests cover this (not a performance measurement). No Game performance claims, full regression or Game files changed. That delivery originally preserved P3.2/F1 artifacts. Final cleanup supersedes artifact retention without changing this package or contract.
