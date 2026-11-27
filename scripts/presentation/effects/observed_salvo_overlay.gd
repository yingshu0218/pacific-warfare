extends MeshInstance3D
## Optical-only dotted trace and terminal marks. Never paints beyond shown_time_s.
const TAPE: Script = preload("res://scripts/presentation/state/observed_salvos.gd")
const TRACE: Color = Color(1.0,.74,.35,.80)
const COLORS: Dictionary = {"sea":Color(.32,.82,1,.93),"hit":Color(1,.40,.19,.96),"land":Color(1,.71,.44,.93),"airburst":Color(.76,.66,1,.93),"expired":Color(.70,.73,.76,.80)}
var lines: ImmediateMesh = ImmediateMesh.new()
var material: StandardMaterial3D = StandardMaterial3D.new()
var point_count: int = 0
var terminal_counts: Dictionary = {}
var segment_count: int = 0

func _ready() -> void:
	mesh = lines
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

func reset() -> void:
	visible = false
	lines.clear_surfaces()
	point_count = 0
	segment_count = 0
	terminal_counts.clear()

func show_salvo(tape: TAPE, source: String, shown_time_s: float, rank: int = 0) -> int:
	reset()
	var group: Dictionary = tape.latest(source,shown_time_s,rank)
	if group.is_empty(): return 0
	var records: Array[Dictionary] = tape.visible_tracks(group,shown_time_s)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return 0
	lines.surface_begin(Mesh.PRIMITIVE_LINES,material)
	for record: Dictionary in records:
		var points: PackedVector3Array = record.points
		point_count += points.size()
		for index: int in range(1,points.size()):
			var a: Vector3 = points[index-1]
			var b: Vector3 = points[index]
			if a.distance_squared_to(b)<.01: continue
			# A broken thin chord between adjacent recorded samples, not a prediction.
			_segment(a,b,TRACE)
		var terminal: String = str(record.terminal)
		if not terminal.is_empty():
			terminal_counts[terminal] = int(terminal_counts.get(terminal,0))+1
			_mark(camera,points[-1],terminal)
	if segment_count == 0:
		# Keep ImmediateMesh valid even on the tick before the first sampled leg.
		_segment(Vector3.ZERO,Vector3.ZERO,Color.TRANSPARENT)
	lines.surface_end()
	visible = true
	return records.size()

func _segment(a: Vector3,b: Vector3,color: Color) -> void:
	segment_count += 1
	lines.surface_set_color(color)
	lines.surface_add_vertex(a)
	lines.surface_add_vertex(b)

func _mark(camera: Camera3D, p: Vector3, kind: String) -> void:
	var r: float = clampf(camera.global_position.distance_to(p)*.012,2.,90.)
	var x: Vector3 = camera.global_basis.x.normalized()*r
	var y: Vector3 = camera.global_basis.y.normalized()*r
	var color: Color = COLORS.get(kind,Color.WHITE)
	if kind == "sea":
		_segment(p-x,p-y*.32,color)
		_segment(p-y*.32,p+x,color)
	elif kind == "hit":
		_segment(p-x-y,p+x+y,color)
		_segment(p-x+y,p+x-y,color)
	elif kind == "airburst":
		_segment(p-x,p+x,color)
		_segment(p-y,p+y,color)
	else:
		_segment(p-x,p+y,color)
		_segment(p+y,p+x,color)
		_segment(p+x,p-y,color)
		_segment(p-y,p-x,color)
