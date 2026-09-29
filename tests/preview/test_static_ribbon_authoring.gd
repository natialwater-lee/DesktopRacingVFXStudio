extends SceneTree
const PATH := "res://presets/examples/talent.solo_run.static_ribbon.vfx.json"
var t = preload("res://tests/support/test_assert.gd").new()
func _init() -> void: call_deferred("run")
func run() -> void:
	var result = preload("res://src/app/vfx_preset_pipeline.gd").new().load_and_validate(PATH)
	t.expect_true(result.success, "Approved static ribbon preset validates")
	if result.success:
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/compatibility/curve_flow_f1.vfx.json"))
		var actual: Dictionary = result.value.raw_data.duplicate(true)
		for i in 8:
			t.expect_true(actual.phases.loop.layers[i].parameters.half_width == [45.0,17.1,13.5,45.0,17.1,13.5,18.0,18.0][i], "Final width lane " + str(i))
			actual.phases.loop.layers[i].parameters.half_width = old.phases.loop.layers[i].parameters.half_width
			actual.phases.loop.layers[i].parameters.profile_version = old.phases.loop.layers[i].parameters.profile_version
		actual.preset_id = old.preset_id; actual.display_name = old.display_name; actual.category = old.category
		t.expect_true(actual == old, "Only identity/profile/final width differ from F")
		var compiled = preload("res://src/export/vfx_export_service.gd").new().validate_saved_source(PATH)
		t.expect_true(compiled.success, "Static ribbon compiles")
		if compiled.success:
			var data: Dictionary = JSON.parse_string(compiled.value.runtime_text())
			var reader = preload("res://src/export/vfx_runtime_definition_reader.gd")
			t.expect_true(data.runtime_definition_version == 3 and data.required_capabilities == ["CURVE_FLOW_STATIC_RIBBON_F2"], "v3 declares new semantics, no version bump")
			t.expect_true(not reader.read(data,[3],["CURVE_FLOW"]).success, "F1-only reader rejects F2")
			t.expect_true(reader.read(data,[3],["CURVE_FLOW"],["CURVE_FLOW_STATIC_RIBBON_F2"]).success, "Explicit F2 reader accepts")
			data.required_capabilities = ["CURVE_FLOW_F1"]
			t.expect_true(not reader.read(data,[3],["CURVE_FLOW"]).success, "Mislabeled F2 rejects")
		t.expect_true(ResourceLoader.exists("res://src/preview/curve_flow/vfx_curve_flow_static_geometry.gd"), "Prepared immutable static geometry is implemented")
		if "--deliver" in OS.get_cmdline_user_args() and t.failure_count()==0:
			var exported = preload("res://src/export/vfx_export_service.gd").new().export_saved_source(PATH,"FAIL_IF_EXISTS")
			t.expect_true(exported.success,"Canonical initial-create once")
			if exported.success: verify_package(result.value.raw_data, preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")._registry())
	print("STATIC_RIBBON assertions=",t.assertion_count()," failures=",t.failure_count())
	quit(1 if t.failure_count() else 0)

class PackageAssets extends RefCounted:
	var textures := {}
	func resolve(id: String) -> VfxResult:
		if not textures.has(id): return VfxResult.failure([VfxIssue.new("ASSET", "missing", id)])
		return VfxResult.ok({"texture": textures[id], "source": "TEXTURE", "logical_id": id, "size_px": [textures[id].get_width(), textures[id].get_height()], "color_rgba": [1,1,1,1], "is_fallback": false})

func verify_package(raw: Dictionary, registry: RefCounted) -> void:
	var base := "res://exports/packages/talent.solo_run.static_ribbon/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "manifest.json"))
	var expected := ["manifest.json"]
	for entry in manifest.files:
		expected.append(entry.path)
		t.expect_true(FileAccess.get_file_as_bytes(base + entry.path).size() == entry.byte_size and FileAccess.get_sha256(base + entry.path) == entry.sha256, "Payload hash/bytes " + entry.path)
	var actual := inventory(base)
	expected.sort(); actual.sort()
	t.expect_true(expected == actual and actual.size() == 5, "Exactly five physical files, no stale/import payload")
	t.expect_true(JSON.parse_string(FileAccess.get_file_as_string(base + manifest.source.path)) == raw, "Packaged source semantic identity")
	var runtime_text := FileAccess.get_file_as_string(base + manifest.runtime_definition.path)
	t.expect_true(not "prototypes/" in runtime_text and not "res://" in runtime_text and not "C:/" in runtime_text, "Portable runtime references")
	var decoded = preload("res://src/export/vfx_runtime_definition_reader.gd").read(JSON.parse_string(runtime_text), [3], ["CURVE_FLOW"], ["CURVE_FLOW_STATIC_RIBBON_F2"])
	t.expect_true(decoded.success, "Packaged runtime reload")
	if not decoded.success: return
	var assets := PackageAssets.new()
	for dep in manifest.asset_dependencies:
		var source: String = "res://assets/vfx/" + dep.package_path.get_file()
		t.expect_true(FileAccess.get_file_as_bytes(source) == FileAccess.get_file_as_bytes(base + dep.package_path), "Packaged texture byte identity " + dep.logical_id)
		var image := Image.new()
		t.expect_true(image.load_png_from_buffer(FileAccess.get_file_as_bytes(base + dep.package_path)) == OK, "External package PNG decode")
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		var imported_image: Image = (load(source) as Texture2D).get_image()
		t.expect_true(image.get_data() == imported_image.get_data(), "Reloaded texture mip identity " + dep.logical_id)
		assets.textures[dep.logical_id] = ImageTexture.create_from_image(image)
	var plan = preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd").new(registry).build(decoded.value.normalized_data)
	var runtime = preload("res://src/preview/rendering/vfx_preview_render_runtime.gd").new(plan.value, {"anchors":{"CENTER":[0,0]}}, registry, preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd").new(), assets)
	runtime.activate_phase("loop", {}); runtime.advance(1.5, {})
	t.expect_true(runtime.draw_packets().size() == 8, "Reloaded package renders all eight lanes using packaged assets only")

func inventory(base: String, relative: String = "") -> Array:
	var result := []
	for file in DirAccess.get_files_at(base + relative): result.append(relative + file)
	for directory in DirAccess.get_directories_at(base + relative): result.append_array(inventory(base, relative + directory + "/"))
	return result
