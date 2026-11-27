extends "res://aircraft/visual_study/airframe_geometry.gd"
## Rebuilt hand-lofted exterior for display. No behavior or mechanical assemblies.

const BODY: Array[Vector4] = [
	Vector4(-6.96,-0.35,.56,.56),Vector4(-6.67,-.30,.625,.615),Vector4(-6.15,-.22,.69,.725),
	Vector4(-5.58,-.14,.735,.82),Vector4(-4.74,-.09,.755,.96),Vector4(-3.40,-.07,.755,1.03),
	Vector4(-1.80,-.05,.74,1.07),Vector4(.02,-.06,.72,1.04),Vector4(1.45,-.03,.68,.91),
	Vector4(2.80,.02,.615,.81),Vector4(4.31,.07,.51,.62),Vector4(5.60,.13,.38,.44),
	Vector4(6.82,.20,.235,.30),Vector4(7.59,.22,.135,.16),Vector4(8.01,.20,.018,.028)]
const WING: Array[Vector4] = [
	Vector4(.40,-4.68,.48,.47),Vector4(.83,-4.64,.42,.45),Vector4(1.60,-4.49,.29,.41),
	Vector4(2.64,-4.30,.12,.39),Vector4(3.55,-4.15,-.02,.36),Vector4(4.75,-3.92,-.23,.31),
	Vector4(6.15,-3.64,-.42,.26),Vector4(7.65,-3.35,-.64,.20),Vector4(9.10,-3.03,-.86,.15),
	Vector4(10.39,-2.73,-1.08,.10),Vector4(10.91,-2.59,-1.30,.071),Vector4(11.16,-2.43,-1.56,.047),
	Vector4(11.25,-2.18,-1.94,.022)]
const TAIL: Array[Vector4] = [
	Vector4(.08,4.72,7.31,.155),Vector4(.45,4.95,7.31,.138),Vector4(1.40,5.28,7.28,.107),
	Vector4(2.50,5.70,7.26,.076),Vector4(3.35,6.04,7.18,.052),Vector4(3.73,6.31,7.05,.033),
	Vector4(3.84,6.58,6.81,.012)]
var _skin: StandardMaterial3D
var _glass: StandardMaterial3D
var _frame: StandardMaterial3D
var _joint: StandardMaterial3D
var _metal: StandardMaterial3D
var _dark: StandardMaterial3D
var _cowl: StandardMaterial3D
var _marking: StandardMaterial3D

func _ready() -> void:
	_skin = _paint(Color.WHITE,true)
	_glass = _paint(Color("3b5159"))
	_glass.roughness = .24
	_glass.metallic = .25
	_frame = _paint(Color("5e654d"))
	_joint = _paint(Color("3e4837"))
	_metal = _paint(Color("4e5149"))
	_metal.metallic = .34
	_dark = _paint(Color("252b29"))
	_cowl = _paint(Color("343a35"))
	_cowl.metallic = .16
	_marking = _paint(Color("993b32"))
	_loft("Fuselage",_body_rings(BODY),_skin)
	_glazing()
	_wings()
	_masts_and_windows()
	_nacelles()

func _wings() -> void:
	var fin: Array[Vector4] = [
		Vector4(.29,4.88,7.77,.16),Vector4(.64,5.20,7.69,.14),Vector4(1.23,5.61,7.63,.115),
		Vector4(1.96,5.93,7.56,.093),Vector4(2.54,6.13,7.63,.068),Vector4(2.82,6.32,7.56,.050),
		Vector4(2.98,6.56,7.39,.027),Vector4(3.04,6.82,7.11,.012)]
	_loft("Single fin",_vertical_rings(fin),_skin)
	for side: float in [-1.0,1.0]:
		var code: String = _side_code(side)
		_loft("Wing "+code,_span_rings(WING,side,-.02,.075),_skin)
		_loft("Stabilizer "+code,_span_rings(TAIL,side,.20,.025),_skin)
		_seam("Aileron line "+code,WING,side,5.35,10.87,.78,-.02,.075)
		_seam("Flap line "+code,WING,side,.90,5.34,.75,-.02,.075)
		_seam("Elevator line "+code,TAIL,side,.52,3.60,.64,.20,.025)
		var rudder := PackedVector3Array()
		for row: Vector4 in fin:
			rudder.append(Vector3(side*(.92*row.w+.004),row.x,lerpf(row.y,row.z,.70)))
		_line("Rudder seam "+code,rudder,.014,_joint)
		_roundel(side)

func _span_point(rows: Array[Vector4],side: float,x: float,c: float,h: float,rise: float) -> Vector3:
	var row := _sample(rows,x)
	var a: float = acos(clampf(c*2.0-1.0,-1,1))
	var step: float = TAU/float(SECTION_POINTS)
	var lo: float = floorf(a/step)*step
	var hi: float = lo+step
	var lc: float = (1.0+cos(lo))*.5
	var hc: float = (1.0+cos(hi))*.5
	var depth: float = lerpf(sin(lo)*(1.05-.30*lc),sin(hi)*(1.05-.30*hc),inverse_lerp(lc,hc,c))
	return Vector3(x*side,h+rise*x+row.w*depth+.009,lerpf(row.y,row.z,c))

func _seam(label: String,rows: Array[Vector4],side: float,begin: float,finish: float,c: float,h: float,rise: float) -> void:
	var points := PackedVector3Array([_span_point(rows,side,begin,c,h,rise)])
	for row: Vector4 in rows:
		if row.x > begin and row.x < finish:
			points.append(_span_point(rows,side,row.x,c,h,rise))
	points.append(_span_point(rows,side,finish,c,h,rise))
	_line(label,points,.015,_joint)

func _roundel(side: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(3):
		for i: int in range(32):
			var a: float = TAU*i/32.0
			var b: float = TAU*(i+1)/32.0
			var p: Vector3 = _roundel_coord(side,row*.29,a)
			var q: Vector3 = _roundel_coord(side,(row+1)*.29,a)
			var r: Vector3 = _roundel_coord(side,(row+1)*.29,b)
			_triangle(st,p,q,r,Vector3.UP)
			if row > 0:
				_triangle(st,p,r,_roundel_coord(side,row*.29,b),Vector3.UP)
	st.generate_normals()
	_mesh("Wing marking "+_side_code(side),st.commit(),_marking)

func _roundel_coord(side: float,radius: float,a: float) -> Vector3:
	var x: float = 8.28+radius*cos(a)
	var z: float = -2.08+radius*sin(a)
	var row := _sample(WING,x)
	return _span_point(WING,side,x,inverse_lerp(row.y,row.z,z),-.02,.075)

func _glazing() -> void:
	var nose: Array[Vector4] = [
		Vector4(-8.01,-.40,.025,.035),Vector4(-7.97,-.39,.18,.205),Vector4(-7.81,-.38,.345,.325),
		Vector4(-7.59,-.365,.455,.455),Vector4(-7.26,-.35,.525,.515),Vector4(-6.96,-.35,.56,.56)]
	var flight: Array[Vector4] = [
		Vector4(-5.96,.62,.35,.049),Vector4(-5.67,.655,.432,.205),Vector4(-5.34,.73,.455,.355),
		Vector4(-4.94,.76,.48,.405),Vector4(-4.55,.78,.485,.373),Vector4(-4.10,.80,.457,.31),
		Vector4(-3.76,.825,.40,.16),Vector4(-3.46,.871,.24,.105)]
	var dorsal: Array[Vector4] = [
		Vector4(-1.40,.982,.27,.04),Vector4(-1.06,.97,.365,.19),Vector4(-.61,.955,.405,.229),
		Vector4(-.07,.921,.407,.244),Vector4(.49,.899,.403,.24),Vector4(1.04,.874,.391,.216),
		Vector4(1.58,.826,.359,.19),Vector4(2.02,.778,.312,.147),Vector4(2.34,.752,.237,.105),
		Vector4(2.56,.727,.124,.039)]
	_glasshouse("Round glazed nose",nose,1.0)
	_glasshouse("Stepped cockpit",flight,.74)
	_glasshouse("Low continuous dorsal greenhouse",dorsal,.74)

func _glasshouse(label: String,outline: Array[Vector4],power: float) -> void:
	_loft(label,_glass_rings(outline,power),_glass)
	for i: int in range(1,outline.size()-1):
		var s: Vector4 = outline[i]
		var rib: Array[Vector4] = [Vector4(s.x-.022,s.y,s.z+.011,s.w+.012),Vector4(s.x+.022,s.y,s.z+.011,s.w+.012)]
		_loft(label+" transverse %d"%i,_glass_rings(rib,power),_frame,false)
	var guides: Array = [0.0,PI*.5,PI,PI*1.5] if power == 1.0 else [.49,1.18,1.96,2.65]
	for i: int in range(guides.size()):
		var path := PackedVector3Array()
		for j: int in range(1 if power == 1.0 else 0,outline.size()):
			var s: Vector4 = outline[j]
			path.append(_glass_coord(Vector4(s.x,s.y,s.z+.014,s.w+.014),guides[i],power))
		_line(label+" longitudinal %d"%i,path,.024,_frame)

func _glass_coord(s: Vector4,a: float,power: float) -> Vector3:
	return Vector3(s.z*signf(cos(a))*pow(absf(cos(a)),power),s.y+s.w*signf(sin(a))*pow(absf(sin(a)),power),s.x)

func _glass_rings(rows: Array[Vector4],power: float) -> Array[PackedVector3Array]:
	var rings: Array[PackedVector3Array] = []
	for row: Vector4 in rows:
		var ring := PackedVector3Array()
		for i: int in range(SECTION_POINTS):
			ring.append(_glass_coord(row,TAU*i/float(SECTION_POINTS),power))
		rings.append(ring)
	return rings

func _masts_and_windows() -> void:
	for side: float in [-1.0,1.0]:
		var code := _side_code(side)
		for col: int in range(3):
			for row: int in range(2):
				var id: String = "Low nose pane "+code+"%d%d"%[col,row]
				var z: float = -6.53+.50*col-.03*row
				var a: float = -.53-.24*row
				_body_patch(id+" trim",side,z,a,.204,.13,.010,_joint)
				_body_patch(id,side,z,a,.176,.106,.017,_glass)
		for i: int in range(2):
			_body_patch("Aft cabin inset "+code+str(i),side,1.28+.63*i,.47,.111,.15,.016,_glass)
		_body_patch("Long aft skin join "+code,side,3.12,-.30,1.65,.010,.011,_joint)
		var hatch := PackedVector3Array()
		for p: Vector2 in [Vector2(3.38,-.23),Vector2(3.38,.55),Vector2(3.94,.55),Vector2(3.94,-.23),Vector2(3.38,-.23)]:
			hatch.append(_body_coord(side,p.x,p.y,.013))
		_line("Cabin access outline "+code,hatch,.014,_joint)
	var mast := Vector3(0,1.71,-3.15)
	_line("Aerial mast",PackedVector3Array([Vector3(0,1.025,-3.25),mast]),.040,_frame)
	var anchor := Vector3(0,2.95,6.75)
	_line("Aerial",PackedVector3Array([mast,mast.lerp(anchor,.52)-Vector3(0,.041,0),anchor]),.012,_metal)

func _body_coord(side: float,z: float,theta: float,lift: float) -> Vector3:
	var s := _sample(BODY,z)
	var segment: float = theta*SECTION_POINTS/TAU
	var a: float = floorf(segment)*TAU/SECTION_POINTS
	var b: float = a+TAU/SECTION_POINTS
	var v := Vector2(cos(a),sin(a)).lerp(Vector2(cos(b),sin(b)),segment-floorf(segment))
	return Vector3(side*(s.z*v.x+lift*cos(theta)),s.y+s.w*v.y+lift*sin(theta),z)

func _body_patch(label: String,side: float,z: float,theta: float,halfz: float,halfa: float,lift: float,mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(5):
		var a: float = z+halfz*(2.0*i/5.0-1.0)
		var b: float = z+halfz*(2.0*(i+1)/5.0-1.0)
		for j: int in range(4):
			var c: float = theta+halfa*(.50*j-1.0)
			var d: float = theta+halfa*(.50*(j+1)-1.0)
			var p: Vector3 = _body_coord(side,a,c,lift)
			var q: Vector3 = _body_coord(side,b,c,lift)
			var r: Vector3 = _body_coord(side,b,d,lift)
			var t: Vector3 = _body_coord(side,a,d,lift)
			_triangle(st,p,q,r,Vector3(side,0,0))
			_triangle(st,p,r,t,Vector3(side,0,0))
	st.generate_normals()
	_mesh(label,st.commit(),mat)

func _nacelles() -> void:
	var pod: Array[Vector4] = [
		Vector4(-5.10,-.48,.83,.88),Vector4(-4.98,-.48,.83,.88),Vector4(-4.24,-.48,.815,.87),
		Vector4(-3.26,-.48,.78,.81),Vector4(-2.47,-.43,.68,.70),Vector4(-1.75,-.33,.56,.55),
		Vector4(-1.02,-.16,.37,.31),Vector4(-.48,-.08,.14,.13),Vector4(-.32,-.08,.038,.032)]
	var cowl: Array[Vector4] = [
		Vector4(-5.91,-.45,.57,.61),Vector4(-5.82,-.46,.71,.765),Vector4(-5.62,-.45,.78,.84),pod[0]]
	var lip: Array[Vector4] = [cowl[0],Vector4(-5.95,-.45,.545,.59),Vector4(-5.91,-.45,.462,.515),Vector4(-5.78,-.45,.44,.482)]
	var recess: Array[Vector4] = [Vector4(-5.77,-.45,.445,.487),Vector4(-5.74,-.45,.452,.495)]
	var hub: Array[Vector4] = [
		Vector4(-6.52,-.41,.027,.028),Vector4(-6.43,-.41,.129,.14),Vector4(-6.21,-.41,.211,.217),
		Vector4(-6.01,-.41,.254,.268),Vector4(-5.85,-.41,.213,.226)]
	var well: Array[Vector4] = [
		Vector4(-4.12,-1.17,.275,.20),Vector4(-3.86,-1.20,.455,.24),Vector4(-3.44,-1.18,.46,.24),
		Vector4(-2.93,-1.095,.383,.19),Vector4(-2.56,-.99,.22,.125),Vector4(-2.33,-.94,.062,.047)]
	var band: Array[Vector4] = [Vector4(-5.14,-.48,.835,.882),Vector4(-5.10,-.48,.835,.882)]
	for side: float in [-1.0,1.0]:
		var code := _side_code(side)
		var x: float = 2.68*side
		_loft("Nacelle "+code,_body_rings(pod),_skin).position.x=x
		_loft("Cowling "+code,_body_rings(cowl),_cowl,false).position.x=x
		_loft("Rolled inlet "+code,_body_rings(lip),_cowl,false).position.x=x
		_loft("Recess shadow "+code,_body_rings(recess),_dark).position.x=x
		_loft("Cowl seam "+code,_body_rings(band),_frame,false).position.x=x
		_loft("Propeller spinner "+code,_body_rings(hub),_metal).position.x=x
		_loft("Closed wheel fairing "+code,_body_rings(well),_skin).position.x=x
		_line("Closed wheel seam "+code,PackedVector3Array([Vector3(x,-1.437,-3.81),Vector3(x,-1.424,-3.45),Vector3(x,-1.295,-2.95)]),.012,_joint)
		for i: int in range(9):
			var a: float = TAU*i/9.0
			_line("Inlet shadow detail "+code,PackedVector3Array([Vector3(x+.273*cos(a),-.45+.283*sin(a),-5.80),Vector3(x+.42*cos(a+.065),-.45+.45*sin(a+.065),-5.79)]),.034,_metal)
		for i: int in range(3):
			_blade("Propeller blade "+code+str(i+1),Vector3(x,-.41,-6.12),.37+side*.18+TAU*i/3.0)

func _blade(label: String,center: Vector3,angle: float) -> void:
	var rows: Array[Vector4] = [
		Vector4(.19,-.055,.055,.037),Vector4(.48,-.1,.12,.039),Vector4(.98,-.11,.13,.032),
		Vector4(1.46,-.1,.115,.024),Vector4(1.64,-.068,.066,.015),Vector4(1.71,-.022,.026,.009)]
	var rings: Array[PackedVector3Array] = _vertical_rings(rows)
	for r: int in range(rings.size()):
		for i: int in range(rings[r].size()):
			var p: Vector3 = rings[r][i]
			rings[r][i] = Vector3(p.z,p.y,p.x)
	var m := _loft(label,rings,_metal)
	m.position=center
	m.rotation.z=angle

func _vertical_rings(rows: Array[Vector4]) -> Array[PackedVector3Array]:
	var rings: Array[PackedVector3Array] = []
	for row: Vector4 in rows:
		var ring := PackedVector3Array()
		for i: int in range(SECTION_POINTS):
			var a: float = TAU*i/float(SECTION_POINTS)
			ring.append(Vector3(row.w*sin(a),row.x,lerpf(row.y,row.z,(1.0+cos(a))*.5)))
		rings.append(ring)
	return rings

func _sample(rows: Array[Vector4],x: float) -> Vector4:
	for i: int in range(rows.size()-1):
		var l: Vector4 = rows[i]
		var r: Vector4 = rows[i+1]
		if x <= r.x:
			return l.lerp(r,clampf(inverse_lerp(l.x,r.x,x),0,1))
	return rows[-1]

func _line(label: String,path: PackedVector3Array,width: float,mat: Material) -> void:
	for i: int in range(path.size()-1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i+1]
		if a.distance_squared_to(b) < 1e-10:
			continue
		var box := BoxMesh.new()
		box.size=Vector3(width,width,a.distance_to(b))
		var m := _mesh(label+" %d"%i,box,mat)
		m.position=(a+b)*.5
		m.quaternion=Quaternion(Vector3.BACK,(b-a).normalized())

func _side_code(side: float) -> String:
	return "L" if side < 0.0 else "R"

func _vertex(surface: SurfaceTool,p: Vector3) -> void:
	var t: float = smoothstep(-.48,-.05,p.y)
	var color: Color = Color("9e9e90").srgb_to_linear().lerp(Color("525a3a").srgb_to_linear(),t)
	var v: float = 1.0+.035*sin(p.z*2.7+p.x*5.1)+.021*cos(p.z*7.9-p.y*5.6)
	surface.set_color(Color(color.r*v,color.g*v,color.b*v,1.0))
	surface.add_vertex(p)
