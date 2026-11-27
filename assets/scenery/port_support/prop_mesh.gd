extends RefCounted
## Shared, material-batched scenery. All dimensions are in game metres.

const STEEL := Color("404c4e")
const BLACK := Color("293335")
const RUST := Color("854939")
const DECK := Color("857458")
const WOOD := Color("a0845f")
const CREAM := Color("cfbf9e")
const GLASS := Color("344d58")
const GREEN := Color("626c4e")
const LIGHT_GREEN := Color("818c69")
const LINE := Color("d0c3a1")
const RED := Color("ad644f")
const BUOY_GREEN := Color("54877a")
const RUBBER := Color("2a3030")

var _surface: SurfaceTool
var _meshes: Dictionary = {}

func mesh_for(kind: String) -> ArrayMesh:
	if _meshes.has(kind): return _meshes[kind]
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"tug": _tug()
		"barge": _barge()
		"buoy_red": _buoy(RED, true)
		"buoy_green": _buoy(BUOY_GREEN, false)
		"tractor": _tractor()
		"ladder": _ladder()
		"cart": _cart()
		"drums": _drums()
		_: return null
	_surface.index()
	_surface.generate_normals()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	_surface.set_material(material)
	var mesh: ArrayMesh = _surface.commit()
	_meshes[kind] = mesh
	return mesh

func _face(points: Array[Vector3], tint: Color, outward: Vector3) -> void:
	# Godot uses clockwise winding for a front face.
	if (points[2]-points[0]).cross(points[1]-points[0]).dot(outward) < 0.0:
		points.reverse()
	for i: int in range(1, points.size()-1):
		for p: Vector3 in [points[0],points[i],points[i+1]]:
			_surface.set_smooth_group(-1)
			_surface.set_color(tint.srgb_to_linear())
			_surface.add_vertex(p)

func _box(c: Vector3, size: Vector3, tint: Color) -> void:
	var x: Vector3 = Vector3.RIGHT*size.x*.5
	var y: Vector3 = Vector3.UP*size.y*.5
	var z: Vector3 = Vector3.BACK*size.z*.5
	for pair: Array in [[x,y,z],[y,x,z],[z,x,y]]:
		var n: Vector3 = pair[0]
		var u: Vector3 = pair[1]
		var v: Vector3 = pair[2]
		for direction: float in [-1.0,1.0]:
			var p: Vector3 = c+n*direction
			_face([p-u-v,p+u-v,p+u+v,p-u+v],tint,n*direction)

func _pipe(a: Vector3,b: Vector3,ra: float,rb: float,tint: Color, sides: int=10) -> void:
	var dir: Vector3 = (b-a).normalized()
	var u: Vector3 = dir.cross(Vector3.UP if absf(dir.y)<.9 else Vector3.RIGHT).normalized()
	var v: Vector3 = dir.cross(u)
	var start: Array[Vector3] = []
	var end: Array[Vector3] = []
	for i: int in sides:
		var angle: float = TAU*float(i)/sides
		var point: Vector3 = cos(angle)*u+sin(angle)*v
		start.append(a+point*ra)
		end.append(b+point*rb)
	for i: int in sides:
		var j: int = (i+1)%sides
		_face([start[i],start[j],end[j],end[i]],tint,(start[i]+start[j])*.5-a)
	_face(start,tint,-dir)
	_face(end,tint,dir)

func _hull(outline: PackedVector2Array, y_top: float) -> void:
	var levels: PackedFloat32Array = [-1.3,-.29,.18,y_top-.20,y_top]
	var widths: PackedFloat32Array = [.72,.93,.98,1.0,.985]
	var tones: Array[Color] = [RUST,RUST,STEEL,BLACK]
	for j: int in range(levels.size()-1):
		for i: int in outline.size():
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[(i+1)%outline.size()]
			_face([_hull_p(a,levels[j],widths[j]),_hull_p(b,levels[j],widths[j]),_hull_p(b,levels[j+1],widths[j+1]),_hull_p(a,levels[j+1],widths[j+1])],tones[j],Vector3(a.x+b.x,0,a.y+b.y))
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for p: Vector2 in outline:
		top.append(_hull_p(p,y_top,widths[-1]))
		bottom.append(_hull_p(p,levels[0],widths[0]))
	_face(top,DECK,Vector3.UP)
	_face(bottom,RUST,Vector3.DOWN)

func _hull_p(p: Vector2, height: float, inset: float) -> Vector3:
	return Vector3(p.x*inset,height,p.y*(.70+.30*inset))

func _tug() -> void:
	var outline: PackedVector2Array = PackedVector2Array([Vector2(0,-13),Vector2(1.5,-11.9),Vector2(2.9,-9),Vector2(3.55,-5),Vector2(3.62,5.8),Vector2(3.1,9.8),Vector2(1.7,11.8),Vector2(-1.7,11.8),Vector2(-3.1,9.8),Vector2(-3.62,5.8),Vector2(-3.55,-5),Vector2(-2.9,-9),Vector2(-1.5,-11.9)])
	_hull(outline,1.70)
	_box(Vector3(0,2.67,-1.12),Vector3(4.7,1.94,8.2),GREEN)
	_box(Vector3(0,3.72,-1.12),Vector3(4.85,.22,8.45),STEEL)
	_box(Vector3(0,4.70,-3.16),Vector3(4.15,1.74,4.2),CREAM)
	_box(Vector3(0,5.61,-3.22),Vector3(4.48,.28,4.52),GREEN)
	for x: float in [-1.30,0.0,1.30]:
		_box(Vector3(x,4.95,-5.275),Vector3(.99,.60,.038),GLASS)
	for side: float in [-1.0,1.0]:
		for z: float in [-4.45,-3.36,-2.23]:
			_box(Vector3(side*2.083,4.95,z),Vector3(.038,.56,.81),GLASS)
		for z: float in [-6.6,-2.7,1.5,5.7,8.8]:
			_pipe(Vector3(side*3.12,1.68,z),Vector3(side*3.12,2.39,z),.064,.055,STEEL,6)
		_pipe(Vector3(side*3.12,2.38,-6.6),Vector3(side*3.12,2.38,8.8),.051,.051,LINE,6)
		for z: float in [-5.4,0.4,6.6]:
			_pipe(Vector3(side*3.54,1.01,z),Vector3(side*3.72,1.01,z),.52,.48,RUBBER,12)
			_pipe(Vector3(side*3.72,1.01,z),Vector3(side*3.75,1.01,z),.23,.21,STEEL,10)
	_pipe(Vector3(0,3.8,1.1),Vector3(0,6.95,1.1),.68,.46,BLACK,12)
	_pipe(Vector3(0,5.35,1.1),Vector3(0,5.73,1.1),.58,.56,RED,12)
	_pipe(Vector3(0,5.71,-2.1),Vector3(0,9.1,-2.1),.10,.066,CREAM,8)
	_pipe(Vector3(-1.38,7.80,-2.1),Vector3(1.38,7.80,-2.1),.044,.044,STEEL,6)
	_box(Vector3(0,1.98,5.97),Vector3(2.60,.55,2.0),STEEL)
	_pipe(Vector3(-1.23,2.42,5.97),Vector3(1.23,2.42,5.97),.54,.54,DECK,12)
	for z: float in [-10.0,9.25]:
		for x: float in [-.71,.71]:
			_pipe(Vector3(x,1.71,z),Vector3(x,2.20,z),.20,.18,STEEL,8)

func _crate(c: Vector3,s: Vector3) -> void:
	_box(c,s,WOOD)
	for x: float in [-.35,.35]:
		_box(c+Vector3(x*s.x, s.y*.5+.028,0),Vector3(s.x*.14,.06,s.z*.97),DECK)
	for z: float in [-1.0,1.0]:
		_box(c+Vector3(0,0,z*(s.z*.5+.023)),Vector3(s.x*.93,s.y*.14,.06),DECK)

func _barge() -> void:
	var shape: PackedVector2Array = PackedVector2Array([Vector2(3.0,-24),Vector2(6,-21),Vector2(6,21),Vector2(3.0,24),Vector2(-3.0,24),Vector2(-6,21),Vector2(-6,-21),Vector2(-3,-24)])
	_hull(shape,1.30)
	for side: float in [-1.0,1.0]:
		_box(Vector3(5.03*side,1.77,0),Vector3(.28,.94,36),STEEL)
		for z: int in range(-16,17,4):
			_box(Vector3(4.82*side,1.59,z),Vector3(.32,.54,.34),STEEL)
		for z: float in [-18.5,18.5]:
			_pipe(Vector3(side*4.55,1.3,z),Vector3(side*4.55,2.14,z),.23,.20,BLACK,8)
	for z: float in [-18.0,18.0]:
		_box(Vector3(0,1.77,z),Vector3(10.1,.94,.27),STEEL)
	for c: Vector3 in [Vector3(-2.5,2.40,-11),Vector3(1.70,2.37,-11.3),Vector3(-2.6,2.38,-6.6),Vector3(-2.35,2.26,6.25)]:
		_crate(c,Vector3(3.20,2.14,3.45))
	_box(Vector3(1.70,3.66,-11.3),Vector3(3.40,.31,3.63),GREEN)
	_box(Vector3(.88,2.29,8.2),Vector3(4.0,1.96,8.20),GREEN)
	_box(Vector3(.90,3.08,8.2),Vector3(4.16,.58,8.34),LIGHT_GREEN)
	for z: float in [5.5,8.0,10.7]:
		_box(Vector3(.90,3.39,z),Vector3(4.20,.065,.12),LINE)
	_box(Vector3(0,1.70,-21),Vector3(2.35,.80,1.4),BLACK)
	_pipe(Vector3(-1.12,2.28,-21),Vector3(1.12,2.28,-21),.48,.48,STEEL,12)

func _buoy(body: Color, can_top: bool) -> void:
	_pipe(Vector3(0,-.48,0),Vector3(0,.20,0),1.16,1.39,body,14)
	_pipe(Vector3(0,.20,0),Vector3(0,.87,0),1.39,.94,body,14)
	_pipe(Vector3(0,.39,0),Vector3(0,.52,0),1.38,1.25,CREAM,14)
	_pipe(Vector3(0,.82,0),Vector3(0,2.27,0),.51,.20,body,12)
	for i: int in 4:
		var angle: float = float(i)*PI*.5
		var side: Vector3 = Vector3(cos(angle),0,sin(angle))
		_pipe(side*.80+Vector3.UP*.76,side*.21+Vector3.UP*2.18,.058,.048,STEEL,6)
	_pipe(Vector3(0,2.26,0),Vector3(0,2.63,0),.36,.36,CREAM,10)
	_pipe(Vector3(0,2.65,0),Vector3(0,3.17,0),.48,.48 if can_top else .045,body,10)

func _wheel(x: float,y: float,z: float,r: float) -> void:
	var side: float = signf(x)
	_pipe(Vector3(x-side*.12,y,z),Vector3(x+side*.12,y,z),r,r,RUBBER,12)
	_pipe(Vector3(x+side*.115,y,z),Vector3(x+side*.14,y,z),r*.48,r*.48,STEEL,10)

func _tractor() -> void:
	for side: float in [-1.0,1.0]:
		_wheel(side*.84,.60,.83,.60)
		_wheel(side*.68,.38,-1.11,.38)
	_box(Vector3(0,.65,0),Vector3(1.35,.44,2.83),GREEN)
	_box(Vector3(0,1.13,-.80),Vector3(1.02,.77,1.25),LIGHT_GREEN)
	_box(Vector3(0,1.12,-1.441),Vector3(.86,.54,.062),BLACK)
	for y: float in [.92,1.045,1.17,1.295]:
		_box(Vector3(0,y,-1.49),Vector3(.72,.027,.045),STEEL)
	_box(Vector3(0,1.10,.72),Vector3(.57,.19,.57),BLACK)
	_box(Vector3(0,1.30,1.00),Vector3(.57,.41,.13),BLACK)
	for side: float in [-1.0,1.0]:
		_box(Vector3(side*.78,1.26,.80),Vector3(.36,.11,1.37),LIGHT_GREEN)
		_box(Vector3(side*.54,1.20,-1.30),Vector3(.15,.17,.16),CREAM)
	_pipe(Vector3(.35,1.51,-.58),Vector3(.35,2.01,-.58),.052,.050,BLACK,7)
	_pipe(Vector3(0,1.03,.22),Vector3(0,1.64,-.01),.05,.052,BLACK,8)
	_pipe(Vector3(-.26,1.64,-.01),Vector3(.26,1.64,-.01),.04,.04,STEEL,8)
	_pipe(Vector3(0,.52,1.37),Vector3(0,.22,3.7),.062,.055,STEEL,8)
	_box(Vector3(0,.26,3.70),Vector3(.24,.16,.28),CREAM)

func _ladder() -> void:
	for side: float in [-1.0,1.0]:
		var x: float = .55*side
		_pipe(Vector3(x,.04,1.45),Vector3(x,2.85,-.51),.060,.060,STEEL,6)
		_pipe(Vector3(x,.06,-1.56),Vector3(x,2.85,-.51),.054,.054,STEEL,6)
		_pipe(Vector3(x,.80,1.22),Vector3(x,3.37,-.55),.049,.049,CREAM,6)
		_pipe(Vector3(x,2.75,-.68),Vector3(x,3.36,-.68),.050,.048,CREAM,6)
	for i: int in range(1,8):
		var t: float = float(i)/8
		_box(Vector3(0,lerpf(.04,2.78,t),lerpf(1.45,-.51,t)),Vector3(1.09,.105,.29),WOOD)
	_box(Vector3(0,2.80,-.63),Vector3(1.18,.16,.79),DECK)

func _cart() -> void:
	for side: float in [-1.0,1.0]:
		for z: float in [-.53,.53]: _wheel(side*.57,.21,z,.21)
	_box(Vector3(0,.415,0),Vector3(1.02,.15,1.6),STEEL)
	_box(Vector3(0,.75,-.07),Vector3(.92,.56,1.21),RED)
	_box(Vector3(0,1.045,-.07),Vector3(.98,.072,1.29),BLACK)
	for y: float in [.58,.78,.945]:
		_box(Vector3(.479,y,-.09),Vector3(.057,.040,.68),CREAM)
	for side: float in [-1.0,1.0]:
		_pipe(Vector3(side*.38,.64,.68),Vector3(side*.34,.91,1.10),.037,.037,STEEL,8)
	_pipe(Vector3(-.34,.91,1.10),Vector3(.34,.91,1.10),.036,.036,STEEL,8)

func _drums() -> void:
	_box(Vector3(.24,.08,0),Vector3(2.38,.16,1.66),DECK)
	for p: Vector3 in [Vector3(-.42,.15,-.34),Vector3(.35,.15,-.30),Vector3(-.36,.15,.43)]:
		_pipe(p,p+Vector3.UP*.88,.28,.28,GREEN,12)
		for y: float in [.20,.65,.84]:
			_pipe(p+Vector3.UP*y,p+Vector3.UP*(y+.05),.296,.296,STEEL,12)
	_crate(Vector3(.99,.50,.32),Vector3(.72,.69,.68))
