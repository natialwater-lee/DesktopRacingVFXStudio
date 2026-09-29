extends "res://src/preview/rendering/vfx_preview_layer_renderer.gd"
const Evaluator := preload("res://src/preview/curve_flow/vfx_curve_flow_evaluator.gd")
const Contract := preload("res://src/preview/curve_flow/vfx_curve_flow_contract.gd")
var flow := Evaluator.new()
var geometry: RefCounted

func restart(frame_context: Dictionary) -> void:
	super.restart(frame_context)
	if _parameters().profile_version == 2:
		assert(geometry != null, "Static geometry must be prepared by the plan")
		flow.lanes = [Contract.lane(_parameters())]
		flow.tables = geometry.tables.duplicate()
		flow.restart()
	else:
		flow.configure([Contract.lane(_parameters())])
	_emit_packet(frame_context)

func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	flow.advance(delta_seconds)
	_emit_packet(frame_context)

func stop_emission() -> void:
	super.stop_emission()
	flow.stop()

func has_residual() -> bool:
	return not flow.segments.is_empty()

func clear() -> void:
	super.clear()
	flow.clear()

func _emit_packet(frame_context: Dictionary) -> void:
	_packets.clear()
	if flow.segments.is_empty() and geometry == null: return
	var packet := _packet_base(frame_context)
	packet["curve_flow"] = flow
	if geometry != null: packet["curve_geometry"] = geometry
	_packets.append(packet)
