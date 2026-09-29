# CURVE_FLOW Runtime Definition v3 / F1 interop contract

Status: retained F1 compatibility contract. Final Solo Run uses the F2 Static Ribbon contract.

## Version / identity

Compatibility fixture `utility.fixture.curve_flow_f1`; Package Format 1, authoring Schema 1 additive CURVE_FLOW type, Runtime Definition 3.
Runtime `required_capabilities: ["CURVE_FLOW_F1"]`; layer `parameters.profile_version: 1`.
Reject unsupported runtime version, CURVE_FLOW type or profile before rendering. Never reinterpret this as PARTICLE/TRAIL or downgrade to v1/v2. Existing non-CURVE_FLOW version selection is unchanged (modulated=>v2, otherwise v1).
Use `src/export/vfx_runtime_definition_reader.gd` as an explicit capability-gate reference; Game must implement its own call site and pass supported versions/types.

## Coordinates, ordering and units

Vehicle source canvas 256x512; CENTER origin (0,0), forward -Y, rear +Y. All path points, lengths, widths and tessellation tolerances are source pixels; speed is source px/s; time is seconds; rotation degrees clockwise in Godot 2D. No world/history trail or bend.
Vehicle-local paths rotate and translate with the current vehicle. Apply vehicle scale only once.
Hyper used by approval has alpha-visible height 468px, rear reference Y=233.5; game scale .095 (44.46px visible height). Do not bake .095 into package.
Six side lanes UNDER_VEHICLE then two top lanes OVER_VEHICLE. Within each plane preserve source layer array order and per-lane birth order. All eight layers CORE, additive, CENTER, offset [0,0], scale [1,1], rotation 0, cap sum 22. No automatic LOD simplification was added.

## Frozen F lane table

Numbers below are exported float values from approved prototype F, not re-authored rounded approximations. Main lanes 0 and 3 use native PNG; other lanes use baked RG procedural texture. Widths are HALF widths before tapers, already include F's multipliers.
Top paths intentionally retain their longer Y=608 endpoint; only side paths use the .35-car wake.

| Lane | Plane | Cubics (P0,P1,P2,P3) | Delay | Interval | Length | Speed | Cap | Brightness | Half width | Texture phase |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| loop.side_left_0 | UNDER_VEHICLE | `[[[-76,-247],[-117,-207],[-130,-35],[-125,100]],[[-125,100],[-120,235],[-113,332.299987792969],[-110,397.299987792969]]]` | 0.02 | 0.47 | 470 | 1020 | 3 | 0.88 | 30 | 0 |
| loop.side_left_1 | UNDER_VEHICLE | `[[[-85,-239],[-127,-207],[-140,-35],[-135,100]],[[-135,100],[-130,235],[-123,332.299987792969],[-120,397.299987792969]]]` | 0.19 | 0.5 | 330 | 1077 | 3 | 0.43 | 11.4 | 0.137 |
| loop.side_left_2 | UNDER_VEHICLE | `[[[-94,-231],[-137,-207],[-150,-35],[-145,100]],[[-145,100],[-140,235],[-133,332.299987792969],[-130,397.299987792969]]]` | 0.38 | 0.53 | 240 | 1134 | 3 | 0.27 | 9 | 0.274 |
| loop.side_right_0 | UNDER_VEHICLE | `[[[76,-247],[117,-207],[130,-35],[125,100]],[[125,100],[120,235],[113,332.299987792969],[110,397.299987792969]]]` | 0.11 | 0.487 | 470 | 1041 | 3 | 0.88 | 30 | 0.411 |
| loop.side_right_1 | UNDER_VEHICLE | `[[[85,-239],[127,-207],[140,-35],[135,100]],[[135,100],[130,235],[123,332.299987792969],[120,397.299987792969]]]` | 0.31 | 0.517 | 330 | 1098 | 3 | 0.43 | 11.4 | 0.548 |
| loop.side_right_2 | UNDER_VEHICLE | `[[[94,-231],[137,-207],[150,-35],[145,100]],[[145,100],[140,235],[133,332.299987792969],[130,397.299987792969]]]` | 0.49 | 0.547 | 240 | 1155 | 3 | 0.27 | 9 | 0.685 |
| loop.top_left | OVER_VEHICLE | `[[[-24,-225],[-48,-130],[-46,-30],[-38,90]],[[-38,90],[-30,210],[-49,410],[-73,608]]]` | 0.26 | 0.69 | 340 | 985 | 2 | 0.34 | 12 | 0.822 |
| loop.top_right | OVER_VEHICLE | `[[[24,-225],[48,-130],[46,-30],[38,90]],[[38,90],[30,210],[49,410],[73,608]]]` | 0.57 | 0.74 | 385 | 1050 | 2 | 0.34 | 12 | 0.959 |

## Distance evaluator and emission

Connected cubic Bezier segments, C1 joins (endpoint + derivative continuity tolerance .001px).
Build cumulative chord-length table once per immutable path using recursive midpoint de Casteljau:
control polygon length minus endpoint chord <= per-cubic .05px error budget AND chord <=4px; split child tolerance in half, maximum depth20. Append endpoints in order.
Distance lookup clamps to [0,path_length], binary searches cumulative lengths and linearly interpolates chord endpoints. Tangent = normalize(sample(d+1)-sample(d-1)). Prototype dense-reference max observed arc length error .003002px; this is an observed value, not a substitute for the algorithm.
Tessellate visible segment with ceil((end-start)/3) subdivisions, minimum2, uniformly in arc distance.

No RNG consumption; seed=0 is the sole supported value. Do not invent jitter. First scheduled birth=delay, subsequent births add interval. Advance clocks in seconds; process scheduled births <= time+1e-9, lanes in array order. Each birth computes alive occupancy at its scheduled time, using (born-old_born)*speed < path_length+segment_length. If cap reached skip that birth, do not queue it. Then head=(time-born)*speed. Retain until head >= path_length+segment_length.
Side delays intentionally differ; not strict alternation. Fixed step1/60 matches Studio playback; evaluator uses analytic birth times, not frame timestamps.
Active segment tail=head-length; visible span [max(tail,0),min(head,path_length)]. Skip spans shorter than .001px. Never compress whole PNG into clipped visible span.

## Lifecycle

Empty START duration0 transitions immediately to LOOP, no tick delay. LOOP activates all eight lanes with local time0. Empty END duration.001 never emits.
stop_emission disables scheduled births immediately; elapsed movement continues and existing tails leave the path. Draining MUST outlive END duration. Do not clear merely because END timer expired.
force_clear empties segments immediately; restart resets time, births, next-birth schedules and geometry. UI auto preview still uses its existing two-second LOOP demonstration; manual LOOP can run continuously.
Game ACTIVE, deactivation, teardown integration remains a Game task.

## Width, alpha and UV (F1 immutable profile)

Let u=(d-tail)/length, y=sample(d).y, end_y=last control point.y, H=authored half_width.
taper = smoothstep(0,.30,u) * (1-smoothstep(.74,1,u)).
release = 1-smoothstep(235,end_y,y).
half-width = H * lerp(.04,1,taper) * lerp(.18,1,release).
path_fade = smoothstep(0,16,d) * smoothstep(0,28,path_length-d).
vertex alpha = brightness * path_fade * release.
Ribbon vertices = center +/- perpendicular(tangent)*half-width.
Vertex R stores u; B=0 for native PNG, B=1 for RG procedural. Keep this encoding separate from any material tint.
Mesh uses the original triangle winding/index order. Geometry and color/UV parity against F is tested at .001px tolerance.

### Native strand

`fx.solo_run_flow_strand_v1`, 512x171 RGBA8, source PNG byte-identical to approved image.
UV.x=u (tail0, bright moving head1); UV.y maps [0,1] across [38/171,148/171], excluding vertical transparent margins. Clamp/no repeat. Linear mipmap filtering, source-color RGB sampler.
Output RGB=sample.rgb; alpha=sample.a*vertex_alpha. No extra tint, analytic core, halo, segment-envelope multiplication or bloom. Width taper already applies.

### Procedural RG texture

`fx.curve_flow_filaments_v1`, 512x64 RGBA8 baked losslessly once; alpha1, B0.
R stores champagne filaments, G stores soft golden halo; sample as linear data (NOT sRGB color). Repeat horizontally, linear mipmap filtering.
UV.x=(d-head)/1024 + texture_phase; UV.y=(side+1)/2. Constant physical period1024px; no stretching with clipped segment length.
Generation at phase=TAU*x/512, cross=y/63*2-1-.045*sin(3*phase):
split=.22*pow(.5+.5*sin(2*phase+.4),2);
grain=.86+.08*sin(5*phase)+.04*cos(9*phase);
R=(.50*exp(-((cross-split)/.19)^2)+.42*exp(-((cross+split)/.22)^2))*grain;
G=.30*exp(-cross^2/.30)*(.92+.05*sin(phase)).
Quantize RGBA8 before mipmap generation. Package PNG is authoritative; no runtime procedural regeneration required.

core=R*1.65, halo=G.
cross_width=abs(UV.y*2-1); edge=1-smoothstep(.72,1,cross_width).
envelope=smoothstep(0,.38,u)*(1-smoothstep(.68,1,u)).
RGB=mix([1,.59,.20],[1,.94,.78],core/max(core+halo,.001)).
alpha=vertex_alpha*(core+halo)*edge*envelope.
Unshaded additive blending, no bloom. Import both textures lossless, mipmaps enabled, fix_alpha_border=false, premultiply=false. Package loader must decode PNG bytes, convert to RGBA8, then generate mipmaps once and reuse textures. Bind only the active native/data sampler per layer; do not bind the same GL texture to conflicting repeat/clamp samplers.

## Reference files / ownership

- Evaluator: `src/preview/curve_flow/vfx_curve_flow_evaluator.gd`
- Mesh/shader: `src/preview/curve_flow/vfx_curve_flow_mesh.gd`, `vfx_curve_flow.gdshader`
- Lifecycle adapter: `src/preview/curve_flow/vfx_curve_flow_layer_renderer.gd`
- Validation/conversion: `src/preview/curve_flow/vfx_curve_flow_contract.gd`
- Version gate: `src/export/vfx_runtime_definition_reader.gd`
- Full lane data: `tests/fixtures/compatibility/curve_flow_f1.vfx.json`

These files are implementation references for Game, not executable code delivered implicitly by a JSON package. A Game without CURVE_FLOW_F1 must reject this package. No Game work occurred.

## Finalization

The retired F1 user preset/package and A–F prototype were removed after final Static Ribbon approval. The eight-lane compatibility fixture remains outside the editor library; common F1 evaluator, renderer and capability checks remain supported.

For final editor playback and delivery use `talent.solo_run.static_ribbon` and [the F2 contract](curve_flow_static_ribbon_f2.md). Historical prototype pixel comparisons are not current regression evidence.
