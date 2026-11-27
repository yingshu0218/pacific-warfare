extends Node3D
## CL-55 detached exterior exhibit. y=0 is the waterline; bow is -Z.
## Equipment shapes are inert game props, not construction or simulation resources.

const HALF_LENGTH: float = 92.9767
const HALF_BEAM: float = 10.1346
const DRAFT: float = 6.096

# Rows: longitudinal position, half-width at main deck, deck height, half-width at water.
const STATIONS: Array[Vector4] = [
	Vector4(-HALF_LENGTH,0.02,8.30,0.02), Vector4(-91,1.32,8.20,0.46),
	Vector4(-87,3.08,8.02,1.66), Vector4(-81,4.79,7.82,3.18),
	Vector4(-73,6.35,7.53,5.02), Vector4(-62,7.76,7.18,6.83),
	Vector4(-51,8.89,6.94,8.12), Vector4(-39,9.70,6.74,9.10),
	Vector4(-26,10.06,6.57,9.75), Vector4(-11,HALF_BEAM,6.48,9.91),
	Vector4(6,HALF_BEAM,6.42,9.92), Vector4(24,9.99,6.38,9.62),
	Vector4(40,9.53,6.37,9.01), Vector4(54,8.81,6.35,8.22),
	Vector4(66,7.84,6.34,7.13), Vector4(76,6.73,6.36,5.86),
	Vector4(84,5.38,6.43,4.48), Vector4(89,3.90,6.50,3.04),
	Vector4(92,2.45,6.57,1.75), Vector4(HALF_LENGTH,1.25,6.59,0.70),
]
var _steel: StandardMaterial3D
var _deck: StandardMaterial3D
var _upper: StandardMaterial3D
var _dark: StandardMaterial3D
var _hull_side: StandardMaterial3D
var _underbody: StandardMaterial3D
var _group: Node3D


func _ready() -> void:
	_steel = _paint("88979e")
	_deck = _paint("54656c")
	_upper = _paint("a4acac")
	_dark = _paint("29363e")
	_hull_side = _paint("536c7c")
	_underbody = _paint("744646")
	_group = _layer("Hull and deck")
	_hull()
	_group = _layer("Bridge and deckhouses")
	_deckhouses()
	_group = _layer("Funnels and masts")
	_funnels_and_masts()
	_group = _layer("Static exterior silhouettes")
	_fittings()
	_group = _layer("Deck furniture and railings")
	_details()
	_group = _layer("Underwater fittings")
	_underwater_fittings()


func _paint(hex: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.76
	return mat


func _layer(label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	add_child(node)
	return node


func _instance(label: String, shape: Mesh, material: Material, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = shape
	node.material_override = material
	node.position = position
	_group.add_child(node, true)
	return node


func _hull() -> void:
	# Work through the drawn outer silhouette, from keel to deck (no internal geometry).
	var below := SurfaceTool.new()
	var stripe := SurfaceTool.new()
	var sides := SurfaceTool.new()
	var deck := SurfaceTool.new()
	for surface: SurfaceTool in [below, stripe, sides, deck]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(STATIONS.size() - 1):
		var a: Vector4 = STATIONS[i]; var b: Vector4 = STATIONS[i + 1]
		for direction: float in [-1.0, 1.0]:
			var rail_a: PackedVector3Array = _section(a,direction); var rail_b: PackedVector3Array = _section(b,direction)
			var outward := Vector3(direction,0,0)
			for ring: int in range(rail_a.size() - 1):
				var surface: SurfaceTool = below if ring < 2 else (stripe if ring == 2 else sides)
				_quad(surface,rail_a[ring],rail_b[ring],rail_b[ring+1],rail_a[ring+1],outward)
		_quad(deck,Vector3(-a.y,a.z,a.x),Vector3(a.y,a.z,a.x),Vector3(b.y,b.z,b.x),Vector3(-b.y,b.z,b.x),Vector3.UP)
		var bottom_a := _section(a,1)[0]; var bottom_b := _section(b,1)[0]
		_quad(below,Vector3(-bottom_a.x,bottom_a.y,bottom_a.z),bottom_a,bottom_b,Vector3(-bottom_b.x,bottom_b.y,bottom_b.z),Vector3.DOWN)
	for end: int in [0,STATIONS.size()-1]:
		var left: PackedVector3Array = _section(STATIONS[end],-1); var right: PackedVector3Array = _section(STATIONS[end],1)
		for ring: int in range(left.size()-1):
			var surface: SurfaceTool = below if ring < 2 else (stripe if ring == 2 else sides)
			_quad(surface,left[ring],right[ring],right[ring+1],left[ring+1],Vector3.FORWARD if end == 0 else Vector3.BACK)
	_commit("Keel and underwater hull",below,_underbody)
	_commit("Boot stripe",stripe,_dark)
	_commit("Hull plating",sides,_hull_side)
	_commit("Continuous weather deck",deck,_deck)


func _section(row: Vector4, side: float) -> PackedVector3Array:
	var fullness: float = smoothstep(0.0,48.0,HALF_LENGTH-absf(row.x))
	var keel: float = lerpf(-0.65,-DRAFT,fullness)
	return PackedVector3Array([
		Vector3(side * row.w * 0.28,keel,row.x),
		Vector3(side * row.w * 0.82,keel * 0.65,row.x),
		Vector3(side * row.w * 0.98,-0.30,row.x),
		Vector3(side * lerpf(row.w,row.y,0.08),0.40,row.x),
		Vector3(side * lerpf(row.w,row.y,0.49),row.z*0.54,row.x),
		Vector3(side * row.y,row.z,row.x),
	])


func _tri(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,out: Vector3) -> void:
	s.add_vertex(a)
	if (b-a).cross(c-a).dot(out) > 0.0:
		s.add_vertex(c); s.add_vertex(b)
	else:
		s.add_vertex(b); s.add_vertex(c)


func _quad(s: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,out: Vector3) -> void:
	_tri(s,a,b,c,out); _tri(s,a,c,d,out)


func _commit(label: String, surface: SurfaceTool, material: Material) -> void:
	surface.index()
	surface.generate_normals()
	_instance(label,surface.commit(),material)


func _box(label: String, p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _instance(label,shape,material,p)


func _octagon(label: String, p: Vector3, width: float, height: float, length: float, cut: float, material: Material, taper: float = 1.0) -> void:
	var x: float = width*0.5
	var z: float = length*0.5
	var path := PackedVector2Array([
		Vector2(-x+cut,-z),Vector2(x-cut,-z),Vector2(x,-z+cut),Vector2(x,z-cut),
		Vector2(x-cut,z),Vector2(-x+cut,z),Vector2(-x,z-cut),Vector2(-x,-z+cut),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i: int in range(path.size()):
		var a: Vector2 = path[i]; var b: Vector2 = path[(i+1)%path.size()]
		var low_a := Vector3(a.x,-height*0.5,a.y)
		var low_b := Vector3(b.x,-height*0.5,b.y)
		var top_a := Vector3(a.x*taper,height*0.5,a.y*taper)
		var top_b := Vector3(b.x*taper,height*0.5,b.y*taper)
		_quad(surface,low_a,low_b,top_b,top_a,Vector3(a.x+b.x,0,a.y+b.y))
		_tri(surface,Vector3(0,-height*0.5,0),low_a,low_b,Vector3.DOWN)
		_tri(surface,Vector3(0,height*0.5,0),top_a,top_b,Vector3.UP)
	surface.generate_normals()
	_instance(label,surface.commit(),material,p)


func _pipe(label: String, p: Vector3, h: float, lower: float, upper: float, extent_z: float, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.radial_segments = 14
	shape.height = h
	shape.bottom_radius = lower
	shape.top_radius = upper
	var item := _instance(label,shape,material,p)
	item.scale.z = extent_z
	return item


func _spar(label: String, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var diff: Vector3 = b-a
	var item := _box(label,(a+b)*0.5,Vector3(width,width,diff.length()),material)
	item.quaternion = Quaternion(Vector3.BACK,diff.normalized())


func _deckhouses() -> void:
	_octagon("Forward deckhouse",Vector3(0,8.18,-26),14.50,3.15,28,1.80,_steel)
	_octagon("Forward bridge base",Vector3(0,11.13,-32.1),11.20,3.0,12.50,1.65,_steel)
	_octagon("Bridge deck",Vector3(0,12.78,-33),13.1,0.40,11.7,1.75,_deck)
	_octagon("Enclosed bridge",Vector3(0,14.11,-33.9),9.4,2.56,9.3,1.52,_upper)
	_box("Forward window band",Vector3(0,14.58,-38.49),Vector3(6.2,0.64,0.18),_dark)
	for side: float in [-1.0,1.0]:
		_box("Bridge side window band",Vector3(side*4.71,14.57,-33.85),Vector3(0.17,0.58,4.35),_dark)
		for j: int in range(5):
			_box("Bridge mullion",Vector3(j*1.18-2.36,14.60,-38.60),Vector3(0.16,0.73,0.13),_upper)
	_octagon("Bridge roof",Vector3(0,15.54,-33.4),10.0,0.42,9.9,1.65,_upper)
	_octagon("Forward lookout enclosure",Vector3(0,16.89,-32.7),5.30,2.30,5.4,0.8,_steel)
	_octagon("Center deckhouse",Vector3(0,7.9,0),14.75,3.1,25.5,1.35,_steel)
	_octagon("Aft deckhouse",Vector3(0,8.01,30),14.2,3.25,30.0,1.70,_steel)
	_octagon("Aft raised deck",Vector3(0,10.83,32),11.40,2.52,12.65,1.4,_steel)
	_octagon("Aft lookout enclosure",Vector3(0,13.09,32),5.85,1.94,7.2,0.95,_upper)


func _funnels_and_masts() -> void:
	for z: float in [-16.8,9.0]:
		_octagon("Funnel foundation",Vector3(0,10.05,z),7.5,1.3,9.2,1.1,_steel)
		_pipe("Funnel casing",Vector3(0,14.53,z),8.55,2.78,2.30,1.19,_upper)
		_pipe("Funnel cap band",Vector3(0,18.94,z),0.92,2.33,2.28,1.19,_dark)
		_pipe("Funnel lip",Vector3(0,19.41,z),0.22,2.30,2.22,1.19,_steel)
		_pipe("Dark funnel opening",Vector3(0,19.54,z),0.05,1.93,1.93,1.18,_dark)
	for z: float in [-23.1,19.2]:
		var top: float = 33.3 if z < 0 else 31.6
		_pipe("Mast lower",Vector3(0,17.85,z),17.0,0.33,0.21,1.0,_steel)
		_pipe("Mast top",Vector3(0,(top+25.5)*0.5,z),top-25.5,0.20,0.093,1.0,_dark)
		for x: float in [-2.65,2.65]:
			_spar("Mast stay",Vector3(x,10.0,z+1.4),Vector3(0,23.2,z),0.24,_steel)
		_spar("Yardarm",Vector3(-4.55,26.2,z),Vector3(4.55,26.2,z),0.15,_dark)
		_spar("Small yardarm",Vector3(-2.16,29.7,z),Vector3(2.16,29.7,z),0.14,_dark)
		_box("Mast observation platform",Vector3(0,22.7,z),Vector3(2.6,0.33,2.5),_steel)
		_box("Simple mast top silhouette",Vector3(0,top-0.63,z),Vector3(2.4,0.65,0.31),_dark)


func _deck_height(z: float) -> float:
	for i: int in range(STATIONS.size() - 1):
		var a: Vector4 = STATIONS[i]
		var b: Vector4 = STATIONS[i + 1]
		if z <= b.x:
			return lerpf(a.z, b.z, inverse_lerp(a.x, b.x, z))
	return STATIONS[-1].z


func _fittings() -> void:
	for z: float in [-66.0,-51.5,47.0,62.0]:
		var raised: bool = z == -51.5 or z == 47.0
		var y: float = _deck_height(z)
		var mount_h: float = 3.4 if raised else 0.72
		_pipe("Large silhouette seat",Vector3(0,y+mount_h*0.5-0.12,z),mount_h,3.05,2.92,1.0,_steel)
		_octagon("Large enclosed silhouette",Vector3(0,y+mount_h+1.22,z),6.8,2.60,7.7,1.05,_upper,0.90)
		var sign_z: float = -1.0 if z < 0 else 1.0
		for x: float in [-1.38,0.0,1.38]:
			_spar("Inert silhouette spar",Vector3(x,y+mount_h+1.31,z+sign_z*3.34),Vector3(x,y+mount_h+1.67,z+sign_z*8.15),0.29,_dark)
	for z: float in [-39.6,37.8]:
		var y: float = 9.1 if z < 0 else 8.55
		_octagon("Centerline small enclosed silhouette",Vector3(0,y,z),4.5,2.2,4.8,0.70,_upper)
		var sign_z: float = -1.0 if z < 0 else 1.0
		for x: float in [-0.65,0.65]:
			_spar("Small inert silhouette spar",Vector3(x,y,z+sign_z*2.16),Vector3(x,y+0.17,z+sign_z*4.85),0.22,_dark)
	for side: float in [-1.0,1.0]:
		for z: float in [-13.4,17.3]:
			var x: float = side*7.23
			_pipe("Deck platform",Vector3(x,6.95,z),1.10,2.03,1.97,1.0,_steel)
			_octagon("Outboard enclosed silhouette",Vector3(x,8.56,z),4.15,2.24,4.9,0.75,_upper)
			for j: float in [-0.62,0.62]:
				_spar("Outboard inert silhouette spar",Vector3(x+side*1.85,8.65,z+j),Vector3(x+side*4.17,8.92,z+j),0.22,_dark)


func _details() -> void:
	for sign_x: float in [-1.0,1.0]:
		for i: int in range(2,STATIONS.size()-2):
			var a: Vector4 = STATIONS[i]; var b: Vector4 = STATIONS[i+1]
			var pa := Vector3(sign_x*(a.y-0.24),a.z,a.x)
			var pb := Vector3(sign_x*(b.y-0.24),b.z,b.x)
			_spar("Deck rail",pa+Vector3.UP*1.03,pb+Vector3.UP*1.03,0.10,_upper)
			_spar("Lower deck rail",pa+Vector3.UP*0.55,pb+Vector3.UP*0.55,0.07,_steel)
			var sections: int = ceili(pa.distance_to(pb)/3.4)
			for j: int in range(sections):
				var anchor: Vector3 = pa.lerp(pb,float(j)/sections)
				_spar("Rail stanchion",anchor,anchor+Vector3.UP*1.07,0.10,_steel)
		for z: float in [-6.0,2.0]:
			_octagon("Boat cradle",Vector3(sign_x*6.6,9.63,z),2.17,0.33,6.95,0.5,_dark)
			_octagon("Utility launch",Vector3(sign_x*6.6,10.19,z),2.02,0.91,7.08,0.75,_upper)
			_octagon("Launch interior shadow",Vector3(sign_x*6.6,10.69,z),1.47,0.16,5.48,0.53,_dark)
		for z: float in [-81.6,-76.0,74.7,81.8]:
			var x: float = sign_x*(3.00 if z < -80 else 4.55)
			var y: float = _deck_height(z) - 0.03
			_pipe("Mooring bollard",Vector3(x,y+0.39,z),0.8,0.27,0.25,1.0,_dark)
	_octagon("Foredeck windlass cover",Vector3(0,_deck_height(-78.8)+0.38,-78.8),3.9,0.8,3.1,0.6,_steel)
	_octagon("Afterdeck handling platform",Vector3(0,_deck_height(77)+0.665,77),9.5,1.41,8.9,1.45,_steel)
	_box("Afterdeck handling path",Vector3(0,7.89,77),Vector3(7.3,0.15,1.1),_dark)
	_pipe("Afterdeck derrick base",Vector3(-3.24,7.54,80),2,0.56,0.42,1.0,_steel)
	_spar("Afterdeck derrick boom",Vector3(-3.24,8.5,80),Vector3(-3.24,13.2,73.8),0.37,_steel)
	_spar("Stern ensign staff",Vector3(0,6.52,89),Vector3(0,10.5,89),0.10,_upper)

	for x: float in [-4.7, 4.7]:
		_octagon("Aft handling beam support",Vector3(x,7.20,78),0.81,1.65,2.0,0.19,_steel)
		_spar("Aft static handling beam",Vector3(x,8.05,73.5),Vector3(x,8.05,83.2),0.31,_steel)
	var vents: Array[Vector3] = [Vector3(-3.8,9.5,-1.6),Vector3(3.8,9.5,-1.6),Vector3(-3.9,9.65,29),Vector3(3.9,9.65,29)]
	for p: Vector3 in vents:
		_pipe("Deck ventilator",p+Vector3.UP*0.43,0.94,0.55,0.51,1.0,_steel)
		_pipe("Deck ventilator cover",p+Vector3.UP*0.93,0.16,0.64,0.61,1.0,_upper)

	for x: float in [-4.42,4.42]:
		var side: float = signf(x)
		_octagon("Bridge transverse lookout",Vector3(x,12.85,-28.7),2.1,0.95,3.1,0.4,_steel)
		_octagon("Aft walkway lookout",Vector3(x,11.87,32.0),2.25,0.93,2.6,0.46,_upper)
		_box("Aft access ladder shadow",Vector3(side*7.0,7.92,36),Vector3(0.14,2.60,1.18),_dark)
		for step: int in range(5):
			_box("Aft access ladder rung",Vector3(side*7.10,6.94+step*0.44,36),Vector3(0.25,0.12,1.11),_steel)
		_spar("Foredeck anchor chain",Vector3(side*0.81,_deck_height(-78.7)+0.07,-78.7),Vector3(side*1.03,_deck_height(-90.0)+0.07,-90.0),0.17,_dark)
	var service: Array[Vector3] = [Vector3(0,10.25,-25),Vector3(-4.4,10.33,-22),Vector3(4.4,10.33,-22),Vector3(0,10.05,14.1)]
	for spot: Vector3 in service:
		_octagon("Service enclosure",spot,3.0,1.45,4.0,0.54,_steel)
	_octagon("Bridge top observation silhouette",Vector3(0,18.28,-32.18),2.27,0.85,2.54,0.44,_upper)
	_octagon("Aft top observation silhouette",Vector3(0,14.38,32.12),2.27,0.85,2.54,0.44,_upper)


func _underwater_fittings() -> void:
	# Exterior visual tokens only. No propulsion mesh, axes or control wiring.
	_octagon("Rudder silhouette",Vector3(0,-2.36,86.4),0.45,4.10,3.80,0.18,_underbody)
	for x: float in [-3.6,-1.85,1.85,3.6]:
		var z: float = 76.3 if absf(x) > 3.0 else 81.2
		var p := Vector3(x,-2.63,z)
		_spar("Stern fitting support",Vector3(x*0.78,-1.56,z-7.7),p,0.29,_underbody)
		var hub: MeshInstance3D = _pipe("Propeller silhouette hub",p,1.15,0.28,0.22,1.0,_underbody)
		hub.rotation.x = PI*0.5
		for j: int in range(3):
			var angle: float = TAU*float(j)/3.0
			var direction := Vector3(cos(angle),sin(angle),0.0)
			_spar("Propeller silhouette blade",p+direction*0.1,p+direction*1.12+Vector3.BACK*0.20,0.28,_underbody)
