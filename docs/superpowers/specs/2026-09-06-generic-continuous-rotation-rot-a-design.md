# Generic Continuous Rotation ROT-A Design

## Status

Approved architecture and implementation-plan pass. This document does not
authorize implementation by itself. ROT-A implementation must remain Studio
only and must not modify a production Rotor Lift preset, package, or PNG.

## Goal

Add one generic Runtime Modulation preset-source type, `LINEAR_PHASE`, that
samples the existing effect-local elapsed-time seam as a repeating phase in
`[0.0, 1.0)`. Existing `LINEAR_RANGE`,
`TRANSFORM_ROTATION_DEGREES`, and `ADD` bindings can then map that phase to
`0 -> +360` or `0 -> -360` degrees without a new renderer or rotation target.

The immediate consumer is a future Rotor Lift swirl authoring pass, but ROT-A
contains no Rotor Lift-specific behavior or authoring.

## Scope and non-goals

ROT-A changes only the generic Studio Schema/validation/modulation
compile-and-evaluate path, focused tests, and existing Schema/Export contract
documentation.

It must not add or modify:

- a Renderer, shader, material, Preview host, packet ordering, Node, Timer,
  Tween, clock, timeline, mutable per-layer history, RNG, or service/manager;
- `TRANSFORM_ROTATION_DEGREES`, `LINEAR_RANGE`, binding order, clamp timing,
  or existing SINE semantics;
- Runtime Definition v3 or Package Format v2;
- `equipment.rotor_lift.downwash`, its canonical package, or its three PNGs;
- DesktopIdleRacing files or integration; or
- any canonical Package write.

The user Git policy applies to the implementation: no `git add`, commit,
reset, checkout, revert, clean, or stash.

## Existing seam and decision

`VfxPreviewRuntimeModulationEvaluator._sample_sources(instance_elapsed_seconds)`
already receives the effect-local elapsed time used by `OSCILLATOR/SINE`. It
has a compiled source array and a pre-sized `PackedFloat64Array` of sampled
values. ROT-A reuses this exact method parameter and storage.

The evaluator currently samples every source as:

```gdscript
sin(TAU * source.frequency_hz() * instance_elapsed_seconds + source.phase_radians())
```

The compiled `VfxRuntimeModulationSourceSpec` currently stores only a source
id, frequency, and oscillator phase. ROT-A adds a small compiled source-kind
slot so that the existing evaluator can choose one scalar formula without
JSON, Dictionary, Array, or String traversal during a tick.

The chosen design is preferable to the two rejected alternatives:

| Alternative | Result | Reason |
| --- | --- | --- |
| Map existing SINE to rotation | Rejected | SINE reverses direction every half-cycle, so it is not fan rotation. |
| Replace large textures with angular-velocity particles | Rejected | birth/death seams and cap pressure cannot guarantee continuous opaque Core/Soft motion. |
| Generic `LINEAR_PHASE` source | Selected | one compiled source type reusing the existing time seam and target path. |

## Authoring contract

`LINEAR_PHASE` is a strict source shape:

```json
{
  "id": "rotor.core.phase",
  "type": "LINEAR_PHASE",
  "frequency_hz": 1.5
}
```

Rules:

- `frequency_hz` is finite and strictly greater than `0`.
- Negative frequency is invalid. Opposite direction comes from a binding's
  output range, never a frequency sign.
- `wave` and `phase_degrees` are forbidden for `LINEAR_PHASE`.
- Existing `OSCILLATOR` remains a distinct strict shape: it still requires
  `wave: "SINE"`, finite `phase_degrees`, and its existing finite,
  non-negative `frequency_hz` rule.
- A source id remains unique at preset scope. Existing source sharing and
  declaration-order behavior remain unchanged.

The Schema represents the two strict shapes as alternatives rather than making
`wave` or `phase_degrees` optional globally. The Schema-owned Runtime
Modulation configuration declares each type's output bounds and whether its
wave/phase fields are required. The rule catalog and contract validator use
that declaration only to validate the two source forms; it does not create a
new expression language or source subsystem.

## Evaluation semantics

For a finite `instance_elapsed_seconds` and valid positive frequency:

```gdscript
phase = fposmod(instance_elapsed_seconds * frequency_hz, 1.0)
```

The result is finite and satisfies `0.0 <= phase < 1.0`. At a period boundary,
the raw scalar wraps from near `1.0` to near `0.0`. When mapped to rotation,
`359.x` and `0.x` degrees are orientation-adjacent; tests must use wrapped
angular delta rather than raw subtraction.

No `phase_offset` is introduced. Authors use existing static layer rotation
for a visible initial angle difference. No phase state is accumulated.

Example shared phase source and opposite mappings:

```json
{
  "id": "rotor.core.phase",
  "type": "LINEAR_PHASE",
  "frequency_hz": 1.5
}
```

```json
{
  "target": "TRANSFORM_ROTATION_DEGREES",
  "operation": "ADD",
  "source": { "type": "PRESET_SOURCE", "source_id": "rotor.core.phase" },
  "mapping": {
    "type": "LINEAR_RANGE",
    "input_min": 0.0,
    "input_max": 1.0,
    "output_min": 0.0,
    "output_max": 360.0
  }
}
```

The opposing layer differs only by `output_max: -360.0`. The final effective
rotation stays:

```text
authored base rotation + source contributions in declaration order
-> existing target clamp once, when authored
```

ROT-A never makes a rotation clamp mandatory. A `0 -> 360` continuous mapping
would be broken by an inappropriate finite clamp.

## Compiled Preview program

`VfxRuntimeModulationSourceSpec` gains two source-kind constants and retains
the existing immutable scalar fields:

```text
SOURCE_OSCILLATOR_SINE
SOURCE_LINEAR_PHASE
slot, source id, source kind, frequency, oscillator phase radians
```

For `LINEAR_PHASE`, the phase-radians field is stored as neutral `0.0` and is
never read by its evaluator branch. The program builder resolves the authored
source type once while building the immutable program. The evaluator then
switches on the integer kind while writing into its already-sized
`PackedFloat64Array`.

Per source per tick, the `LINEAR_PHASE` work is one multiplication and one
positive floating modulo. It creates no Dictionary, Array, String, Node,
Timer, Tween, source object, or history record. A two-source/four-binding
fixture therefore samples two shared scalar values and reuses the same program
and source-spec identities across steady-state ticks.

The existing `TEXTURED_SPRITE` effective transform path consumes the evaluated
rotation. No Preview renderer file changes. A synthetic textured-sprite
fixture proves rotation changes through the existing packet path while its
render layer count and attachment pivot root remain stable.

## Runtime Definition and portability

The existing `VfxExportCompiler` already classifies any modulation-bearing
preset as Runtime Definition v2 and deep-copies
`runtime_modulation_sources` into the v2 document. ROT-A needs no exporter
architecture or writer change. Tests bind this existing projection to the new
strict source shape:

```json
"runtime_modulation_sources": [
  {
    "id": "rotor.core.phase",
    "type": "LINEAR_PHASE",
    "frequency_hz": 1.5
  }
]
```

The Package Format remains v1. Static non-modulated presets keep Runtime
Definition v1 and must not receive a source table, phase placeholder, or
modulation field. ROT-A creates no Package and performs no writer call.

## Test design

A test-only `TEXTURED_SPRITE` fixture owns two `LINEAR_PHASE` sources and four
bindings. It exercises one shared 1 Hz source with `+360` and `-360` mappings,
a 0.5 Hz source, authored base rotation, and the existing modulation pivot.

Focused tests must prove:

1. strict source validation: valid source; missing/zero/negative/non-finite
   frequency rejection; no wave/phase leakage;
2. evaluator sequences for 1 Hz, 2 Hz, and 0.5 Hz; output always `[0, 1)`;
3. period wrap and a wrapped visual angular delta near `0.72` degrees across
   `0.999` to `1.001` seconds at 1 Hz;
4. shared source opposite-sign mappings, two independent frequencies, base
   rotation composition, and pivot root error `<= 0.001` source pixels;
5. unchanged SINE values and static-v1 golden output;
6. v2 source round-trip and portability with no `res://` or absolute path;
7. stable two-source/four-binding compiled program identity and fixed sample
   count over 100 ticks; and
8. existing Preview renderer count/packet path unchanged.

## Maintenance cost and stop gates

The intended maintenance cost is one documented source type, one compiled
integer source-kind branch, one Schema/validator alternative, and focused
tests. No source-specific class hierarchy, manager, service, or special-case
Preset branch is permitted.

Implementation must stop and report instead of expanding scope if it needs a
new elapsed-time accumulator, Timer/Tween/Node, Preview renderer or shader
change, mutable layer history, a Runtime Definition v3, a new rotation target,
Rotor Lift-specific logic, per-tick collection/string allocation, or a broad
Runtime Modulation API signature rewrite.

## Protection matrix

| Protected item | ROT-A result |
| --- | --- |
| `equipment.rotor_lift.downwash` source | unchanged |
| Rotor Lift canonical package | unchanged; no writer call |
| Rotor Lift Core/Soft/Turbulence PNGs | unchanged |
| Existing `OSCILLATOR/SINE` | numeric behavior unchanged |
| Static v1 presets | byte-stable v1 projection remains unchanged |
| Preview renderer and packets | no implementation file change |
| DesktopIdleRacing | no access |
