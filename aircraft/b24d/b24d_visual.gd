extends "res://aircraft/visual_study/airframe_geometry.gd"
## Rebuilt static exterior. Public outline reference; no engineering or flight behavior.

const HALF_SPAN := 16.764
const HALF_LENGTH := 10.1092
var olive: StandardMaterial3D
var pale: StandardMaterial3D
var dark: StandardMaterial3D
var glass: StandardMaterial3D
var frame: StandardMaterial3D
var blue: StandardMaterial3D
var white: StandardMaterial3D
var amber: StandardMaterial3D
var counts: Dictionary = {}

func _ready() -> void:
	olive = _paint(Color("4e5542"))
	pale = _paint(Color("777c74"))
	dark = _paint(Color("222a2d"))
	glass = _paint(Color("31464f"))
	glass.roughness = 0.23
	frame = _paint(Color("606653"))
	blue = _paint(Color("2c4059"))
	white = _paint(Color("eeede6"))
	amber = _paint(Color("d0a24c"))
	build_body()
	build_wings()
	build_tail()
	for side: float in [-1,1]:
		engine(Vector3(side*3.378,0.68,-5.08))
		engine(Vector3(side*7.798,0.83,-4.84))
		body_mark(side)


func build_body() -> void:
	var stations: Array[Vector4] = [
		Vector4(-8.83,-0.18,0.77,1.12),Vector4(-8.22,-0.14,0.91,1.18),
		Vector4(-7.46,-0.10,1.00,1.25),Vector4(-6.52,-0.08,1.05,1.35),
		Vector4(-5.44,-0.11,1.10,1.48),Vector4(-4.02,-0.16,1.13,1.52),
		Vector4(-2.40,-0.19,1.13,1.57),Vector4(-0.60,-0.19,1.13,1.58),
		Vector4(1.0,-0.15,1.10,1.52),Vector4(3.0,-0.05,1.02,1.41),
		Vector4(4.67,0.04,0.91,1.24),Vector4(6.22,0.14,0.78,1.06),
		Vector4(7.63,0.26,0.67,0.92),Vector4(8.67,0.36,0.56,0.78),
		Vector4(9.43,0.38,0.41,0.64),Vector4(9.71,0.37,0.31,0.49),
		Vector4(9.97,0.35,0.21,0.29),Vector4(HALF_LENGTH,0.34,0.065,0.15)]
	coat("Fuselage",square(stations,0.48),stations,0.48)
	var nose: Array[Vector4] = [
		Vector4(-HALF_LENGTH,-0.19,0.020,0.032),Vector4(-10.047,-0.20,0.19,0.35),
		Vector4(-9.89,-0.23,0.35,0.57),Vector4(-9.71,-0.25,0.46,0.72),
		Vector4(-9.44,-0.23,0.56,0.87),Vector4(-9.14,-0.21,0.66,1.00),
		Vector4(-8.83,-0.18,0.77,1.12)]
	var rim := square(nose,0.48)
	coat("Nose outer shell",rim,nose,0.48)
	for j: int in [1,3]:
		for a: int in [0,3,6,9,12,15,18,21]:
			window("Nose pane",rim,j,j+2,a,a+3)
	var canopy: Array[Vector4] = [
		Vector4(-7.21,1.08,0.78,0.09),Vector4(-6.81,1.27,0.85,0.20),
		Vector4(-6.49,1.36,0.89,0.24),Vector4(-5.98,1.38,0.92,0.22),
		Vector4(-5.46,1.27,0.94,0.16),Vector4(-5.18,1.24,0.89,0.06)]
	var cabin := square(canopy,0.41)
	_loft("Cockpit cap",cabin,olive)
	for j: int in range(4):
		for a: int in [0,9]:
			window("Cockpit side pane",cabin,j,j+1,a,a+3)
	for a: int in [2,6]:
		window("Cockpit windscreen",cabin,0,1,a,a+4)
	var bump := SphereMesh.new()
	bump.radius=0.41
	bump.height=0.82
	bump.radial_segments=24
	bump.rings=10
	var blister := _mesh("Low rooftop glazing",bump,glass)
	blister.position=Vector3(0,1.40,-4.62)
	blister.scale=Vector3(1,0.62,1.10)
	var back := square(stations.slice(14),0.48)
	for a: int in [0,6,12,18]:
		window("Tail enclosure pane",back,1,3,a,a+5)
	for side: float in [-1,1]:
		box("Waist observation recess",Vector3(side*0.953,0.16,4.05),Vector3(0.025,0.43,0.70),dark).rotation.y=side*-0.07
		box("Waist metal sill",Vector3(side*0.955,-0.055,4.05),Vector3(0.026,0.029,0.72),frame).rotation.y=side*-0.07


func square(rows: Array[Vector4], rounding: float) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array]=[]
	for row: Vector4 in rows:
		var ring := PackedVector3Array()
		for i: int in range(SECTION_POINTS):
			var a: float=TAU*i/SECTION_POINTS
			ring.append(Vector3(row.z*signf(cos(a))*pow(absf(cos(a)),rounding),
				row.y+row.w*signf(sin(a))*pow(absf(sin(a)),rounding),row.x))
		result.append(ring)
	return result


func sample(rows: Array[Vector4], at: float) -> Vector4:
	for i: int in range(1,rows.size()):
		if at<=rows[i].x:
			return rows[i-1].lerp(rows[i],clampf(inverse_lerp(rows[i-1].x,rows[i].x,at),0,1))
	return rows[-1]


func coat(label: String, rings: Array[PackedVector3Array], rows: Array[Vector4], rounding: float, level: Vector2=Vector2.ZERO) -> MeshInstance3D:
	var m:=_loft(label,rings,olive)
	var raw: Array=m.mesh.surface_get_arrays(0)
	var arr:=ArrayMesh.new()
	var verts: PackedVector3Array=raw[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array=raw[Mesh.ARRAY_NORMAL]
	var ix: PackedInt32Array=raw[Mesh.ARRAY_INDEX]
	for top: bool in [true,false]:
		var s:=SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces:=0
		for i: int in range(0,ix.size(),3):
			var p: Vector3=(verts[ix[i]]+verts[ix[i+1]]+verts[ix[i+2]])/3.0
			var cutoff:=level.x+absf(p.x)*level.y
			if not rows.is_empty():
				var row:=sample(rows,p.z)
				cutoff=row.y-row.w*pow(sin(TAU/SECTION_POINTS),rounding)
			if (p.y>=cutoff)!=top:
				continue
			faces+=1
			for j: int in range(3):
				s.set_normal(norms[ix[i+j]])
				s.add_vertex(verts[ix[i+j]])
		if faces>0:
			s.index()
			s.set_material(olive if top else pale)
			s.commit(arr)
	m.mesh=arr
	m.material_override=null
	return m


func surface(rings: Array[PackedVector3Array], u: float, v: float) -> Vector3:
	var r:=mini(floori(u),rings.size()-2)
	var a:=posmod(floori(v),SECTION_POINTS)
	var b: int=(a+1)%SECTION_POINTS
	var p: float=u-r
	var q: float=v-floorf(v)
	var i: PackedVector3Array=rings[r]
	var j: PackedVector3Array=rings[r+1]
	var k: Vector3=i[a]*(1-p)+j[a]*(p-q)+j[b]*q if p>=q else i[a]*(1-q)+j[b]*p+i[b]*(q-p)
	return k+(k-_center(i).lerp(_center(j),p)).normalized()*0.009


func window(label: String,rings: Array[PackedVector3Array],r0: int,r1: int,a0: int,a1: int) -> void:
	var s:=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: int in range(r0,r1):
		for a: int in range(a0,a1):
			var x0:=maxf(r,r0+0.13)
			var x1:=minf(r+1,r1-0.13)
			var y0:=maxf(a,a0+0.14)
			var y1:=minf(a+1,a1-0.14)
			var p:=surface(rings,x0,y0)
			var n:=Vector3(p.x,p.y-_center(rings[r]).y,0)
			quad(s,p,surface(rings,x1,y0),surface(rings,x1,y1),surface(rings,x0,y1),n)
	s.generate_normals()
	_mesh(label,s.commit(),glass)


func build_wings() -> void:
	var wing: Array[Vector4]=[
		Vector4(0.12,-4.01,0.15,0.454),Vector4(1.15,-3.97,0.08,0.448),
		Vector4(3.47,-3.82,-0.12,0.42),Vector4(5.86,-3.68,-0.35,0.368),
		Vector4(8.08,-3.52,-0.52,0.32),Vector4(10.48,-3.38,-0.74,0.27),
		Vector4(12.68,-3.24,-0.94,0.22),Vector4(14.72,-3.10,-1.16,0.163),
		Vector4(15.89,-2.96,-1.30,0.10),Vector4(16.40,-2.85,-1.49,0.064),
		Vector4(16.68,-2.65,-1.72,0.032),Vector4(HALF_SPAN,-2.42,-2.05,0.012)]
	for side: float in [-1,1]:
		coat("Port wing" if side<0 else "Starboard wing",_span_rings(wing,side,0.94,0.042),[],1,Vector2(0.94,0.042))
		line_on_wing(wing,side,8.45,15.91,0.81,0.94,0.042)
		line_on_wing(wing,side,1.32,8.24,0.80,0.94,0.042)
	surface_mark(Vector3(-13.1,0,-2.22),wing,0.82)


func build_tail() -> void:
	var tail: Array[Vector4]=[Vector4(0.06,6.76,9.12,0.16),Vector4(1.30,6.77,9.12,0.147),
		Vector4(2.80,6.78,9.12,0.126),Vector4(3.46,6.79,9.09,0.096),
		Vector4(3.86,7.57,8.88,0.075),Vector4(3.94,7.82,8.57,0.037)]
	var fin: Array[Vector4]=[Vector4(-0.49,7.94,8.17,0.022),Vector4(-0.42,7.49,8.53,0.054),
		Vector4(-0.27,7.16,8.86,0.079),Vector4(-0.02,6.96,9.06,0.094),
		Vector4(0.30,6.81,9.27,0.104),Vector4(0.72,6.74,9.35,0.112),
		Vector4(1.14,6.72,9.38,0.116),Vector4(1.62,6.71,9.37,0.108),
		Vector4(2.02,6.76,9.30,0.10),Vector4(2.36,6.88,9.16,0.081),
		Vector4(2.63,7.08,8.98,0.065),Vector4(2.84,7.33,8.79,0.044),
		Vector4(2.98,7.64,8.50,0.030),Vector4(3.024,7.91,8.25,0.013)]
	for side: float in [-1,1]:
		coat("Horizontal tail",_span_rings(tail,side,0.84,0.014),[],1,Vector2(0.84,0.014))
		line_on_wing(tail,side,0.55,3.63,0.69,0.84,0.014)
		var rows: Array[PackedVector3Array]=[]
		for row: Vector4 in fin:
			var rim:=PackedVector3Array()
			for i: int in range(SECTION_POINTS):
				var a: float=TAU*i/SECTION_POINTS
				rim.append(Vector3(side*(3.851+(row.x-1.18)*0.014)+sin(a)*row.w,row.x,lerpf(row.y,row.z,0.5+cos(a)*0.5)))
			rows.append(rim)
		_loft("Port fin" if side<0 else "Starboard fin",rows,olive)
		var s:=SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ix: int=5 if side>0 else SECTION_POINTS-5
		for i: int in range(1,rows.size()-2):
			var p:=rows[i][ix]+Vector3(side*0.008,0,0)
			var q:=rows[i+1][ix]+Vector3(side*0.008,0,0)
			quad(s,p,q,q+Vector3(0,0,0.019),p+Vector3(0,0,0.019),Vector3(side,0,0))
		s.generate_normals()
		_mesh("Fin hinge visual",s.commit(),frame)


func engine(at: Vector3) -> void:
	var rows: Array[Vector4]=[
		Vector4(-0.18,0,0.635,0.64),Vector4(-0.10,0,0.71,0.73),Vector4(0.15,-0.01,0.765,0.77),
		Vector4(0.50,-0.02,0.785,0.78),Vector4(1.05,-0.04,0.789,0.782),
		Vector4(1.40,-0.055,0.774,0.78),Vector4(1.80,-0.04,0.70,0.71),
		Vector4(2.24,0.035,0.56,0.57),Vector4(2.72,0.135,0.34,0.36),
		Vector4(3.04,0.28,0.17,0.16),Vector4(3.24,0.36,0.055,0.084)]
	coat("Engine nacelle",square(rows,0.83),rows,0.83).position=at
	var ring: Array[Vector4]=[Vector4(-0.195,0,0.627,0.633),Vector4(-0.173,0,0.665,0.67),Vector4(-0.098,0,0.716,0.735)]
	_loft("Rounded cowling lip",_body_rings(ring),frame,false).position=at
	var aperture: Array[Vector4]=[Vector4(-0.196,0,0.614,0.618),Vector4(-0.178,0,0.639,0.643)]
	_loft("Recessed cowl face",_body_rings(aperture),dark).position=at
	var collar: Array[Vector4]=[Vector4(1.072,-0.039,0.790,0.786),Vector4(1.105,-0.040,0.796,0.790)]
	_loft("Cowl lap seam",square(collar,0.83),frame,false).position=at
	var hub: Array[Vector4]=[Vector4(-0.54,0,0.046,0.046),Vector4(-0.46,0,0.145,0.145),Vector4(-0.34,0,0.206,0.206),Vector4(-0.22,0,0.20,0.20)]
	_loft("Propeller hub",_body_rings(hub),pale).position=at
	var strip: Array[Vector4]=[Vector4(0.12,-0.048,0.047,0.030),Vector4(0.47,-0.09,0.114,0.034),
		Vector4(1.13,-0.13,0.137,0.022),Vector4(1.56,-0.147,0.049,0.014),Vector4(1.67,-0.119,0.025,0.011)]
	for n: int in range(3):
		var phi: float=0.23+TAU*n/3.0
		blade("Propeller blade",strip,at+Vector3(0,0,-0.36),phi,dark)
		blade("Propeller tip",[strip[-1],Vector4(1.742,-0.081,-0.012,0.008)],at+Vector3(0,0,-0.36),phi,amber)


func blade(label: String, rows: Array[Vector4], origin: Vector3, phi: float, mat: Material) -> void:
	var rings: Array[PackedVector3Array]=[]
	for row: Vector4 in rows:
		var ring:=PackedVector3Array()
		for i: int in range(SECTION_POINTS):
			var a: float=TAU*i/SECTION_POINTS
			ring.append(Vector3(lerpf(row.y,row.z,0.5+cos(a)*0.5),row.x,row.w*sin(a)))
		rings.append(ring)
	var part:=_loft(label,rings,mat)
	part.position=origin
	part.rotation.z=phi


func wing_top(rows: Array[Vector4],x: float,z: float,base: float,rise: float,lift: float) -> Vector3:
	var row:=sample(rows,absf(x))
	var t:=clampf(inverse_lerp(row.y,row.z,z),0,1)
	return Vector3(x,base+absf(x)*rise+row.w*sin(acos(2*t-1))*(1.05-0.30*t)+lift,z)


func line_on_wing(rows: Array[Vector4],side: float,x0: float,x1: float,f: float,base: float,rise: float) -> void:
	var s:=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(16):
		var a:=lerpf(x0,x1,i/16.0)
		var b:=lerpf(x0,x1,(i+1)/16.0)
		var r:=sample(rows,a)
		var t:=sample(rows,b)
		var z0:=lerpf(r.y,r.z,f)
		var z1:=lerpf(t.y,t.z,f)
		quad(s,wing_top(rows,side*a,z0,base,rise,0.009),wing_top(rows,side*b,z1,base,rise,0.009),
			wing_top(rows,side*b,z1+0.016,base,rise,0.009),wing_top(rows,side*a,z0+0.016,base,rise,0.009),Vector3.UP)
	s.generate_normals()
	_mesh("Control hinge visual",s.commit(),frame)


func surface_mark(at: Vector3,rows: Array[Vector4],r: float) -> void:
	for star: bool in [false,true]:
		var s:=SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps: int=10 if star else 40
		var lift: float=0.026 if star else 0.017
		for i: int in range(steps):
			var p:=mark_step(i,steps,r,star)
			var q:=mark_step(i+1,steps,r,star)
			_triangle(s,wing_top(rows,at.x,at.z,0.94,0.042,lift),
				wing_top(rows,at.x+p.x,at.z-p.y,0.94,0.042,lift),
				wing_top(rows,at.x+q.x,at.z-q.y,0.94,0.042,lift),Vector3.UP)
		s.generate_normals()
		_mesh("Wing white star" if star else "Wing blue roundel",s.commit(),white if star else blue)


func mark_step(i: int,n: int,r: float,star: bool) -> Vector2:
	var radius: float=r*(0.34 if star and i%2==1 else (0.87 if star else 1.0))
	return Vector2(sin(TAU*i/n),cos(TAU*i/n))*radius


func body_mark(side: float) -> void:
	for star: bool in [false,true]:
		var s:=SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps: int=10 if star else 40
		var at:=Vector3(side*(1.031 if star else 1.021),0.095,3.59)
		var outward:=Vector3(side,0,0.064).normalized()
		var toward:=Vector3(-side*0.064,0,1).normalized()
		for i: int in range(steps):
			var p:=mark_step(i,steps,0.61,star)
			var q:=mark_step(i+1,steps,0.61,star)
			_triangle(s,at,at+Vector3.UP*p.y+toward*p.x,at+Vector3.UP*q.y+toward*q.x,outward)
		s.generate_normals()
		_mesh("Fuselage white star" if star else "Fuselage blue roundel",s.commit(),white if star else blue)


func box(label: String,at: Vector3,extent: Vector3,mat: Material) -> MeshInstance3D:
	var shape:=BoxMesh.new()
	shape.size=extent
	var node:=_mesh(label,shape,mat)
	node.position=at
	return node


func quad(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,n: Vector3) -> void:
	_triangle(s,a,b,c,n)
	_triangle(s,a,c,d,n)


func _mesh(label: String,shape: Mesh,mat: Material) -> MeshInstance3D:
	var count: int=int(counts.get(label,0))+1
	counts[label]=count
	return super._mesh(label if count==1 else "%s %d" % [label,count],shape,mat)
