extends Node3D
## Shared art helpers. Metres; +X starboard and -Z forward.
## This library does not expose flight, weapons or combat interfaces.
const GEO: Script = preload("res://aircraft/b25j/geometry.gd")
var paint: Dictionary = {}

func _set_paint(top: Color, bottom: Color) -> void:
	paint.skin=GEO.material(Color.WHITE)
	paint.skin.vertex_color_use_as_albedo=true
	paint.top=GEO.material(top)
	paint.bottom=GEO.material(bottom)
	paint.glass=GEO.material(Color("304850"),0.12)
	paint.glass.roughness=0.23
	paint.frame=GEO.material(top.darkened(.12))
	paint.dark=GEO.material(Color("202729"))
	paint.seam=GEO.material(top.darkened(.23))
	paint.metal=GEO.material(Color("929a96"),0.36)
	paint.yellow=GEO.material(Color("caaf42"))
	paint.white=GEO.material(Color("e0ded2"))
	paint.navy=GEO.material(Color("21374d"))
	paint.red=GEO.material(Color("863d35"))
	paint.nav_green=GEO.material(Color("326f5d"))

func _body(host: Node3D, id: String, profile: Array, at: Vector3=Vector3.ZERO, cap: bool=true) -> void:
	GEO.part(host,id,GEO.loft(profile,profile[0][0],profile[-1][0],paint.top.albedo_color,paint.bottom.albedo_color,Vector4.ZERO,cap),paint.skin,at)

func _wing(host: Node3D,id: String, profile: Array,side: float,at: Vector3=Vector3.ZERO) -> void:
	GEO.part(host,id,GEO.wing(profile,side,profile[0][0],profile[-1][0],0.,1.,Vector3.ZERO,paint.top.albedo_color,paint.bottom.albedo_color),paint.skin,at)

func _ellipsoid(host: Node3D,id: String,shape: Vector3,at: Vector3,mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius=1.;mesh.height=2.;mesh.radial_segments=24;mesh.rings=12
	GEO.part(host,id,mesh,mat,at).scale=shape

func _plate(host: Node3D,id: String,rows: Array,thickness: float,mat: Material,at: Vector3=Vector3.ZERO) -> void:
	var outline := PackedVector2Array()
	for row: Array in rows: outline.append(Vector2(row[0],row[1]))
	GEO.plate(host,id,outline,thickness,mat).position=at

func _fin(host: Node3D,id: String,rows: Array,at: Vector3=Vector3.ZERO,red_tip: bool=false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := SurfaceTool.new()
	tip.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(rows.size()-1):
		var surface: SurfaceTool=tip if red_tip and float(rows[i][0])>=1.79 else st
		for j: int in range(30):
			var a: float=TAU*j/30.0;var b: float=TAU*(j+1)/30.0
			var p: Array=rows[i];var q: Array=rows[i+1]
			var va:=_fin_point(p,a);var vb:=_fin_point(q,a)
			var vc:=_fin_point(q,b);var vd:=_fin_point(p,b)
			GEO.quad(surface,va,vb,vc,vd,Vector3(sin((a+b)*.5),0,cos((a+b)*.5)))
	for i: int in [0,rows.size()-1]:
		var row: Array=rows[i]
		for j: int in 30:
			GEO.triangle(tip if red_tip and i>0 else st,Vector3(0,row[0],(row[1]+row[2])*.5),_fin_point(row,TAU*j/30.),_fin_point(row,TAU*(j+1)/30.),Vector3.DOWN if i==0 else Vector3.UP)
	GEO.part(host,id,GEO.finish(st),paint.top,at)
	if red_tip: GEO.part(host,"PaintedFinTip",GEO.finish(tip),paint.red,at)

func _fin_point(row: Array,a: float) -> Vector3:
	return Vector3(row[3]*sin(a),row[0],lerpf(row[1],row[2],.5+.5*cos(a)))

func _canopy(host: Node3D,profile: Array) -> void:
	GEO.part(host,"CanopyGlass",GEO.loft(profile,profile[0][0],profile[-1][0],Color.WHITE,Color.WHITE),paint.glass)
	for i: int in range(1,profile.size()-1):
		if i%2==1:
			GEO.arch(host,"CanopyBow",profile,profile[i][0],.036,paint.frame,-PI*.51,PI*.51)
	for side: float in [-1.,1.]:
		for j: int in range(profile.size()-1):
			var a: Vector3=GEO.shell_point(profile,profile[j][0],side*PI*.43)
			var b: Vector3=GEO.shell_point(profile,profile[j+1][0],side*PI*.43)
			GEO.rod(host,"CanopyLowerRail",a,b,.016,paint.frame)

func _prop(host: Node3D,at: Vector3,radius: float,spinner: Vector3,phase: float,clockwise: float,mat: Material) -> void:
	var prop: Node3D=GEO.group(host,"Propeller",at)
	_ellipsoid(prop,"Spinner",spinner,Vector3(0,0,-spinner.z*.32),mat)
	for i: int in 3:
		var blade: Node3D=GEO.group(prop,"Blade_%d"%i)
		blade.rotation.z=phase+TAU*i/3.
		var flat: Node3D=GEO.group(blade,"BladePlane")
		flat.rotation.y=PI*.5
		var w: float=radius*.083*clockwise
		_plate(flat,"BladeSkin",[[.18,-w*.34],[radius*.34,-w],[radius*.70,-w*1.14],[radius*.92,-w*.80],[radius,-w*.20],[radius*.98,w*.39],[radius*.72,w*.90],[radius*.31,w*.63],[.18,w*.25]],.047,paint.dark)
		_plate(flat,"TipPaint",[[radius*.912,-w*.80],[radius*.92,-w*.80],[radius,-w*.20],[radius*.98,w*.39],[radius*.912,w*.58]],.049,paint.yellow)

func _projection(kind: String,profile: Array,point: Vector2,side: float,layer: float) -> Vector3:
	if kind=="wing":
		var r: Array=GEO.sample(profile,absf(point.x))
		var p: Vector3=GEO.wing_point(profile,absf(point.x),clampf((point.y-r[1])/r[2],0.,1.),side>0.)
		p.x=point.x;p.y+=side*layer
		return p
	var row: Array=GEO.sample(profile,point.x)
	var dy: float=point.y-row[1]
	var h: float=row[3] if dy>=0. else row[4]
	return Vector3(side*(row[2]*sqrt(maxf(0.,1.-pow(dy/h,2)))+layer),point.y,point.x)

func _decal(host: Node3D,id: String,kind: String,profile: Array,shape: Array[Vector2],side: float,layer: float,material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: PackedInt32Array=Geometry2D.triangulate_polygon(PackedVector2Array(shape))
	var outward:=Vector3.UP*side if kind=="wing" else Vector3.RIGHT*side
	for i: int in range(0,indices.size(),3):
		_patch_triangle(st,kind,profile,shape[indices[i]],shape[indices[i+1]],shape[indices[i+2]],side,layer,outward,3)
	if not indices.is_empty():GEO.part(host,id,GEO.finish(st),material)

func _patch_triangle(st: SurfaceTool,kind: String,p: Array,a: Vector2,b: Vector2,c: Vector2,side: float,layer: float,n: Vector3,level: int) -> void:
	if level<=0:
		GEO.triangle(st,_projection(kind,p,a,side,layer),_projection(kind,p,b,side,layer),_projection(kind,p,c,side,layer),n)
		return
	var ab: Vector2=(a+b)*.5;var ac: Vector2=(a+c)*.5;var bc: Vector2=(b+c)*.5
	_patch_triangle(st,kind,p,a,ab,ac,side,layer,n,level-1)
	_patch_triangle(st,kind,p,ab,b,bc,side,layer,n,level-1)
	_patch_triangle(st,kind,p,ac,bc,c,side,layer,n,level-1)
	_patch_triangle(st,kind,p,ab,bc,ac,side,layer,n,level-1)

func _quad2(center: Vector2,w: float,h: float) -> Array[Vector2]:
	return [center+Vector2(-w,-h)*.5,center+Vector2(w,-h)*.5,center+Vector2(w,h)*.5,center+Vector2(-w,h)*.5]

func _star_bar(host: Node3D,kind: String,profile: Array,center: Vector2,radius: float,side: float) -> void:
	var offset: float=.022 if kind=="body" else .016
	var star: Array[Vector2]=[]
	var disc: Array[Vector2]=[]
	for i: int in 30:
		var a: float=TAU*i/30.
		disc.append(center+Vector2(cos(a),sin(a))*radius)
	for i: int in 10:
		var a: float=TAU*i/10.+(PI*.5 if kind=="body" else -PI*.5)
		star.append(center+Vector2(cos(a),sin(a))*radius*(.92 if i%2==0 else .37))
	_decal(host,"InsigniaDisc",kind,profile,disc,side,offset+.006,paint.navy)
	_decal(host,"InsigniaBorder",kind,profile,_quad2(center,radius*4.08,radius*.60),side,offset,paint.navy)
	_decal(host,"InsigniaBars",kind,profile,_quad2(center,radius*3.90,radius*.42),side,offset+.003,paint.white)
	_decal(host,"InsigniaStar",kind,profile,star,side,offset+.012,paint.white)

func _wing_seam(host: Node3D,p: Array, side: float,span: float) -> void:
	for i: int in 10:
		var a: Vector3=GEO.wing_point(p,span,.09+.82*i/10.,true)
		var b: Vector3=GEO.wing_point(p,span,.09+.82*(i+1)/10.,true)
		a.x*=side;b.x*=side
		var seam: MeshInstance3D=GEO.box(host,"SheetJoin",Vector3(.014,.010,a.distance_to(b)),(a+b)*.5+Vector3.UP*.009,paint.seam)
		seam.basis=Basis.looking_at((b-a).normalized(),Vector3.UP)

func _encode_number(host: Node3D,p: Array,center: Vector2,half: float,side: float,code: String) -> void:
	const SEG: Dictionary={"2":[0,1,3,4,6],"9":[0,1,2,3,5,6]}
	var rows: Array=[[0,1,1.04,.12],[.52,.5,.13,.88],[-.52,.5,.13,.88],[0,0,1.04,.12],[-.52,-.5,.13,.88],[.52,-.5,.13,.88],[0,-1,1.04,.12]]
	# Left-to-right depends which side is being viewed.
	var sign_h: float=-1. if side>0. else 1.
	for j: int in code.length():
		for part: int in SEG[code[j]]:
			var r: Array=rows[part]
			var at: Vector2=center+Vector2((r[0]+(j-.5)*1.55)*half*sign_h,r[1]*half)
			_decal(host,"CodeStroke","body",p,_quad2(at,r[2]*half,r[3]*half),side,.021,paint.white)
