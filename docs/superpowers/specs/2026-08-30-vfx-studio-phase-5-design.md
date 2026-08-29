# DesktopRacingVFXStudio Phase 5: Portable VFX Export Package Design

## Goal

Phase 5 generates a Studio-owned, portable VFX Export Package from one saved,
contract-valid .vfx.json Preset. The Package is the only handoff artifact for a
later DesktopIdleRacing importer/runtime project.

~~~text
DesktopRacingVFXStudio
  -> VFX Export Package
  -> DesktopIdleRacing importer/runtime
~~~

The Studio never reads from, writes to, selects as an output destination,
formats, stages, or commits the DesktopIdleRacing repository. The Package does
not define gameplay trigger timing, target selection, ownership, or game
runtime lifecycle control.

## Confirmed boundaries

- Godot 4.7.1 stable and dependency-free GDScript only.
- schemas/vfx_schema_v1.json remains unchanged. schema_version 1 retains its
  current fields, defaults, enums, lifecycle shape, and semantic rules.
- Export accepts a saved source file only. A dirty Editor edit session, invalid
  document, Preview state, Render Plan, renderer packet, Vehicle Profile, or
  Performance Snapshot is never an Export source.
- The Source copy preserves saved authoring representation. The Runtime
  Definition is a separate, normalized and compiled representation.
- Package Format Version, Runtime Definition Version, and VFX Schema Version
  are independent fields.
- Phase 5 creates no DesktopIdleRacing importer, game renderer, VfxService,
  gameplay binding, dynamic LOD, screenshot system, package history, remote
  upload, Windows Export, or performance report export.
- project.godot and src/editor/main/vfx_editor_main.tscn remain untouched. The
  runtime-created VfxPreviewWorkspace is the UI integration seam.
- Codex does not run git add or git commit. SourceTree manages all changes.

## Source and compiler flow

~~~text
saved .vfx.json path
  -> VfxPresetPipeline.load_and_validate
  -> VfxPresetDocument
       raw_data          -> deterministic Source copy
       normalized_data   -> effective-space Runtime compiler
  -> VfxExportPackagePlan
  -> VfxAtomicPackageWriter
~~~

VfxExportService owns this orchestration. It takes a saved authoring path, not
a mutable VfxPresetEditSession. The Editor supplies its current saved path and
blocks Export while VfxPresetEditSession.is_dirty() is true.

### Source copy semantics

The Package writes source/<preset_id>.vfx.json from
VfxPresetDocument.raw_data after the saved source has decoded and passed
Contract validation. It uses the deterministic JSON codec, so whitespace and
object-key order are canonicalised, but missing authoring defaults remain
missing. It preserves saved authoring meaning, not original byte formatting,
and contains no original filesystem path.

### Runtime Definition semantics

The Package writes runtime/vfx_runtime_definition_v1.json from
VfxPresetDocument.normalized_data. The compiler additionally resolves every
Layer effective space_mode: an explicit Layer value wins; otherwise it uses the
Preset default_space_mode. The result makes effective space_mode explicit in
every compiled Layer.

The Runtime Definition retains only portable VFX semantic data: Layer type,
enabled state, Importance, blend mode, plane, sort order, resolved space,
anchors, normalized transform, normalized type parameters, logical asset IDs,
lifecycle, and runtime-input contract.

It never contains a Preview renderer class, GDScript path, .tscn, .tres,
.gdshader, Stress result, Preview asset source type, Studio absolute or res://
path, Vehicle reference image, or Preview Profile state.

## Package format v1

The Package root is fixed inside the Studio repository:

~~~text
res://exports/packages/<preset_id>/
  manifest.json
  source/
    <preset_id>.vfx.json
  runtime/
    vfx_runtime_definition_v1.json
  assets/
    <registry-defined file names>
~~~

package_format_version is 1. A Package package_id is its validated preset_id in
v1. A folder name is never silently sanitised: a value outside the Schema
preset_id pattern blocks Export.

preview.png is not generated in Phase 5 and its absence is not a warning. A
future explicit preview artifact must live under preview/ and remain optional to
an importer.

### Manifest v1

manifest.json has this exact semantic structure. The deterministic serializer
defines object-key ordering; the shown order is for human review.

~~~json
{
  "package_format_version": 1,
  "package_id": "talent.zero_zone",
  "preset": {
    "preset_id": "talent.zero_zone",
    "display_name": "Zero Zone",
    "category": "RACE_TALENT",
    "vfx_schema_version": 1,
    "lifecycle_mode": "START_LOOP_END",
    "default_space_mode": "VEHICLE_LOCAL"
  },
  "source": {
    "path": "source/talent.zero_zone.vfx.json",
    "sha256": "<64-lowercase-hex>",
    "byte_size": 0
  },
  "runtime_definition": {
    "version": 1,
    "path": "runtime/vfx_runtime_definition_v1.json",
    "sha256": "<64-lowercase-hex>",
    "byte_size": 0
  },
  "requirements": {
    "required_vehicle_anchors": ["CENTER"],
    "runtime_inputs": ["intensity"],
    "importance_summary": {
      "CORE": 3,
      "DETAIL": 6,
      "EXTRA": 2
    }
  },
  "asset_dependencies": [
    {
      "logical_id": "fx.energy_shard",
      "kind": "TEXTURE_PNG",
      "package_path": "assets/energy_shard.png",
      "sha256": "<64-lowercase-hex>",
      "byte_size": 0
    }
  ],
  "files": [
    {
      "path": "assets/energy_shard.png",
      "sha256": "<64-lowercase-hex>",
      "byte_size": 0
    }
  ]
}
~~~

files lists the Source copy, Runtime Definition, and physical assets. It does
not list manifest.json, avoiding a self-referential checksum. The Manifest is
metadata and inventory only; it never contains gameplay triggers or Studio
performance policy data.

### Runtime Definition v1

~~~json
{
  "runtime_definition_version": 1,
  "preset": {
    "preset_id": "talent.zero_zone",
    "display_name": "Zero Zone",
    "category": "RACE_TALENT",
    "lifecycle_mode": "START_LOOP_END",
    "default_space_mode": "VEHICLE_LOCAL"
  },
  "required_vehicle_anchors": ["CENTER"],
  "runtime_inputs": [
    {
      "name": "intensity",
      "value_type": "number",
      "default": 1.0,
      "minimum": 0.0,
      "maximum": 1.0
    }
  ],
  "phases": [
    {
      "name": "start",
      "duration_seconds": 0.12,
      "layers": [
        {
          "id": "start.inner_flash",
          "type": "GLOW",
          "enabled": true,
          "importance": "CORE",
          "blend_mode": "ADDITIVE",
          "render_plane": "UNDER_VEHICLE",
          "sort_order": 0,
          "space_mode": "VEHICLE_LOCAL",
          "anchors": ["CENTER"],
          "transform": {
            "offset": [0.0, 0.0],
            "rotation_degrees": 0.0,
            "scale": [1.0, 1.16]
          },
          "parameters": {
            "radius": 115.0,
            "opacity": 0.9,
            "pulse_hz": 0.0,
            "color_rgba": [0.55, 0.92, 1.0, 0.95]
          }
        }
      ]
    }
  ]
}
~~~

phases is an ordered array. ONE_SHOT exports [one_shot]; START_LOOP_END exports
[start, loop, end]. A loop object has no duration_seconds. The compiler copies
every normalized type-specific parameter, including logical sprite_asset_ref
and texture_asset_ref values. The Manifest maps logical IDs to Package files.

## Requirement derivation

The compiler reads enums and rule configuration from the loaded Schema Registry;
it does not duplicate Schema enum lists in GDScript.

| Derived data | Rule |
| --- | --- |
| Required vehicle anchors | Inspect enabled Layers only; resolve effective space; include declared anchors only for vehicle Space Modes named by EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS; deduplicate in Schema Anchor enum order. |
| Runtime inputs | Preserve Preset declaration order; resolve x_vfx_runtime_inputs and emit its value type, default, and declared constraints; create no input-to-parameter binding. |
| Phase order | Read lifecycle phase names from LIFECYCLE_PHASE_STRUCTURE. |
| Asset references | Resolve the type parameter Schema, inspect properties ending _asset_ref whose resolved Schema is logical_id, then read the parameter value; keep no manual field list. |
| Importance summary | Count all compiled Layers in fixed Schema enum order: CORE, DETAIL, EXTRA. Per-Layer Importance remains runtime truth. |

Phase 5 exports neither the Phase 4 HIGH/MEDIUM/LOW policy mapping nor its
thresholds, workload budgets, frame times, P95, environment context, or
Snapshot. Importance is semantic authoring data, not a performance claim.

## Fail-closed asset and Preset policy

Preview availability never implies Production-export availability.
VfxExportAssetRegistry loads a separate Studio policy document and never falls
back to VfxPreviewAssetRegistry.

~~~json
{
  "policy_version": 1,
  "assets": {
    "fx.energy_shard": {
      "export_policy": "EXPORTABLE",
      "kind": "TEXTURE_PNG",
      "source_path": "res://assets/vfx/energy_shard.png",
      "package_file_name": "energy_shard.png"
    },
    "fx.preview_texture_fixture": {
      "export_policy": "PREVIEW_ONLY",
      "reason": "TEST_FIXTURE"
    }
  }
}
~~~

An asset blocks Export when its logical ID is absent from this registry, its
policy is not EXPORTABLE, its kind is not TEXTURE_PNG, its source is missing or
unreadable, its source lies under tests/, or its filename collides with
different bytes. Missing dependencies never receive a Preview magenta fallback.

Phase 5 permits only explicit static PNG production art. Procedural Preview
assets such as fx.confetti_square, fx.trail_streak, and fx.placeholder are
blocked. Recipe export and PNG baking require a future approved phase.

The compiler copies each required physical asset once. It orders dependencies by
logical ID. If more than one logical ID resolves to byte-identical source
content, it emits one physical file and maps each logical ID to that path.
There is no global cross-Package shared asset store.

config/vfx_export_preset_policy_v1.json contains Preset-level exceptions. It
marks utility.renderer_showcase with export_allowed false and
STUDIO_VALIDATION_FIXTURE. An absent policy entry leaves a Preset eligible;
UTILITY is not globally blocked.

## Path safety, checksums, and deterministic order

Every Package path, including Manifest references, must be package-relative,
forward-slash separated, non-empty, and free of drive letters, leading slash,
backslash, traversal, res://, and user://. It must be rooted in source/,
runtime/, or assets/ for its role. Invalid paths are rejected, not sanitised.

Every Manifest-listed file includes a lower-case SHA-256 and byte_size. An
importer must verify Package version, safe path, listed-file existence, byte
size, and SHA-256 before consuming Runtime Definition. manifest.json itself is
not in files/hash metadata.

For identical saved Source, Schema, Export policy, asset bytes, and format
version, final Package content is identical:

- JSON uses the current deterministic key-sorted serializer, two-space indent,
  and one LF final newline.
- Required anchors use Schema Anchor enum order.
- Runtime inputs retain Preset declaration order.
- Phases use lifecycle order and Layers retain source authoring order.
- Asset dependencies use lexical logical-ID order.
- files uses lexical Package-relative path order.
- Importance summary uses CORE, DETAIL, EXTRA order.
- Package content contains no timestamp, UUID, session value, machine path, or
  original source path.

Temporary names may be runtime-unique because they are never Package content.

## Atomic whole-package replacement

All temporary directories live under the same Studio export root:

~~~text
res://exports/.staging/<unique-temp>/
res://exports/.backup/<unique-temp>/
res://exports/packages/<preset_id>/
~~~

The Writer completes this sequence:

1. Create and populate staging.
2. Validate staging tree, Manifest paths, byte sizes, and SHA-256 values.
3. If an approved final Package exists, rename it to backup.
4. Rename staging to final.
5. Remove backup only after final rename success.

A staging failure leaves the final untouched. A final rename failure restores the
backup immediately and reports any restore failure as EXPORT_IO. The Writer
never deletes a final Package before a staged replacement is validated. Backup
cleanup failure is a warning and leaves a recoverable backup.

FAIL_IF_EXISTS is for deterministic tests and noninteractive callers.
REPLACE_EXISTING is available only after UI confirmation. Replacement is whole
directory replacement, never merge.

## Export UI and documentation

VfxPreviewWorkspace receives one runtime-created mode:

~~~text
[ AUTHORING PREVIEW | PERFORMANCE | EXPORT ]
~~~

VfxExportPanel is compact and session-only. It displays current Preset, fixed
Studio Package path, dirty-state gate, READY/WARNING/BLOCKED validation state,
anchors, runtime inputs, asset inventory, and last result. It exposes Validate
Export and Export Package; the latter requests confirmation only if a final
Package exists. It has no game path picker, importer action, or screenshot
capture.

Task D adds docs/VFX_EXPORT_PACKAGE_V1.md. It fixes Package layout, versions,
Manifest and Runtime Definition semantics, logical asset mapping, path and
checksum validation, and one-way Studio/game ownership. It specifies an
Importer contract only; it does not implement one.

## Zero Zone acceptance

~~~text
exports/packages/talent.zero_zone/
  manifest.json
  source/talent.zero_zone.vfx.json
  runtime/vfx_runtime_definition_v1.json
  assets/energy_shard.png
  assets/energy_spark.png
~~~

The Package has required_vehicle_anchors [CENTER], runtime_inputs [intensity],
two production assets, and an Importance summary of CORE 3, DETAIL 6, EXTRA 2.
fx.energy_shard is copied once despite multiple Layer references. The Package
contains no technical fixture, procedural Preview asset, shader, script,
absolute path, or res:// path.

## Implementation boundaries and verification

Phase 5 adds small, single-purpose files under src/export/ and
src/editor/export/:

- VfxExportPaths: fixed output roots and safe relative path checks.
- VfxExportAssetRegistry: fail-closed logical asset policy.
- VfxExportPresetPolicy: Preset-specific eligibility.
- VfxExportRequirementDeriver: Schema-derived requirements and assets.
- VfxExportPackagePlan: immutable compiled package inventory.
- VfxExportCompiler: Source, Runtime, and Manifest creation.
- VfxExportHasher: SHA-256 and byte sizes.
- VfxExportFileBackend: testable file/rename seam.
- VfxAtomicPackageWriter: staging, verification, replacement, rollback.
- VfxExportService: saved-source orchestration.
- VfxExportPanel: editor presentation only.

The Export runner verifies valid Zero Zone compilation; raw-vs-runtime
semantics; defaults and effective space; anchor/input/asset derivation;
fail-closed policies; deduplication; fixture, procedural, missing, and
unregistered rejection; safe paths; deterministic output; checksums; atomic
failure preservation; and Studio-only Preset rejection.

Final regression runs Contract, Editor, Preview, Performance, and Export suites,
then a Godot headless editor parse. Windows Export is excluded.

