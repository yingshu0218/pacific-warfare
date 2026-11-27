extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## Reusable static visual primitives. No moving or physical components.

func _draw_section(row: Vector4, side: float, rake_m: float, tuck_m: float) -> PackedVector3Array:
	var pts: PackedVector3Array = super._section(row,side)
	var z_ratio: float = absf(row.x)/_half_length()
	var end: float = smoothstep(0.72,1.0,z_ratio)
	for step: int in range(pts.size()-1):
		var p: Vector3 = pts[step]
		p.z += end*(rake_m if row.x < 0 else -tuck_m)*(1.0-float(step)/5.0)
		if step==4:
			p.x *= 1.0-0.14*end
		pts[step]=p
	return pts


func _gallery(label: String,p: Vector3,w: float,h: float,l: float,mat: Material) -> void:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 20
	for i: int in range(n):
		var a: float = TAU*float(i)/float(n)
		var b: float = TAU*float(i+1)/float(n)
		var aa := Vector3(cos(a)*w*0.5,0,sin(a)*l*0.5)
		var bb := Vector3(cos(b)*w*0.5,0,sin(b)*l*0.5)
		_quad(s,aa-Vector3.UP*h*0.5,bb-Vector3.UP*h*0.5,bb+Vector3.UP*h*0.5,aa+Vector3.UP*h*0.5,aa+bb)
		_tri(s,Vector3.UP*h*0.5,aa+Vector3.UP*h*0.5,bb+Vector3.UP*h*0.5,Vector3.UP)
		_tri(s,-Vector3.UP*h*0.5,aa-Vector3.UP*h*0.5,bb-Vector3.UP*h*0.5,-Vector3.UP)
	_commit(label,s,mat)
	(_group.get_child(-1) as Node3D).position = p


func _windows_face(p: Vector3, count: int, gap: float, pane: float, y: float) -> void:
	for i: int in range(count):
		var x: float = (float(i)-float(count-1)*0.5)*gap
		_box("Observation window inset",p+Vector3(x,0,0),Vector3(pane,y,0.07),_dark)


func _mast_silhouette(z: float,foot: float,top: float,yard: float,spread: float) -> void:
	_spar("Mast upright",Vector3(0,foot,z),Vector3(0,top,z+0.73),0.26,_steel)
	_spar("Primary cross-yard",Vector3(-yard,top-5.20,z+0.66),Vector3(yard,top-5.20,z+0.66),0.101,_dark)
	_spar("Upper cross-yard",Vector3(-yard*0.49,top-2.53,z+0.69),Vector3(yard*0.49,top-2.53,z+0.69),0.082,_dark)
	for side: float in [-1.0,1.0]:
		_spar("Mast diagonal support",Vector3(side*spread,foot,z+1.62),Vector3(0,top-9.08,z+0.50),0.188,_steel)
		_spar("Thin halyard",Vector3(side*yard*0.84,top-5.20,z+0.61),Vector3(side*spread*0.78,foot+2.2,z-0.59),0.039,_dark)
	var aerial := Vector3(0,top-1.23,z+0.73)
	_lattice(aerial,yard*0.70,1.20)


func _lattice(p: Vector3,w: float,h: float) -> void:
	for y: float in [-0.46,0.0,0.46]:
		_spar("Period grille visual bar",p+Vector3(-w*0.49,y*h,0),p+Vector3(w*0.49,y*h,0),0.067,_steel)
	for k: int in range(7):
		var x: float = lerpf(-w*0.49,w*0.49,float(k)/6.0)
		_spar("Period grille visual upright",p+Vector3(x,-h*0.50,0),p+Vector3(x,h*0.50,0),0.059,_steel)


func _photo_case(z: float,x: float,y: float,w: float,l: float,h: float,raised: float,bars: int,direction: Vector3) -> void:
	var c := Vector3(x,y,z)
	_pipe("Display housing base",c+Vector3.UP*raised*0.5,raised,w*0.40,w*0.38,1.0,_steel)
	c.y += raised
	if raised>2.1:
		_octagon("Outer plinth",c-Vector3.UP*(raised-0.45),w*1.02,1.04,l*0.96,w*0.145,_steel,0.95)
	var side := Vector3(direction.z,0,-direction.x)
	var sh := GCase.new()
	sh.center = c+Vector3.UP*h*0.47
	sh.width = w
	sh.length = l
	sh.height = h
	sh.front = direction
	_case_shape(sh)
	for k: int in range(bars):
		var lane: float = (float(k)-(float(bars)-1.0)*0.5)*w*0.15
		var a: Vector3 = c+Vector3.UP*h*0.53+side*lane
		_spar("Inert exterior outline strip",a+direction*l*0.40,a+direction*l*0.99+Vector3.UP*h*0.13,w*0.028,_dark)
	for sign: float in [-1,1]:
		_spar("Casing edge relief",sh.center+side*w*0.39*sign+direction*l*0.28,sh.center+side*w*0.39*sign-direction*l*0.28,w*0.016,_steel)


class GCase:
	var center: Vector3
	var width: float
	var length: float
	var height: float
	var front: Vector3


func _case_shape(c: GCase) -> void:
	var geom := SurfaceTool.new()
	geom.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front: Vector3 = c.front
	var side := Vector3(front.z,0,-front.x)
	var contour := PackedVector2Array([Vector2(-0.32,-0.5),Vector2(0.32,-0.5),Vector2(0.50,-0.28),
		Vector2(0.50,0.29),Vector2(0.31,0.50),Vector2(-0.31,0.50),Vector2(-0.50,0.29),Vector2(-0.50,-0.28)])
	for i: int in range(contour.size()):
		var a: Vector2 = contour[i]
		var b: Vector2 = contour[(i+1)%contour.size()]
		var v: Vector3 = side*a.x*c.width+front*a.y*c.length
		var q: Vector3 = side*b.x*c.width+front*b.y*c.length
		_quad(geom,c.center+v-Vector3.UP*c.height*0.50,c.center+q-Vector3.UP*c.height*0.50,
			c.center+q*0.82+Vector3.UP*c.height*0.50,c.center+v*0.82+Vector3.UP*c.height*0.50,v+q)
		_tri(geom,c.center+Vector3.UP*c.height*0.50,c.center+v*0.82+Vector3.UP*c.height*0.50,c.center+q*0.82+Vector3.UP*c.height*0.50,Vector3.UP)
		_tri(geom,c.center-Vector3.UP*c.height*0.50,c.center+v-Vector3.UP*c.height*0.50,c.center+q-Vector3.UP*c.height*0.50,Vector3.DOWN)
	_commit("Dated static casing silhouette",geom,_upper)


func _weather_rails(height: float,space: float) -> void:
	var rows: Array[Vector4] = _stations()
	for side: float in [-1.0,1.0]:
		for i: int in range(2,rows.size()-2):
			var a: Vector4 = rows[i]
			var b: Vector4 = rows[i+1]
			var p := Vector3(side*(a.y-0.21),a.z,a.x)
			var q := Vector3(side*(b.y-0.21),b.z,b.x)
			for ratio: float in [0.43,1.0]:
				_spar("Weather deck rail",p+Vector3.UP*height*ratio,q+Vector3.UP*height*ratio,0.083,_upper)
			var count: int = ceili(p.distance_to(q)/space)
			for j: int in range(count):
				var foot: Vector3 = p.lerp(q,float(j)/float(count))
				_spar("Rail stanchion",foot,foot+Vector3.UP*height,0.076,_steel)


func _duty_boat(p: Vector3,side: float,scale: float) -> void:
	_octagon("Launch lower seat",p,2.27*scale,0.58*scale,6.05*scale,0.51*scale,_dark)
	_octagon("Launch body",p+Vector3.UP*0.69*scale,2.25*scale,0.82*scale,6.64*scale,0.72*scale,_upper,0.90)
	_octagon("Launch canvas",p+Vector3.UP*1.15*scale,1.45*scale,0.104*scale,5.31*scale,0.55*scale,_deck)
	for z: float in [-1.98,1.98]:
		_spar("Inert launch davit",p+Vector3(-side*0.65,-0.32,z)*scale,p+Vector3(side*0.75,1.76,z+0.23)*scale,0.17*scale,_steel)


func _hawse_relief(z: float,x: float,y: float,extent: float) -> void:
	for side: float in [-1.0,1.0]:
		var p := Vector3(side*x,y,z)
		_octagon("Hawse relief",p,0.45,0.92*extent,1.40*extent,0.18,_upper)
		var q: Vector3 = p+Vector3(side*0.28,-0.87*extent,0)
		_spar("Anchor relief",p+Vector3(side*0.27,0.42*extent,0),q,0.16*extent,_dark)
		for along: float in [-1.0,1.0]:
			_spar("Anchor point relief",q,q+Vector3(0,0.47*extent,along*0.57*extent),0.135*extent,_dark)


func _underbody_shapes(positions: PackedVector3Array,rudder_z: float,scale: float) -> void:
	_octagon("Inert stern steering outline",Vector3(0,-2.1*scale,rudder_z),0.51*scale,4.1*scale,3.7*scale,0.19*scale,_underbody,0.84)
	for p: Vector3 in positions:
		_spar("Underbody exterior stay",Vector3(p.x*0.77,p.y*0.60,p.z-5.71*scale),p,0.26*scale,_underbody)
		var hub := _pipe("Inert underwater hub",p,0.73*scale,0.27*scale,0.25*scale,1.0,_underbody)
		hub.rotation.x = PI/2
		for j: int in range(3):
			var a: float = TAU*float(j)/3.0
			var dir := Vector3(cos(a),sin(a),0)
			_spar("Underwater silhouette relief",p+dir*0.13*scale,p+dir*1.08*scale,0.24*scale,_underbody)
