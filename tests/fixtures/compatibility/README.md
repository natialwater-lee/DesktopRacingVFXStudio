# Retained compatibility data

Outside the preset library by design. No retired PNGs or executable prototypes are needed.

- `particle_bend.vfx.json`: one emitted sprite with signed input, ADD, pivot, quadratic Bend and clamp; tests retain v2 projection/round-trip and straight Preview fallback.
- `curve_flow_f1.vfx.json`: the eight-path F1 source table needed for F1 serialization/rendering compatibility and the approved F2 comparison. Shared current textures are reused; no old package copy.

The only user-facing Solo Run is `talent.solo_run.static_ribbon`. These fixtures must not be registered in the editor library or exported as delivery packages.
